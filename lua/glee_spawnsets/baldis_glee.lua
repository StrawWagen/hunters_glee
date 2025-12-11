local hasBaldi = scripted_ents.GetStored( "npc_accurate_baldi_cg" )

if not hasBaldi then return end


local set = {
    name = "baldis_glee",
    prettyName = "Basic Education",
    description = "Baldi wants to teach you a lesson.",
    difficultyPerMin = { 100 / 10, 1000 / 10 },
    waveInterval = { 30, 90 },
    diffBumpWhenWaveKilled = 50,
    startingBudget = "default",
    spawnCountPerDifficulty = { 0.05 },
    startingSpawnCount = { 0, 1 },
    maxSpawnCount = 1,
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    resourcesAdded = { "3296659042" },
    spawns = {},
    chanceToBeVotable = 15,
}

local npc = {
    name = "cg_baldi",
    prettyName = "Baldi.",
    class = "npc_accurate_baldi_cg",
    spawnType = "hunter",
    difficultyCost = { 15 },
    countClass = "npc_accurate_baldi_cg",
    maxCount = { 1 },
}
table.insert( set.spawns, npc )

if #set.spawns <= 0 then return end

table.insert( GLEE_SPAWNSETS, set )
