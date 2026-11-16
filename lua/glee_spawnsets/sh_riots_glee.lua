-- incase we keep: paparazzi = reporter

local set = {
    name = "riots_glee",
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
        difficultyPerMin = "default",
        waveInterval = "default",
        maxSpawnDist = { 2500, 3500 }, -- CLOSE!
        startingSpawnCount = 1,
        maxSpawnCount = 12,
        chanceToBeVotable = 1,
        spawns = {
            {
                hardRandomChance = nil,
                name = "angry_rioter",
                prettyName = "Angry Rioter",
                class = "terminator_nextbot_fakeply",
                spawnType = "hunter",
                difficultyCost = 1,
                countClass = "terminator_nextbot*",
                minCount = { 0 },
                maxCount = { 12 },
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

table.insert( GLEE_SPAWNSETS, set )
