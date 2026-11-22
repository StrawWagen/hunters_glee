local set = {
    name = "combines_glee_gunship_armageddon",
    prettyName = "Combine Gunship Armageddon",
    description = "Don't look up.",
    maxSpawnCount = 6,
    -- 2 at the start, so it never opens like the lone gunship
    -- the count, so a small server wants 2, and the budget, so the first wave can afford 2
    startingSpawnCount = 2,
    startingBudget = 40,
    roundStartSound = "ambient/levels/streetwar/gunship_distant1.wav",
    chanceToBeVotable = 0.5,
    -- the raid's gunship, a flock of them, from the start
    importedMiserySpawns = {
        {
            name = "combines_glee",
            overrides = {
                combine_metropolice = NULL,
                combine_soldier_rareearly = NULL,
                combine_soldier_early = NULL,
                combine_soldier = NULL,
                combine_shotgun_RARE = NULL,
                combine_shotgun_COMMON = NULL,
                combine_elite_RARE = NULL,
                combine_elite_COMMON = NULL,
                combine_rocketeer = NULL,
                combine_gunship = {
                    prettyName = "A Combine Gunship",
                    -- killing one doesn't end the round
                    isBoss = false,
                    -- a wave's budget is startingBudget + difficulty, so 2 a wave at first, then more, up to the cap
                    difficultyCost = 20,
                    difficultyNeeded = NULL,
                    minutesNeeded = NULL,
                    maxCount = { 6 },
                    -- drops the raid's arrival sting, roundStartSound already announces them
                    postSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PostSpawn( ... ) end },
                },
            },
        },
    },
}

table.insert( GLEE_SPAWNSETS, set )
