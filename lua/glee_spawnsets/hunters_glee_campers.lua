local function setWeaponOverride( hunter, wepClass )
    hunter.DefaultWeapon = wepClass
    hunter.TERM_FISTS = wepClass

end

local function giveRPG( _, hunter )
    setWeaponOverride( hunter, "weapon_rpg" )
end

local function giveTauCannon( _, hunter )
    setWeaponOverride( hunter, "termhunt_taucannon" )
end

local campersDelightSpawnSet = {
    name = "hunters_glee_campers",
    prettyName = "Camper's Delight",
    description = "More campers than a tf2 trade lobby? impossible!",
    difficultyPerMin = "default",
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = "default*4",
    startingSpawnCount = "default",
    maxSpawnCount = "default*2",
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    genericSpawnerRate = "default",
    chanceToBeVotable = 1,
    spawns = {
            hardRandomChance = nil,
            name = "tau_terminator", -- unique name
            prettyName = "A Tau Campin' Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveTauCannon },
        },
        {
            hardRandomChance = nil,
            name = "rpg_terminator", -- unique name
            prettyName = "A RPG Campin' Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail", -- class COUNTED, uses findbyclass
            preSpawnedFuncs =  { giveRPG },
        },
    }
}

table.insert( GLEE_SPAWNSETS, campersDelightSpawnSet )
