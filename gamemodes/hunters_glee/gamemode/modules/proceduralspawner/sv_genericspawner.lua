
local CurTime = CurTime
local IsValid = IsValid
local IsTableOfEntitiesValid = IsTableOfEntitiesValid
local table_insert = table.insert
local ipairs = ipairs
local pairs = pairs

local GAMEMODE = GAMEMODE or GM

local vec_down = Vector( 0, 0, -1 )

local function justSpawnTheDamnEnt( class, tr )
    local sentTbl = scripted_ents.GetStored( class )
    local spawnFunc = scripted_ents.GetMember( class, "SpawnFunction" )
    local entitySpawned
    local data = GAMEMODE.genericSpawnTables[class]

    if sentTbl and spawnFunc and not ( data and data.preSpawnedFunc ) then
        -- you want a player, base_entity? fine.
        local fauxSpawner = GAMEMODE:anAlivePlayer()
        if not IsValid( fauxSpawner ) then return end
        entitySpawned = spawnFunc( sentTbl, fauxSpawner, tr, class )

    else
        entitySpawned = ents.Create( class )
        entitySpawned:SetPos( tr.HitPos )

        if data and data.preSpawnedFunc then
            data.preSpawnedFunc( entitySpawned )

        end

        entitySpawned:Spawn()
        entitySpawned:Activate()
        entitySpawned:DropToFloor()

    end
    if data and data.postSpawnedFunc then
        data.postSpawnedFunc( entitySpawned )

    end
    return entitySpawned

end

GAMEMODE.genericSpawnTables = GAMEMODE.genericSpawnTables or {}
local currentlySpawning = {}
local created = {}

local function onJobSuccced( spawned, className )
    --print( spawned, "AAAAAAAAAAAA" )
    currentlySpawning[className] = currentlySpawning[className] + -1
    local spawnedOfClass = created[className] or {}
    table_insert( spawnedOfClass, spawned )

end
local function onJobBail( className )
    currentlySpawning[className] = currentlySpawning[className] + -1

end
local function onJobInvalid( className )
    currentlySpawning[className] = currentlySpawning[className] + -1
    GAMEMODE.genericSpawnTables[className] = nil

end

local function addJob( curr )
    local className = curr.className
    local minAreaSize = curr.minAreaSize

    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then
        onJobBail( className )
        return false

    end

    local livePly = GAMEMODE:anAlivePlayer()
    if not IsValid( livePly ) then
        onJobBail( className )
        return false

    end

    local offsetFromGround = Vector( 0, 0, minAreaSize / 2 )
    local hull = Vector( minAreaSize, minAreaSize, minAreaSize * 0.75 ) / 4

    local theTrace = {
        mins = -hull,
        maxs = hull,
        mask = MASK_SOLID,
    }

    local genericJob = {}
    genericJob.jobsName = "auto_spawn.. " .. className
    genericJob.posFindingOrigin = livePly:GetPos()
    genericJob.spawnRadius = curr.radius or 5000
    genericJob.onFailed = function() onJobBail( className ) end

    genericJob.originIsDefinitive = false
    genericJob.sortForNearest = false
    genericJob.areaFilteringFunction = function( currJob, area )
        if area:IsBlocked() then return end
        if area:IsUnderwater() then return end

        -- cant fit the trace
        if area:GetSizeX() < minAreaSize then return end
        if area:GetSizeY() < minAreaSize then return end

        -- dont place in occupied areas
        local start = currJob:posDerivingFunc( area )[1]
        theTrace.start = start
        theTrace.endpos = start

        local trResult = util.TraceHull( theTrace )

        if trResult.Hit or trResult.StartSolid then return end

        return true

    end
    genericJob.hideFromPlayers = true
    genericJob.posDerivingFunc = function( _, area )
        local points = { area:GetCenter() + offsetFromGround }
        return points

    end
    genericJob.maxPositionsForScoring = 400
    genericJob.posScoringBudget = 1000
    genericJob.posScoringFunction = function( _, toCheckPos, budget )
        -- get nook score, the more nooked the point is, the bigger the score.
        -- makes it prefer to spawn indoors 
        local nookScore = terminator_Extras.GetNookScore( toCheckPos )

        -- too close to players!
        local nearest, distSqr = GAMEMODE:nearestAlivePlayer( toCheckPos )
        local tooClose = 750 + genericJob.spawnRadius / math.Rand( 4, 6 )

        if nearest and distSqr < tooClose^2 then
            nookScore = nookScore / 2

        end

        if nookScore >= 3 then
            entsNearby = ents.FindInSphere( toCheckPos, minAreaSize / 2 )
            local count = 0
            for _, ent in ipairs( entsNearby ) do
                if IsValid( ent ) and ent:IsSolid() and IsValid( ent:GetPhysicsObject() ) then
                    count = count + 1

                end
            end
            if count >= 1 then
                nookScore = 3 + -count

            end
        end

        budget = budget + - 1
        return nookScore

    end
    genericJob.onPosFoundFunction = function( _, bestPosition )
        -- check again
        theTrace.start = bestPosition
        theTrace.endpos = bestPosition

        local trResult = util.TraceHull( theTrace )

        if trResult.Hit or trResult.StartSolid then
            return false

        end

        local downOffs = ( minAreaSize * 1.25 )
        local quickTrace = util.QuickTrace( bestPosition, vec_down * downOffs )
        if not quickTrace.HitWorld then
            return false

        end

        local spawned = justSpawnTheDamnEnt( className, quickTrace )

        if not IsValid( spawned ) then
            onJobInvalid( className )
            print( "procedural class spawning job \"" .. className ..  "\" failed, ent didnt spawn." )
            return false

        end

        --debugoverlay.Cross( bestPosition, 100, 30, color_white, true )

        onJobSuccced( spawned, className )
        return true

    end

    GAMEMODE:addProceduralSpawnJob( genericJob )

end

local nextCheck = 0
local enabled = {}

hook.Add( "glee_sv_validgmthink_active", "glee_spawner_managegenericspawns", function()
    if nextCheck > CurTime() then return end
    nextCheck = CurTime() + 5

    -- validate the spawned tables
    for className, entsSpawned in ipairs( created ) do
        if IsTableOfEntitiesValid( entsSpawned ) then continue end
        local rebuiltTable = {}
        for _, currEnt in ipairs( entsSpawned ) do
            if IsValid( currEnt ) then
                table_insert( rebuiltTable, currEnt )

            end
        end
        created[className] = rebuiltTable

    end

    for className, curr in pairs( GAMEMODE.genericSpawnTables ) do
        -- setup
        if not currentlySpawning[className] then
            currentlySpawning[className] = 0
            created[className] = {}

        end
        -- handle random enabling/disabling
        local isEnabled = enabled[className]
        if isEnabled == nil then
            isEnabled = math.Rand( 0, 100 ) < curr.chance
            enabled[className] = isEnabled

        end
        if isEnabled == false then continue end

        local maxCount = curr.maxCount
        local count = #created[className] + currentlySpawning[className]
        --print( count, maxCount, "AAAAAAAAAAAA" )
        if count >= maxCount then continue end

        --print( "ADDED", className )
        addJob( curr )
        currentlySpawning[className] = currentlySpawning[className] + 1

    end
end )


hook.Add( "huntersglee_round_into_limbo", "glee_resetgenericspawnchances", function()
    enabled = nil
    enabled = {}
    created = nil
    created = {}
    currentlySpawning = nil
    currentlySpawning = {}

end )

hook.Add( "PreCleanupMap", "glee_resetgenericspawnchances", function()
    enabled = nil
    enabled = {}
    created = nil
    created = {}
    currentlySpawning = nil
    currentlySpawning = {}

end )




-- THE GENERIC SPAWNER IN QUESTION

-- call this func once and the gamemode will maintain X count of ents on the map
-- just run the function with a class, and itll spawn it somewhere big enough for minAreaSize
-- chance is per round chance for it to start being respawned
-- if you want to do something cooler, see the beartrap, crate, skull spawner for functioning examples

function GM:RandomlySpawnEnt( className, maxCount, chance, minAreaSize, radius, preSpawnedFunc, postSpawnedFunc )
    local curr = {
        className = className,
        chance = chance,
        maxCount = maxCount,
        minAreaSize = minAreaSize,
        radius = radius,
        preSpawnedFunc = preSpawnedFunc,
        postSpawnedFunc = postSpawnedFunc,

    }
    GAMEMODE.genericSpawnTables[className] = curr

end

-- eg.... 
-- you would put this at the very end of your shiny 'lua/entities/sent_ball.lua'
--[[

-- only enable if gamemode is GLEE
local GAMEMODE = GAMEMODE or GM
if not GAMEMODE.RandomlySpawnEnt then return end


-- keep 5 sent_balls spawned in the map
local spawnCount = 5

-- only enabled in x % of rounds
local enabledChance = 10

-- won't spawn in areas thinner/smaller than this
local minAreaSize = 25 

-- optional
local radius = 5000 -- defaults to 5000 when nil

-- optional
-- called on ent BEFORE it's spawned, also blocks this spawn from trying to find a "SpawnFunction" on the sent table
local function preSpawnedFunc( spawned )
    print( "you will soon be unable to escape the", spawned )

end

-- optional
-- called on ent after it's spawned
local function postSpawnedFunc( spawned )
    print( "you cannot escape the", spawned )

end

GAMEMODE:RandomlySpawnEnt( "sent_ball", spawnCount, enabledChance, minAreaSize, radius, preSpawnedFunc, postSpawnedFunc )

--]]