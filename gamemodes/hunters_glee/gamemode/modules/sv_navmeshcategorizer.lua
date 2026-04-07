
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

function GAMEMODE:AddExtraFlag( area, flag )
    local flags = self.areaExtraFlags[area] or 0
    if bit.band( flags, flag ) ~= 0 then return end -- already has flag

    self.areaExtraFlags[area] = bit.bor( flags, flag )

end


local ceilingLowThreshold  = 120
local ceilingHighThreshold = 300


local flags = {}
GM.NavEFlags = flags -- Nav Extra Flags

flags.FLAT = 1 -- flat ground
flags.UNDER_SKY = 2 -- area is under sky
flags.LOW_CEILING = 4 -- area has low ceiling
flags.HIGH_CEILING = 8 -- area has high ceiling
flags.LOCALE_BEACH = 16 -- near or in shallow water, on sand or a displacement
flags.LOCALE_RUNWAY = 32 -- long flat open area, like an airstrip, only consider if area is perfectly flat and large
flags.LOCALE_PEAK = 64 -- in highest 10% of the map, and higher center than all neighbors
flags.LOCALE_DREG = 128 -- lowest 500u of the map


-- navmesh understanding stuff
local function reset()
    GAMEMODE.isSkyOnMap = false
    GAMEMODE.areaExtraFlags = {}
    GAMEMODE.highestSkyZ = -math.huge -- highest z on map, probably skybox height
    GAMEMODE.highestAreaZ = -math.huge -- highest navarea center's z
    GAMEMODE.lowestAreaZ = math.huge -- lowest navarea center's z
    GAMEMODE.navmeshTotalSurfaceArea = 0
    GAMEMODE.navmeshUnderSkySurfaceArea = 0

end

-- guarantees data is never nil even if glee_navmesh_beginvisiting never fires (e.g. no navmesh on map)
hook.Add( "InitPostEntity", "glee_baseline_navdata", reset )

-- the greedy patcher can re-run mid-session without a map reload, so InitPostEntity won't fire again
hook.Add( "glee_navmesh_beginvisiting", "glee_reset_navdata", reset )

-- lifted above the nav surface so the sky trace origin doesn't start clipped into the floor geometry
local centerOffset = Vector( 0, 0, 25 )

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
        GAMEMODE:AddExtraFlag( area, GAMEMODE.NavEFlags.UNDER_SKY )

    else
        -- Fraction * IsUnderSky_Distance gives clearance without a laggy Distance() call;
        -- ceiling flags only apply indoors; open-sky clearance is effectively infinite so we skip it
        local clearance = skyTraceResult.Fraction * GAMEMODE.IsUnderSky_Distance
        if clearance < ceilingLowThreshold then
            GAMEMODE:AddExtraFlag( area, GAMEMODE.NavEFlags.LOW_CEILING )

        elseif clearance > ceilingHighThreshold then
            GAMEMODE:AddExtraFlag( area, GAMEMODE.NavEFlags.HIGH_CEILING )

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

    if areaIsFlat( area ) then
        GAMEMODE:AddExtraFlag( area, GAMEMODE.NavEFlags.FLAT )

    end

    if not util.IsInWorld( areasCenter ) then return end

    local adjacents = area:GetAdjacentAreas()

    if #adjacents <= 0 then return end
    if area:IsUnderwater() then
        for _, neighbor in ipairs( adjacents ) do
            if neighbor:IsUnderwater() then continue end
            GAMEMODE:AddExtraFlag( neighbor, GAMEMODE.NavEFlags.LOCALE_BEACH )

        end
    end

    local areaSmallestAxis = math.min( area:GetSizeX(), area:GetSizeY() )

end )