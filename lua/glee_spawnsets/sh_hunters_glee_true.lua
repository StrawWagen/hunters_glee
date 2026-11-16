local set = {
    name = "hunters_glee_true",
}

if SERVER then
    local postSpawnedOvercharge = GAMEMODE.setHelpers.postSpawnedOvercharge

    local setSv = {
        prettyName = "True Glee",
        description = "Smart, cruel enemies.\nThe paths of intervention are closed to you.",
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
        chanceToBeVotable = 10,
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
    table.Merge( set, setSv )

end

function set:Activate()
    GAMEMODE.setHelpers.makeNoSelfReviving( self )

end

table.insert( GLEE_SPAWNSETS, set )
