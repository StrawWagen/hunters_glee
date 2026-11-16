local set = {
    name = "infernal_glee_thehorde",
    prettyName = "The Infernal Horde",
    description = "It burns, it burns! IT BURNS!",
    difficultyPerMin = "default*3",
    waveInterval = "default*0.35",
    diffBumpWhenWaveKilled = "default*4",
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = { 25 },
    maxSpawnCount = { 40 },
    maxSpawnDist = "default*0.5", -- spawn close, these cant pathfind
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 15,
    chanceToBeVotableWhenHard = 50, -- stick around when this is still a challenge
    spawns = {
        {
            name = "infernal_ambler",
            prettyName = "An Infernal Ambler",
            class = "terminator_nextbot_infernalskeleton_slow",
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
            name = "infernalskele",
            prettyName = "An Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = 4,
            difficultyStopAfter = { 2000, 4000 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SpawnHeadlessChance = 80
                    spawned.SkeleRunsAfterEnemySprints = false

                end,
            },
        },
        {
            hardRandomChance = 35,
            name = "infernalskele_undersky",
            prettyName = "An Infernal Heckler",
            class = "terminator_nextbot_infernalskeleton",
            spawnType = "hunter",
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = 6,
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRunsAfterEnemySprints = false

                end,
            },
        },
        {
            hardRandomChance = 15,
            name = "infernalskele_large_EARLY",
            prettyName = "An Infernal Rumbler",
            class = "terminator_nextbot_infernalskeleton_large",
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 50, 100 },
            maxCount = { 1 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRunsAfterEnemySprints = false

                end,
            },
        },
        {
            hardRandomChance = 15,
            name = "infernalskele_big_EARLY",
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big",
            spawnType = "hunter",
            spawnSameZ = true,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            difficultyCost = { 100, 200 },
            maxCount = { 1 },
        },
        {
            hardRandomChance = nil,
            name = "infernalskele_large_LATE",
            prettyName = "An Infernal Rumbler",
            class = "terminator_nextbot_infernalskeleton_large",
            spawnType = "hunter",
            difficultyCost = { 500, 1000 },
            maxCount = { 10 },
            preSpawnedFuncs = {
                function( _, spawned )
                    spawned.SkeleRunsAfterEnemySprints = false

                end,
            },
        },
        {
            hardRandomChance = 50,
            name = "infernalskele_big_LATE",
            prettyName = "An Infernal Sentinel",
            class = "terminator_nextbot_infernalskeleton_big",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 1000, 2000 },
            maxCount = { 10 },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
