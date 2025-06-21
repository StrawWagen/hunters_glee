local function giveCamera( _, hunter )
    hunter:Give( "gmod_camera" )

end

local set = {
    name = "hunters_glee_paparazzi", -- unique name
    prettyName = "Paparazzi's Glee",
    description = "Oh god, they're taking photos of us!",
    difficultyPerMin = { 250 / 10, 500 / 10 }, -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 15, 25 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default",
    maxSpawnCount = { 25 }, -- hard cap on count
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "paparazzi", -- unique name
            prettyName = "Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 2,
            countClass = "terminator_nextbot*", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 20 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs = { giveCamera },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
