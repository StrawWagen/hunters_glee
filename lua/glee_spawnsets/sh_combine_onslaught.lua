-- the hardcore take on the Combine raid, fought as a squad of rebels
local set = {
    name = "combine_onslaught",
}

if SERVER then
    -- every combine HATES YOU
    local function angerOnSpawn( _spawnData, spawned )
        spawned:ReallyAnger( 60 )

    end

    local setSv = {
        prettyName = "COMBINE ONSLAUGHT",
        description = "The Combine are coming for every last one of you...\nThere's no one left to save you.",
        author = "boomertaters",
        difficultyPerMin = "default*2",
        waveInterval = "default*0.5",
        diffBumpWhenWaveKilled = "default*2",
        startingSpawnCount = 8,
        maxSpawnCount = 60,
        roundEndSound = "ambient/levels/streetwar/gunship_distant2.wav",
        roundStartSound = "ambient/levels/streetwar/city_chant1.wav", -- death is upon us
        chanceToBeVotable = 0.5,
        startWeapons = {
            { class = "weapon_smg1", purchaseClips = 3 },
        },
        spawns = {
            {
                hardRandomChance = { 0, 15 },
                name = "combine_soldier_reallyearly",
                prettyName = "A Combine Soldier",
                class = "terminator_nextbot_csoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 2, 4 },
                difficultyStopAfter = { 100 },
                maxCount = { 2, 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
        },
        -- the raid, minus the metrocops, and everything comes sooner
        importedMiserySpawns = {
            {
                name = "combines_glee",
                overrides = {
                    combine_metropolice = NULL,
                    combine_soldier_rareearly = NULL,
                    combine_soldier_early = {
                        difficultyNeeded = { 15, 25 },
                        maxCount = { 4, 5 },
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                    combine_soldier = {
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                    combine_shotgun_RARE = {
                        difficultyNeeded = { 25, 50 },
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                    combine_shotgun_COMMON = {
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                    combine_elite_RARE = {
                        difficultyNeeded = { 25, 50 },
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                    combine_elite_COMMON = {
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                    combine_rocketeer = {
                        postSpawnedFuncs = { angerOnSpawn },
                    },
                },
            },
        },
    }
    table.Merge( set, setSv )

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    setHelpers.setBaseRole( self, "rebel" )
    setHelpers.addRoleVariant( self, "medic" )
    setHelpers.addRoleVariant( self, "engineer" )
    setHelpers.addRoleVariant( self, "shieldbearer" )
    setHelpers.addRoleVariant( self, "reporter" )
    setHelpers.addRoleVariant( self, "juggernaut" )

end

table.insert( GLEE_SPAWNSETS, set )
