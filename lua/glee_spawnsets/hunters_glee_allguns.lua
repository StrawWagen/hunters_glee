-- credit https://steamcommunity.com/id/Boomeritaintaters/
-- and credit to idksomething for the inspiration https://steamcommunity.com/id/blahaj1337/





local function setWeaponOverride( hunter, wepClass )
    hunter.DefaultWeapon = wepClass

end

local function givePistol( _, hunter )
    setWeaponOverride( hunter, "weapon_pistol" )
end

local function giveSMG( _, hunter )
    setWeaponOverride( hunter, "weapon_smg1" )
end

local function giveAR2( _, hunter )
    setWeaponOverride( hunter, "weapon_ar2" )
end

local function giveRPG( _, hunter )
    setWeaponOverride( hunter, "weapon_rpg" )
end

local function give357( _, hunter )
    setWeaponOverride( hunter, "weapon_357" )
end

local function giveXBOW( _, hunter )
    setWeaponOverride( hunter, "weapon_crossbow" )
end


local set = {
    name = "hunters_glee_allguns", -- unique name
    prettyName = "The Gleeurge",
    description = "Oh god, they're taking photos of us with they're guns!",
    difficultyPerMin = "default*3.3", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 10, 25 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = "default",
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 4.4,
    spawns = {
        {
            hardRandomChance = nil,
            name = "paparazzi_pistol", -- unique name
            prettyName = "A Paparazzi With A Pistol",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 2,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 20 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs =  { givePistol },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_smg", -- unique name
            prettyName = "A Paparazzi With A Smg",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 4,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 15 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs =  { giveSMG },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_357", -- unique name
            prettyName = "A Paparazzi With A Revolver",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 5.5,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 5 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs =  { give357 },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_ar2", -- unique name
            prettyName = "A Paparazzi With A Ar2",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 6,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 15 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs =  { giveAR2 },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_xbow", -- unique name
            prettyName = "A Paparazzi With A Crossbow",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 7.5,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 5 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs =  { giveXBOW },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_rpg", -- unique name
            prettyName = "A Paparazzi With A RPG",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 10,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 5 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs =  { giveRPG },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )

