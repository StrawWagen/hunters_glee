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
    name = "hunters_glee_paparazzi_allgun",
    prettyName = "Paparazzi Population... Boom?",
    description = "Paparazzi, with guns? this is some kind of purge, a gleeful purge? a gleeurge???", -- secret for those who check
    difficultyPerMin = "default*1.5",
    waveInterval = "default",
    diffBumpWhenWaveKilled = { 10, 25 },
    startingBudget = "default",
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
            name = "paparazzi_pistol",
            prettyName = "A Pistoling Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 1, 3 }, -- reduced from 2 to make more common
            preSpawnedFuncs =  { givePistol },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_smg",
            prettyName = "A Submachinegunning Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 2, 4 },
            preSpawnedFuncs =  { giveSMG },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_ar2",
            prettyName = "A Pulse Riflin' Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 6, 12 },
            preSpawnedFuncs =  { giveAR2 },
        },
        {
            hardRandomChance = nil,
            name = "paparazzi_357",
            prettyName = "A Revolver-Wielding Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 6, 12 },
            preSpawnedFuncs =  { give357 },
        },
        {
            hardRandomChance = { 10, 20 },
            name = "paparazzi_flaregun",
            prettyName = "A Flare-Flinging Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 8, 16 },
            preSpawnedFuncs =  { giveFlareGun },
        },
        {
            hardRandomChance = { 0, 20 },
            name = "paparazzi_xbow",
            prettyName = "A Bolti'n Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 50, 150 },
            preSpawnedFuncs =  { giveXBOW },
        },
        {
            hardRandomChance = { 5, 75 },
            name = "paparazzi_rpg",
            prettyName = "A Rocket Propelled Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 25, 75 }, -- doubled from 10 to spawn much later
            preSpawnedFuncs =  { giveRPG },
        },
        {
            hardRandomChance = { 5, 20 },
            name = "paparazzi_ar3",
            prettyName = "An AR3-Annihilating Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 50, 150 },
            preSpawnedFuncs =  { giveAR3 },
        },
        {
            hardRandomChance = { 5, 20 },
            name = "paparazzi_taucannon",
            prettyName = "A Tau-Blasting Paparazzi",
            class = "terminator_nextbot_fakeply",
            spawnType = "hunter",
            difficultyCost = { 100, 200 },
            preSpawnedFuncs =  { giveTauCannon },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
