
-- z in the filename so its last in alphabetical order lol

local plysNeeded = CreateConVar( "huntersglee_proceduralcratesmaxplayers", 8, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Player count threshold to stop randomly spawning weapon crates", 0, 32 )

local stepSize = 50
local minAreas = 70

local vecFiftyUp = Vector( 0, 0, 50 )
local lastCrate = nil
local placedAlready = {}
local crateSpawningFailed = nil

local function nearbyGreaterThanCount( pos, radius, toCheck, target )
    local radiusSqr = radius^2
    local count = 0
    if #toCheck == 0 or not pos then return end
    for _, thing in ipairs( toCheck ) do
        if IsValid( thing ) and thing:GetPos():DistToSqr( pos ) < radiusSqr then
            count = count + 1
        end
        if count > target then
            return true
        end
    end
end

local traceHitTooCloseDist = 200^2

local function alivePlayers()
    local out = {}
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() > 0 then
            table.insert( out, ply )

        end
    end
    return out

end

local function FindCrateSpawnPos()
    -- Get a random player's pos
    local ply = table.Random( alivePlayers() )
    if not ply or not IsValid( ply ) then return end

    local plyShootPos = ply:GetShootPos()

    -- place crates in clusters!
    local sortCenterIsABox = false
    local sortPos = plyShootPos
    local searchRange = 5000

    if #navmesh.GetAllNavAreas() > 4000 then
        searchRange = 8000

    end

    if IsValid( lastCrate ) then
        sortPos = lastCrate:GetPos()
        sortCenterIsABox = true
        searchRange = 3500

    end

    local crates = ents.FindByClass( "item_item_crate" )
    if #crates > 30 then return end

    local navAreas = navmesh.Find( sortPos, searchRange, stepSize, stepSize )

    -- ok the spot we putting it is too small, maybe try placing next to a hunter?
    if not navAreas or #navAreas < minAreas then
        local hunter = table.Random( GAMEMODE.termHunt_hunters )
        if not IsValid( hunter ) then return end
        sortPos = hunter:GetPos()

        navAreas = navmesh.Find( sortPos, searchRange, stepSize, stepSize )

    end
    -- nope didnt work
    if not navAreas or #navAreas < minAreas then return end

    -- Sort the nav areas by furthest to closest from the player
    table.sort( navAreas, function( a, b )
        if sortCenterIsABox == true then
            return a:GetCenter():DistToSqr( sortPos ) < b:GetCenter():DistToSqr( sortPos )
        else
            return a:GetCenter():DistToSqr( sortPos ) > b:GetCenter():DistToSqr( sortPos )
        end
    end )

    -- this whole max traces budget made more sense when this wasnt couroutined
    local done = 0
    local maxTraces = 400
    local maxToCheckNook = 2000
    local toCheckNooks = {}

    -- Iterate over the collection of nav areas until we run out of traces
    for _, area in ipairs( navAreas ) do
        coroutine.yield()
        if
            not area:IsBlocked()
            and not area:IsUnderwater()
            and ( sortCenterIsABox or not placedAlready[ area:GetID() ] )
            and not nearbyGreaterThanCount( pos, 400, crates, 4 )

        then
            local toCheck = area:GetRandomPoint() + vecFiftyUp
            local visible = nil

            for _, visPly in ipairs( alivePlayers() ) do
                if not IsValid( visPly ) then continue end
                coroutine.yield()
                local firstChecksShootPos = visPly:GetShootPos()
                local vis, visTr = terminator_Extras.PosCanSee( toCheck, firstChecksShootPos )
                if vis then
                    visible = true
                    break

                end
                if visTr and visTr.HitPos:DistToSqr( firstChecksShootPos ) < traceHitTooCloseDist then
                    visible = true
                    break

                end
            end

            done = done + 1

            if not visible and util.IsInWorld( toCheck ) then
                table.insert( toCheckNooks, toCheck )
                if #toCheckNooks > maxToCheckNook then break end

            end
            if done > maxTraces then break end

        end
    end

    local scoredPositions = {}

    for _, toCheckPos in ipairs( toCheckNooks ) do
        coroutine.yield()
        local nookScore = terminator_Extras.GetNookScore( toCheckPos )
        -- avoid boring spaces, target very open areas or very enclosed areas.
        if nookScore < 1.5 then -- we are in a very very open space
            nookScore = 3 + math.abs( nookScore )
        end
        -- when we placing the anchor box, punish putting too close to player
        if not sortCenterIsABox then
            local dist = toCheckPos:Distance( plyShootPos )
            if dist < searchRange * 0.5 then
                local proxPunishment = ( dist - searchRange ) / searchRange
                nookScore = nookScore + ( proxPunishment * 5 )
            end
        end
        scoredPositions[ math.Round( nookScore, 2 ) ] = toCheckPos
    end

    local bestPositionKey = table.maxn( scoredPositions )
    local bestPosition = scoredPositions[ bestPositionKey ]

    -- did people move so that they could see this spot?
    for _, visPly2 in ipairs( alivePlayers() ) do
        if not IsValid( visPly2 ) then continue end
        local finalChecksShootPos = visPly2:GetShootPos()
        local vis, visTr = terminator_Extras.PosCanSee( bestPosition, finalChecksShootPos )
        if vis then
            return

        end
        if visTr and visTr.HitPos:DistToSqr( finalChecksShootPos ) < traceHitTooCloseDist then
            return

        end
    end

    return bestPosition

end

local crateSpawningCor = nil
local nextCrateSpawn = 0
local _CurTime = CurTime

-- this code was beautiful, then the coroutine attacked....

function GM:crateSpawnThink( players )
    if crateSpawningFailed then return end
    if #players > plysNeeded:GetInt() then return end
    if nextCrateSpawn > _CurTime() then return end
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then nextCrateSpawn = _CurTime() + 15 return end
    -- continue spawning calculations
    if crateSpawningCor then
        local startTime = SysTime()
        local good, result = nil, nil
        while math.abs( startTime - SysTime() ) < 0.0004 do
            if coroutine.status( crateSpawningCor ) == "dead" then break end
            good, result = coroutine.resume( crateSpawningCor )
            if good == false then
                ErrorNoHaltWithStack( result )
                crateSpawningFailed = true
                break

            end
        end

        if result == "done" or good ~= true then
            crateSpawningCor = nil

        end
    -- create the spawning function
    elseif crateSpawningCor == nil then
        crateSpawningCor = coroutine.create( function()
            local spawnPos = FindCrateSpawnPos()
            if not spawnPos then coroutine.yield( "done" ) return end

            local time = math.random( 55 * 0.8, 55 * 1.2 )

            GAMEMODE.roundExtraData = GAMEMODE.roundExtraData or {}

            proceduralCratePlaces = GAMEMODE.roundExtraData.proceduralCratePlaces or 0
            GAMEMODE.roundExtraData.proceduralCratePlaces = proceduralCratePlaces + 1

            local mod = GAMEMODE.roundExtraData.proceduralCratePlaces % 12

            local crate

            if mod == 10 and proceduralCratePlaces > 15 then
                crate = GAMEMODE:ManhackCrate( spawnPos )

            elseif mod == 9 and proceduralCratePlaces > 10 and #player.GetAll() <= 1 then
                crate = GAMEMODE:ScreamingCrate( spawnPos )

            elseif ( mod == 6 and proceduralCratePlaces > 12 ) or ( mod == 3 and proceduralCratePlaces > 20 ) then
                crate = GAMEMODE:WeaponsCrate( spawnPos )

            else
                crate = GAMEMODE:NormalCrate( spawnPos )

            end

            if not crate then coroutine.yield( "done" ) return end

            lastCrate = crate

            if ( GAMEMODE.roundExtraData.proceduralCratePlaces % 4 ) ~= 0 then
                time = 1

            else
                lastCrate = nil

            end

            if GAMEMODE.roundExtraData.proceduralCratePlaces < 6 then
                time = 1

            end

            local placedArea = GAMEMODE:getNearestNav( spawnPos, 500 )
            if placedArea and placedArea.IsValid and placedArea:IsValid() then
                placedAlready[ placedArea:GetID() ] = true

            end

            nextCrateSpawn = _CurTime() + time

            coroutine.yield( "done" )

        end )
    end
end
