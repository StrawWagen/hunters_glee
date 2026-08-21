
local set = {
    name = "infernal_glee_thehorde", -- unique name
    prettyName = "The Infernal Horde",
    description = "It burns, it burns! IT BURNS!",
    difficultyPerMin = "default*3", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default*4", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default*5",
    maxSpawnCount = { 40 }, -- hard cap on count
    maxSpawnDist = "default*0.5", -- spawn close, these cant pathfind
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 1,
    chanceToBeVotableWhenHard = 5, -- stick around when this is still a challenge
    spawns = {
        {
            hardRandomChance = nil,
            name = "infernalskele", -- unique name
            prettyName = "An Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 2,
            preSpawnedFuncs = function( _, spawned )
                spawned.SpawnHeadlessChance = 85

            end,
        },
        {
            hardRandomChance = 15,
            name = "infernalskele_big_EARLY", -- unique name
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 100, 200 },
            countClass = "terminator_nextbot_infernalskeleton_big",
            maxCount = { 1 },
        },
        {
            hardRandomChance = nil,
            name = "infernalskele_big_LATE", -- unique name
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 1000, 2000 },
            countClass = "terminator_nextbot_infernalskeleton_big",
            maxCount = { 10 },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
