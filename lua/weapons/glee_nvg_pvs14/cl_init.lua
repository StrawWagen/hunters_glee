include( "shared.lua" )

DEFINE_BASECLASS( "glee_nvg_base" )

-- the haptic goggles' radar, all clientside, only the wearer sees the cone and its marks
-- the radar runs from SetupWear, at the bottom

-- The radar ------------------------------------------------------------------

local pierceStep = 8 -- how finely the far side of a wall is looked for, smaller is exact but more traces
local maxWalls = 12 -- most separate pieces of solid one ray goes into
local minPierceCost = 32 -- least a single piece of solid can cost, in pierce units. thin shells - terrain
-- displacements, thin brushes - measure as barely anything thick, so without a floor a ray slips through
-- a hill for a couple of units and quietly crosses the whole map
local detectLife = 10 -- a target counts as new again after this long without being hit
local detectSound = "buttons/combine_button7.wav" -- combine terminal chirp, short and electronic

local coneColor = Color( 255, 200, 30, 51 ) -- HL2 hud yellow, 80% transparent so the map reads straight through it
local markSize = 3
local markColorPlayer = Color( 70, 150, 255 ) -- other people read blue
local markColorOther = Color( 255, 60, 60 ) -- everything else, NPCs and the evil creatures, reads red
local maxMarks = 200

local scanColor = Color( 15, 90, 30, 77 ) -- dark green, 70% see through: where the sweep is right now
local scanLife = 0.2 -- how long the sweep's band hangs on screen after a slice
local scanSize = 2
-- the cone's edge, in three rings: the thick one on the cone's own line, then two thinner ones a
-- 4px gap outside each at 1080p. offsets are from the cone's own line to the middle of the ring, so
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
            width = math.max( 1, math.floor( ring.width * scale + 0.5 ) ),
        }
    end

    return coneRingsScaled

end
local scanHead = {} -- the slice fired last frame, for drawing the sweep's band

local detected = {} -- [ent] = { pos = where it was last hit, seen = when }
local marks = {} -- { pos = where it was caught, color, ent, sweep, born, bare }
local scanIndex = 1 -- where the next frame's slice of the sweep starts
local sweepPass = 0 -- completed sweeps so far; each one nudges the grid to creep across the last one's gaps
local shiftSteps = 16 -- each sweep slides the grid a 16th of a cell sideways
local shiftElevSteps = 3 -- and three 16ths down

-- the sweep's hum, from the Alien: Isolation - Motion Tracker addon
-- a loop on its own channel, so it runs under the sweep instead of pinging over it
local radarLoopSound = "sound/glee/nvg/motiontracker_noise_loop.wav"
local radarLoopVolume = 0.35
local radarLoop = nil -- the playing IGModAudioChannel

local function stopRadarLoop()
    if not radarLoop then return end
    radarLoop:Stop()
    radarLoop = nil

end

local function startRadarLoop()
    if radarLoop then
        -- the file ran out before the radar did: start it again rather than going quiet
        if radarLoop:GetState() == ( GMOD_CHANNEL_STOPPED or 0 ) then
            radarLoop = nil

        else
            return

        end
    end

    sound.PlayFile( radarLoopSound, "noblock", function( channel, errID, errStr )
        if not channel then
            MsgN( "[glee] nvg radar loop failed: ", errID, " ", errStr )
            return

        end
        radarLoop = channel
        channel:SetVolume( radarLoopVolume )
        channel:Play()

    end )
end

local function radarRunning( wep, wearer )
    return wep:GetRadarOn() and wep:GetDown() and wearer:Alive()

end

local function isTarget( ent, me )
    if not IsValid( ent ) or ent == me then return false end
    if ent:IsPlayer() then return ent:Alive() end
    if ent:IsNPC() or ent:IsNextBot() then return ent:Health() > 0 end
    return false

end

-- beeps once per target, until it's gone unhit for detectLife
-- every later hit moves the record to the new spot
local function hitTarget( ent, pos )
    local record = detected[ent]
    if record then
        record.pos = pos
        record.seen = CurTime()
        return

    end
    detected[ent] = { pos = pos, seen = CurTime() }
    -- surface.PlaySound is fixed at full volume, so this is emitted instead to halve it.
    -- level 75 is normal attenuation, and the emitter is the listener, so it lands in their ears
    LocalPlayer():EmitSound( detectSound, 75, 100, 0.5 )

end

local function readsAsPlayer( ent )
    return ent:IsPlayer()

end

local function markColorFor( ent )
    return IsValid( ent ) and readsAsPlayer( ent ) and markColorPlayer or markColorOther

end

local function addMark( worldPos, color, ent, bare )
    -- caught again on a later sweep, so it has moved: its blips from the sweeps before this one go,
    -- and the cone shows where it is now instead of the trail behind it. same-sweep hits stay, a
    -- big thing can legitimately be caught on more than one ray
    if ent then
        for i = #marks, 1, -1 do
            local mark = marks[i]
            if mark.ent == ent and mark.sweep < sweepPass then table.remove( marks, i ) end

        end
    end

    if #marks >= maxMarks then table.remove( marks, 1 ) end
    marks[#marks + 1] = {
        pos = worldPos,
        color = color or markColorOther,
        born = CurTime(),
        ent = ent,
        sweep = sweepPass,
        bare = bare, -- nothing but the target on that line, see pulse
    }

end

local traceData = { mask = MASK_SHOT }
local traceResult = {}
traceData.output = traceResult

local function trace( start, endpos, filter )
    traceData.start = start
    traceData.endpos = endpos
    traceData.filter = filter
    util.TraceLine( traceData )
    return traceResult

end

local isInWall = terminator_Extras.glee_IsInWall

-- how far through the solid at entry, along dir, the far side is. nil if not within budget
-- steps forward and traces back to the entry, the first step that isn't still inside is past the far side,
-- and its trace back stops on the far side's face
-- inWorld is whether entry is on a world brush. those steps check point contents instead, far cheaper,
-- and only the step that comes out gets traced. it matters, the ground and the void past the map are
-- deeper than any budget, so every ray aimed at them walks the whole thing
local function solidThickness( me, entry, dir, budget, inWorld )
    local stepped = 0
    while stepped < budget do
        stepped = math.min( stepped + pierceStep, budget )
        local probe = entry + dir * stepped
        if not ( inWorld and isInWall( probe ) ) then
            local back = trace( probe, entry, me )
            if not back.StartSolid then
                if not back.Hit then return stepped end -- thinner than a step
                return stepped * ( 1 - back.Fraction ) -- back.Fraction is how far the far face is from probe

            end
        end
    end
end

-- knocks dir off course by degrees, around a random axis
local function deflect( dir, degrees )
    local ang = dir:Angle()
    ang:RotateAroundAxis( dir, math.Rand( 0, 360 ) )
    ang:RotateAroundAxis( ang:Up(), degrees )
    return ang:Forward()

end

-- one ray, piercing what it hits until it's out of pierce, range or walls, hits sky, or finds a target
local function castRay( me, start, dir, pierce, maxLength, deflectEvery, deflectDegrees )
    local travelled = 0
    for _ = 1, maxWalls do
        local tr = trace( start, start + dir * ( maxLength - travelled ), me )
        if not tr.Hit or tr.HitSky then return end
        if isTarget( tr.Entity, me ) then
            hitTarget( tr.Entity, tr.HitPos )
            return tr.Entity, tr.HitPos

        end

        local entry = tr.HitPos
        travelled = travelled + start:Distance( entry )
        local thickness = solidThickness( me, entry, dir, math.min( pierce, maxLength - travelled ), tr.HitWorld )
        if not thickness then return end

        -- charge the real thickness, but never less than one wall's worth: a displacement hill is a
        -- skin with no measurable depth, and it should still cost like something rather than nothing
        pierce = pierce - math.max( thickness, minPierceCost )
        travelled = travelled + thickness
        start = entry + dir * ( thickness + 1 )
        -- both numbers live on the wavelength; a wavelength that leaves either out gets a straight ray
        if deflectEvery and deflectEvery > 0 and deflectDegrees and deflectDegrees ~= 0 then
            dir = deflect( dir, thickness / deflectEvery * deflectDegrees )

        end
        if pierce <= 0 or travelled >= maxLength then return end

    end
end

-- a cone's worth of directions, filled as a grid and then ordered from the middle outwards
-- cached per cone size, point count and shift
-- shift (in cells, 0 up to 1) slides every row across and down by that fraction of a cell, so each
-- sweep samples a slightly different set of points and the gaps between them get filled in over time.
-- the two axes are separate so the drift can lean: shiftElev in cells down, shiftAz in cells left
local discCache = {}

-- the radar's cone is the circle it always was, with the top and bottom sliced off flat: a band
-- cut out of that circle. this is how tall the band is, as a fraction of the circle's radius. 1
-- would be the whole circle again, 0 a line through its middle
-- the narrow cone is small enough to be the whole circle; the wider ones flatten out to the band
local bandSquash = 0.3
local bandFullCone = 10 -- this wide, whole circle
local bandFlatCone = 40 -- this wide, the band above
local function bandOf( halfAngle )
    local cone = math.deg( halfAngle ) * 2
    if cone <= bandFullCone then return 1 end
    if cone >= bandFlatCone then return bandSquash end

    local t = ( cone - bandFullCone ) / ( bandFlatCone - bandFullCone )
    return 1 + ( bandSquash - 1 ) * t

end

-- a direction from its screen-plane offsets: u is y/x (left), v is z/x (up). the normalisation
-- keeps it a unit vector, and constant v stays level on screen, which is what makes the pancake's
-- top and bottom actually straight instead of bowed by the perspective divide
local function pancakeDir( u, v )
    local inv = 1 / math.sqrt( 1 + u * u + v * v )
    return Vector( inv, u * inv, v * inv )
end

local function discDirs( halfAngle, count, shiftAz, shiftElev )
    shiftAz = shiftAz or 0
    shiftElev = shiftElev or 0
    local key = halfAngle .. ":" .. count .. ":" .. shiftAz .. ":" .. shiftElev
    local cached = discCache[key]
    if cached then return cached end

    local dirs = {}
    local radiusUV = math.tan( halfAngle )
    local halfElevUV = radiusUV * bandOf( halfAngle )
    -- a band cut from that circle: every row reaches out to the circle's own edge, so the sides
    -- keep the circle's curve while the top and bottom are flat cuts across it
    local topU = math.sqrt( math.max( radiusUV * radiusUV - halfElevUV * halfElevUV, 0 ) )
    local area = 2 * halfElevUV * topU
        + 2 * radiusUV * radiusUV * math.asin( math.min( halfElevUV / math.max( radiusUV, 1e-9 ), 1 ) )
    local cell = math.sqrt( math.max( area, 1e-6 ) / math.max( count, 1 ) )
    local rows = math.max( 1, math.floor( 2 * halfElevUV / cell + 0.5 ) )
    local rowStep = 2 * halfElevUV / rows

    for r = 0, rows - 1 do
        local v = halfElevUV - ( r + 0.5 + shiftElev ) * rowStep
        if math.abs( v ) <= halfElevUV + 1e-9 then
            -- the row is only as wide as the circle still is at that height
            local halfWidth = math.sqrt( math.max( radiusUV * radiusUV - v * v, 0 ) )
            local cols = math.max( 1, math.floor( 2 * halfWidth / cell + 0.5 ) )
            local step = 2 * halfWidth / cols

            for c = 0, cols - 1 do
                local idx = ( c + 0.5 + shiftAz ) % cols -- the shift rolls along the row and wraps
                -- idx carries the half-cell centre; no extra half step, or the row leans left
                dirs[#dirs + 1] = pancakeDir( -halfWidth + idx * step, v )

            end
        end
    end

    discCache[key] = dirs
    -- x is cos(offset from the middle), so sorting descending walks outwards ring by ring. equal
    -- radii are broken by azimuth, so each ring still reads as one tidy band rather than a scatter
    table.sort( dirs, function( a, b )
        if a.x ~= b.x then return a.x > b.x end
        return math.atan2( a.z, a.y ) < math.atan2( b.z, b.y )

    end )
    return dirs

end

-- the band's outline, in the screen plane's offsets. same mapping as the rays, so the line drawn
-- on screen is the boundary they fill: the circle's own arc down each side, flat top and bottom
-- where it was cut
local outlineSegments = 20 -- points along the flat top and bottom
local arcSegments = 24 -- points along each side's arc
local outlineCache = {}

local function pancakeOutline( halfAngle )
    local cached = outlineCache[halfAngle]
    if cached then return cached end

    local radiusUV = math.tan( halfAngle )
    local halfElevUV = radiusUV * bandOf( halfAngle )
    -- where the cut meets the circle, as an angle round it
    local cutAngle = math.asin( math.min( halfElevUV / math.max( radiusUV, 1e-9 ), 1 ) )
    local topU = radiusUV * math.cos( cutAngle )
    local dirs = {}

    local function add( u, v )
        dirs[#dirs + 1] = pancakeDir( u, v )

    end

    for i = 0, outlineSegments do
        add( -topU + 2 * topU * i / outlineSegments, halfElevUV ) -- top, left to right
    end
    for i = 1, arcSegments do
        local at = cutAngle - 2 * cutAngle * i / arcSegments
        add( radiusUV * math.cos( at ), radiusUV * math.sin( at ) ) -- right arc, top to bottom
    end
    for i = 1, outlineSegments do
        add( topU - 2 * topU * i / outlineSegments, -halfElevUV ) -- bottom, right to left
    end
    for i = 1, arcSegments do
        local at = -cutAngle + 2 * cutAngle * i / arcSegments
        add( -radiusUV * math.cos( at ), radiusUV * math.sin( at ) ) -- left arc, bottom to top
    end

    outlineCache[halfAngle] = dirs
    return dirs

end

-- only the rays find things, so what traces pass through never shows
-- the snakes and fungus are SOLID_NONE, and that's deliberate
-- blipping them without a ray reaching them lit the fungus up on sight

local function pulse( me, wep )
    local wavelength = wep:CurrentWavelength()
    local eyePos = me:EyePos()
    local ang = me:EyeAngles()
    local halfCone = math.rad( wep:CurrentCone() / 2 )

    -- the pattern is a fixed grid of points; each frame walks only a slice of it, so a full sweep
    -- takes points / rays frames instead of costing the whole grid every frame. the grid creeps
    -- a fraction of a cell every sweep, so anything that fell between points gets caught later
    local shiftAz = ( sweepPass % shiftSteps ) / shiftSteps
    local shiftElev = ( sweepPass * shiftElevSteps % shiftSteps ) / shiftSteps
    local dirs = discDirs( halfCone, wep:CurrentResolution().points, shiftAz, shiftElev )
    local count = #dirs
    local perFrame = math.max( 1, math.min( wavelength.rays, count ) )

    for n = 0, perFrame - 1 do
        local localDir = dirs[( scanIndex - 1 + n ) % count + 1]
        local dir = LocalToWorld( localDir, angle_zero, vector_origin, ang )
        local hit, hitPos = castRay( me, eyePos, dir, wavelength.pierce, wavelength.length,
            wavelength.deflectEvery, wavelength.deflectDegrees )
        -- only a ray that ended on a target gets here. a wall, the sky, an exhausted pierce budget
        -- and running out of range all return nothing from castRay, so geometry never leaves a blip
        if hit then
            -- a second ray up the same bearing, plain: no piercing, no deflection, it stops at the
            -- first solid. a contact that only came through a wall or off a bent ray still has that
            -- wall or that thing in the way, so this lands on something other than the target and
            -- the blip is drawn at full size. a contact with nothing else on the line is a bare
            -- one, and it gets a single pixel instead
            local sight = trace( eyePos, eyePos + dir * wavelength.length, me )
            local bare = not sight.Hit or sight.Entity == hit

            -- the ray bends on every wall it pierces, so hitPos does not sit on the line the wearer
            -- fired along. the blip goes at the closest point of that original line to the contact:
            -- correct bearing, correct depth, and it parallaxes properly as the view moves
            local reach = math.max( ( hitPos - eyePos ):Dot( dir ), 0 )
            addMark( eyePos + dir * reach, markColorFor( hit ), hit, bare )

        end

    end

    -- remember the slice so the HUD can show where the sweep has got to
    scanHead.first = scanIndex
    scanHead.count = perFrame
    scanHead.halfCone = halfCone
    scanHead.points = wep:CurrentResolution().points
    scanHead.shiftAz = shiftAz
    scanHead.shiftElev = shiftElev
    scanHead.ang = ang
    scanHead.born = CurTime()

    local before = scanIndex
    scanIndex = ( scanIndex - 1 + perFrame ) % count + 1
    if scanIndex <= before then sweepPass = sweepPass + 1 end -- the cursor came back round: one sweep done
end

local function radarThink( wep, wearer )
    local now = CurTime()
    local life = wep.MarkLife

    for ent, record in pairs( detected ) do
        if now - record.seen > detectLife then detected[ent] = nil end

    end
    for i = #marks, 1, -1 do
        if now - marks[i].born > life then table.remove( marks, i ) end

    end

    if not radarRunning( wep, wearer ) then
        stopRadarLoop()
        return

    end

    startRadarLoop()
    pulse( wearer, wep )

end


-- Drawing --------------------------------------------------------------------

-- where a world point lands on screen, nil if it's behind the view
local function pointToScreen( pos )
    local scr = pos:ToScreen()
    if not scr.visible then return end
    return scr.x, scr.y

end

-- where a world direction lands on screen, nil if it's behind
local function viewDirToScreen( dir, eyePos, eyeAng )
    if dir:Dot( eyeAng:Forward() ) <= 0.01 then return end
    local scr = ( eyePos + dir * 100 ):ToScreen()
    if not scr.visible then return end
    return scr.x, scr.y

end

-- the outline can run off the screen at wide cones, and a line that stops at the edge reads as a
-- gap, so this one takes the projection even when the point is outside the screen. anything behind
-- the view is still dropped, which is what the forward dot test is for
local function outlineDirToScreen( dir, eyePos, eyeAng )
    if dir:Dot( eyeAng:Forward() ) <= 0.01 then return end
    local scr = ( eyePos + dir * 100 ):ToScreen()
    return scr.x, scr.y

end

-- what to call the thing a blip belongs to: a player's name, an entity's own print name, else its
-- class, which is at least honest about what the radar caught
local function nameOf( ent )
    if not IsValid( ent ) then return end
    if ent:IsPlayer() then return ent:Nick() end

    local name = ent.PrintName
    if name and name ~= "" then return name end
    return ent:GetClass()

end

-- everything the radar paints is sized in pixels at 1080p, times this
-- so it keeps its weight at any resolution, instead of shrinking into the picture
local function hudScale()
    return math.Clamp( ScrH() / 1080, 0.75, 2.5 )

end

-- the blip labels' face follows the hl2 style's, so changing glee's font moves them too
local labelFace = nil
local labelNameFont = "DermaDefaultBold"
local labelDistFont = "DermaDefault"
local labelBuiltSize, labelBuiltScale

-- the label's own sizes and distances at 1080p: the two faces, how far right of the blip it sits,
-- and how far each line drops
local labelNameSize, labelDistSize = 20, 18
local labelGap, labelNameDrop, labelDistDrop = 10, 9, 13

local function labelFonts()
    local scale = hudScale()
    local nameSize = math.max( 10, math.floor( labelNameSize * scale + 0.5 ) )
    local distSize = math.max( 9, math.floor( labelDistSize * scale + 0.5 ) )

    if not terminator_Extras or not terminator_Extras.glee_Style then
        return labelNameFont, labelDistFont, 1

    end

    local face = terminator_Extras.glee_Style( "hl2" ):Settings().fontName
    if face == labelFace and nameSize == labelBuiltSize then
        return labelNameFont, labelDistFont, labelBuiltScale

    end

    -- a font is baked at one size, so a new screen height means a new pair: naming them after the
    -- size keeps the old pair from being handed back by a stale name
    labelFace, labelBuiltSize, labelBuiltScale = face, nameSize, scale
    labelNameFont, labelDistFont = "glee_nvg_haptic_name_" .. nameSize, "glee_nvg_haptic_dist_" .. distSize
    surface.CreateFont( labelNameFont, { font = face, size = nameSize, weight = 700, antialias = true } )
    surface.CreateFont( labelDistFont, { font = face, size = distSize, weight = 400, antialias = true } )
    return labelNameFont, labelDistFont, scale

end

-- surface.DrawLine is one pixel wide whatever it is handed, so a ring of width n is n of them side
-- by side. not surface.DrawCircle, that draws solid whatever alpha it's handed. the points they run between sit
-- on each vertex's bisector rather than on each segment's own normal: the end of one segment and the
-- start of the next are then the same point, so a corner has nothing to leave open. 1/cos of half
-- the turn is how much further along that bisector an offset has to sit to stay the same distance
-- from the cone's line round the corner, clamped so a hairpin cannot throw a spike across the screen
local function segmentNormal( from, to, axisX, axisY )
    local dx, dy = to.x - from.x, to.y - from.y
    local length = math.sqrt( dx * dx + dy * dy )
    if length < 0.001 then return end

    local nx, ny = dy / length, -dx / length
    if nx * ( from.x - axisX ) + ny * ( from.y - axisY ) < 0 then nx, ny = -nx, -ny end
    return nx, ny

end

local miterX, miterY, miterScale = {}, {}, {}

local function miterLoop( points, axisX, axisY )
    local last = #points

    for i = 1, last do
        local point = points[i]
        local inX, inY = segmentNormal( points[( i - 2 ) % last + 1], point, axisX, axisY )
        local outX, outY = segmentNormal( point, points[i % last + 1], axisX, axisY )

        inX, inY = inX or outX, inY or outY
        outX, outY = outX or inX, outY or inY

        if not inX then
            miterX[i], miterY[i], miterScale[i] = 0, 0, 0

        else
            local mx, my = inX + outX, inY + outY
            local length = math.sqrt( mx * mx + my * my )

            if length > 0.001 then
                mx, my = mx / length, my / length
                miterX[i], miterY[i] = mx, my
                miterScale[i] = 1 / math.max( mx * inX + my * inY, 0.4 )

            else
                miterX[i], miterY[i], miterScale[i] = outX, outY, 1

            end
        end
    end

end

-- one ring of the edge: a line per pixel of its width, each walking the same loop a pixel further
-- out. offsets are snapped to whole pixels, because a line laid down on a fraction of one covers
-- two of them at half strength and the ring reads thicker than it is
local function drawRing( points, ring )
    local last = #points
    local first = math.floor( ring.offset - ( ring.width - 1 ) * 0.5 + 0.5 )

    for pixel = 0, ring.width - 1 do
        local reach = first + pixel

        for i = 1, last do
            local j = i % last + 1
            local from = reach * miterScale[i]
            local to = reach * miterScale[j]

            surface.DrawLine(
                points[i].x + miterX[i] * from, points[i].y + miterY[i] * from,
                points[j].x + miterX[j] * to, points[j].y + miterY[j] * to )
        end
    end

end


-- the cone's edge around the crosshair, and a mark where each ray found something
-- marks sit in world space, so close ones slide faster as the view moves, that's the radar's depth
local function drawRadar( wep, wearer )
    if not radarRunning( wep, wearer ) then return end

    local life = wep.MarkLife
    local eyePos, eyeAng = EyePos(), EyeAngles()
    local halfCone = math.rad( wep:CurrentCone() / 2 )

    -- the band outline: the circle's arc down each side, flat top and bottom. every point of it is a
    -- direction a ray can fire along, so the rings drawn are exactly the shape the sweep fills
    local outline = {}
    for _, localDir in ipairs( pancakeOutline( halfCone ) ) do
        local x, y = outlineDirToScreen( LocalToWorld( localDir, angle_zero, vector_origin, eyeAng ), eyePos, eyeAng )
        if x then
            local previous = outline[#outline]
            -- a zero-length segment has no direction to lay a ring's width along
            if not previous or math.abs( x - previous.x ) > 0.01 or math.abs( y - previous.y ) > 0.01 then
                outline[#outline + 1] = { x = x, y = y }

            end
        end

    end

    -- the generator ends where it started, drop that copy of the first point too
    if #outline > 1 then
        local first, final = outline[1], outline[#outline]
        if math.abs( first.x - final.x ) < 0.01 and math.abs( first.y - final.y ) < 0.01 then
            outline[#outline] = nil
        end
    end

    draw.NoTexture()
    surface.SetDrawColor( coneColor.r, coneColor.g, coneColor.b, coneColor.a )
    local forwardX, forwardY = outlineDirToScreen( eyeAng:Forward(), eyePos, eyeAng )
    local axisX, axisY = forwardX or ScrW() * 0.5, forwardY or ScrH() * 0.5
    local scale = hudScale()
    miterLoop( outline, axisX, axisY )
    for _, ring in ipairs( ringsFor( scale ) ) do
        drawRing( outline, ring )
    end

    local now = CurTime()
    local scanPixel = math.max( 1, math.floor( scanSize * scale + 0.5 ) )
    local markPixel = math.max( 2, math.floor( markSize * scale + 0.5 ) )
    local barePixel = math.max( 2, math.floor( 2 * scale + 0.5 ) )

    -- the band of points the sweep is currently working through, fading out behind it
    if scanHead.born and now - scanHead.born < scanLife then
        local dirs = discDirs( scanHead.halfCone, scanHead.points, scanHead.shiftAz, scanHead.shiftElev )
        local total = #dirs
        local fade = math.max( 0, 1 - ( now - scanHead.born ) / scanLife )
        surface.SetDrawColor( scanColor.r, scanColor.g, scanColor.b, scanColor.a * fade )
        for n = 0, scanHead.count - 1 do
            local localDir = dirs[( scanHead.first - 1 + n ) % total + 1]
            -- the band belongs to the sweep that made it, at the angle the wearer was facing then
            local bandDir = LocalToWorld( localDir, angle_zero, vector_origin, scanHead.ang or eyeAng )
            local x, y = viewDirToScreen( bandDir, eyePos, eyeAng )
            if x then surface.DrawRect( x - scanPixel, y - scanPixel, scanPixel * 2, scanPixel * 2 ) end

        end
    end

    -- every target gets a name, on its newest blip: a crowd of zombies reads as a crowd instead of
    -- one anonymous "Zombie". marks go oldest first, so later ones overwrite the slot's position
    local labels, labelSlot = {}, {}

    for _, mark in ipairs( marks ) do
        local x, y = pointToScreen( mark.pos )
        if x then
            local alpha = 255 * ( 1 - ( now - mark.born ) / life )
            local color = mark.color
            surface.SetDrawColor( color.r, color.g, color.b, alpha )
            if mark.bare then
                -- nothing else on the line, so a smaller dot
                -- snapped to whole pixels, a rect starting on a fraction loses its edge column
                surface.DrawRect( math.floor( x ), math.floor( y ), barePixel, barePixel )
            else
                surface.DrawRect( x - markPixel, y - markPixel, markPixel * 2, markPixel * 2 )
            end

            if IsValid( mark.ent ) then
                local slot = labelSlot[mark.ent]
                if slot then
                    labels[slot].x = x
                    labels[slot].y = y
                    labels[slot].pos = mark.pos
                    labels[slot].born = mark.born

                else
                    labels[#labels + 1] = { ent = mark.ent, x = x, y = y, pos = mark.pos, color = color, born = mark.born }
                    labelSlot[mark.ent] = #labels

                end
            end
        end
    end

    local nameFont, distFont, labelScale = labelFonts()

    for _, label in ipairs( labels ) do
        local name = nameOf( label.ent )
        if name and name ~= "" then
            -- the outline fades with the text: left on full black it outlives the glyphs and reads
            -- as black text at the end of the fade instead of nothing at all
            local alpha = math.Clamp( 255 * ( 1 - ( now - label.born ) / life ), 0, 255 )
            draw.SimpleTextOutlined( name, nameFont, label.x + labelGap * labelScale, label.y - labelNameDrop * labelScale,
                Color( label.color.r, label.color.g, label.color.b, alpha ),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, alpha ) )

            -- hammer units from the eye to where the blip actually sits, recomputed as the wearer
            -- moves so the number tracks the blip's range instead of the moment it was found
            local dist = math.Round( eyePos:Distance( label.pos ) )
            draw.SimpleTextOutlined( dist .. "u", distFont, label.x + labelGap * labelScale, label.y + labelDistDrop * labelScale,
                Color( label.color.r, label.color.g, label.color.b, alpha ),
                TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, alpha ) )

        end
    end
end


-- Putting them on ------------------------------------------------------------

function SWEP.SetupWear( wear )
    BaseClass.SetupWear( wear )

    local wearer = wear.wearer

    wear:OnRemove( function()
        stopRadarLoop()
        table.Empty( detected )
        table.Empty( marks )

    end )

    wear:Hook( "Think", function( wep )
        radarThink( wep, wearer )

    end )

    wear:Hook( "HUDPaint", function( wep )
        drawRadar( wep, wearer )

    end )
end
