
local  terminatorSpawnSet = {
    name = "hunters_glee_wraiths", -- unique name
    prettyName = "Terminator Wraiths",
    description = "Tons of cloaking terminators, are you up for a real challenge?",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = "default",
    maxSpawnCount = "default",
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 15,
    spawns = {
        {
            name = "terminator_invisible",
            prettyName = "A Wraith Terminator",
            class = "terminator_nextbot_wraith",
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
            countClass = "terminator_nextbot_wraith",
            minCount = { 3 },
            postSpawnedFuncs = nil,
        },
    }
}

table.insert( GLEE_SPAWNSETS, terminatorSpawnSet )
