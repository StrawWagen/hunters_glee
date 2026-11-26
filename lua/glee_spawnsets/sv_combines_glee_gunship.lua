local set = {
    name = "combines_glee_gunship",
    prettyName = "The Combine Gunship",
    description = "Something circles overhead.\nBring it down, or keep your head down.",
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    roundEndSound = "combines_glee",
    roundStartSound = "ambient/levels/streetwar/gunship_distant1.wav",
    chanceToBeVotable = 0.5,
    -- just the raid's gunship, there from the start
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
                    -- only 1 can exist, so the cost never limits it
                    difficultyCost = 1,
                    difficultyNeeded = NULL,
                    minutesNeeded = NULL,
                    -- no arrival sound, roundStartSound already announces it
                    postSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PostSpawn( ... ) end },
                },
            },
        },
    },
}

function set:Activate()
    self:Hook( "glee_gunship_firstspottedplayer", function()
        -- once per round, this misery can stay active across many rounds
        local roundData = GAMEMODE.roundExtraData
        if roundData.gunshipPlayedTrack then return end
        roundData.gunshipPlayedTrack = true
        GAMEMODE:SendMusic( "tracks/gunshipBattle" )

    end )
    self:Hook( "glee_gunship_desperate", function()
        local roundData = GAMEMODE.roundExtraData
        if roundData.gunshipPlayedDesperateTrack then return end
        roundData.gunshipPlayedDesperateTrack = true
        GAMEMODE:SendMusic( "tracks/gunshipBattle" )

    end )
end

table.insert( GLEE_SPAWNSETS, set )
