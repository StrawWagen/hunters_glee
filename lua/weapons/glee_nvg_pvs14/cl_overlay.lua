-- The haptic goggles' overlay, included by cl_init.lua
-- a screen stuck to the wearer's face, nothing on it is pinned to the world
-- the cone, the sweep's trail, the settings under them, and a box round where each contact's rays went out
-- drawOverlay at the bottom ties it together

local haptic = SWEP.Haptic
local bandOutline = haptic.bandOutline
local followShare = haptic.followShare
local contacts = haptic.contacts
local slices = haptic.slices
local trailSlices = haptic.trailSlices
local radarRunning = haptic.radarRunning
local retiredFade = haptic.retiredFade

local style = terminator_Extras.glee_Style( "hl2" )

-- all of it is the style's text colour, targets too, whoever they are
-- how faint each part is lives here, as a share of the role's own alpha, so a style's palette carries over whole
local deviceRole = "text"

-- two strengths for the whole overlay: the squares, and everything else
-- the squares are fainter, where they overlap they add up, and a crowd of them outshone the edge
local hudAlpha = 0.6 -- the edge, the boxes, the text and the lines
local squareAlpha = 0.18 -- a square as it appears, the trail's head and the hits

-- every size here is in 1080p pixels, times the style's scale, but the squares', which are in grid cells

-- n pixels, rounded to whole ones, never under one
local function wholePixels( n )
    return math.max( 1, math.Round( n ) )

end


-- Where things land on screen ------------------------------------------------
-- everything is local to the eyes, and the screen is stuck to them, so a direction goes straight onto it
-- never out into the world and back with ToScreen, floats at map coordinates come back a hundredth of a pixel off
-- whenever you move, and that's enough to flip which pixel the text rounds to, it jiggled

local forwardLocal = Vector( 1, 0, 0 )
local screenMidX, screenMidY = 0, 0
local focal = 1 -- in pixels, how far off the middle a direction one unit to the side of one unit forward lands

local function setView()
    local view = render.GetViewSetup()
    screenMidX = view.x + view.width * 0.5
    screenMidY = view.y + view.height * 0.5
    focal = view.width * 0.5 / math.tan( math.rad( view.fov * 0.5 ) )

end

-- a direction local to the eyes to where it lands on screen. nil if it's behind
-- off screen ones still project, the cone's outline runs off the screen at wide cones, and a line
-- that stops at the edge reads as a gap
local function faceToScreen( localDir )
    local ahead, leftward, upward = localDir:Unpack()
    if ahead <= 0.01 then return end

    return screenMidX - focal * leftward / ahead, screenMidY - focal * upward / ahead

end

-- one of the sweep's grid cells across, on screen at the cone's middle, set every frame
-- the squares are sized in these, so zooming in grows them along with the gaps between them
local cellPx = 1
local cellProbe = Vector()

local function measureCell( wep, centerX, centerY )
    local cell = haptic.gridCell( wep )
    cellProbe:SetUnpacked( 1, cell, 0 )
    local x, y = faceToScreen( cellProbe )
    cellPx = math.sqrt( ( x - centerX ) ^ 2 + ( y - centerY ) ^ 2 )

end

-- n cells across, in whole pixels, never under one
local function cellsToPx( cells )
    return wholePixels( cells * cellPx )

end


-- The cone -------------------------------------------------------------------
-- its edge, in three rings: the thick one on the cone's own line, then two thinner ones a
-- 4px gap outside each. offsets are from the cone's own line to the middle of the ring, so
-- the clear space stays even whatever the widths are

local coneRings = {
    { offset = 0, width = 3 },
    { offset = 6.5, width = 2 },
    { offset = 12, width = 1 },
}

-- a ring's width is a count of one-pixel lines, not a length, so it cannot be scaled after the fact:
-- the set for a given scale is built once and handed back, one entry per ring either way
local coneRingsScaled, coneRingsScale
local function ringsFor( scale )
    if coneRingsScale == scale then return coneRingsScaled end

    coneRingsScale, coneRingsScaled = scale, {}

    for i, ring in ipairs( coneRings ) do
        coneRingsScaled[i] = {
            offset = ring.offset * scale,
            width = wholePixels( ring.width * scale ),
        }
    end

    return coneRingsScaled

end

-- the outline on screen, and its lowest and highest y. the points are kept and written over
local outlinePoints = {}

local function projectOutline( wep )
    local count, lowest, highest = 0, nil, nil

    for _, localDir in ipairs( bandOutline( math.rad( wep:CurrentCone() / 2 ) ) ) do
        local x, y = faceToScreen( localDir )
        if x then
            local previous = outlinePoints[count]
            -- a zero-length segment has no direction to lay a ring's width along
            if not previous or math.abs( x - previous.x ) > 0.01 or math.abs( y - previous.y ) > 0.01 then
                count = count + 1
                local point = outlinePoints[count] or {}
                outlinePoints[count] = point
                point.x, point.y = x, y
                if not lowest or y > lowest then lowest = y end
                if not highest or y < highest then highest = y end

            end
        end
    end

    -- the generator ends where it started, drop that copy of the first point too
    if count > 1 then
        local first, final = outlinePoints[1], outlinePoints[count]
        if math.abs( first.x - final.x ) < 0.01 and math.abs( first.y - final.y ) < 0.01 then
            count = count - 1

        end
    end
    for i = #outlinePoints, count + 1, -1 do
        outlinePoints[i] = nil

    end

    return outlinePoints, lowest, highest

end

-- surface.DrawLine is one pixel wide whatever it is handed, so a ring of width n is n of them side by side
-- (not surface.DrawCircle, that draws solid whatever alpha it's handed)
-- each line is the outline pushed outwards, every corner along the line halfway between its two segments,
-- so neighbouring segments share their corner and none is left open

local maxCornerStretch = 2.5 -- a sharp corner has to go further to keep its distance, this far at most, or a hairpin throws a spike

-- the segment's normal, pointing away from the cone's middle. nil if it's too short to have a direction
local function segmentNormal( from, to, middleX, middleY )
    local alongX, alongY = to.x - from.x, to.y - from.y
    local length = math.sqrt( alongX * alongX + alongY * alongY )
    if length < 0.001 then return end

    local normalX, normalY = alongY / length, -alongX / length
    local pointsInwards = normalX * ( from.x - middleX ) + normalY * ( from.y - middleY ) < 0
    if pointsInwards then normalX, normalY = -normalX, -normalY end
    return normalX, normalY

end

-- per outline point, which way its corner is pushed, and how much further than a straight edge would be
local cornerX, cornerY, cornerStretch = {}, {}, {}

local function measureCorners( points, middleX, middleY )
    local count = #points

    for i = 1, count do
        local previous = points[( i - 2 ) % count + 1]
        local point = points[i]
        local nextPoint = points[i % count + 1]
        local inX, inY = segmentNormal( previous, point, middleX, middleY )
        local outX, outY = segmentNormal( point, nextPoint, middleX, middleY )

        -- a segment with no direction borrows its neighbour's
        inX, inY = inX or outX, inY or outY
        outX, outY = outX or inX, outY or inY

        if not inX then
            cornerX[i], cornerY[i], cornerStretch[i] = 0, 0, 0

        else
            local halfwayX, halfwayY = inX + outX, inY + outY
            local length = math.sqrt( halfwayX * halfwayX + halfwayY * halfwayY )

            if length > 0.001 then
                halfwayX, halfwayY = halfwayX / length, halfwayY / length
                cornerX[i], cornerY[i] = halfwayX, halfwayY
                -- the sharper the corner, the less the halfway line lines up with either segment's normal
                local lineUp = halfwayX * inX + halfwayY * inY
                cornerStretch[i] = math.min( 1 / lineUp, maxCornerStretch )

            else
                -- a full turn back, the two normals cancel out
                cornerX[i], cornerY[i], cornerStretch[i] = outX, outY, 1

            end
        end
    end

end

-- one ring of the edge: a line per pixel of its width, each walking the same loop a pixel further
-- out. offsets are snapped to whole pixels, because a line laid down on a fraction of one covers
-- two of them at half strength and the ring reads thicker than it is
local function drawRing( points, ring )
    local count = #points
    local innermost = math.Round( ring.offset - ( ring.width - 1 ) * 0.5 )

    for pixel = 0, ring.width - 1 do
        local push = innermost + pixel

        for i = 1, count do
            local nextI = i % count + 1
            local fromPush = push * cornerStretch[i]
            local toPush = push * cornerStretch[nextI]

            surface.DrawLine(
                points[i].x + cornerX[i] * fromPush, points[i].y + cornerY[i] * fromPush,
                points[nextI].x + cornerX[nextI] * toPush, points[nextI].y + cornerY[nextI] * toPush )
        end
    end

end

local function drawCone( outline, axisX, axisY, scale )
    local color = style:Color( deviceRole )
    surface.SetDrawColor( color.r, color.g, color.b, color.a * hudAlpha )
    measureCorners( outline, axisX, axisY )
    for _, ring in ipairs( ringsFor( scale ) ) do
        drawRing( outline, ring )

    end
end


-- The sweep's trail ----------------------------------------------------------
-- the sweep's last moments, the newest big and bright, the older shrinking and dimming behind it
-- by age, not by frame, so the trail's the same length at any framerate
-- plain squares, small enough to leave gaps between the grid's points
-- where they overlap they add up, so the freshest edge still stands out on its own

local headSize, tailSize = 0.5, 0.25 -- in grid cells, across a square, the newest's and the oldest's
local tailAlpha = 0.15 -- the oldest's brightness, as a share of the newest's
local trailTime = 0.1 -- seconds, how far back the trail reaches

local function drawTrail()
    local color = style:Color( deviceRole )
    local now = CurTime()
    local newest = haptic.newestSlice()

    -- oldest first, so the newest lands on top
    for back = trailSlices - 1, 0, -1 do
        local slice = slices[( newest - 1 - back ) % trailSlices + 1]
        local born = slice.born
        if born and now - born < trailTime then
            local t = ( now - born ) / trailTime
            local size = cellsToPx( Lerp( t, headSize, tailSize ) )
            local half = size * 0.5
            local alpha = color.a * squareAlpha * Lerp( t, 1, tailAlpha )
            surface.SetDrawColor( color.r, color.g, color.b, alpha )

            local dirs = slice.dirs
            local count = #dirs
            for n = 0, slice.count - 1 do
                local x, y = faceToScreen( dirs[( slice.first - 1 + n ) % count + 1] )
                if x then surface.DrawRect( math.floor( x - half ), math.floor( y - half ), size, size ) end

            end
        end
    end
end


-- The contacts ---------------------------------------------------------------
-- a box round where its live hits' rays went out, never the thing itself: that would follow it
-- through walls between sweeps, and give away its whole size off one grazing ray
-- brackets when any ray saw it with nothing in the way, a full outline when they all came through something

local boxPad = 5 -- added round each side of the hits
local boxLine = 2
local bracketShare = 0.3 -- of the box's shorter side, how long each bracket's arm is
local bracketMax = 14
-- per second, how quickly the box follows its hits, size and middle both
-- a new sweep moves its hits, and the box glides there instead of jumping, a jump every sweep reads as a flicker
local boxEase = 14
local hitSize = 0.25 -- in grid cells, across each hit's square, the trail's tail size, so they don't merge

-- newly caught, the box is knocked once and settles
-- once per beep, never per sweep. a box flickering at the sweep's rate is a photosensitivity risk
local catchKick = 4
local catchDecay = 10 -- per second

-- the box's corners, each an arm along the top or bottom and one down the side
local function drawBrackets( x, y, w, h, line, arm )
    local right, bottom = x + w - line, y + h - line

    surface.DrawRect( x, y, arm, line )
    surface.DrawRect( x, y, line, arm )
    surface.DrawRect( x + w - arm, y, arm, line )
    surface.DrawRect( right, y, line, arm )
    surface.DrawRect( x, bottom, arm, line )
    surface.DrawRect( x, y + h - arm, line, arm )
    surface.DrawRect( x + w - arm, bottom, arm, line )
    surface.DrawRect( right, y + h - arm, line, arm )

end

-- each hit's square, fading as it retires
-- returns the live hits' bounds on screen, and whether any of them was bare. nothing if none are live and on screen
-- the box is the live hits' alone, the retired ones are only fading out
local function drawHits( contact, color )
    local size = cellsToPx( hitSize )
    local half = size * 0.5
    local minX, minY, maxX, maxY
    local anyBare = false

    for i = 1, contact.hitCount do
        local hit = contact.hits[i]
        local hitFade, live = retiredFade( hit )
        local x, y
        if hitFade > 0 then x, y = faceToScreen( hit.dir ) end

        if x then
            surface.SetDrawColor( color.r, color.g, color.b, color.a * squareAlpha * hitFade )
            surface.DrawRect( math.floor( x - half ), math.floor( y - half ), size, size )

            if live then
                minX, maxX = math.min( minX or x, x ), math.max( maxX or x, x )
                minY, maxY = math.min( minY or y, y ), math.max( maxY or y, y )
                anyBare = anyBare or hit.bare

            end
        end
    end

    if not minX then return end
    return minX, minY, maxX, maxY, anyBare

end

-- where the box is heading, filled before every followBox
local boxTarget = {}

-- glides the contact's box towards target, or snaps straight there
local function followBox( contact, target, snap )
    if snap then
        contact.boxMidX, contact.boxMidY = target.midX, target.midY
        contact.boxHalfW, contact.boxHalfH = target.halfW, target.halfH
        return

    end

    local share = followShare( boxEase )
    contact.boxMidX = Lerp( share, contact.boxMidX, target.midX )
    contact.boxMidY = Lerp( share, contact.boxMidY, target.midY )
    contact.boxHalfW = Lerp( share, contact.boxHalfW, target.halfW )
    contact.boxHalfH = Lerp( share, contact.boxHalfH, target.halfH )

end

-- how far the catch kick throws the box right now, a fresh way on each beep
local function catchKickOffset( contact, scale )
    if contact.kickedAt ~= contact.beepedAt then
        contact.kickedAt = contact.beepedAt
        local way = math.Rand( 0, math.pi * 2 )
        contact.kickX, contact.kickY = math.cos( way ), math.sin( way )

    end

    local kick = catchKick * scale * math.exp( -( CurTime() - contact.beepedAt ) * catchDecay )
    return contact.kickX * kick, contact.kickY * kick

end

local function drawContact( contact, scale )
    -- the box lasts as long as its newest hit
    local fade = retiredFade( contact )
    if fade <= 0 then return end

    local color = style:Color( deviceRole )
    local minX, minY, maxX, maxY, anyBare = drawHits( contact, color )

    -- every hit retired, the box fades where it last was
    -- not drawn last frame, the radar was off or it was off screen, so it snaps rather than grows in from stale
    local frame = FrameNumber()
    local drawnLastFrame = contact.boxFrame == frame - 1
    if minX then
        local pad = boxPad * scale
        boxTarget.midX = ( minX + maxX ) * 0.5
        boxTarget.midY = ( minY + maxY ) * 0.5
        boxTarget.halfW = ( maxX - minX ) * 0.5 + pad
        boxTarget.halfH = ( maxY - minY ) * 0.5 + pad
        followBox( contact, boxTarget, not drawnLastFrame )
        contact.boxBare = anyBare

    elseif not drawnLastFrame then
        return

    end
    contact.boxFrame = frame

    local kickX, kickY = catchKickOffset( contact, scale )
    local midX, midY = contact.boxMidX + kickX, contact.boxMidY + kickY

    -- each edge rounded on its own, so a gliding box slides whole instead of its far edges twitching
    local x = math.Round( midX - contact.boxHalfW )
    local y = math.Round( midY - contact.boxHalfH )
    local w = math.Round( midX + contact.boxHalfW ) - x
    local h = math.Round( midY + contact.boxHalfH ) - y
    local line = wholePixels( boxLine * scale )

    surface.SetDrawColor( color.r, color.g, color.b, color.a * hudAlpha * fade )
    if contact.boxBare then
        local arm = math.max( line, math.floor( math.min( bracketMax * scale, math.min( w, h ) * bracketShare ) ) )
        drawBrackets( x, y, w, h, line, arm )

    else
        surface.DrawOutlinedRect( x, y, w, h, line )

    end

    -- for its name's line, see drawNames. the drawn box's middle, so the line moves with it
    contact.boxCenterX, contact.boxCenterY, contact.boxFade = x + w * 0.5, y + h * 0.5, fade

end

local function drawContacts( scale )
    for _, contact in pairs( contacts ) do
        drawContact( contact, scale )

    end
end


-- The text -------------------------------------------------------------------
-- the settings under the cone, the targets' names over it
-- printed like the cone, same colour, same faintness, no shadow
-- side by side, stacked up on the narrowest cone, where a line would stick out past it either side

local textFont = "small"
local textGap = 12 -- off the cone's outermost ring, and off the screen's edge
local textSeparator = "     "
local textColor = Color( 0, 0, 0 ) -- scratch, the role's colour is copied in each time

local function isStacked( wep )
    return wep:CurrentCone() == math.min( unpack( wep.Cones ) )

end

-- how far past the cone's own line the text sits
local function textClearance( scale )
    return ( coneRings[#coneRings].offset + textGap ) * scale

end

-- the row's pieces, measured, kept and written over
local pieceW, pieceH = {}, {}

-- pieces[1] to pieces[count], the whole row's width and height
local function measureRow( pieces, count, stacked )
    local totalW, totalH = 0, 0
    for i = 1, count do
        local w, h = style:Measure( pieces[i], textFont )
        pieceW[i], pieceH[i] = w, h
        if stacked then
            totalW, totalH = math.max( totalW, w ), totalH + h

        else
            totalW, totalH = totalW + w, math.max( totalH, h )

        end
    end

    if not stacked and count > 1 then
        totalW = totalW + style:Measure( textSeparator, textFont ) * ( count - 1 )

    end
    return totalW, totalH

end

-- the row measureRow just measured, centred on x, top at y
-- alphas[i] is each piece's share of the faintness, nil for all of it
-- each piece's left edge goes in startX[i], its bottom right corner in endX[i], endY[i]
local startX, endX, endY = {}, {}, {}

local function drawRow( pieces, count, stacked, totalW, x, y, alphas )
    local color = style:Color( deviceRole )
    local font = style:Font( textFont )
    local gap = not stacked and style:Measure( textSeparator, textFont ) or 0
    -- text only lands on whole pixels, so it's snapped here, before the ends are kept
    -- left to draw.SimpleText, it rounds its own way, and the lines off the ends jiggle against it
    local left = math.Round( x - totalW * 0.5 )
    y = math.Round( y )

    for i = 1, count do
        local w, h = pieceW[i], pieceH[i]
        local pieceX = stacked and math.Round( x - w * 0.5 ) or left

        textColor:SetUnpacked( color.r, color.g, color.b, color.a * hudAlpha * ( alphas and alphas[i] or 1 ) )
        draw.SimpleText( pieces[i], font, pieceX, y, textColor )
        startX[i], endX[i], endY[i] = pieceX, pieceX + w, y + h

        if stacked then
            y = y + h

        else
            left = left + w + gap

        end
    end
end


-- The settings ---------------------------------------------------------------
-- under the cone, the wheel's settings with their names in full

local radarOff = { "RADAR: OFF" }
local readout = {}
local readoutWavelength, readoutResolution, readoutCone

-- rebuilt only when a setting changes
local function readoutFor( wep )
    local wavelength = wep:CurrentWavelength()
    local resolution = wep:CurrentResolution()
    local cone = wep:CurrentCone()
    if wavelength == readoutWavelength and resolution == readoutResolution and cone == readoutCone then return readout end

    readoutWavelength, readoutResolution, readoutCone = wavelength, resolution, cone
    readout[1] = string.upper( "Wavelength: " .. ( wavelength.fullName or wavelength.name ) )
    readout[2] = string.upper( "Resolution: " .. resolution.name )
    readout[3] = string.upper( "Field of View: " .. cone .. "°" )
    return readout

end

-- centred on x, below lowest, kept on screen
local function drawReadout( wep, pieces, x, lowest, scale )
    local stacked = isStacked( wep )
    local totalW, totalH = measureRow( pieces, #pieces, stacked )
    local y = math.min( lowest + textClearance( scale ), ScrH() - totalH - textGap * scale )
    drawRow( pieces, #pieces, stacked, totalW, x, y )

end


-- The names ------------------------------------------------------------------
-- over the cone, one per name, however many share it, alphabetical so they keep their places
-- each underlined, a line from the underline's end down to the middle of every box going by it

local names, nameAlphas = {}, {}
local nameIndex = {} -- [name] = its place in names, this frame

local function drawNames( wep, x, highest, scale )
    local frame = FrameNumber()
    local count = 0
    table.Empty( nameIndex )

    -- only the boxes drawContact drew this frame
    for _, contact in pairs( contacts ) do
        if contact.boxFrame == frame and not nameIndex[contact.name] then
            count = count + 1
            names[count] = contact.name
            nameIndex[contact.name] = count

        end
    end
    for i = #names, count + 1, -1 do
        names[i] = nil

    end
    if count <= 0 then return end

    table.sort( names )
    for i = 1, count do
        nameIndex[names[i]] = i
        nameAlphas[i] = 0

    end

    -- a name's as faint as the freshest box going by it
    for _, contact in pairs( contacts ) do
        if contact.boxFrame == frame then
            local i = nameIndex[contact.name]
            nameAlphas[i] = math.max( nameAlphas[i], contact.boxFade )

        end
    end

    local stacked = isStacked( wep )
    local totalW, totalH = measureRow( names, count, stacked )
    local y = math.max( highest - textClearance( scale ) - totalH, textGap * scale )
    drawRow( names, count, stacked, totalW, x, y, nameAlphas )

    local color = style:Color( deviceRole )

    -- underlined, so the lines run out of the name instead of starting off its corner
    for i = 1, count do
        surface.SetDrawColor( color.r, color.g, color.b, color.a * hudAlpha * nameAlphas[i] )
        surface.DrawLine( startX[i], endY[i], endX[i], endY[i] )

    end

    for _, contact in pairs( contacts ) do
        if contact.boxFrame == frame then
            local i = nameIndex[contact.name]
            surface.SetDrawColor( color.r, color.g, color.b, color.a * hudAlpha * contact.boxFade )
            surface.DrawLine( endX[i], endY[i], contact.boxCenterX, contact.boxCenterY )

        end
    end
end


-- Drawing it all -------------------------------------------------------------

-- every frame they're worn. flipped down with the radar off, only says so, where the settings would be
local function drawOverlay( wep, wearer )
    if not wep:IsGleeSeeing( wearer ) then return end

    setView()

    local scale = style:ScaledExact( 1 )
    local running = radarRunning( wep, wearer )

    local axisX, axisY = faceToScreen( forwardLocal )
    measureCell( wep, axisX, axisY )

    local outline, lowest, highest = projectOutline( wep )
    lowest, highest = lowest or axisY, highest or axisY

    if not running then
        drawReadout( wep, radarOff, axisX, lowest, scale )
        return

    end

    drawCone( outline, axisX, axisY, scale )
    drawTrail()
    drawContacts( scale )
    drawNames( wep, axisX, highest, scale )
    drawReadout( wep, readoutFor( wep ), axisX, lowest, scale )

end


-- What the other files use --------------------------------------------------

haptic.drawOverlay = drawOverlay
