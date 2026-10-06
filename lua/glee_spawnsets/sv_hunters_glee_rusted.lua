local set = {
    name = "hunters_glee_rusted", -- unique name
    prettyName = "Rusted Glee",
    description = "Ancient terminators, their brains are dulled, but still functional.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 5, 10 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default*0.5",
    startingSpawnCount = { 2, 4 },
    maxSpawnCount = 12, -- hard cap on count
    maxSpawnDist = { 2500, 3500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 10, -- and fade into the background if this host isn't challenged by this
    chanceToBeVotableWhenHard = 50, -- stick around when this is still a challenge
    easy = true,
    tutorialExit = true,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator", -- unique name
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail_skinlessrusty", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
        },
        {
            hardRandomChance = nil,
            name = "terminator", -- unique name
            prettyName = "The New Terminator",
            class = "terminator_nextbot_snail_skinless", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 50, 100 },
            countClass = "terminator_nextbot_snail_skinless",
            maxCount = { 1 },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
