-- every misery's nil fields come from here, and "default*2" means 2x these
-- MUCH better to use "default*", because these WILL change eventually

local minute = 60

local defaultSpawnSet = {
    name = "default",
    template = true, -- makes this never show up in misery votes
    prettyName = "Default",
    description = "Where every misery's nil fields come from.",
    difficultyPerMin = { 100 / 10, 150 / 10 }, -- 100-150% diff at 10 mins
    waveInterval = { minute, minute * 1.6 }, -- interval between spawn waves
    diffBumpWhenWaveKilled = { 10, 20 }, -- clearing waves makes the round get harder, escape heli also increases difficulty by small portions of this
    startingBudget = 20, -- starting difficulty
    startingSpawnCount = { 1.8, 2 }, -- spawn count at the start of the round
    spawnCountPerDifficulty = { 0.08, 0.1 }, -- slowly added to above, ramping up maxCount per difficulty
    maxSpawnCount = 10, -- final, impassible roof on hunter count
    maxSpawnDist = { 4500, 6500 }, -- spawner avoids spawning hunters >this far away from players
    minSpawnDist = 500, -- will never spawn closer than this, don't shrink, anything closer than this, feels unfair
    genericSpawnerRate = 1, -- speeds up or slows down the procedural item spawner ( crate spawns, flare spawns, etc )
    breathingRoom = 0, -- scales sv_breathingroom's extra delay between waves, 0 is off
    roundEndSound = "tracks/roundEnd", -- paths with tracks/ are parsed by sv_music.lua
    roundWinSound = "tracks/roundWin",
    roundPerfectWinSound = "tracks/roundPerfectWin",
    roundStartSound = "", -- plays ON round start ( early start plays if this is empty )
    roundEarlyStartSound = "tracks/roundEarlyStart", -- played 10 seconds before round starts, IF roundStartSound is empty
    highIntensitySound = "tracks/highIntensity",
        -- played when gamemode is super high intensity
        -- can play when a "spawn wave" is wiped, with no more than 1/4 of players alive
    grigoriArrivalSound = "tracks/grigoriArrival", -- played when grigori arrives
    secondGrigoriArrivalSound = "tracks/secondGrigoriArrival", -- played when grigori arrives
    noMoreGrigoriSound = "tracks/stopper/grigori", -- played when there are no more grigori
    startWeapons = {},
    defaultWeapons = { "weapon_crowbar", "gmod_camera", "termhunt_radio" }, -- the first one's what they're holding on spawn
}

table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
