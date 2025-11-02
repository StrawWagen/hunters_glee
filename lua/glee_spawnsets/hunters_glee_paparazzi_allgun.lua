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
    name = "hunters_glee_paparazzi_allgun", -- unique name
    prettyName = "Paparazzi Population... Boom?",
    description = "Paparazzi, with guns? this is some kind of purge, a gleeful purge? a gleeurge???", -- secret for those who check
    difficultyPerMin = "default*1.5", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 10, 25 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default",
    startingSpawnCount = 5,
    maxSpawnCount = 50,
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 1,
    spawns = {
        {
            hardRandomChance = nil,
            name = "paparazzi_pistol", -- unique name
            prettyName = "A Paparazzi With A Pistol",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 1.5, -- reduced from 2 to make more common
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { givePistol },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_smg", -- unique name
            prettyName = "A Paparazzi With A Smg",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 3, -- reduced from 4 to make more common
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveSMG },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_357", -- unique name
            prettyName = "A Paparazzi With A Revolver",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 5.5,
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { give357 },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_ar2", -- unique name
            prettyName = "A Paparazzi With A Ar2",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 4.5, -- reduced from 6 to make more common
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveAR2 },
        },
        {
            hardRandomChance = 0.35, -- 35% chance to spawn when budget allows
            name = "paparazzi_xbow", -- unique name
            prettyName = "A Paparazzi With A Crossbow",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 12, -- increased to spawn later
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveXBOW },
        },
        {
            hardRandomChance = 0.15, -- only 15% chance to spawn when budget allows
            name = "paparazzi_rpg", -- unique name
            prettyName = "A Paparazzi With A RPG",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = 20, -- doubled from 10 to spawn much later
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveRPG },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
