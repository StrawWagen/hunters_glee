
-- z in the filename so its last in alphabetical order lol

local sv_cheats = GetConVar( "sv_cheats" )

local function isCheats()
    return sv_cheats:GetBool()

end

-- job critically failed
local function spawnJobErr( name, reason )
    if not isCheats() then return end
    ErrorNoHaltWithStack( name .. reason )

end

-- job failed for intended reason
local function spawnJobInfo( name, reason )
    if not isCheats() then return end
    print( name .. " " .. reason )

end

local proceduralSpawnerJobs = {}
local currJobCoroutine

local defaultStepSize = 50 * 3
local defaultMinAreas = 60

local function alivePlayers()
    local out = {}
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() > 0 then
            table.insert( out, ply )

        end
    end
    return out

end

local traceHitTooCloseDist = 200^2

local function aPlayerCanSeePos( toCheck )
    local visible = nil

    for _, visPly in ipairs( alivePlayers() ) do
        if not IsValid( visPly ) then continue end
        coroutine.yield()
        local firstChecksShootPos = visPly:GetShootPos()
        local vis, visTr = terminator_Extras.PosCanSeeComplex( toCheck, firstChecksShootPos, visPly )
        if vis then
            visible = true
            break

        end
        if visTr and visTr.HitPos:DistToSqr( firstChecksShootPos ) < traceHitTooCloseDist then
            visible = true
            break

        end
    end
    return visible

end

function GM:addProceduralSpawnJob( job )
    table.insert( proceduralSpawnerJobs, job )

end

local maxPerf = 0.0008

if game.IsDedicated() then
    maxPerf = 0.001

end

local nextPrint = 0

hook.Add( "glee_sv_validgmthink", "glee_proceduralspawner", function( _, currState, _ )
    if currState ~= GAMEMODE.ROUND_ACTIVE then return end

    --[[if nextPrint < CurTime() then
        nextPrint = CurTime() + 1
        local count = #proceduralSpawnerJobs
        print( count )
        if count >= 1 then
            print( proceduralSpawnerJobs[1].jobsName )

        end
    end]]--

    -- tackle current job
    if currJobCoroutine then
        local startTime = SysTime()
        local good, result = nil, nil

        while math.abs( startTime - SysTime() ) < maxPerf do
            if coroutine.status( currJobCoroutine ) == "dead" then break end
            good, result = coroutine.resume( currJobCoroutine )

            if good == false then
                ErrorNoHaltWithStack( result )
                currJobCoroutine = nil
                table.remove( proceduralSpawnerJobs, 1 )
                break

            end
        end

        -- finished or errored
        if result == "done" or good ~= true then
            currJobCoroutine = nil
            table.remove( proceduralSpawnerJobs, 1 )

        end
        return

    end
    if #proceduralSpawnerJobs <= 0 then return end

    -- pull job from the table, only remove it if the job errors, or completes
    -- if job fails for an expected reason, we repeat it until it succeeds.
    currJob = proceduralSpawnerJobs[1]

    if not currJob.jobsName then spawnJobErr( currJob.jobsName, "No jobsName" ) return end

    if not currJob.posFindingOrigin then spawnJobErr( currJob.jobsName, "No posFindingOrigin" ) return end
    -- currJob.originIsDefinitive
    -- will the origin fall back to near a hunter, if it's "invalid"? fixed no crates spawning when players are like high up, on a navmesh island/rooftop 
    -- currJob.spawnRadius
    -- searching radius, smaller = faster spawning.
    -- currJob.sortForNearest
    -- sort for nearest areas to the finding origin? allowed crates spawning in groups.
    if not currJob.areaFilteringFunction then spawnJobErr( currJob.jobsName, "No areaFilteringFunction" ) return end
    -- filters areas, use this to discard like underwater areas, too small areas
    -- currJob.hideFromPlayers
    -- NEVER spawn in front of players? will discard entire job if the final pos can be seen by players.
    if not currJob.posDerivingFunc then spawnJobErr( currJob.jobsName, "No posDerivingFunc" ) return end
    -- gets points inside the area, needs to return a table. if your thing spawns in the center of areas, return table with getcenter, random? random points.
    if not currJob.maxPositionsForScoring then spawnJobErr( currJob.jobsName, "No maxPositionsForScoring" ) return end
    -- how many points to find for the scorer? stops checking entire navmesh just to spawn one damn crate.
    if not currJob.posScoringFunction then spawnJobErr( currJob.jobsName, "No posScoringFunction" ) return end
    -- ran on every position returned true on filtering func, pos with best returned score is chosen!
    if not currJob.posScoringBudget then spawnJobErr( currJob.jobsName, "No posScoringBudget" ) return end
    -- how much budget to give the scoring function?
    if not currJob.onPosFoundFunction then spawnJobErr( currJob.jobsName, "No onPosFoundFunction" ) return end
    -- final function, use to place like crates.

    currJobCoroutine = coroutine.create( function()
        currJob.spawningOrigin = currJob.posFindingOrigin
        local hideFromPlayers = currJob.hideFromPlayers
        local overrideSpawnRadius = currJob.spawnRadius
        local spawnRadius

        -- spagheti
        if overrideSpawnRadius then
            spawnRadius = overrideSpawnRadius

        else
            spawnRadius = 4000

            if #navmesh.GetAllNavAreas() > 4000 then
                spawnRadius = 8000

            end
            currJob.spawnRadius = spawnRadius

        end

        local navAreas = navmesh.Find( currJob.spawningOrigin, spawnRadius, defaultStepSize, defaultStepSize )

        -- ok the spot we putting it is too small, maybe try placing next to a hunter?
        if not navAreas or ( hideFromPlayers and ( #navAreas < defaultMinAreas ) ) then
            -- the job doesnt want us to do this!
            -- bail so the queue isnt held up!
            if currJob.originIsDefinitive then coroutine.yield( "done" ) spawnJobInfo( currJob.jobsName, "Spawn job bailed, definitive origin was too small/invald." ) return end

            local hunter = GAMEMODE:aRandomHunter()
            if not IsValid( hunter ) then coroutine.yield( "done" ) spawnJobInfo( currJob.jobsName, "Spawn job bailed, no hunters for origin to fall back to." ) return end
            currJob.spawningOrigin = hunter:GetPos()

            navAreas = navmesh.Find( currJob.spawningOrigin, spawnRadius, defaultStepSize, defaultStepSize )

        end

        -- dont spawn off navmesh or in really small isolated rooms/rooftops
        if not navAreas or ( hideFromPlayers and ( #navAreas < defaultMinAreas ) ) then coroutine.yield( "done" ) spawnJobInfo( currJob.jobsName, "Spawn job bailed, origin was too small/invalid." ) return end

        local areaDistances = {}
        for _, area in ipairs( navAreas ) do
            areaDistances[area] = area:GetCenter():DistToSqr( currJob.spawningOrigin )

        end

        local sortForNearest = currJob.sortForNearest
        -- check areas close/far from the point first
        table.sort( navAreas, function( a, b )
            if sortForNearest == true then
                return areaDistances[a] < areaDistances[b]

            else
                return areaDistances[a] > areaDistances[b]

            end
        end )

        local goodPositions = {}

        local filteringFunc = currJob.areaFilteringFunction
        local posDerivingFunc = currJob.posDerivingFunc
        local maxPoints = currJob.maxPositionsForScoring

        for _, area in ipairs( navAreas ) do
            coroutine.yield()
            if filteringFunc( currJob, area ) then
                local toCheck = posDerivingFunc( currJob, area )
                if not toCheck then continue end
                for _, checkPos in pairs( toCheck ) do
                    if not checkPos then continue end

                    if not util.IsInWorld( checkPos ) then continue end
                    if hideFromPlayers and aPlayerCanSeePos( checkPos ) then continue end

                    table.insert( goodPositions, checkPos )

                    if #goodPositions > maxPoints then break end

                end
                if #goodPositions > maxPoints then break end

            end
        end

        local scoringFunc = currJob.posScoringFunction
        local budget = currJob.posScoringBudget
        local scoredPositions = {}

        for _, toCheckPos in ipairs( goodPositions ) do
            coroutine.yield()
            local score = scoringFunc( currJob, toCheckPos, budget )
            scoredPositions[ math.Round( score, 2 ) ] = toCheckPos

        end

        local bestPositionKey = table.maxn( scoredPositions )
        local bestPosition = scoredPositions[ bestPositionKey ]

        if not bestPosition then return end

        if hideFromPlayers and aPlayerCanSeePos( bestPosition ) then coroutine.yield( "done" ) spawnJobInfo( currJob.jobsName, "Spawn job bailed, best pos found was visible to a player." ) return end

        local foundFunc = currJob.onPosFoundFunction
        local allGood = foundFunc( currJob, bestPosition )
        if allGood == nil then coroutine.yield( "done" ) spawnJobErr( currJob.jobsName, "onPosFoundFunction NEEDS to return TRUE or FALSE to complete job." ) return end

        if allGood ~= true then coroutine.yield( "done" ) spawnJobInfo( currJob.jobsName, "onPosFoundFunction returned false" ) return end
        --debugoverlay.Cross( bestPosition, 100, 100, color_white, true )
        coroutine.yield( "done" )

    end )
end )

hook.Add( "huntersglee_round_into_limbo", "glee_cleanupproceduralspawner_jobs", function()
    proceduralSpawnerJobs = nil
    proceduralSpawnerJobs = {}

end )

hook.Add( "PreCleanupMap", "glee_cleanupproceduralspawner_jobs", function()
    proceduralSpawnerJobs = nil
    proceduralSpawnerJobs = {}

end )