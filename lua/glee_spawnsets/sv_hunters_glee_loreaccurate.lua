local set = {
    name = "hunters_glee_loreaccurate",
    prettyName = "Lore Accurate Glee",
    description = "One Lore Accurate Terminator.",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    maxSpawnDist = { 2500, 4500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 8,
    spawns = {
        {
            hardRandomChance = nil,
            name = "theOneTerminator",
            prettyName = "The Lore Accurate Terminator",
            class = "terminator_nextbot_loreaccurate",
            spawnType = "hunter",
            difficultyCost = 1,
            maxCount = 1,
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
