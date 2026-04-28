
local minute = 60

-- all nil entries, or entries set as "default", in spawnsets, are parsed into these
-- provide a number and the num will be the same every round
-- provide a table with 2 numbers, and the num will be random between them every round
-- provide a string that's "default*2", and the num will be the default variable multiplied by 2
-- MUCH better to use "default*" system, because the defaults WILL change eventually

return {
    difficultyPerMin = { 100 / 10, 150 / 10 }, -- 100-150% diff at 10 mins
    waveInterval = { minute, minute * 1.6 },
    diffBumpWhenWaveKilled = { 10, 20 },
    startingBudget = 20,
    spawnCountPerDifficulty = { 0.08, 0.1 },
    startingSpawnCount = { 1.8, 2 },
    maxSpawnCount = 10,
    maxSpawnDist = { 4500, 6500 },
    minSpawnDist = 500, -- if you spawn closer than this, it feels unfair
    roundEndSound = "tracks/roundEnd", -- parsed by sv_solidsounds.lua
    roundWinSound = "tracks/roundWin",
    roundPerfectWinSound = "tracks/roundPerfectWin",
    roundStartSound = "", -- no sound for glee
    genericSpawnerRate = 1,
}