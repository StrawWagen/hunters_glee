local set = {
    name = "hunters_glee_loreaccurate", -- unique name
    prettyName = "Lore Accurate Glee",
    description = "One Lore Accurate Terminator.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    maxSpawnDist = { 2500, 4500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
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
            countClass = "terminator_nextbot_loreaccurate",
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
