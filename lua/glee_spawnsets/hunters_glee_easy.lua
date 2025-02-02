local set = {
    name = "hunters_glee_easy", -- unique name
    prettyName = "Baby's first Glee",
    description = "Hunter's Glee with no overcharged hunters, less terminators overall.\nBasically story mode.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 5, 10 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = 1,
    maxSpawnCount = 5, -- hard cap on count
    themeSound = "default",
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator", -- unique name
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 15, 25 },
            countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
            minCount = { 1 }, -- will ALWAYS maintain this count
            maxCount = { 5 }, -- will never exceed this count, uses findbycount
        },
        {
            hardRandomChance = { 0, 2 }, -- chance this is even checked
            name = "terminator_doppleganger",
            prettyName = "Terminator Doppleganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = { 20 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 2 },
            maxCount = { 5 },
        }
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
