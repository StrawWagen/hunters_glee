local set = {
    name = "infernal_glee_titans",
    prettyName = "The Infernal Titans",
    description = "They're huge, on fire, and bad to the bone...",
    difficultyPerMin = "default*3",
    waveInterval = "default*0.35",
    diffBumpWhenWaveKilled = "default*4",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = { 5 },
    maxSpawnCount = { 40 },
    maxSpawnDist = "default*0.5", -- spawn close, these cant pathfind
    roundEndSound = "default",
    roundEarlyStartSound = "hunters_glee/music/alexscott/glee_inferno_titans.mp3",
    chanceToBeVotable = 1,
    chanceToBeVotableWhenHard = 5, -- stick around when this is still a challenge
    spawns = {
        {
            hardRandomChance = 50,
            name = "infernalskele",
            prettyName = "The Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 4,
            maxCount = { 1 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRunsAfterEnemySprints = false

                end,
            },
        },
        {
            hardRandomChance = 25,
            name = "infernalrumbler",
            prettyName = "The Infernal Rumbler",
            class = "terminator_nextbot_infernalskeleton_large",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 4,
            maxCount = { 1 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRunsAfterEnemySprints = false

                end,
            },
        },
        {
            name = "infernalskele_big_EARLY",
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big",
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 15, 25 },
            maxCount = { 5 },
        },
        {
            hardRandomChance = 75,
            name = "infernalskele_big",
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big",
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 100, 200 },
            maxCount = { 20 },
        },
        {
            hardRandomChance = 50,
            name = "infernalskele_big_LATE",
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big",
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 500, 1000 },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
