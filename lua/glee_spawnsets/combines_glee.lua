-- credit to https://steamcommunity.com/id/TakeTheBeansIDontCare/

local genericCombineCounter = "terminator_nextbot_c*"

local zambieSpawnSet = {
    name = "combines_glee", -- unique name
    prettyName = "Combine RAID!",
    description = "Get down!",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingSpawnCount = 4,
    maxSpawnCount = 40,
    roundEndSound = "music/hl2_song6.mp3",
    roundStartSound = "ambient/alarms/scanner_alert_pass1.wav",
    chanceToBeVotable = 1,
    spawns = {
        {
            name = "combine_metropolice",
            prettyName = "Metropolice",
            class = "terminator_nextbot_cmetro",
            spawnType = "hunter",
            difficultyCost = { 1 },
            difficultyStopAfter = { 50, 100 },
            countClass = genericCombineCounter,
            minCount = { 4 },
            postSpawnedFuncs = nil,
        },
        {
            name = "combine_soldier",
            prettyName = "A Combine Soldier",
            class = "terminator_nextbot_csoldier",
            spawnType = "hunter",
            difficultyCost = { 2, 4 },
            difficultyNeeded = { 50, 100 },
            countClass = genericCombineCounter,
            postSpawnedFuncs = nil,
        },
        {
            hardRandomChance = { 0, 15 },
            name = "combine_shotgun_RARE", -- spawns early with a max count
            prettyName = "A Combine Shotgunner",
            class = "terminator_nextbot_cshotgunsoldier",
            spawnType = "hunter",
            difficultyCost = { 4, 8 },
            difficultyNeeded = { 50, 100 },
            countClass = "terminator_nextbot_cshotgunsoldier",
            maxCount = { 4 },
            postSpawnedFuncs = nil,
        },
        {
            name = "combine_shotgun_COMMON",
            prettyName = "A Combine Shotgunner",
            class = "terminator_nextbot_cshotgunsoldier",
            spawnType = "hunter",
            difficultyCost = { 4, 6 },
            difficultyNeeded = { 150, 200 },
            countClass = genericCombineCounter,
            postSpawnedFuncs = nil,
        },
        {
            hardRandomChance = { 0, 5 },
            name = "combine_elite_RARE", -- spawns early with a max count
            prettyName = "A Combine Elite",
            class = "terminator_nextbot_celitesoldier",
            spawnType = "hunter",
            difficultyCost = { 10, 20 },
            difficultyNeeded = { 50, 100 },
            countClass = "terminator_nextbot_celitesoldier",
            maxCount = { 1 },
            postSpawnedFuncs = nil,
        },
        {
            name = "combine_elite_COMMON", -- spawns early with a max count
            prettyName = "A Combine Elite",
            class = "terminator_nextbot_celitesoldier",
            spawnType = "hunter",
            difficultyCost = { 5, 15 },
            difficultyNeeded = { 150, 200 },
            countClass = "terminator_nextbot_celitesoldier",
            maxCount = { 4 },
            postSpawnedFuncs = nil,
        },
    }
}

table.insert( GLEE_SPAWNSETS, zambieSpawnSet )
