local set = {
    name = "combines_glee_gunship", -- unique name
    prettyName = "The Combine Gunship",
    description = "Something circles overhead.\nBring it down, or keep your head down.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    roundEndSound = "music/hl2_song6.mp3",
    roundStartSound = "ambient/levels/streetwar/gunship_distant1.wav",
    chanceToBeVotable = 0.5,
    spawns = {
        {
            name = "the_gunship",
            prettyName = "The Combine Gunship",
            class = "npc_combinegunship",
            spawnType = "hunter",
            isBoss = true,
            difficultyCost = 1,
            countClass = "npc_combinegunship",
            maxCount = 1,
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            firmPreferredEFlags = true,
            -- the gunship module loads with the addon, look it up when called
            canSpawnOnMap = function( ... ) return terminator_Extras.glee_Gunship.CanSpawnOnMap( ... ) end,
            areaFilter = function( ... ) return terminator_Extras.glee_Gunship.AreaFilter( ... ) end,
            preSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PreSpawn( ... ) end },
            postSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PostSpawn( ... ) end },
        },
    }
}

function set:Activate()
    self:Hook( "glee_gunship_firstspottedplayer", function()
        -- once per round, this misery can stay active across many rounds
        local roundData = GAMEMODE.roundExtraData
        if roundData.gunshipPlayedTrack then return end
        roundData.gunshipPlayedTrack = true
        GAMEMODE:SendMusic( "tracks/gunshipBattle" )

    end )
    -- the track's list plays round robin, so this is a different song for the last stretch
    self:Hook( "glee_gunship_desperate", function()
        local roundData = GAMEMODE.roundExtraData
        if roundData.gunshipPlayedDesperateTrack then return end
        roundData.gunshipPlayedDesperateTrack = true
        GAMEMODE:SendMusic( "tracks/gunshipBattle" )

    end )
end

table.insert( GLEE_SPAWNSETS, set )
