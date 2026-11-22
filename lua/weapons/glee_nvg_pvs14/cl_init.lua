include( "shared.lua" )

-- the haptic goggles' use wheel and radar, all clientside, only the wearer sees the cone and its marks

local hapticClass = "glee_nvg_pvs14"

local function wavelengthOf( wep )
    local wavelengths = wep.Wavelengths
    return wavelengths[wep:GetWavelength()] or wavelengths[1]

end

local function coneOf( wep )
    local cones = wep.Cones
    return cones[wep:GetCone()] or cones[1]

end

local function resolutionOf( wep )
    local resolutions = wep.Resolutions
    local resolution = resolutions[wep:GetResolution()]
    if resolution then return resolution end

    -- an unset index falls back to Standard rather than whatever happens to be first
    for _, other in ipairs( resolutions ) do
        if other.name == "Standard" then return other end

    end
    return resolutions[1]

end

-- the wheel ---------------------------------------------------------------------

local OUTER_RADIUS_1080P = 300

-- built when it opens, so the labels say what picking them does right now
local function wheelActions( wep )
    local wavelengths = wep.Wavelengths
    local nextIndex = wep:GetWavelength() % #wavelengths + 1
    local cones = wep.Cones
    local nextCone = wep:GetCone() % #cones + 1
    local resolutions = wep.Resolutions
    local nextResolution = wep:GetResolution() % #resolutions + 1
    return {
        { key = "radar", label = "Radar: " .. ( wep:GetRadarOn() and "On" or "Off" ) },
        { key = "wavelength", label = "Wl: " .. wavelengthOf( wep ).name .. " > " .. wavelengths[nextIndex].name },
        { key = "cone", label = "Cone: " .. coneOf( wep ) .. "° > " .. cones[nextCone] .. "°" },
        { key = "resolution", label = "Res: " .. resolutionOf( wep ).name .. " > " .. resolutions[nextResolution].name },
    }
end

-- glee_carrying's use wheel, opened on the held goggles instead of something aimed at
-- shares glee_Carrying.CurrentWheel, so its own CreateMove lets go of it when use is released
local function openWheel( ply, wep )
    local carrying = terminator_Extras and terminator_Extras.glee_Carrying
    if not carrying then return end

    local oldWheel = carrying.CurrentWheel
    if IsValid( oldWheel ) then oldWheel:Remove() end

    local wheel = vgui.Create( "glee_wheel" )
    if not IsValid( wheel ) then return end
    local outer = wheel:Style():Scaled( OUTER_RADIUS_1080P )

    wheel:SetSize( outer * 2, outer * 2 )
    wheel:SetItems( wheelActions( wep ) )
    wheel:Center()

    function wheel:GetItemStatus()
        return IsValid( wep ) and ply:GetActiveWeapon() == wep

    end

    function wheel:OnItemSelected( item )
        net.Start( "glee_nvg_hapticpick" )
            net.WriteString( item.key )
        net.SendToServer()
        self:Close()

    end

    hook.Add( "Think", wheel, function( self )
        if IsValid( wep ) and ply:Alive() and ply:GetActiveWeapon() == wep then return end
        self:Close()

    end )

    wheel:HoldAim()
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    carrying.CurrentWheel = wheel

end

-- E with the goggles out, and nothing usable in front, so doors and pickups still work
local function aimingAtSomething( ply )
    local carrying = terminator_Extras and terminator_Extras.glee_Carrying
    local range = carrying and carrying.UseRange or 90
    local shootPos = ply:EyePos()
    local tr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + ply:GetAimVector() * range,
        filter = ply,
    } )
    return IsValid( tr.Entity )

end

-- PlayerBindPress only runs when a key's pressed, not every tick
-- returns nothing so +use still goes through, glee_carrying's own CreateMove lets go of the wheel on release
hook.Add( "PlayerBindPress", "glee_nvg_hapticwheel", function( ply, bind, pressed )
    if not pressed or bind ~= "+use" then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) or wep:GetClass() ~= hapticClass then return end
    if not ply:Alive() or ply:InVehicle() then return end
    if aimingAtSomething( ply ) then return end

    openWheel( ply, wep )

end )

-- the radar ---------------------------------------------------------------------

local maxRange = 8000 -- furthest a ray goes in total, solid included
local pierceStep = 8 -- how finely the far side of a wall is looked for, smaller is exact but more traces
local maxWalls = 12 -- most separate pieces of solid one ray goes into
local minPierceCost = 32 -- least a single piece of solid can cost, in pierce units. thin shells - terrain
-- displacements, thin brushes - measure as barely anything thick, so without a floor a ray slips through
-- a hill for a couple of units and quietly crosses the whole map
local detectLife = 10 -- a target counts as new again after this long without being hit
local detectSound = "buttons/blip1.wav"

local coneColor = Color( 255, 200, 30, 120 ) -- HL2 hud yellow, bright enough to read on dark maps
local markLife = 3 -- how long a hit's mark stays in the cone
local markSize = 3
local markColor = Color( 255, 60, 60 )
local maxMarks = 64

local scanColor = Color( 15, 90, 30, 77 ) -- dark green, 70% see through: where the sweep is right now
local scanLife = 0.2 -- how long the sweep's band hangs on screen after a slice
local scanSize = 3
local scanHead = {} -- the slice fired last frame: first, count, halfCone, points, born

local detected = {} -- [ent] = { pos = where it was last hit, seen = when }
local marks = {} -- { dir = the direction it was caught on, relative to the view, born }
local scanIndex = 1 -- where the next frame's slice of the sweep starts
local sweepPass = 0 -- completed sweeps so far; each one nudges the grid to creep across the last one's gaps
local shiftSteps = 16 -- a sweep moves the grid a 16th of a cell sideways, so it drifts about a pixel at a time
local shiftElevSteps = 3 -- the vertical drift is three times the sideways one: 3 pixels down, 1 pixel left

local function radarRunning( me )
    if not IsValid( me ) or not me:Alive() then return end
    if me:GetGleeNVGOnClass() ~= hapticClass then return end
    local wep = me:GetWeapon( hapticClass )
    if not IsValid( wep ) then return end
    if not wep:GetRadarOn() then return end
    return wep

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
    surface.PlaySound( detectSound )

end

local function addMark( localDir )
    if #marks >= maxMarks then table.remove( marks, 1 ) end
    marks[#marks + 1] = { dir = localDir, born = CurTime() }

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

-- how far through the solid at entry, along dir, the far side is. nil if not within budget
-- steps forward and traces back to the entry, the first step that isn't still inside is past the far side,
-- and its trace back stops on the far side's face
local function solidThickness( me, entry, dir, budget )
    local stepped = 0
    while stepped < budget do
        stepped = math.min( stepped + pierceStep, budget )
        local probe = entry + dir * stepped
        local back = trace( probe, entry, me )
        if not back.StartSolid then
            if not back.Hit then return stepped end -- thinner than a step
            return stepped * ( 1 - back.Fraction ) -- back.Fraction is how far the far face is from probe

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
local function castRay( me, wep, start, dir, pierce )
    local travelled = 0
    for _ = 1, maxWalls do
        local tr = trace( start, start + dir * ( maxRange - travelled ), me )
        if not tr.Hit or tr.HitSky then return end
        if isTarget( tr.Entity, me ) then
            hitTarget( tr.Entity, tr.HitPos )
            return true

        end

        local entry = tr.HitPos
        travelled = travelled + start:Distance( entry )
        local thickness = solidThickness( me, entry, dir, math.min( pierce, maxRange - travelled ) )
        if not thickness then return end

        -- charge the real thickness, but never less than one wall's worth: a displacement hill is a
        -- skin with no measurable depth, and it should still cost like something rather than nothing
        pierce = pierce - math.max( thickness, minPierceCost )
        travelled = travelled + thickness
        start = entry + dir * ( thickness + 1 )
        dir = deflect( dir, thickness / wep.PierceDeflectEvery * wep.PierceDeflectDegrees )
        if pierce <= 0 or travelled >= maxRange then return end

    end
end

-- a cone's worth of directions laid out in rows, top to bottom, so the rays fill the circle
-- instead of scattering. built once per cone size, ray count and shift, since it never changes
-- shift (in cells, 0 up to 1) slides every row across and down by that fraction of a cell, so each
-- sweep samples a slightly different set of points and the gaps between them get filled in over time.
-- the two axes are separate so the drift can lean: shiftElev in cells down, shiftAz in cells left
local discCache = {}

local function discDirs( halfAngle, count, shiftAz, shiftElev )
    shiftAz = shiftAz or 0
    shiftElev = shiftElev or 0
    local key = halfAngle .. ":" .. count .. ":" .. shiftAz .. ":" .. shiftElev
    local cached = discCache[key]
    if cached then return cached end

    local dirs = {}
    local rows = math.max( 1, math.floor( math.sqrt( count ) + 0.5 ) )
    local cell = 2 * halfAngle / rows

    for r = 0, rows - 1 do
        local elev = halfAngle - ( r + 0.5 + shiftElev ) * cell -- +halfAngle is the top of the circle
        local halfWidth = math.sqrt( math.max( halfAngle * halfAngle - elev * elev, 0 ) )
        local cols = math.max( 1, math.floor( 2 * halfWidth / cell + 0.5 ) )
        local step = 2 * halfWidth / cols

        for c = 0, cols - 1 do
            local idx = ( c + 0.5 + shiftAz ) % cols -- the shift rolls along the row and wraps
            local az = -halfWidth + ( idx + 0.5 ) * step
            local off = math.sqrt( elev * elev + az * az )
            if off < 1e-6 then
                dirs[#dirs + 1] = Vector( 1, 0, 0 )
            else
                local s = math.sin( off ) / off
                dirs[#dirs + 1] = Vector( math.cos( off ), s * az, s * elev )

            end
        end
    end

    discCache[key] = dirs
    return dirs

end

local function pulse( me, wep )
    local wavelength = wavelengthOf( wep )
    local eyePos = me:EyePos()
    local ang = me:EyeAngles()
    local up = ang:Up()
    local halfCone = math.rad( coneOf( wep ) / 2 )
    local origin = eyePos - up * 4

    -- the pattern is a fixed grid of points; each frame walks only a slice of it, so a full sweep
    -- takes points / rays frames instead of costing the whole grid every frame. the grid creeps
    -- a fraction of a cell every sweep, so anything that fell between points gets caught later
    local shiftAz = ( sweepPass % shiftSteps ) / shiftSteps
    local shiftElev = ( sweepPass * shiftElevSteps % shiftSteps ) / shiftSteps
    local dirs = discDirs( halfCone, resolutionOf( wep ).points, shiftAz, shiftElev )
    local count = #dirs
    local perFrame = math.max( 1, math.min( wavelength.rays, count ) )

    for n = 0, perFrame - 1 do
        local localDir = dirs[( scanIndex - 1 + n ) % count + 1]
        local dir = LocalToWorld( localDir, angle_zero, vector_origin, ang )
        if castRay( me, wep, origin, dir, wavelength.pierce ) then addMark( localDir ) end

    end

    -- remember the slice so the HUD can show where the sweep has got to
    scanHead.first = scanIndex
    scanHead.count = perFrame
    scanHead.halfCone = halfCone
    scanHead.points = resolutionOf( wep ).points
    scanHead.shiftAz = shiftAz
    scanHead.shiftElev = shiftElev
    scanHead.born = CurTime()

    local before = scanIndex
    scanIndex = ( scanIndex - 1 + perFrame ) % count + 1
    if scanIndex <= before then sweepPass = sweepPass + 1 end -- the cursor came back round: one sweep done
end

hook.Add( "Think", "glee_nvg_hapticradar", function()
    local now = CurTime()

    for ent, record in pairs( detected ) do
        if now - record.seen > detectLife then detected[ent] = nil end

    end
    for i = #marks, 1, -1 do
        if now - marks[i].born > markLife then table.remove( marks, i ) end

    end

    local me = LocalPlayer()
    local wep = radarRunning( me )
    if not wep then return end
    pulse( me, wep ) -- every frame

end )

-- where a direction relative to the view lands on screen, nil if it's behind
local function viewDirToScreen( localDir, eyePos, eyeAng )
    if localDir.x <= 0.01 then return end
    local worldDir = LocalToWorld( localDir, angle_zero, vector_origin, eyeAng )
    local scr = ( eyePos + worldDir * 100 ):ToScreen()
    if not scr.visible then return end
    return scr.x, scr.y

end

-- the cone's edge around the crosshair, and a mark wherever a ray that hit something started off
hook.Add( "HUDPaint", "glee_nvg_hapticcone", function()
    local me = LocalPlayer()
    local wep = radarRunning( me )
    if not wep then return end

    local eyePos, eyeAng = EyePos(), EyeAngles()
    local cx, cy = ScrW() / 2, ScrH() / 2
    local halfCone = math.rad( coneOf( wep ) / 2 )
    local edgeX, edgeY = viewDirToScreen( Vector( math.cos( halfCone ), 0, math.sin( halfCone ) ), eyePos, eyeAng )
    if edgeX then
        local radius = math.sqrt( ( edgeX - cx ) ^ 2 + ( edgeY - cy ) ^ 2 )
        surface.DrawCircle( cx, cy, radius, coneColor.r, coneColor.g, coneColor.b, coneColor.a )

    end

    local now = CurTime()

    -- the band of points the sweep is currently working through, fading out behind it
    if scanHead.born and now - scanHead.born < scanLife then
        local dirs = discDirs( scanHead.halfCone, scanHead.points, scanHead.shiftAz, scanHead.shiftElev )
        local total = #dirs
        local fade = math.max( 0, 1 - ( now - scanHead.born ) / scanLife )
        surface.SetDrawColor( scanColor.r, scanColor.g, scanColor.b, scanColor.a * fade )
        for n = 0, scanHead.count - 1 do
            local localDir = dirs[( scanHead.first - 1 + n ) % total + 1]
            local x, y = viewDirToScreen( localDir, eyePos, eyeAng )
            if x then surface.DrawRect( x - scanSize, y - scanSize, scanSize * 2, scanSize * 2 ) end

        end
    end

    for _, mark in ipairs( marks ) do
        local x, y = viewDirToScreen( mark.dir, eyePos, eyeAng )
        if x then
            local alpha = 255 * ( 1 - ( now - mark.born ) / markLife )
            surface.SetDrawColor( markColor.r, markColor.g, markColor.b, alpha )
            surface.DrawRect( x - markSize, y - markSize, markSize * 2, markSize * 2 )

        end
    end
end )
