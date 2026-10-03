
local set = {
    name = "infernal_glee_titans", -- unique name
    prettyName = "The Infernal Titans",
    description = "They're huge, on fire, and bad to the bone...",
    difficultyPerMin = "default*3", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default*4", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = { 5 },
    maxSpawnCount = { 40 }, -- hard cap on count
    maxSpawnDist = "default*0.5", -- spawn close, these cant pathfind
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 1,
    chanceToBeVotableWhenHard = 5, -- stick around when this is still a challenge
    spawns = {
        {
            hardRandomChance = 50,
            name = "infernalskele", -- unique name
            prettyName = "The Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 4,
            countClass = "terminator_nextbot_infernalskeleton",
            maxCount = { 1 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRareRunning = false

                end,
            },
        },
        {
            hardRandomChance = 25,
            name = "infernalrumbler", -- unique name
            prettyName = "The Infernal Rumbler",
            class = "terminator_nextbot_infernalskeleton_large", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 4,
            countClass = "terminator_nextbot_infernalskeleton_large",
            maxCount = { 1 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRareRunning = false

                end,
            },
        },
        {
            name = "infernalskele_big_EARLY", -- unique name
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 15, 25 },
            countClass = "terminator_nextbot_infernalskeleton_big",
            maxCount = { 5 },
        },
        {
            hardRandomChance = 75,
            name = "infernalskele_big", -- unique name
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 100, 200 },
            countClass = "terminator_nextbot_infernalskeleton_big",
            maxCount = { 20 },
        },
        {
            hardRandomChance = 50,
            name = "infernalskele_big_LATE", -- unique name
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big", -- class spawned
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 500, 1000 },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
