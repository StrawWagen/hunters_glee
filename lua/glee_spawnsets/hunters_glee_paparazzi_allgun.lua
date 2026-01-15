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

local function giveFlareGun( _, hunter )
    setWeaponOverride( hunter, "termhunt_aeromatix_flare_gun" )
end

local function giveAR3( _, hunter )
    setWeaponOverride( hunter, "termhunt_ar3" )
end

local function giveTauCannon( _, hunter )
    setWeaponOverride( hunter, "termhunt_taucannon" )
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
            prettyName = "A Pistoling Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 1, 3 }, -- reduced from 2 to make more common
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { givePistol },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_smg", -- unique name
            prettyName = "A Submachinegunning Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 2, 4 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveSMG },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_ar2", -- unique name
            prettyName = "A Pulse Riflin' Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 6, 12 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveAR2 },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_357", -- unique name
            prettyName = "A Revolver-Wielding Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 6, 12 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { give357 },
        },
        {
            hardRandomChance = 0.15,
            name = "paparazzi_flaregun", -- unique name
            prettyName = "A Flare-Flinging Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 8, 16 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveFlareGun },
        },
        {
            hardRandomChance = 0.15,
            name = "paparazzi_xbow", -- unique name
            prettyName = "A Bolti'n Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 50, 150 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveXBOW },
        },
        {
            hardRandomChance = 0.75,
            name = "paparazzi_rpg", -- unique name
            prettyName = "A Rocket Propelled Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 25, 75 }, -- doubled from 10 to spawn much later
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveRPG },
        },
        {
            hardRandomChance = 0.15,
            name = "paparazzi_ar3", -- unique name
            prettyName = "An AR3-Annihilating Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 50, 150 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveAR3 },
        },
        {
            hardRandomChance = 0.05,
            name = "paparazzi_taucannon", -- unique name
            prettyName = "A Tau-Blasting Paparazzi",
            class = "terminator_nextbot_fakeply", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 100, 200 },
            countClass = "terminator_nextbot_fakeply", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveTauCannon },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
