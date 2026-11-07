-- for testing soldier squads, one squad, refilled as they die
-- huntersglee_misery_setto combines_glee_squadtest

local set = {
    name = "combines_glee_onesquad", -- unique name
    prettyName = "The Long Patrol",
    description = "One squad, forever.",
    difficultyPerMin = "default",
    waveInterval = { 10 }, -- refill dead members quickly
    diffBumpWhenWaveKilled = "default",
    startingSpawnCount = 6,
    maxSpawnCount = 6,
    hordeSpawn = true, -- spawn them together, so they form one squad
    roundEndSound = "music/hl2_song6.mp3",
    roundStartSound = "ambient/alarms/scanner_alert_pass1.wav",
    chanceToBeVotable = 0.1,
    spawns = {
        -- minCount bypasses the budget, so the squad's always full
        {
            name = "squadtest_elite",
            prettyName = "A Combine Elite",
            class = "terminator_nextbot_celitesoldier",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 1 },
            countClass = "terminator_nextbot_celitesoldier",
            minCount = { 1 },
            maxCount = { 1 },
        },
        {
            name = "squadtest_soldier",
            prettyName = "A Combine Soldier",
            class = "terminator_nextbot_csoldier",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 1 },
            countClass = "terminator_nextbot_csoldier",
            minCount = { 4 },
            maxCount = { 4 },
        },
        {
            name = "squadtest_shotgun",
            prettyName = "A Combine Shotgunner",
            class = "terminator_nextbot_cshotgunsoldier",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 1 },
            countClass = "terminator_nextbot_cshotgunsoldier",
            minCount = { 1 },
            maxCount = { 1 },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
