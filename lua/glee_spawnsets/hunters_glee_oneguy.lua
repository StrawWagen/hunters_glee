local zambieSpawnSet = {
    name = "hunters_glee_oneguy", -- unique name
    prettyName = "One Gleeful Hunter",
    description = "One Terminator, he'll always be back.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    maxSpawnDist = { 4500, 6500 },
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 25,
    spawns = {
        {
            hardRandomChance = nil,
            name = "zambie_godcrab",
            prettyName = "The Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = 1,
            maxCount = 1,
            countClass = "terminator_nextbot_snail*",
        },
    }
}

table.insert( GLEE_SPAWNSETS, zambieSpawnSet )
