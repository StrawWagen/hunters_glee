local set = {
    name = "hunters_glee_easy",
    prettyName = "Gleefully Relaxed Hunters",
    description = "Smart, bulletproof, cruel enemies, in very limited numbers. Beware.",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = { 5, 10 },
    startingBudget = "default",
    spawnCountPerDifficulty = "default*0.5",
    startingSpawnCount = 1,
    maxSpawnCount = 2,
    maxSpawnDist = { 2500, 3500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 5, -- and fade into the background if this host isn't challenged by this
    chanceToBeVotableWhenHard = 20, -- stick around when this is still a challenge
    easy = true,
    tutorialExit = true,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator_rusty",
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail_skinlessrusty",
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
            difficultyStopAfter = { 50, 75 },
            minCount = { 1 },
            maxCount = { 1 },
        },
        {
            hardRandomChance = nil,
            name = "terminator",
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 15, 25 },
        },
        {
            hardRandomChance = { 0, 2 },
            name = "terminator_doppleganger",
            prettyName = "Terminator Doppleganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = { 20 },
        }
    }
}

table.insert( GLEE_SPAWNSETS, set )
