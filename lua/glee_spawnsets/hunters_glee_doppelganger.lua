local set = {
    name = "hunters_glee_doppelganger", -- unique name
    prettyName = "Doppelgangers",
    description = "It's... You?",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = 1,
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "you",
            prettyName = "A Doppelganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 15 }, -- will never exceed this count, uses findbycount
            countClass = "terminator_nextbot_snail_disguised",
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
