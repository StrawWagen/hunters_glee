
local hasSanic = scripted_ents.GetStored( "npc_sanic" )
local hasObunga = scripted_ents.GetStored( "npc_obunga" )

if not ( hasSanic or hasObunga ) then return end -- you are safe


local set = {
    name = "nextbot_brainrot", -- unique name
    prettyName = "PNG Nextbot Brainrot",
    description = "Sanic, and/or Obunga.\nObjectively shallower gameplay.\nYou happy now?",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = { 0.05 },
    startingSpawnCount = { 0, 2 },
    maxSpawnCount = 50, -- hard cap on count
    resourcesAdded = {},
    spawns = {}
}

if hasSanic then
    local npc = {
        hardRandomChance = { 15, 75 }, -- chance this is even checked
        name = "brainrot_sanic",
        prettyName = "A Sanic",
        class = "npc_sanic",
        spawnType = "hunter",
        difficultyCost = { 10 },
        countClass = "npc_sanic",
        minCount = { 0 },
        maxCount = { 50 },
    }
    table.insert( set.spawns, npc )
    table.insert( set.resourcesAdded, "174117071" )
    RunConsoleCommand( "npc_sanic_force_download", 0 ) -- nuh uh
    RunConsoleCommand( "npc_sanic_acquire_distance", 99999 )

end

if hasObunga then
    local npc = {
        hardRandomChance = { 15, 75 }, -- chance this is even checked
        name = "brainrot_obunga",
        prettyName = "An Obunga",
        class = "npc_obunga",
        spawnType = "hunter",
        difficultyCost = { 10 },
        countClass = "npc_obunga",
        minCount = { 0 },
        maxCount = { 50 },
    }
    table.insert( set.spawns, npc )
    table.insert( set.resourcesAdded, "2803406998" )
    RunConsoleCommand( "npc_obunga_force_download", 0 )
    RunConsoleCommand( "npc_obunga_acquire_distance", 99999 )

end

if #set.spawns <= 0 then return end ---???? might happen

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
