
local function areasSurfaceArea( area )
    return area:GetSizeX() * area:GetSizeY()

end

local GAMEMODE = GAMEMODE or GM


-- TODO; impliment
local flags = {}
GM.NavEFlags = flags -- extra flags
flags.FLAT = 1 -- flat ground
flags.UNDER_SKY = 2 -- area is under sky
flags.LOW_CEILING = 4 -- area has low ceiling
flags.HIGH_CEILING = 8 -- area has high ceiling
flags.ROOM_TINY = 16
flags.ROOM_SMALL = 32
flags.ROOM_LARGE = 64
flags.ROOM_HUGE = 128
flags.LOCALE_BEACH = 256 -- near or in shallow water, on sand or a displacement
flags.LOCALE_PEAK = 512 -- highest 10% of the map, highest of nearby neighbors
flags.LOCALE_RUNWAY = 1024 -- long flat open area, like an airstrip
flags.LOCALE_DREG = 2048 -- lowest 10% of the map


-- navmesh understanding stuff
local function reset()
    GAMEMODE.isSkyOnMap = false
    GAMEMODE.areasUnderSky = {}
    GAMEMODE.highestZ = -math.huge -- highest z on map, probably skybox height
    GAMEMODE.highestAreaZ = -math.huge -- highest navarea center's z
    GAMEMODE.navmeshTotalSurfaceArea = 0
    GAMEMODE.navmeshUnderSkySurfaceArea = 0

end

hook.Add( "InitPostEntity", "glee_baseline_navdata", reset )

hook.Add( "glee_navmesh_beginvisiting", "glee_reset_navdata", reset )

local centerOffset = Vector( 0, 0, 25 )

hook.Add( "glee_navmesh_visit", "glee_precache_skydata", function( area )
    local areasCenter = area:GetCenter()
    local underSky, hitPos = GAMEMODE:IsUnderSky( areasCenter + centerOffset )
    if underSky then
        GAMEMODE.isSkyOnMap = true
        GAMEMODE.areasUnderSky[ area ] = true
        GAMEMODE.navmeshUnderSkySurfaceArea = GAMEMODE.navmeshUnderSkySurfaceArea + areasSurfaceArea( area )

    end

    local currHitZ = hitPos.z
    if currHitZ > GAMEMODE.highestZ then
        GAMEMODE.highestZ = currHitZ

    end

    local currAreaZ = areasCenter.z
    if currAreaZ > GAMEMODE.highestAreaZ then
        GAMEMODE.highestAreaZ = currAreaZ

    end
end )

hook.Add( "glee_navmesh_visit", "glee_precache_navsurfacearea", function( area )
    local areasSurface = areasSurfaceArea( area )
    GAMEMODE.navmeshTotalSurfaceArea = GAMEMODE.navmeshTotalSurfaceArea + areasSurface

end )
