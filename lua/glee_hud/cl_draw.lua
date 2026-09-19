--[[------------------------------------
    The drawing primitives every style is built out of. None of them know what a style
    is; they take settings tables and draw. Add a new decoration here, then point a
    style's background at it.
--]]-------------------------------------

terminator_Extras.glee_HudHelpers = terminator_Extras.glee_HudHelpers or {}
local hudHelpers = terminator_Extras.glee_HudHelpers


-- Text ----------------------------------------------------------------------

-- Measures whole lines, not words, so kerning can't push a line past maxWidth.
-- A word wider than maxWidth overflows on its own line
function hudHelpers.WrapText( text, font, maxWidth )
    surface.SetFont( font )
    local lines = {}

    for _, paragraph in ipairs( string.Explode( "\n", text, false ) ) do
        local line = ""

        for _, word in ipairs( string.Explode( " ", paragraph, false ) ) do
            local try = ( line == "" ) and word or ( line .. " " .. word )

            if line ~= "" and surface.GetTextSize( try ) > maxWidth then
                lines[#lines + 1] = line
                line = word

            else
                line = try

            end
        end

        lines[#lines + 1] = line

    end

    return table.concat( lines, "\n" )

end

-- The 1.2 has to match drawShadowedTextBetterData's line spacing
function hudHelpers.MeasureText( text, font )
    surface.SetFont( font )
    local lines = string.Explode( "\n", text, false )
    local widest = 0
    local height = 0

    for ind, line in ipairs( lines ) do
        local lineWidth, lineHeight = surface.GetTextSize( line )
        widest = math.max( widest, lineWidth )

        if ind < #lines then
            height = height + ( lineHeight * 1.2 )

        else
            height = height + lineHeight

        end
    end

    return widest, height

end


-- Sound ---------------------------------------------------------------------

-- surface.PlaySound has no pitch arg. volume defaults to 0.5, level to 75
function hudHelpers.PlaySound( sounds, pitch, channel, volume, level )
    LocalPlayer():EmitSound( sounds[math.random( 1, #sounds )], level or 75, pitch, volume or 0.5, channel )

end


-- Ghosts --------------------------------------------------------------------

-- Ghosts are faint copies of a message that spiral onto it as it arrives
function hudHelpers.BuildGhosts( ghostSettings )
    local ghosts = {}

    for ind = 1, ghostSettings.count do
        local orbit = math.rad( math.Rand( ghostSettings.orbitMin, ghostSettings.orbitMax ) )
        if math.random( 2 ) == 1 then -- half of them sweep the other way round
            orbit = -orbit

        end

        ghosts[ind] = {
            angle = math.rad( math.Rand( 0, 360 ) ),
            spread = math.Rand( ghostSettings.spreadMin, ghostSettings.spreadMax ),
            orbit = orbit,
            startAt = math.Rand( 0, ghostSettings.startSpread ),
            progress = 0,
            eased = 0,
        }
    end

    return ghosts

end

-- Returns how many ghosts appeared this call
function hudHelpers.AdvanceGhosts( ghosts, elapsed, ghostSettings )
    local appeared = 0

    for _, ghost in ipairs( ghosts ) do
        local progress = math.Clamp( ( elapsed - ghost.startAt ) / ghostSettings.mergeTime, 0, 1 )
        ghost.progress = progress
        ghost.eased = 1 - ( ( 1 - progress ) ^ 3 )

        if progress > 0 and not ghost.appeared then
            ghost.appeared = true
            appeared = appeared + 1

        end
    end

    return appeared

end

-- 0 to 1, reaching 1 as the last ghost lands
function hudHelpers.GhostsMaterialised( elapsed, ghostSettings )
    return math.Clamp( elapsed / ( ghostSettings.startSpread + ghostSettings.mergeTime ), 0, 1 )

end

-- Writes the alpha of data's colors, so pass copies, never a style's own
function hudHelpers.DrawGhosts( ghosts, ghostSettings, data, landingX, landingY )
    local textColor = data.textColor
    local shadowColor = data.shadowColor

    for _, ghost in ipairs( ghosts ) do
        if ghost.progress <= 0 then continue end

        local eased = ghost.eased

        -- peaks halfway in, gone once it lands
        local fade = math.sin( eased * math.pi )
        textColor.a = ghostSettings.peakAlpha * fade
        shadowColor.a = ghostSettings.peakAlpha * fade

        local angle = ghost.angle + ( ghost.orbit * eased )
        local dist = ghost.spread * ( 1 - eased )

        data.posX = landingX + ( math.cos( angle ) * dist )
        data.posY = landingY + ( math.sin( angle ) * dist )
        surface.drawShadowedTextBetterData( data )

    end
end

-- The ghosts still on their way in, then the solid text behind them, at x, y.
-- materialised is from GhostsMaterialised. ghostData and solidData are drawShadowedTextBetterData
-- tables, ghostData's colors have to be copies, see DrawGhosts
function hudHelpers.DrawArrivingText( ghosts, ghostSettings, ghostData, solidData, x, y, materialised )
    if ghosts and materialised < 1 then
        hudHelpers.DrawGhosts( ghosts, ghostSettings, ghostData, x, y )

    end

    solidData.posX = x
    solidData.posY = y

    -- squared, so the solid copy stays hidden while the ghosts are still spread out
    local oldMultiplier = surface.GetAlphaMultiplier()
    surface.SetAlphaMultiplier( oldMultiplier * ( materialised ^ 2 ) )
    surface.drawShadowedTextBetterData( solidData )
    surface.SetAlphaMultiplier( oldMultiplier )

end


-- Blot ----------------------------------------------------------------------

-- A soft dark smudge behind text. Spills past x, y, w, h, and past the panel's bounds.
-- blot is settings like the soulthought style's blot, state a key of its colors
function hudHelpers.DrawBlot( blot, x, y, w, h, state )
    local color = blot.colors[state]

    local blotX = x - blot.spillX
    local blotY = y - blot.spillY
    local blotW = w + ( blot.spillX * 2 )
    local blotH = h + ( blot.spillY * 2 )

    local wasClipping = DisableClipping( true )

    for layer = 0, blot.layers - 1 do
        local insetX = layer * blot.insetX
        local insetY = layer * blot.insetY
        local layerW = blotW - ( insetX * 2 )
        local layerH = blotH - ( insetY * 2 )

        if layerW <= 0 or layerH <= 0 then break end

        local cornerRad = math.floor( layerH / 2.5 )
        draw.RoundedBox( cornerRad, blotX + insetX, blotY + insetY, layerW, layerH, color )

    end

    DisableClipping( wasClipping )

end


-- Torn strip ----------------------------------------------------------------

-- surface.DrawPoly wants convex shapes, wound clockwise
local tornQuad = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }

local function drawQuad( x1, y1, x2, y2, x3, y3, x4, y4 )
    tornQuad[1].x, tornQuad[1].y = x1, y1
    tornQuad[2].x, tornQuad[2].y = x2, y2
    tornQuad[3].x, tornQuad[3].y = x3, y3
    tornQuad[4].x, tornQuad[4].y = x4, y4
    surface.DrawPoly( tornQuad )

end

local function makeRipReaches( settings, rows )
    local topReach = math.Rand( 0, settings.ripReachMax )
    local bottomReach = math.Rand( 0, settings.ripReachMax )

    local reaches = {}
    for ind = 1, rows + 1 do
        local slant = Lerp( ( ind - 1 ) / rows, topReach, bottomReach )
        reaches[ind] = math.max( slant + math.Rand( -settings.ripNoise, settings.ripNoise ), 0 )

    end
    return reaches

end

-- Rerolled only when the strip's size changes, so the tears hold still between frames
local function getTornShape( settings, cache, segments, rows )
    local shape = cache.tornShape
    if shape and shape.segments == segments and shape.rows == rows then return shape end

    shape = { segments = segments, rows = rows, top = {}, bottom = {} }
    for ind = 1, segments + 1 do
        shape.top[ind] = math.Rand( 0, settings.tearDepth )
        shape.bottom[ind] = math.Rand( 0, settings.tearDepth )

    end
    shape.left = makeRipReaches( settings, rows )
    shape.right = makeRipReaches( settings, rows )

    cache.tornShape = shape
    return shape

end

-- A dark strip ripped out of a page, jagged along the top and bottom, its ends torn off at a slant.
-- The ends spill past x and x + w, and past the panel's bounds.
-- settings is like the god style's tornStrip, state a key of its colors.
-- cache is any table that lives as long as the strip, the torn shape is kept on it.
function hudHelpers.DrawTornStrip( settings, x, y, w, h, state, cache )
    local segments = math.max( math.ceil( w / settings.tearSegment ), 1 )
    local rows = math.max( math.ceil( h / settings.ripRowStep ), 1 )
    local shape = getTornShape( settings, cache, segments, rows )

    local wasClipping = DisableClipping( true )
    draw.NoTexture()
    surface.SetDrawColor( settings.colors[state] )

    local segmentW = w / segments
    for ind = 1, segments do
        local leftX = x + ( ind - 1 ) * segmentW
        local rightX = leftX + segmentW
        drawQuad(
            leftX, y + shape.top[ind],
            rightX, y + shape.top[ind + 1],
            rightX, y + h - shape.bottom[ind + 1],
            leftX, y + h - shape.bottom[ind]
        )
    end

    -- each end spans the height of the strip's outermost column
    local last = segments + 1
    local rightX = x + w
    local leftTop = y + shape.top[1]
    local leftRowH = ( y + h - shape.bottom[1] - leftTop ) / rows
    local rightTop = y + shape.top[last]
    local rightRowH = ( y + h - shape.bottom[last] - rightTop ) / rows

    for row = 1, rows do
        local leftY1 = leftTop + ( row - 1 ) * leftRowH
        drawQuad(
            x - shape.left[row], leftY1,
            x, leftY1,
            x, leftY1 + leftRowH,
            x - shape.left[row + 1], leftY1 + leftRowH
        )

        local rightY1 = rightTop + ( row - 1 ) * rightRowH
        drawQuad(
            rightX, rightY1,
            rightX + shape.right[row], rightY1,
            rightX + shape.right[row + 1], rightY1 + rightRowH,
            rightX, rightY1 + rightRowH
        )
    end

    DisableClipping( wasClipping )

end


-- Motion --------------------------------------------------------------------

-- 0 to 1, eased. Each order starts arrivalSettings.stagger later
function hudHelpers.ArrivalProgress( openedAt, order, arrivalSettings )
    local startAt = openedAt + ( order * arrivalSettings.stagger )
    local progress = math.Clamp( ( CurTime() - startAt ) / arrivalSettings.time, 0, 1 )

    return 1 - ( ( 1 - progress ) ^ 3 )

end

-- Keeps jitterX and jitterY on whatever table you hand it, ready for a draw position to add.
-- Owns its own clock, a per frame reroll is a buzz nobody can see and it would shake harder
-- the better your hardware is. Safe to call every frame, it only rerolls when it's due.
-- jitterSettings is like the god style's jitter
function hudHelpers.DoJitter( state, jitterSettings )
    if state.nextJitter and state.nextJitter > CurTime() then return end

    local interval = jitterSettings.interval
    state.nextJitter = CurTime() + math.Rand( interval[1], interval[2] )

    local pixels = jitterSettings.pixels
    state.jitterX = math.random( -pixels, pixels )
    state.jitterY = math.random( -pixels, pixels )

end
