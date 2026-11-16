local set = {
    name = "hunters_glee_rusted",
    prettyName = "Rusted Glee",
    description = "Ancient terminators, their brains are dulled, but still functional.",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = { 5, 10 },
    startingBudget = "default",
    spawnCountPerDifficulty = "default*0.5",
    startingSpawnCount = { 2, 4 },
    maxSpawnCount = 12,
    maxSpawnDist = { 2500, 3500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "hunters_glee/music/alexscott/glee_rust.mp3",
    chanceToBeVotable = 10, -- and fade into the background if this host isn't challenged by this
    chanceToBeVotableWhenHard = 50, -- stick around when this is still a challenge
    easy = true,
    tutorialExit = true,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator",
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail_skinlessrusty",
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
        },
        {
            hardRandomChance = nil,
            name = "terminator_shinyandnew",
            prettyName = "The New Terminator",
            class = "terminator_nextbot_snail_skinless",
            spawnType = "hunter",
            difficultyCost = { 50, 100 },
            maxCount = { 1 },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
