-- incase we keep: paparazzi = reporter

local set = {
    name = "riots_glee", -- unique name
}

local function giveRandomWeapon( _, hunter )
    local wpns = { "weapon_crowbar", "weapon_shotgun", "weapon_smg1" }

    hunter:Give( wpns[math.random( #wpns )] )

end

if SERVER then
    local setSv = {
        prettyName = "Riot's Glee",
        author = "dedactedlife and IndefiniteXD",
        description = "They're mad at your creations, and want all of you dead. Stop them.",
        difficultyPerMin = "default", -- difficulty per minute
        waveInterval = "default", -- time between spawn waves
        maxSpawnDist = { 2500, 3500 }, -- CLOSE!
        startingSpawnCount = 1,
        maxSpawnCount = 12,
        chanceToBeVotable = 1,
        spawns = {
            {
                hardRandomChance = nil,
                name = "angry_rioter", -- unique name
                prettyName = "Angry Rioter",
                class = "terminator_nextbot_fakeply", -- class spawned
                spawnType = "hunter",
                difficultyCost = 1,
                countClass = "terminator_nextbot*", -- class COUNTED, uses findbyclass
                minCount = { 0 }, -- will ALWAYS maintain this count
                maxCount = { 12 }, -- will never exceed this count, uses findbycount
                postSpawnedFuncs = { giveRandomWeapon },
            }
        }
    }

    table.Merge( set, setSv )

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    setHelpers.setBaseRole( self, "swatGrunt" )

    setHelpers.addRoleVariant( self, "medic" )
    setHelpers.addRoleVariant( self, "tank" )
    setHelpers.addRoleVariant( self, "sniper" )

end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
