-- TODO: make this generic and not smelly hard coded

local maxHuntersAtMinutes = {
    [0] = 2,
    -- these cannot be math.Rand apparently, have to be .random
    [math.random( 6, 10 )] = 4,
    [math.random( 10, 15 )] = 6,
    [math.random( 15, 23 )] = 7,

}

local dopplegangerChance = math.Rand( 0, 2 )

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

local waveLength = math.random( 60, 100 )

local minutesAddedPerDeadWave = 5
local deadWaveMinutesAdded = 0

if math.random( 0, 100 ) < 25 then
    minutesAddedPerDeadWave = minutesAddedPerDeadWave * math.Rand( 1, 4 )

end

local nextSpawnCheck = 0
local amntToSpawn = 0
local nextWave = 0
local waveSize = 0
local overchargedChance = 0

hook.Add( "glee_sv_validgmthink_active", "glee_spawnhunters", function( _, _, cur )
    if not GAMEMODE.HuntersGleeDoneTheGreedyPatch then return end
    if nextSpawnCheck > cur then return end
    nextSpawnCheck = cur + 0.2

    local dead = waveIsDead()
    local deadAndWasAlive = dead and wasAlive

    local overrideCount = overrideCountVar:GetInt()

    wasAlive = not dead

    if nextWave < cur or deadAndWasAlive then
        -- if bots are getting owned, increase difficulty.
        if deadAndWasAlive then
            local added = minutesAddedPerDeadWave + math.Rand( -0.25, 0.25 )
            deadWaveMinutesAdded = deadWaveMinutesAdded + added

        end

        nextWave = cur + waveLength + math.random( -20, 20 )

        local roundTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )
        local minutes = roundTime / 60
        minutes = minutes + deadWaveMinutesAdded

        for minutesNeeded, currMax in pairs( maxHuntersAtMinutes ) do
            if minutesNeeded <= minutes then
                waveSize = currMax

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

        if overrideCount > 0 then
            amntToSpawn = overrideCount
            waveSize = overrideCount

        else
            amntToSpawn = waveSize

        end

    end

    local hasSomeToSpawn = amntToSpawn > 0
    local hasRoomToSpawn = aliveHuntersCount() < waveSize

    if not hasSomeToSpawn or not hasRoomToSpawn then return end

    local classOverride = nil
    if math.random( 0, 100 ) < dopplegangerChance then
        classOverride = "terminator_nextbot_disguised"

    end
    local spawned, theHunter = GAMEMODE:spawnHunter( classOverride )

    if not spawned or not IsValid( theHunter ) then return end
    amntToSpawn = math.Clamp( amntToSpawn + -1, 0, math.huge )

    if math.random( 0, 100 ) > overchargedChance then return end
    glee_Overcharge( theHunter )
    local lightning = ents.Create( "glee_lightning" )
    lightning:SetOwner( theHunter )
    lightning:SetPos( theHunter:GetPos() )
    lightning:SetPowa( 12 )
    lightning:Spawn()

end )

hook.Add( "PostCleanupMap", "glee_resethunterspawnerstats", function()
    wasAlive = false
    nextWave = 0
    amntToSpawn = 0
    waveSize = 0
    overchargedChance = 0
    -- don't reset minutes added, so maps that kill lots of terms get harder and harder

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

local defaultRadius = 8000
local maxRadius = 9000
local minRadius = 500
local fails = 0

-- spawn a hunter as far away as possible from every player by inching a distance check around
-- made to be really random/overcomplicated so you never really know where they'll spawn from
function GM:getValidHunterPos()
    local dynamicTooCloseFailCounts = GAMEMODE.roundExtraData.dynamicTooCloseFailCounts or -2
    local dynamicTooCloseDist = GAMEMODE.roundExtraData.dynamicTooCloseDist or defaultRadius

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
            local visible, visResult
            local hitCloseBy
            if not invalid then
                visible, visResult = terminator_Extras.PosCanSee( pos, checkPos )
                hitCloseBy = visResult.HitPos:DistToSqr( checkPos ) < 350^2

            end
            if visible or hitCloseBy then
                invalid = true

            -- always check for this
            elseif pos:DistToSqr( checkPos ) < dynamicTooCloseDist^2 then -- dist check!
                invalid = true
                wasTooClose = true
                break

            end
        end

        if randomArea:IsUnderwater() then
            -- make it a bit closer
            dynamicTooCloseDist = dynamicTooCloseDist - 100
            GAMEMODE.roundExtraData.dynamicTooCloseDist = math.Clamp( dynamicTooCloseDist, minRadius, maxRadius )

        end

        if not invalid or ( fails > 2000 and not wasTooClose ) then
            fails = 0
            -- good spawnpoint, spawn here
            --debugoverlay.Cross( spawnPos, 100, 20, color_white, true )
            GAMEMODE.roundExtraData.dynamicTooCloseFailCounts = -2
            return spawnPos, true

        end

        fails = fails + 1

        -- random picked area was too close, decrease cutoff radius
        if wasTooClose then
            --debugoverlay.Cross( spawnPos, 10, 20, Color( 255,0,0 ), true )
            GAMEMODE.roundExtraData.dynamicTooCloseFailCounts = dynamicTooCloseFailCounts + 1
            dynamicTooCloseDist = dynamicTooCloseDist + ( -dynamicTooCloseFailCounts * 25 )
            GAMEMODE.roundExtraData.dynamicTooCloseDist = math.Clamp( dynamicTooCloseDist, minRadius, maxRadius )

        end
    end
    return nil, nil

end
