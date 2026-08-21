
local set = {
    name = "infernal_glee_thehorde", -- unique name
    prettyName = "The Infernal Horde",
    description = "It burns, it burns! IT BURNS!",
    difficultyPerMin = "default*3", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default*4", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = { 25 },
    maxSpawnCount = { 40 }, -- hard cap on count
    maxSpawnDist = "default*0.5", -- spawn close, these cant pathfind
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 2,
    chanceToBeVotableWhenHard = 20, -- stick around when this is still a challenge
    spawns = {
        {
            name = "infernal_ambler", -- unique name
            prettyName = "An Infernal Ambler",
            class = "terminator_nextbot_infernalskeleton_slow", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = 1,
            difficultyStopAfter = { 50, 100 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SpawnHeadlessChance = 95

                end,
            },
        },
        {
            hardRandomChance = 85,
            name = "infernalskele", -- unique name
            prettyName = "An Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 4,
            difficultyStopAfter = { 500, 1000 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SpawnHeadlessChance = 80

                end,
            },
        },
        {
            hardRandomChance = 25,
            name = "infernalskele_undersky", -- unique name
            prettyName = "An Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton", -- class spawned
            spawnType = "hunter",
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = 6,
        },
        {
            hardRandomChance = 15,
            name = "infernalskele_large_EARLY", -- unique name
            prettyName = "An Infernal Rumbler",
            class = "terminator_nextbot_infernalskeleton_large", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 50, 100 },
            countClass = "terminator_nextbot_infernalskeleton_large",
            maxCount = { 1 },
        },
        {
            hardRandomChance = 15,
            name = "infernalskele_big_EARLY", -- unique name
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 100, 200 },
            countClass = "terminator_nextbot_infernalskeleton_big",
            maxCount = { 1 },
        },
        {
            hardRandomChance = nil,
            name = "infernalskele_large_LATE", -- unique name
            prettyName = "An Infernal Rumbler",
            class = "terminator_nextbot_infernalskeleton_large", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 500, 1000 },
            countClass = "terminator_nextbot_infernalskeleton_large",
            maxCount = { 10 },
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
