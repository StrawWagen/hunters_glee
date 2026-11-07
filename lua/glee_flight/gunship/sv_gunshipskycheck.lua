-- does the map, and does a spot on it, have the sky a gunship needs
local gunship = terminator_Extras.glee_Gunship

-- roughly one orbit's worth of ground under the sky
local minUnderSkySurfaceArea = 5000^2
-- less sky than that is fine, if most of the map sits under it
-- a lone tower's roof is tiny, but it still has a whole sky around it
local minDeepUnderSkyShare = 0.5
-- still needs a roof to spawn from
local minRoofSurfaceArea = 500^2
-- a spawn has to rise at least this far before it hits something
local minSpawnClearance = 800
local minAreaSize = 150

local liftHullHalfWidth = 150
local liftHullHalfHeight = 60
local liftStartOffset = Vector( 0, 0, liftHullHalfHeight + 20 )

local liftTrData = {
    mask = MASK_NPCSOLID_BRUSHONLY,
    mins = Vector( -liftHullHalfWidth, -liftHullHalfWidth, -liftHullHalfHeight ),
    maxs = Vector( liftHullHalfWidth, liftHullHalfWidth, liftHullHalfHeight ),
}

-- rises from a spot on the ground, up to cruise height or the ceiling
-- returns where it got to, and how far it rose
function gunship.LiftedPos( groundPos )
    local start = groundPos + liftStartOffset
    liftTrData.start = start
    liftTrData.endpos = groundPos + Vector( 0, 0, gunship.OrbitCfg.cruiseHeight )

    local result = util.TraceHull( liftTrData )
    if result.StartSolid then return start, 0 end

    return result.HitPos, result.HitPos.z - groundPos.z

end

function gunship.CanSpawnOnMap()
    if not GAMEMODE:MapHasEFlags( GAMEMODE.NavEFlags.UNDER_SKY ) then return false end

    -- plenty of open ground, an outdoor map
    local underSkySurfaceArea = GAMEMODE.navmeshUnderSkySurfaceArea
    if underSkySurfaceArea >= minUnderSkySurfaceArea then return true end
    if underSkySurfaceArea < minRoofSurfaceArea then return false end -- tiny roof

    -- not much sky, so look at everything sheltered from it
    -- if most of that sits inside the sky's squares, the map is a tower, or streets ringing a block
    -- if most of it doesn't, it's an indoor map with a skylight or two
    local deepUnderSkySurfaceArea = GAMEMODE.navmeshDeepUnderSkySurfaceArea
    local shadedSurfaceArea = deepUnderSkySurfaceArea + GAMEMODE.navmeshDeepUnderNoSkySurfaceArea
    -- all sky, but too little of it
    if shadedSurfaceArea <= 0 then return false end

    return deepUnderSkySurfaceArea / shadedSurfaceArea >= minDeepUnderSkyShare

end

function gunship.AreaFilter( _, area )
    local smallestWidth = math.min( area:GetSizeX(), area:GetSizeY() )
    if smallestWidth <= minAreaSize then return end

    local _, clearance = gunship.LiftedPos( area:GetCenter() )
    return clearance >= minSpawnClearance

end
