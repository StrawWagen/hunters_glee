-- credit boometaters!

local set = {
    name = "hunters_glee_doppelganger", -- unique name
    prettyName = "You!",
    description = "Hey it's you, and you! And me? ...and you. and you. and oh god, oh god yOU? AND YOU? AND HIM, AND HER?",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = 1,
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 1,
    spawns = {
        {
            hardRandomChance = nil,
            name = "you",
            prettyName = "A Doppelganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = 10,
            countClass = "terminator_nextbot_snail_disguised",
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
