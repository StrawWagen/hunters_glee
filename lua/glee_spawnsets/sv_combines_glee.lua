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
            prettyName = "A Metrocop",
            class = "terminator_nextbot_cmetro",
            spawnType = "hunter",
            difficultyCost = { 1 },
            difficultyStopAfter = { 50, 100 },
            countClass = genericCombineCounter,
            minCount = { 4 },
            postSpawnedFuncs = nil,
        },
        {
            hardRandomChance = { 0, 15 },
            name = "combine_soldier_rareearly",
            prettyName = "A Combine Soldier",
            class = "terminator_nextbot_csoldier",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 2, 4 },
            difficultyNeeded = { 15, 25 },
            difficultyStopAfter = { 100 },
            countClass = "terminator_nextbot_csoldier",
            maxCount = { 1, 2 },
            postSpawnedFuncs = nil,
        },
        {
            name = "combine_soldier_early", -- small squads, before they flood in
            prettyName = "A Combine Soldier",
            class = "terminator_nextbot_csoldier",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 8, 10 },
            difficultyNeeded = { 50, 100 },
            difficultyStopAfter = { 200 },
            countClass = "terminator_nextbot_csoldier",
            maxCount = { 3, 4 },
            postSpawnedFuncs = nil,
        },
        {
            name = "combine_soldier",
            prettyName = "A Combine Soldier",
            class = "terminator_nextbot_csoldier",
            spawnType = "hunter",
            spawnSameZ = true,
            difficultyCost = { 10, 12 },
            difficultyNeeded = { 150, 200 },
            countClass = genericCombineCounter,
            postSpawnedFuncs = nil,
        },
        {
            hardRandomChance = { 0, 15 },
            name = "combine_shotgun_RARE", -- spawns early with a max count
            prettyName = "A Combine Shotgunner",
            class = "terminator_nextbot_cshotgunsoldier",
            spawnType = "hunter",
            difficultyCost = { 20, 30 },
            difficultyNeeded = { 50, 100 },
            countClass = "terminator_nextbot_cshotgunsoldier",
            maxCount = { 4 },
            postSpawnedFuncs = nil,
        },
        {
            hardRandomChance = { 25, 45 },
            name = "combine_shotgun_COMMON",
            prettyName = "A Combine Shotgunner",
            class = "terminator_nextbot_cshotgunsoldier",
            spawnType = "hunter",
            spawnSameZ = true,
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
            spawnSameZ = true,
            difficultyCost = { 5, 15 },
            difficultyNeeded = { 150, 200 },
            countClass = "terminator_nextbot_celitesoldier",
            maxCount = { 4 },
            postSpawnedFuncs = nil,
        },
        {
            hardRandomChance = { 0, 5 },
            name = "combine_rocketeer",
            prettyName = "A Combine Rocketeer",
            class = "terminator_nextbot_crocketeer",
            spawnType = "hunter",
            difficultyCost = { 10, 20 },
            difficultyNeeded = { 150, 300 },
            countClass = "terminator_nextbot_crocketeer",
            maxCount = { 4 },
            postSpawnedFuncs = nil,
        },
        {
            name = "combine_gunship",
            prettyName = "The Combine Gunship",
            class = "npc_combinegunship",
            spawnType = "hunter",
            isBoss = true,
            difficultyCost = { 100 },
            minutesNeeded = 10, -- never sooner
            difficultyNeeded = { 150, 250 },
            countClass = "npc_combinegunship",
            maxCount = { 1 },
            preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
            firmPreferredEFlags = true,
            -- the gunship module loads with the addon, look it up when called
            canSpawnOnMap = function( ... ) return terminator_Extras.glee_Gunship.CanSpawnOnMap( ... ) end,
            areaFilter = function( ... ) return terminator_Extras.glee_Gunship.AreaFilter( ... ) end,
            preSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PreSpawn( ... ) end },
            postSpawnedFuncs = {
                function( ... ) terminator_Extras.glee_Gunship.PostSpawn( ... ) end,
                function()
                    if GAMEMODE.roundExtraData.gunshipArrived then return end
                    GAMEMODE.roundExtraData.gunshipArrived = true
                    GAMEMODE:SendMusic( "ambient/levels/streetwar/gunship_distant2.wav" )

                end,
            },
        },
    }
}

function zambieSpawnSet:Activate()
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

table.insert( GLEE_SPAWNSETS, zambieSpawnSet )
