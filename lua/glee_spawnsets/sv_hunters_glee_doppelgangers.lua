-- credit boometaters!

local set = {
    name = "hunters_glee_doppelgangers",
    prettyName = "Us?",
    description = "Hey it's you, and you! And me? ...and you. and you. and oh god, oh god yOU? AND YOU? AND HIM, AND HER?",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = 1,
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 1,
    spawns = {
        {
            hardRandomChance = nil,
            name = "you",
            prettyName = "A Doppelganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = 10,
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
