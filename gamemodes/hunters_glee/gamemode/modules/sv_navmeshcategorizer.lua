
local bit = bit

local function areasSurfaceArea( area )
    return area:GetSizeX() * area:GetSizeY()

end

local flatMaxHeightDelta = 6

local function areaIsFlat( area )
    -- seed from corner 0 rather than math.huge sentinels so the first comparison is immediately meaningful
    local highestZ = area:GetCorner( 0 ).z
    local lowestZ = highestZ

    for cornerId = 1, 3 do
        local cornerZ = area:GetCorner( cornerId ).z
        if cornerZ > highestZ then
            highestZ = cornerZ

        elseif cornerZ < lowestZ then
            lowestZ = cornerZ

        end
        -- most sloped areas fail after corner 1 or 2; early-exiting keeps the non-flat case cheap
        -- since this runs on every single nav area during the visit pass
        if ( highestZ - lowestZ ) > flatMaxHeightDelta then return false end

    end

    return true

end

local GAMEMODE = GAMEMODE or GM

function GAMEMODE:HasExtraFlag( area, flag )
    local flags = self.areaExtraFlags[area]
    if not flags then return false end
    return bit.band( flags, flag ) ~= 0

end

function GAMEMODE:GetAreasWithFlag( flag )
    return self.areasByExtraFlags[flag]

end

function GAMEMODE:RegisterFlagStatus( area, flag )
    local flags = self.areaExtraFlags[area] or 0

    if bit.band( flags, flag ) ~= 0 then return end -- already has flag

    self.areaExtraFlags[area] = bit.bor( flags, flag )

    local allAreasWithFlag = self.areasByExtraFlags[flag]
    if not allAreasWithFlag then -- first one!
        allAreasWithFlag = {}
        self.areasByExtraFlags[flag] = allAreasWithFlag

    end
    table.insert( allAreasWithFlag, area )

end


local ceilingLowThreshold  = 120
local ceilingHighThreshold = 300

local runwayLength = 5000

local flags = {}
GM.NavEFlags = flags -- Nav Extra Flags

flags.FLAT = 1 -- flat ground
flags.UNDER_SKY = 2 -- area is under sky
flags.LOW_CEILING = 4 -- area has low ceiling
flags.HIGH_CEILING = 8 -- area has high ceiling
flags.LOCALE_BEACH = 16 -- right next to water
flags.LOCALE_RUNWAY = 32 -- long flat open area, like an airstrip, only consider if area is perfectly flat and large
flags.LOCALE_PEAK = 64 -- in highest 10% of the map, and higher center than all neighbors
flags.LOCALE_DREG = 128 -- lowest 500u of the map


-- navmesh understanding stuff
local function reset()
    GAMEMODE.isSkyOnMap = false
    GAMEMODE.areaExtraFlags = {}
    GAMEMODE.areasByExtraFlags = {}
    GAMEMODE.highestSkyZ = -math.huge -- highest z on map, probably skybox height
    GAMEMODE.highestAreaZ = -math.huge -- highest navarea center's z
    GAMEMODE.lowestAreaZ = math.huge -- lowest navarea center's z
    GAMEMODE.navmeshTotalSurfaceArea = 0
    GAMEMODE.navmeshUnderSkySurfaceArea = 0

end

-- set this up on first init
hook.Add( "InitPostEntity", "glee_baseline_navdata", reset )

-- and reset it when greedy patcher runs
hook.Add( "glee_navmesh_beginvisiting", "glee_reset_navdata", reset )

-- lifted above the nav surface so the sky trace origin doesn't start clipped into the floor geometry
local centerOffset = Vector( 0, 0, 25 )

-- precomputed rotation step for runway direction checks (22.5 degrees per step)
local runwayDirStepCos = math.cos( math.rad( 22.5 ) )
local runwayDirStepSin = math.sin( math.rad( 22.5 ) )

-- reusable vectors for runway traces; fields are overwritten each use, no allocations inside the loop
local runwayDir        = Vector( 0, 0, 0 )
local runwayTraceStart = Vector( 0, 0, 0 )
local runwayTraceEnd   = Vector( 0, 0, 0 )

--[[
use hooks 
    glee_navmesh_visit ( area )
    to gather data, apply some simpler flags
and 
    glee_navmesh_postvisit ( area )
    to set flags on areas that need context of the whole navmesh
--]]

hook.Add( "glee_navmesh_visit", "glee_precache_extraflags", function( area )
    local areasCenter = area:GetCenter()

    local areasSurface = areasSurfaceArea( area )
    GAMEMODE.navmeshTotalSurfaceArea = GAMEMODE.navmeshTotalSurfaceArea + areasSurface

    local underSky, hitPos, skyTraceResult = GAMEMODE:IsUnderSky( areasCenter + centerOffset )
    if underSky then
        GAMEMODE.isSkyOnMap = true
        GAMEMODE.navmeshUnderSkySurfaceArea = GAMEMODE.navmeshUnderSkySurfaceArea + areasSurface
        GAMEMODE:RegisterFlagStatus( area, flags.UNDER_SKY )

    else
        -- Fraction * IsUnderSky_Distance gives clearance without a laggy Distance() call;
        -- ceiling flags only apply indoors; open-sky clearance is effectively infinite so we skip it
        local clearance = skyTraceResult.Fraction * GAMEMODE.IsUnderSky_Distance
        if clearance < ceilingLowThreshold then
            GAMEMODE:RegisterFlagStatus( area, flags.LOW_CEILING )

        elseif clearance > ceilingHighThreshold then
            GAMEMODE:RegisterFlagStatus( area, flags.HIGH_CEILING )

        end
    end

    -- highestSkyZ tracks the skybox "lid" height, used for signal attenuation relative to the sky
    -- highestAreaZ tracks the highest walkable point, used for locale/peak detection
    -- they're different concepts even though both relate to "high up on the map"
    local currHitZ = hitPos.z
    if currHitZ > GAMEMODE.highestSkyZ then
        GAMEMODE.highestSkyZ = currHitZ

    end

    local currAreaZ = areasCenter.z
    if currAreaZ > GAMEMODE.highestAreaZ then
        GAMEMODE.highestAreaZ = currAreaZ

    end
    if currAreaZ < GAMEMODE.lowestAreaZ then
        GAMEMODE.lowestAreaZ = currAreaZ

    end

    local flat = areaIsFlat( area )

    if flat then
        GAMEMODE:RegisterFlagStatus( area, flags.FLAT )

    end

    if not util.IsInWorld( areasCenter ) then return end

    local adjacents = area:GetAdjacentAreas()

    if #adjacents <= 0 then return end
    if underSky and area:IsUnderwater() then
        for _, neighbor in ipairs( adjacents ) do
            if neighbor:IsUnderwater() then continue end
            if area:ComputeAdjacentConnectionHeightChange( neighbor ) > 36 then continue end
            GAMEMODE:RegisterFlagStatus( neighbor, flags.LOCALE_BEACH )

        end
    end

    local areaSmallestAxis = math.min( area:GetSizeX(), area:GetSizeY() )
    if underSky and areaSmallestAxis >= 350 and flat then
        local isAReallyLongDirection
        -- seed start angle from area ID so results are stable across sessions
        local startAngle = math.rad( area:GetID() )
        runwayDir.x = math.cos( startAngle )
        runwayDir.y = math.sin( startAngle )
        runwayDir.z = 0

        runwayTraceStart.x = areasCenter.x + centerOffset.x
        runwayTraceStart.y = areasCenter.y + centerOffset.y
        runwayTraceStart.z = areasCenter.z + centerOffset.z

        local trResult = {}
        local trDat = {
            start = runwayTraceStart,
            endpos = runwayTraceEnd,
            mask = MASK_NPCWORLDSTATIC,
            output = trResult,
        }

        for _ = 1, 16 do -- check every 22.5 degrees around the area
            runwayTraceEnd.x = runwayTraceStart.x + runwayDir.x * runwayLength
            runwayTraceEnd.y = runwayTraceStart.y + runwayDir.y * runwayLength
            runwayTraceEnd.z = runwayTraceStart.z

            util.TraceLine( trDat )
            if not trResult.Hit then
                isAReallyLongDirection = true
                break

            end

            -- rotate dir by 22.5 degrees in-place; no new Vector objects
            local nx = runwayDir.x * runwayDirStepCos - runwayDir.y * runwayDirStepSin
            runwayDir.y = runwayDir.x * runwayDirStepSin + runwayDir.y * runwayDirStepCos
            runwayDir.x = nx

        end
        if isAReallyLongDirection then
            GAMEMODE:RegisterFlagStatus( area, flags.LOCALE_RUNWAY )

        end
    end
end )

hook.Add( "glee_navmesh_postvisit", "glee_precache_extraflags", function( area )
    local areasCenter = area:GetCenter()
    local currAreaZ = areasCenter.z

    -- LOCALE_DREG: lowest 500u of the map
    if currAreaZ <= GAMEMODE.lowestAreaZ + 500 then
        GAMEMODE:RegisterFlagStatus( area, flags.LOCALE_DREG )

    end

    -- LOCALE_PEAK: in highest 10% of the map's Z range, and higher center than all neighbors
    local zRange = GAMEMODE.highestAreaZ - GAMEMODE.lowestAreaZ
    local peakThreshold = GAMEMODE.highestAreaZ - zRange * 0.1

    if currAreaZ >= peakThreshold then
        local isHigherThanAllNeighbors = true

        for _, neighbor in ipairs( area:GetAdjacentAreas() ) do
            if neighbor:GetCenter().z >= currAreaZ then
                isHigherThanAllNeighbors = false
                break

            end
        end

        if isHigherThanAllNeighbors then
            GAMEMODE:RegisterFlagStatus( area, flags.LOCALE_PEAK )

        end
    end
end )