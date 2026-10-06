
local set = {
    name = "hunters_glee_oneguy", -- unique name
    prettyName = "You!",
    description = "It's you!",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
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
            countClass = "terminator_nextbot_snail_disguised",
            postSpawnedFuncs = { maybeOverchargeThisDude },
            isBoss = true,
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
