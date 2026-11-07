-- the hardcore take on the Combine raid, fought as a squad of rebels
local set = {
    name = "combine_onslaught", -- unique name
}

if SERVER then
    local genericCombineCounter = "terminator_nextbot_c*"

    -- every combine HATES YOU
    local function angerOnSpawn( _spawnData, spawned )
        spawned:ReallyAnger( 60 )

    end

    local setSv = {
        prettyName = "COMBINE ONSLAUGHT",
        description = "The Combine are coming for every last one of you...\nThere's no one left to save you.",
        author = "boomertaters",
        difficultyPerMin = "default*2", -- difficulty per minute
        waveInterval = "default*0.5", -- time between spawn waves
        diffBumpWhenWaveKilled = "default*2", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
        startingSpawnCount = 8,
        maxSpawnCount = 60,
        roundEndSound = "ambient/levels/streetwar/gunship_distant2.wav",
        roundStartSound = "ambient/levels/streetwar/city_chant1.wav", -- death is upon us
        chanceToBeVotable = 0.5,
        spawns = {
            {
                name = "combine_metropolice",
                prettyName = "A Metrocop",
                class = "terminator_nextbot_cmetro",
                spawnType = "hunter",
                difficultyCost = { 1 },
                difficultyStopAfter = { 50, 100 },
                countClass = genericCombineCounter,
                minCount = { 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 0, 15 },
                name = "combine_soldier_rareearly",
                prettyName = "A Combine Soldier",
                class = "terminator_nextbot_csoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 2, 4 },
                difficultyNeeded = { 15, 25 },
                difficultyStopAfter = { 100 },
                countClass = "terminator_nextbot_csoldier",
                maxCount = { 1, 2 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                name = "combine_soldier_early", -- small squads, before they flood in
                prettyName = "A Combine Soldier",
                class = "terminator_nextbot_csoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 8, 10 },
                difficultyNeeded = { 50, 100 },
                difficultyStopAfter = { 200 },
                countClass = "terminator_nextbot_csoldier",
                maxCount = { 3, 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                name = "combine_soldier",
                prettyName = "A Combine Soldier",
                class = "terminator_nextbot_csoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 10, 12 },
                difficultyNeeded = { 150, 200 },
                countClass = genericCombineCounter,
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 0, 15 },
                name = "combine_shotgun_RARE", -- spawns early with a max count
                prettyName = "A Combine Shotgunner",
                class = "terminator_nextbot_cshotgunsoldier",
                spawnType = "hunter",
                difficultyCost = { 20, 30 },
                difficultyNeeded = { 50, 100 },
                countClass = "terminator_nextbot_cshotgunsoldier",
                maxCount = { 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 25, 45 },
                name = "combine_shotgun_COMMON",
                prettyName = "A Combine Shotgunner",
                class = "terminator_nextbot_cshotgunsoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 4, 6 },
                difficultyNeeded = { 150, 200 },
                countClass = genericCombineCounter,
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 0, 5 },
                name = "combine_elite_RARE", -- spawns early with a max count
                prettyName = "A Combine Elite",
                class = "terminator_nextbot_celitesoldier",
                spawnType = "hunter",
                difficultyCost = { 10, 20 },
                difficultyNeeded = { 50, 100 },
                countClass = "terminator_nextbot_celitesoldier",
                maxCount = { 1 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                name = "combine_elite_COMMON", -- spawns early with a max count
                prettyName = "A Combine Elite",
                class = "terminator_nextbot_celitesoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 5, 15 },
                difficultyNeeded = { 150, 200 },
                countClass = "terminator_nextbot_celitesoldier",
                maxCount = { 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 0, 5 },
                name = "combine_rocketeer",
                prettyName = "A Combine Rocketeer",
                class = "terminator_nextbot_crocketeer",
                spawnType = "hunter",
                difficultyCost = { 10, 20 },
                difficultyNeeded = { 150, 300 },
                countClass = "terminator_nextbot_crocketeer",
                maxCount = { 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                name = "combine_gunship",
                prettyName = "The Combine Gunship",
                class = "npc_combinegunship",
                spawnType = "hunter",
                isBoss = true,
                difficultyCost = { 100 },
                minutesNeeded = 10, -- never sooner
                difficultyNeeded = { 150, 250 },
                countClass = "npc_combinegunship",
                maxCount = { 1 },
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                firmPreferredEFlags = true,
                -- the gunship module loads with the addon, look it up when called
                canSpawnOnMap = function( ... ) return terminator_Extras.glee_Gunship.CanSpawnOnMap( ... ) end,
                areaFilter = function( ... ) return terminator_Extras.glee_Gunship.AreaFilter( ... ) end,
                preSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PreSpawn( ... ) end },
                postSpawnedFuncs = {
                    function( ... ) terminator_Extras.glee_Gunship.PostSpawn( ... ) end,
                    function()
                        if GAMEMODE.roundExtraData.gunshipArrived then return end
                        GAMEMODE.roundExtraData.gunshipArrived = true
                        GAMEMODE:SendMusic( "ambient/levels/streetwar/gunship_distant2.wav" )

                    end,
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
    setHelpers.addRoleVariant( self, "juggernaut" )

    setHelpers.addStartWeapon( self, { class = "weapon_smg1", purchaseClips = 3 } )

end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )