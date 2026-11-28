-- The haptic goggles' rays, included by cl_init.lua
-- where one ray fired from the eyes ends up: what it pierces, how it bends, and what living thing it stops on
-- first, how a direction local to the eyes turns into one in the world, then castRay at the bottom
-- cl_sweep.lua fires them

local haptic = SWEP.Haptic


-- Directions local to the eyes ------------------------------------------------
-- the radar works in directions local to the eyes, x forward, y left, z up, so it turns with the head
-- the sweep fires along them, the overlay draws them

-- eyes = { forward =, left =, up = }, the eyes' own axes in the world
-- each caller keeps its own, refilled every frame by fillEyes
local function fillEyes( eyes, eyeAngles )
    eyes.forward = eyeAngles:Forward()
    eyes.left = -eyeAngles:Right()
    eyes.up = eyeAngles:Up()

end

-- localDir turned to point the same way in the world, written into out
local function eyesToWorld( out, localDir, eyes )
    local forward, left, up = eyes.forward, eyes.left, eyes.up
    local ahead, leftward, upward = localDir:Unpack()

    out:SetUnpacked(
        forward.x * ahead + left.x * leftward + up.x * upward,
        forward.y * ahead + left.y * leftward + up.y * upward,
        forward.z * ahead + left.z * leftward + up.z * upward
    )
    return out

end


-- One ray --------------------------------------------------------------------

local pierceStep = 8 -- how finely the far side of a wall is looked for, smaller is exact but more traces
local maxWalls = 12 -- most separate pieces of solid one ray goes into
local minPierceCost = 32 -- least a single piece of solid can cost, in pierce units. thin shells - terrain
-- displacements, thin brushes - measure as barely anything thick, so without a floor a ray slips through
-- a hill for a couple of units and quietly crosses the whole map

local traceData = { mask = MASK_SHOT }
local traceResult = {}
traceData.output = traceResult

-- the result is shared by every trace here, read what you need before the next one
local function trace( start, endpos, filter )
    traceData.start = start
    traceData.endpos = endpos
    traceData.filter = filter
    util.TraceLine( traceData )
    return traceResult

end

local isAliveThing = terminator_Extras.glee_IsAliveThing

-- only the living stop a ray
-- rays hit what a thing collides with, so one drawn bigger than that, eg the evil crawler's legs, only shows where it collides
local function isTarget( ent, me )
    return ent ~= me and isAliveThing( ent )

end

local isInWall = terminator_Extras.glee_IsInWall

-- thousands of rays a second, many steps each: a new Vector per step is a pile of garbage every frame,
-- and the collector clears it in hitches. so every point here is one of these, filled in place
local probe = Vector()
local rayStart, rayDir, rayEnd, rayEntry = Vector(), Vector(), Vector(), Vector()

-- out = from + dir * length, in place
local function along( out, from, dir, length )
    out:Set( dir )
    out:Mul( length )
    out:Add( from )
    return out

end

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
        along( probe, entry, dir, stepped )
        if not ( inWorld and isInWall( probe ) ) then
            local back = trace( probe, entry, me )
            if not back.StartSolid then
                if not back.Hit then return stepped end -- thinner than a step
                return stepped * ( 1 - back.Fraction ) -- back.Fraction is how far the far face is from probe

            end
        end
    end
end

-- a direction square to both a and b, as three numbers
local function cross( ax, ay, az, bx, by, bz )
    return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx

end

-- knocks dir off course by degrees, towards a random side, in place
-- plain numbers, the Angle way made three new objects a wall
local function deflect( dir, degrees )
    local dirX, dirY, dirZ = dir:Unpack()

    -- crossed with any direction that isn't along it, dir gives one square to it
    local helperX, helperY, helperZ = 0, 0, 1
    if math.abs( dirZ ) > 0.9 then helperX, helperY, helperZ = 1, 0, 0 end

    -- two sideways directions, square to dir and to each other
    local sideX, sideY, sideZ = cross( dirX, dirY, dirZ, helperX, helperY, helperZ )
    local sideLength = math.sqrt( sideX * sideX + sideY * sideY + sideZ * sideZ )
    sideX, sideY, sideZ = sideX / sideLength, sideY / sideLength, sideZ / sideLength
    local otherX, otherY, otherZ = cross( dirX, dirY, dirZ, sideX, sideY, sideZ )

    -- a random way round between them, the way it gets knocked
    local around = math.Rand( 0, math.pi * 2 )
    local awayX = sideX * math.cos( around ) + otherX * math.sin( around )
    local awayY = sideY * math.cos( around ) + otherY * math.sin( around )
    local awayZ = sideZ * math.cos( around ) + otherZ * math.sin( around )

    -- then tipped that many degrees towards it
    local tip = math.rad( degrees )
    local keep, lean = math.cos( tip ), math.sin( tip )

    dir:SetUnpacked(
        dirX * keep + awayX * lean,
        dirY * keep + awayY * lean,
        dirZ * keep + awayZ * lean
    )
end

--[[---------------------------------------------------------
    haptic.castRay
    One ray, piercing what it hits until it's out of pierce, range or walls, hits sky, or finds a target.
    @param me: The wearer, never hit.
    @param start: Where it leaves from. Left as it is.
    @param dir: Which way, normalized. Left as it is.
    @param wavelength: An entry of SWEP.Wavelengths.
    @return: The target it stopped on, or nothing. Walls never return anything.
--]]---------------------------------------------------------
local function castRay( me, start, dir, wavelength )
    local pierce = wavelength.pierce
    local maxLength = wavelength.length
    local deflectEvery = wavelength.deflectEvery
    local deflectDegrees = wavelength.deflectDegrees
    local travelled = 0

    -- the ray's own copies, moved and bent as it goes
    rayStart:Set( start )
    rayDir:Set( dir )

    for _ = 1, maxWalls do
        local tr = trace( rayStart, along( rayEnd, rayStart, rayDir, maxLength - travelled ), me )
        if not tr.Hit or tr.HitSky then return end
        if isTarget( tr.Entity, me ) then return tr.Entity end

        -- copied out, solidThickness traces over tr
        local inWorld = tr.HitWorld
        rayEntry:Set( tr.HitPos )
        travelled = travelled + rayStart:Distance( rayEntry )
        local thickness = solidThickness( me, rayEntry, rayDir, math.min( pierce, maxLength - travelled ), inWorld )
        if not thickness then return end

        -- charge the real thickness, but never less than one wall's worth: a displacement hill is a
        -- skin with no measurable depth, and it should still cost like something rather than nothing
        pierce = pierce - math.max( thickness, minPierceCost )
        travelled = travelled + thickness
        along( rayStart, rayEntry, rayDir, thickness + 1 )
        -- both numbers live on the wavelength; a wavelength that leaves either out gets a straight ray
        if deflectEvery and deflectEvery > 0 and deflectDegrees and deflectDegrees ~= 0 then
            deflect( rayDir, thickness / deflectEvery * deflectDegrees )

        end
        if pierce <= 0 or travelled >= maxLength then return end

    end
end


-- What the other files use --------------------------------------------------

haptic.fillEyes = fillEyes
haptic.eyesToWorld = eyesToWorld
haptic.trace = trace
haptic.along = along
haptic.castRay = castRay
