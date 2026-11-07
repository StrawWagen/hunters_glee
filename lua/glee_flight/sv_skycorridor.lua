local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator
local rayHitsTriggerPush = gleeFlightNavigator.RayHitsTriggerPush

-- finds a hull-sized corridor from a point out to the skybox, somewhere a flyer can enter the map from
-- one random attempt per Step, each failure loosens the search, so call it every think until it finds one
local SkyCorridorSearch = {}
SkyCorridorSearch.__index = SkyCorridorSearch

local startingTooCloseDist = 2000
local minTooCloseDist = 400 -- step down to this if we dont find any good corridors
local startingDirMaxZ = 0.15
local maxDirMaxZ = 1

-- if EVERY direction is trigger pushed, just go ahead and ignore them
local triggerPushHitsBeforeIgnoring = 25

-- cfg:
--   corridorHull  half-width of the widest corridor we look for
--   minHull       half-width of the narrowest, also the corridor's half-height
--   debugConVar   optional, draws the traces
function gleeFlightNavigator.NewSkyCorridorSearch( cfg )
    local search = setmetatable( { cfg = cfg }, SkyCorridorSearch )
    search:Reset()

    return search

end

-- forgets how loose the search got, keeps FallbackPos
function SkyCorridorSearch:Reset()
    self.tooCloseDist = startingTooCloseDist
    self.dirMaxZ = startingDirMaxZ
    self.startingOffset = 0 -- from fromPos to the start of the trace, in the trace's dir
    self.triggerPushHits = 0

end

-- the furthest in-world spot any attempt reached the sky from, even ones rejected as too close
function SkyCorridorSearch:GetFallbackPos()
    return self.fallbackPos

end

-- returns the spot to enter the map at, and the spot the corridor starts from, or nil if this attempt failed
-- ignoreTooClose, take short corridors too, for when fromPos is known to be in a tight space
function SkyCorridorSearch:Step( fromPos, ignoreTooClose )
    local cfg = self.cfg
    local corridorHull = cfg.corridorHull
    local minHull = cfg.minHull
    local debugging = cfg.debugConVar and cfg.debugConVar:GetBool()

    local startPos = fromPos

    local nearestWallResult
    local nearestWallDir
    -- check 4 cardinal directions for nearest wall
    for i = 1, 4 do
        local dir = Vector( 0, 0, 0 )
        if i == 1 then
            dir.y = 1

        elseif i == 2 then
            dir.y = -1

        elseif i == 3 then
            dir.x = 1

        else
            dir.x = -1

        end
        local traceData = {
            start = fromPos,
            endpos = fromPos + dir * corridorHull,
            mask = MASK_PLAYERSOLID_BRUSHONLY,

        }
        local traceResult = util.TraceLine( traceData )
        -- if there's a wall here, and we haven't found a wall yet, or this wall is closer
        if traceResult.Hit and ( not nearestWallResult or traceResult.Fraction < nearestWallResult.Fraction ) then
            nearestWallResult = traceResult
            nearestWallDir = dir

        end
    end

    -- if hit, move start position away from the wall
    if nearestWallResult then
        local offsetDist = corridorHull * ( 1 - nearestWallResult.Fraction )
        offsetDist = offsetDist * math.Rand( 1, 1.25 )
        local offset = ( -nearestWallDir ) * offsetDist
        startPos = fromPos + offset

    end

    local randDir
    if nearestWallDir then
        local awayYaw = ( -nearestWallDir ):Angle().y
        local randYaw = awayYaw + math.Rand( -90, 90 )
        randDir = Angle( 0, randYaw, 0 ):Forward()

    else
        randDir = VectorRand()
        randDir.z = 0
        randDir:Normalize()

    end
    randDir.z = math.Rand( -0.05, self.dirMaxZ ) -- dont look upwards
    randDir:Normalize()

    local offset = randDir * 40000

    local doHitPushCheck = self.triggerPushHits < triggerPushHitsBeforeIgnoring
    if doHitPushCheck and rayHitsTriggerPush( startPos, offset ) then
        self.triggerPushHits = self.triggerPushHits + 1
        if debugging then
            permaPrint( "skycorridor hittriggerpush" )

        end
        return

    end

    local currMins = math.random( -minHull, -corridorHull )
    local currMaxs = math.random( minHull, corridorHull )

    local offsetSize = self.startingOffset + math.random( 25, corridorHull )
    local randOffset = randDir * offsetSize
    local startPosOffsetted = startPos + randOffset
    local spawnPosMins = Vector( currMins, currMins, -minHull / 2 )
    local spawnPosMaxs = Vector( currMaxs, currMaxs, minHull / 2 )

    local traceDataSPos = {
        start = startPosOffsetted,
        endpos = startPos + offset,
        mask = MASK_PLAYERSOLID_BRUSHONLY,
        mins = spawnPosMins,
        maxs = spawnPosMaxs,

    }
    -- first trace, find pos players can reach
    local spawnPosResult = util.TraceHull( traceDataSPos )

    local traceDataSky = {
        start = spawnPosResult.HitPos,
        endpos = startPos + offset,
        mask = MASK_SHOT,
        mins = spawnPosMins * 0.75,
        maxs = spawnPosMaxs * 0.75,

    }
    -- then complete the trace, find the sky
    local findSkyResult = util.TraceHull( traceDataSky )

    if debugging then
        local boxColor = Color( 255, 0, 0, 255 )
        if findSkyResult.HitSky then
            boxColor = Color( 0, 255, 0, 255 )

        end
        debugoverlay.SweptBox(
            spawnPosResult.StartPos,
            spawnPosResult.HitPos,
            traceDataSPos.mins,
            traceDataSPos.maxs,
            Angle( 0, 0, 0 ),
            10,
            boxColor
        )
        debugoverlay.SweptBox(
            findSkyResult.StartPos,
            findSkyResult.HitPos,
            traceDataSky.mins,
            traceDataSky.maxs,
            Angle( 0, 0, 0 ),
            10,
            boxColor
        )

    end

    local hitPos = spawnPosResult.HitPos
    if findSkyResult.HitSky and util.IsInWorld( hitPos ) then
        local oldHitPos = self.fallbackPos
        -- no hit sky fallback yet?
        if not oldHitPos then
            self.fallbackPos = hitPos

        -- there's already a fallback, use the new one if its further
        elseif startPos:DistToSqr( hitPos ) > startPos:DistToSqr( oldHitPos ) then
            self.fallbackPos = hitPos

        end
    end

    local tooClose = hitPos:Distance( startPos ) < self.tooCloseDist
    tooClose = tooClose and not ignoreTooClose

    if spawnPosResult.StartSolid then
        self.startingOffset = self.startingOffset + math.random( 0, 100 )

    end

    if spawnPosResult.StartSolid or tooClose then
        self.tooCloseDist = math.max( self.tooCloseDist - 250, minTooCloseDist )
        self.dirMaxZ = math.Clamp( self.dirMaxZ + 0.05, 0, maxDirMaxZ )
        return

    end

    if not findSkyResult.HitSky then
        self.dirMaxZ = math.Clamp( self.dirMaxZ + 0.05, 0, maxDirMaxZ )
        return

    end

    return hitPos, startPos

end
