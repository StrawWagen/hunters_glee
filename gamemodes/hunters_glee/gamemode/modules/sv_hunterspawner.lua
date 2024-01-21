local maxHuntersAtMinutes = {
    [0] = 2,
    [math.Rand( 3, 5 )] = 4,
    [math.Rand( 8, 12 )] = 6,
    [math.Rand( 15, 25 )] = 7,

}

local dopplegangerChanceAtMinutes = {
    [0] = math.Rand( 0, 5 ),
    [10] = math.Rand( 5, 10 ),
    [20] = math.Rand( 10, 25 ),

}

local overchargedChanceAtMinutes = {
    [0] = 0,
    [10] = math.Rand( 0, 1 ),
    [30] = math.Rand( 5, 25 ),
    [60] = math.Rand( 50, 100 ),

}

local overrideCountVar = CreateConVar( "huntersglee_spawneroverridecount", 0, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Overrides how many terminators will spawn, 0 for automatic count. Above 5 WILL lag.", 0, 32 )

local function aliveHuntersCount()
    local aliveTermsCount = 0
    for _, hunter in ipairs( GAMEMODE.termHunt_hunters ) do
        if IsValid( hunter ) and hunter:Health() > 0 then
            aliveTermsCount = aliveTermsCount + 1

        end
    end
    return aliveTermsCount

end

local wasAlive = false

local function waveIsDead()
    return aliveHuntersCount() <= 0

end

local waveLength = math.random( 120, 180 )

local nextSpawnCheck = 0
local amntToSpawn = 0
local nextWave = 0
local waveSize = 0
local dopplegangerChance = 0
local overchargedChance = 0

hook.Add( "glee_sv_validgmthink_active", "glee_spawnhunters", function( _, _, cur )
    if not GAMEMODE.HuntersGleeDoneTheGreedyPatch then return end
    if nextSpawnCheck > cur then return end
    nextSpawnCheck = cur + 0.2

    local dead = waveIsDead()
    local deadAndWasAlive = dead and wasAlive

    wasAlive = not dead

    if nextWave < cur or deadAndWasAlive then
        nextWave = cur + waveLength + math.random( -20, 20 )
        local roundTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )
        local minutes = roundTime / 60
        --print( minutes )

        for minutesNeeded, currMax in pairs( maxHuntersAtMinutes ) do
            if minutesNeeded <= minutes then
                waveSize = currMax

            else
                break

            end
        end

        for minutesNeeded, currChance in pairs( dopplegangerChanceAtMinutes ) do
            if minutesNeeded <= minutes then
                dopplegangerChance = currChance

            else
                break

            end
        end

        for minutesNeeded, currChance in pairs( overchargedChanceAtMinutes ) do
            if minutesNeeded <= minutes then
                overchargedChance = currChance

            else
                break

            end
        end
        if overchargedChance >= 5 and not GAMEMODE.roundExtraData.overchargedWarning then
            GAMEMODE.roundExtraData.overchargedWarning = true
            huntersGlee_Announce( player.GetAll(), 100, 10, "This hunt has gone on too long...\nOvercharged Hunters are on the prowl..." )

        end

        amntToSpawn = 0

        amntToSpawn = amntToSpawn + waveSize

    end

    local overrideCount = overrideCountVar:GetInt()

    local hasSomeToSpawn = amntToSpawn > 0
    local hasRoomToSpawn = aliveHuntersCount() < math.max( waveSize, overrideCount )

    if hasSomeToSpawn and hasRoomToSpawn then
        local classOverride = nil
        if math.random( 0, 100 ) < dopplegangerChance then
            classOverride = "sb_advanced_nextbot_terminator_hunter_snail_disguised"

        end
        local spawned, theHunter = GAMEMODE:spawnHunter( classOverride )

        if spawned and IsValid( theHunter ) then
            amntToSpawn = math.Clamp( amntToSpawn + -1, 0, math.huge )

            if math.random( 0, 100 ) < overchargedChance then
                glee_Overcharge( theHunter )
                local lightning = ents.Create( "glee_lightning" )
                lightning:SetOwner( theHunter )
                lightning:SetPos( theHunter:GetPos() )
                lightning:SetPowa( 12 )
                lightning:Spawn()

            end
        end
    end
end )

function GM:spawnHunter( classOverride )

    local spawnPos, valid = GAMEMODE:getValidHunterPos()

    if not valid then return end

    --debugoverlay.Cross( spawnPos, 50, 20, Color( 0,0,255 ), true )

    if not isvector( spawnPos ) then return end
    local class = classOverride or GAMEMODE:GetHuntersClass()
    local hunter = ents.Create( class )

    if not IsValid( hunter ) then return end

    hunter:SetPos( spawnPos )
    hunter:Spawn()
    print( hunter )
    table.insert( GAMEMODE.termHunt_hunters, hunter )

    return true, hunter

end

-- spawn a hunter as far away as possible from every player by inching a distance check around
function GM:getValidHunterPos()
    local targetDistanceMin = 9000
    local dynamicTooCloseFailCounts = GAMEMODE.roundExtraData.dynamicTooCloseFailCounts or -2
    local dynamicTooCloseDist = GAMEMODE.roundExtraData.dynamicTooCloseDist or targetDistanceMin

    if not GAMEMODE.biggestNavmeshGroups then return nil, nil end

    local _, theMainGroup = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()

    local playerShootPositions = GAMEMODE:allPlayerShootPositions()

    -- multiple attempts, will march distance down if we can't find a good option, marches up if there is a good spot
    -- makes it super random yet grounded
    for _ = 0, 10 do
        local spawnPos = nil
        local randomArea = table.Random( theMainGroup )
        if not randomArea or not IsValid( randomArea ) then continue end
        spawnPos = randomArea:GetCenter()

        if not isvector( spawnPos ) then continue end
        spawnPos = spawnPos + Vector( 0,0,20 )

        local checkPos = spawnPos + Vector( 0,0,50 )
        local invalid = nil
        local wasTooClose = nil

        for _, pos in ipairs( playerShootPositions ) do
            local visible, visResult = terminator_Extras.posCanSee( pos, checkPos )
            local hitCloseBy = visResult.HitPos:DistToSqr( checkPos ) < 350^2
            if visible or hitCloseBy then
                invalid = true
                break

            elseif pos:DistToSqr( checkPos ) < dynamicTooCloseDist^2 then -- dist check!
                invalid = true
                wasTooClose = true
                break

            end
        end

        if not invalid then
            --debugoverlay.Cross( spawnPos, 100, 20, color_white, true )
            GAMEMODE.roundExtraData.dynamicTooCloseFailCounts = -2
            return spawnPos, true

        end

        -- random picked area was too close, decrease radius
        if wasTooClose then
            --debugoverlay.Cross( spawnPos, 10, 20, Color( 255,0,0 ), true )
            GAMEMODE.roundExtraData.dynamicTooCloseFailCounts = dynamicTooCloseFailCounts + 1
            dynamicTooCloseDist = dynamicTooCloseDist + ( -dynamicTooCloseFailCounts * 25 )
            GAMEMODE.roundExtraData.dynamicTooCloseDist = dynamicTooCloseDist

        end
    end
    return nil, nil

end
