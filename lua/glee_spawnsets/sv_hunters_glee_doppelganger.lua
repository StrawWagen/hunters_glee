local set = {
    name = "hunters_glee_oneguy",
    prettyName = "You!",
    description = "It's you!",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    maxSpawnDist = { 2500, 3500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 1, -- and fade into the background if this host isn't challenged by it
    chanceToBeVotableWhenHard = 15, -- stick around
    easy = true,
    spawns = {
        {
            hardRandomChance = nil,
            name = "the_doppleganger",
            prettyName = "The Doppleganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = 1,
            maxCount = 1,
            postSpawnedFuncs = { maybeOverchargeThisDude },
            isBoss = true,
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
