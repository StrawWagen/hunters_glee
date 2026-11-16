local function giveCamera( _, hunter )
    hunter:Give( "gmod_camera" )

end

local set = {
    name = "hunters_glee_paparazzi",
    prettyName = "Paparazzi's Glee",
    description = "Oh god, they're taking photos of us!",
    difficultyPerMin = "default*3",
    waveInterval = "default",
    diffBumpWhenWaveKilled = { 15, 25 },
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default",
    maxSpawnCount = { 40 },
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "paparazzi",
            prettyName = "Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = 2,
            countClass = "terminator_nextbot*",
            minCount = { 0 },
            maxCount = { 20 },
            postSpawnedFuncs = { giveCamera },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
