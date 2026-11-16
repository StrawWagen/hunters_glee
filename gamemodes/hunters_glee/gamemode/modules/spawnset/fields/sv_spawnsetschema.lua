
-- what every spawnset field holds, shared by the three stages a misery goes through:
--   sv_spawnsetbaker, once at gobble, fills every field in and swaps references for values
--   GM:IsValidSpawnSet in core/sv_spawnset, checks what came out
--   sv_spawnsetroller, every round, rolls the number fields into this round's numbers

local function yapErr( spawnSet, yapStr )
    ErrorNoHaltWithStack( "GLEE: spawnSet " .. spawnSet.name .. " " .. yapStr )

end


-- number values

-- a number field holds a number, { min, max }, { n }, or a function( spawnSet ) returning one of those
-- this round's number, or nil when value isn't one, a function's the roller's to call
local function rolledNumber( value )
    if isnumber( value ) then return value end
    if not istable( value ) or #value > 2 then return end

    local low, high = value[1], value[2]
    if not isnumber( low ) then return end
    if high == nil then return low end
    if not isnumber( high ) then return end

    return math.Rand( low, high )

end

local function isRollable( value )
    return isfunction( value ) or rolledNumber( value ) ~= nil

end


-- set fields

-- every misery has these, nil means the default misery's value, see lua/glee_spawnsets/sv_default.lua
--   number, see rolledNumber
--   sound, a path or track with a "/" in it, or "" for silence
--   weapons, a list of what GM:AddMiserySpawnWeapon takes, see sv_spawnweapons
local defaultedFieldKinds = {
    difficultyPerMin = "number",
    waveInterval = "number",
    diffBumpWhenWaveKilled = "number",
    startingBudget = "number",
    spawnCountPerDifficulty = "number",
    startingSpawnCount = "number",
    maxSpawnCount = "number",
    maxSpawnDist = "number",
    minSpawnDist = "number",
    genericSpawnerRate = "number",
    breathingRoom = "number",
    roundEndSound = "sound",
    roundWinSound = "sound",
    roundPerfectWinSound = "sound",
    roundStartSound = "sound",
    roundEarlyStartSound = "sound",
    highIntensitySound = "sound",
    grigoriArrivalSound = "sound",
    secondGrigoriArrivalSound = "sound",
    noMoreGrigoriSound = "sound",
    startWeapons = "weapons",
    defaultWeapons = "weapons",
}

-- each one a class, a shopHelpers.purchaseWeapon table, or a function( ply ) returning either
local function isWeaponList( value )
    if not istable( value ) then return false end
    for _, weapon in ipairs( value ) do
        local isClass = isstring( weapon )
        local isPurchase = istable( weapon ) and isstring( weapon.class )
        if not ( isClass or isPurchase or isfunction( weapon ) ) then return false end

    end
    return true

end

-- the misery every other misery's nil fields come from
local defaultSetName = "default"

-- only raw miseries have these, the baker reads them and leaves them behind
local rawOnlyFields = {
    importedMiserySpawns = true, -- baked into .spawns
    template = true, -- keeps the misery out of the registry
    needsEveryMisery = true, -- a misery it points at that isn't installed keeps it out of the registry, quietly
}

-- "minutes*0.1", one slot every 10 minutes
-- "difficulty*0.01", one slot every 100 difficulty
-- resolved into { scale, mul }, slotSize in sv_hunterspawner works it out each wave
local slotSizeScales = {
    minutes = true,
    difficulty = true,
}

-- misspelled keys would otherwise be silently ignored, or silently replaced by their default
-- typo = correct
local setCommonTypos = {
    chanceToBeVotableIfHard = "chanceToBeVotableWhenHard",
    authors = "author",
    earlyStartSound = "roundEarlyStartSound",
}


-- .spawns entry fields

-- rolled every round, a field left off this never rolls
local spawnNumberFields = {
    difficultyCost = true,
    difficultyNeeded = true,
    difficultyStopAfter = true,
    minutesNeeded = true,
    hardRandomChance = true,
    minCount = true,
    maxCount = true,
    cooldown = true,
    removeAfterStillSeconds = true,
}

-- filled in by the baker when an entry leaves them nil
local spawnDefaults = {
    minCount = -1, -- -1 is ignored
    maxCount = -1, -- -1 is ignored, it still respects spawnset.maxSpawnCount tho
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

-- never rolled, each checked by its validator
local unrolledSpawnFieldValidators = {
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
    yapErr = yapErr,
    rolledNumber = rolledNumber,
    isRollable = isRollable,
    defaultedFieldKinds = defaultedFieldKinds,
    isWeaponList = isWeaponList,
    defaultSetName = defaultSetName,
    rawOnlyFields = rawOnlyFields,
    slotSizeScales = slotSizeScales,
    setCommonTypos = setCommonTypos,
    spawnNumberFields = spawnNumberFields,
    spawnDefaults = spawnDefaults,
    spawnCommonTypos = spawnCommonTypos,
    validSpawnTypes = validSpawnTypes,
    unrolledSpawnFieldValidators = unrolledSpawnFieldValidators,
}
