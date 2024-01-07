
-- z in the filename so its last in alphabetical order lol

local plysNeeded = CreateConVar( "huntersglee_proceduralcratesmaxplayers", 8, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Player count threshold to stop randomly spawning weapon crates", 0, 32 )


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

local vecFiftyUp = Vector( 0, 0, 50 )
local placedAlready = {}

local staleAndNeedsAScreamer = nil
local boringTimeNeededForScreamer = 0
local nextCrateMixupSpawn = 0
local lastCrate = nil
local anchorCrate = nil

local nextCrateSpawn = 0
local CurTime = CurTime

local crates = {}

hook.Add( "Think", "glee_addcratejobs", function()
    if #player.GetAll() > plysNeeded:GetInt() then return end
    if nextCrateSpawn > CurTime() then return end
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then nextCrateSpawn = CurTime() + 15 return end

    -- if nothing is happening, spawn a screamer crate early
    if nextCrateMixupSpawn < CurTime() then
        nextCrateMixupSpawn = CurTime() + boringTimeNeededForScreamer * math.Rand( 0.45, 0.75 )
        staleAndNeedsAScreamer = true

    end

    local time = math.random( 55 * 0.8, 55 * 1.2 )

    crates = ents.FindByClass( "item_item_crate" )
    if #crates > 30 then nextCrateSpawn = CurTime() + 10 return end

    local alivePlayer = GAMEMODE:anAlivePlayer()
    if not IsValid( alivePlayer ) then return end

    local crateJob = {}
    crateJob.jobsName = "crate"
    crateJob.posFindingOrigin = alivePlayer:GetPos()
    crateJob.originIsDefinitive = false
    crateJob.sortForNearest = false

    crateJob.placedAlready = placedAlready

    crateJob.areaFilteringFunction = function( currJob, area )
        if area:IsBlocked() then return end
        if area:IsUnderwater() then return end
        -- dont place anchor boxes in spots already taken!
        if not currJob.sortForNearest and currJob.placedAlready[ area:GetID() ] then return end
        if nearbyGreaterThanCount( area:GetCenter(), 400, crates, 4 ) then return end
        return true

    end
    crateJob.hideFromPlayers = true
    crateJob.posDerivingFunc = function( _, area )
        local points = { area:GetRandomPoint() + vecFiftyUp }
        for _, spot in ipairs( area:GetHidingSpots( 1 ) ) do
            table.insert( points, spot + vecFiftyUp )

        end
        return points

    end
    crateJob.maxPositionsForScoring = 400
    crateJob.posScoringBudget = 1000
    crateJob.posScoringFunction = function( currJob, toCheckPos, budget )
        -- get nook score, the more nooked the point is, the bigger the score.
        local nookScore = terminator_Extras.GetNookScore( toCheckPos )

        -- if point is in a really really open spot, give a good score, leads to weird crates in the middle of roads and stuff.
        if nookScore < 1.5 then -- we are in a very very open space
            nookScore = 3 + math.abs( nookScore )

        end
        -- when we placing the anchor box, punish putting too close to player
        if not currJob.sortForNearest then
            local dist = toCheckPos:Distance( currJob.spawningOrigin )
            if dist < currJob.spawnRadius * 0.5 then
                local proxPunishment = ( dist - currJob.spawnRadius ) / currJob.spawnRadius
                nookScore = nookScore + ( proxPunishment * 5 )

            end
        end
        budget = budget + - 1
        return nookScore

    end

    GAMEMODE.roundExtraData = GAMEMODE.roundExtraData or {}
    proceduralCratePlaces = GAMEMODE.roundExtraData.proceduralCratePlaces or 0
    GAMEMODE.roundExtraData.proceduralCratePlaces = proceduralCratePlaces + 1

    local mod = GAMEMODE.roundExtraData.proceduralCratePlaces % 12

    -- handle placing crates in groups
    if ( GAMEMODE.roundExtraData.proceduralCratePlaces % 4 ) == 0 or not IsValid( anchorCrate ) then
        anchorCrate = lastCrate

    elseif IsValid( anchorCrate ) then
        crateJob.posFindingOrigin = anchorCrate:GetPos()
        crateJob.sortForNearest = true
        crateJob.spawnRadiusOverride = 3500
        crateJob.maxPositionsForScoring = 100

    end

    if ( GAMEMODE.roundExtraData.proceduralCratePlaces % 4 ) ~= 3 then
        time = 5

    end
    if GAMEMODE.roundExtraData.proceduralCratePlaces < 6 then
        time = 1

    end

    if mod == 10 and proceduralCratePlaces > 15 then
        crateJob.onPosFoundFunction = function( _, bestPosition )
            local crate = GAMEMODE:ManhackCrate( bestPosition )
            if not IsValid( crate ) then return false end
            hook.Run( "glee_proccrates_cratespawned", crate )

            return true

        end
    elseif ( mod == 9 and proceduralCratePlaces > 10 and #GAMEMODE:getDeadPlayers() <= 0 ) or staleAndNeedsAScreamer then
        staleAndNeedsAScreamer = nil
        crateJob.onPosFoundFunction = function( _, bestPosition )
            local crate = GAMEMODE:ScreamingCrate( bestPosition )
            if not IsValid( crate ) then return false end
            hook.Run( "glee_proccrates_cratespawned", crate )

            return true

        end
        crateJob.spawnRadiusOverride = 3500
    elseif ( mod == 6 and proceduralCratePlaces > 12 ) or ( mod == 3 and proceduralCratePlaces > 20 ) then
        crateJob.onPosFoundFunction = function( _, bestPosition )
            local crate = GAMEMODE:WeaponsCrate( bestPosition )
            if not IsValid( crate ) then return false end
            hook.Run( "glee_proccrates_cratespawned", crate )

            return true

        end
    else
        crateJob.onPosFoundFunction = function( _, bestPosition )
            local crate = GAMEMODE:NormalCrate( bestPosition )
            if not IsValid( crate ) then return false end
            hook.Run( "glee_proccrates_cratespawned", crate )

            return true

        end
    end

    GAMEMODE:addProceduralSpawnJob( crateJob )
    --print( "ADDED" )
    --PrintTable( crateJob )

    nextCrateSpawn = CurTime() + time

end )

-- do this otherwise placedAlready doesnt get appeneded within the curoutine for some reason
local function postPlaced( bestPosition )
    local placedArea = GAMEMODE:getNearestNav( bestPosition, 500 )
    if placedArea and placedArea.IsValid and placedArea:IsValid() then
        placedAlready[ placedArea:GetID() ] = true
        for _, area in ipairs( placedArea:GetAdjacentAreas() ) do
            placedAlready[ area:GetID() ] = true

        end
    end
end

hook.Add( "glee_proccrates_cratespawned", "tracklastcrate", function( crate )
    lastCrate = crate
    postPlaced( crate:GetPos() )

end )

hook.Add( "terminator_spotenemy", "glee_trackifbots_needahint", function()
    nextCrateMixupSpawn = CurTime() + boringTimeNeededForScreamer

end )

hook.Add( "huntersglee_round_into_active", "glee_resetboringtime", function()
    boringTimeNeededForScreamer = math.random( 240, 360 )
    nextCrateMixupSpawn = CurTime() + boringTimeNeededForScreamer

    staleAndNeedsAScreamer = nil

end )