
local set = {
    name = "hunters_glee_infernalhorde", -- unique name
    prettyName = "The Infernal Horde",
    description = "It burns, it burns! IT BURNS!",
    difficultyPerMin = "default*3", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default*4", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default*5",
    maxSpawnCount = { 40 }, -- hard cap on count
    maxSpawnDist = "default*0.5",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 1,
    chanceToBeVotableWhenHard = 5, -- stick around when this is still a challenge
    spawns = {
        {
            hardRandomChance = nil,
            name = "infernalskele", -- unique name
            prettyName = "An Infernal Skeleton",
            class = "terminator_nextbot_infernalskeleton", -- class spawned
            spawnType = "hunter",
            difficultyCost = 2,
            preSpawnedFunc = function( _, spawned )
                spawned.SpawnHeadlessChance = 85

            end,
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
