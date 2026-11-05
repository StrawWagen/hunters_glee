
local minute = 60

-- all nil entries, or entries set as "default", in spawnsets, are parsed into these
-- provide a number and the num will be the same every round
-- provide a table with 2 numbers, and the num will be random between them every round
-- provide a string that's "default*2", and the num will be the default variable multiplied by 2
-- MUCH better to use "default*" system, because the defaults WILL change eventually

local setDefaults = {
    difficultyPerMin = { 100 / 10, 150 / 10 }, -- 100-150% diff at 10 mins
    waveInterval = { minute, minute * 1.6 },
    diffBumpWhenWaveKilled = { 10, 20 },
    startingBudget = 20,
    spawnCountPerDifficulty = { 0.08, 0.1 },
    startingSpawnCount = { 1.8, 2 },
    maxSpawnCount = 10,
    maxSpawnDist = { 4500, 6500 },
    minSpawnDist = 500, -- if you spawn closer than this, it feels unfair
    genericSpawnerRate = 1, -- speeds up or slows down the procedural item spawner
    breathingRoom = 0, -- scales sv_breathingroom's extra delay between waves, 0 is off
    roundEndSound = "tracks/roundEnd", -- parsed by sv_music.lua
    roundWinSound = "tracks/roundWin",
    roundPerfectWinSound = "tracks/roundPerfectWin",
    earlyStartSound = "",
    roundStartSound = "", -- plays ON round start ( early start plays if this is empty )
    roundEarlyStartSound = "tracks/roundEarlyStart", -- played 10 seconds before round starts, IF roundStartSound is empty
    highIntensitySound = "tracks/highIntensity",
        -- played when gamemode is super high intensity
        -- can play when a "spawn wave" is wiped, with no more than 1/4 of players alive
    grigoriArrivalSound = "tracks/grigoriArrival", -- played when grigori arrives
    secondGrigoriArrivalSound = "tracks/secondGrigoriArrival", -- played when grigori arrives
    noMoreGrigoriSound = "tracks/stopper/grigori", -- played when there are no more grigori
}

-- passed through as-is, so "default*2" and { min, max } don't work on these
local rawSpawnSetFields = {
    easy = true,
    tutorialExit = true,
    hordeSpawn = true,
    slotSizes = true, -- a table of parsed values, sv_spawnset parses each one
    Activate = true,
    OnRemove = true,
}

local spawnDefaults = {
    minCount = -1, -- if these aren't defined, sets to -1 which makes them ignored
    maxCount = -1, -- just this is ignored, it still respects spawnset.maxSpawnCount tho
}

local slotSizeDefaults = {}

-- "minutes*0.1", one slot every 10 minutes
-- left as a string by the generic parsing, the spawner works it out each wave
local minutesSlotSizePattern = "^minutes%*[%d%.]+$"

-- misspelled keys would otherwise be silently ignored, or silently replaced by their default
-- typo = correct
local setCommonTypos = {
    chanceToBeVotableIfHard = "chanceToBeVotableWhenHard",
}

local spawnCommonTypos = {
    difficultyRequired = "difficultyNeeded",
}

local function isTableOfFunctions( dat )
    if not istable( dat ) then return false, "is not a table" end
    for _, entry in ipairs( dat ) do
        if not isfunction( entry ) then return false, "is not a table of functions" end

    end
    return true

end

local function isTableOfStrings( dat )
    if not istable( dat ) then return false, "is not a table" end
    for _, entry in ipairs( dat ) do
        if not isstring( entry ) then return false, "is not a table of strings" end

    end
    return true

end

local function boolCheck( dat )
    if not isbool( dat ) then return false, "expected to be a bool" end
    return true

end

local function functionCheck( dat )
    if not isfunction( dat ) then return false, "expected to be a function" end
    return true

end

local function enumCheck( dat )
    if not isnumber( dat ) then return false, "expected to be an enum" end

    return true

end

-- sv_hunterspawner only acts on these, so an unknown spawnType would register fine and never spawn
local validSpawnTypes = {
    hunter = true,
}

-- like rawSpawnSetFields, but for .spawns entries, each checked by its validator
local rawSpawnFieldValidators = {
    preSpawnedFuncs = isTableOfFunctions,
    postSpawnedFuncs = isTableOfFunctions,
    isBoss = boolCheck, -- boolean, this is automatically set for some spawnsets by sv_bosshandler
    spawnSameZ = boolCheck,
    spawnBelow = boolCheck,
    spawnAbove = boolCheck,
    preferredEFlags = enumCheck, -- will attempt to spawn this .spawn entry in areas with these Extra Navmesh flags, see sv_navmeshcategorizer
    firmPreferredEFlags = boolCheck, -- never spawn outside areas with ALL preferredEFlags, even if that means never spawning on this map
    scaryAsATerminator = boolCheck,
    hordeSpawn = boolCheck,
    slots = isTableOfStrings, -- eg { "miniboss" }, see .slotSizes on the spawnset
    canSpawnOnMap = functionCheck, -- function( spawnEntry ), false and the entry never spawns on this map, see sv_spawnsetmapcheck
    areaFilter = functionCheck, -- function( spawnEntry, area ), false and the entry won't spawn in that area
}

return {
    setDefaults = setDefaults,
    rawSpawnSetFields = rawSpawnSetFields,
    spawnDefaults = spawnDefaults,
    slotSizeDefaults = slotSizeDefaults,
    validSpawnTypes = validSpawnTypes,
    rawSpawnFieldValidators = rawSpawnFieldValidators,
    minutesSlotSizePattern = minutesSlotSizePattern,
    setCommonTypos = setCommonTypos,
    spawnCommonTypos = spawnCommonTypos,
}
