local terminatorSpawnSet = {
    name = "hunters_glee_wraiths",
    prettyName = "Terminator Wraiths",
    description = "Tons of cloaking terminators, are you up for a real challenge?",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default",
    maxSpawnCount = "default",
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 4, -- and fade into the background if this host isn't challenged by this
    chanceToBeVotableWhenHard = 15, -- stick around
    spawns = {
        {
            name = "terminator_invisible",
            prettyName = "A Wraith Terminator",
            class = "terminator_nextbot_wraith",
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
            minCount = { 3 },
            postSpawnedFuncs = nil,
        },
    }
}

table.insert( GLEE_SPAWNSETS, terminatorSpawnSet )
