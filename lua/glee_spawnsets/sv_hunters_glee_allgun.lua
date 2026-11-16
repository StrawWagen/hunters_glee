local function givePistol( _, hunter )
    hunter:Give( "weapon_pistol" )
end

local function giveSMG( _, hunter )
    hunter:Give( "weapon_smg1" )
end

local function giveAR2( _, hunter )
    hunter:Give( "weapon_ar2" )
end

local function giveRPG( _, hunter )
    hunter:Give( "weapon_rpg" )
end

local function give357( _, hunter )
    hunter:Give( "weapon_357" )
end

local function giveXBOW( _, hunter )
    hunter:Give( "weapon_crossbow" )
end

local function giveAR3( _, hunter )
    hunter:Give( "termhunt_ar3" )
end

local function giveTauCannon( _, hunter )
    hunter:Give( "termhunt_taucannon" )
end


local set = {
    name = "hunters_glee_allgun",
    prettyName = "Heavily Armed Glee",
    description = "Say hello to their little friends.",
    difficultyPerMin = "default*1.5",
    waveInterval = "default",
    diffBumpWhenWaveKilled = { 10, 25 },
    startingBudget = "default",
    spawnCountPerDifficulty = "default",
    startingSpawnCount = 5,
    maxSpawnCount = 10,
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    chanceToBeVotable = 0.8,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator_pistol",
            prettyName = "A Pistoling Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 1, 3 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { givePistol },
        },
        {
            hardRandomChance = nil,
            name = "terminator_smg",
            prettyName = "A Submachinegunning Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 2, 4 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { giveSMG },
        },
        {
            hardRandomChance = nil,
            name = "terminator_ar2",
            prettyName = "A Pulse Riflin' Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 6, 12 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { giveAR2 },
        },
        {
            hardRandomChance = nil,
            name = "terminator_357",
            prettyName = "A Revolver-Wielding Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 6, 12 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { give357 },
        },
        {
            hardRandomChance = { 0, 20 },
            name = "terminator_xbow",
            prettyName = "A Bolti'n Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 50, 150 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { giveXBOW },
        },
        {
            hardRandomChance = { 5, 75 },
            name = "terminator_rpg",
            prettyName = "A Rocket Propelled Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 25, 75 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { giveRPG },
        },
        {
            hardRandomChance = { 5, 20 },
            name = "terminator_ar3",
            prettyName = "An AR3-Annihilating Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 50, 150 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { giveAR3 },
        },
        {
            hardRandomChance = { 5, 20 },
            name = "terminator_taucannon",
            prettyName = "A Tau-Blasting Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 100, 200 },
            countClass = "terminator_nextbot_snail*",
            postSpawnedFuncs = { giveTauCannon },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
