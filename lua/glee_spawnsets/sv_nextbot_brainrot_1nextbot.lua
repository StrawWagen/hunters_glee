
local hasSanic = scripted_ents.GetStored( "npc_sanic" )
local hasObunga = scripted_ents.GetStored( "npc_obunga" )

if not ( hasSanic or hasObunga ) then return end -- you are safe


local set = {
    name = "nextbot_brainrot_1nextbot", -- unique name
    prettyName = "The PNG Nextbot",
    description = "The true smartest enemy.",
    resourcesAdded = {},
    spawns = {},
    maxSpawnCount = 1, -- hard cap on count
    chanceToBeVotable = 0.25,
    chanceToBeVotableIfHard = 1,
    easy = true,
}

local varRandomizers = {}

if hasSanic then
    local function randomizeVar()
        local dist = math.random( 2500, 6000 )
        if math.random( 0, 100 ) < 50 then
            dist = dist * math.random( 1, 10 )

        end
        RunConsoleCommand( "npc_sanic_acquire_distance", dist )

    end
    varRandomizers[#varRandomizers + 1] = randomizeVar

    local npc = {
        hardRandomChance = { 15, 75 }, -- chance this is even checked, only exists cause both can be installed sometimes
        name = "brainrot_sanic",
        prettyName = "The Sanic",
        class = "npc_sanic",
        spawnType = "hunter",
        difficultyCost = { 10 },
        countClass = "npc_sanic",
        maxCount = { 1 },
        postSpawnedFuncs = { randomizeVar }, -- this can be nil
        isBoss = true,
    }
    table.insert( set.spawns, npc )
    table.insert( set.resourcesAdded, "174117071" )
    RunConsoleCommand( "npc_sanic_force_download", 0 ) -- nuh uh

end

if hasObunga then
    local function randomizeVar()
        local dist = math.random( 2500, 6000 )
        if math.random( 0, 100 ) < 50 then
            dist = dist * math.random( 1, 10 )

        end
        RunConsoleCommand( "npc_obunga_acquire_distance", dist )

    end
    varRandomizers[#varRandomizers + 1] = randomizeVar

    local npc = {
        hardRandomChance = { 15, 75 },
        name = "brainrot_obunga",
        prettyName = "The Obunga",
        class = "npc_obunga",
        spawnType = "hunter",
        difficultyCost = { 15 },
        countClass = "npc_obunga",
        maxCount = { 1 },
        postSpawnedFuncs = { randomizeVar }, -- this can be nil
        isBoss = true,
    }
    table.insert( set.spawns, npc )
    table.insert( set.resourcesAdded, "2803406998" )
    RunConsoleCommand( "npc_obunga_force_download", 0 )

end

if #set.spawns <= 0 then return end ---???? might happen

function set:Activate()
    -- these nextbots don't handle death right
    -- they keep movin!
    self:Hook( "OnNPCKilled", function( npc )
        if npc.glee_SpawnsetThatMadeMe ~= self.name then return end
        SafeRemoveEntity( npc )

    end )
    self:Timer( "MessWithFindDistances", 60, 0, function()
        for _, func in ipairs( varRandomizers ) do
            func()

        end
    end )
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
