local postSpawnedOvercharge = GAMEMODE.setHelpers.postSpawnedOvercharge

local defaultSpawnSet = {
    name = "hunters_glee",
    prettyName = "Hunter's Glee",
    description = "Smart, cruel enemies.\nBring them glee.",
    difficultyPerMin = 0.05, -- very little difficulty per minute, let wave clears primarily bump difficulty 
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default",
    maxSpawnCount = 6,
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    genericSpawnerRate = "default",
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator",
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 2 },
            maxCount = { 2 },
            postSpawnedFuncs = { postSpawnedOvercharge },
        },
        {
            hardRandomChance = nil,
            name = "terminator_MORE",
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 15, 25 },
            countClass = "terminator_nextbot_snail*",
            minutesNeeded = { 4, 6 },
            postSpawnedFuncs = { postSpawnedOvercharge },
        },
        {
            hardRandomChance = { 0, 2 },
            name = "terminator_doppleganger",
            prettyName = "A Terminator Doppleganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = { 20 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 2 },
            postSpawnedFuncs = { postSpawnedOvercharge },
        }
    }
}

table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
