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
        description = "The Combine are coming for every last one of you...\nThere's no one left to save you. (by boomertaters)", -- sorry for the plug i wanna be credited
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
                difficultyStopAfter = { 100, 150 },
                countClass = genericCombineCounter,
                minCount = { 8 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 10, 30 },
                name = "combine_soldier_rareearly",
                prettyName = "A Combine Soldier",
                class = "terminator_nextbot_csoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 2, 4 },
                difficultyNeeded = { 5, 25 },
                difficultyStopAfter = { 100 },
                countClass = "terminator_nextbot_csoldier",
                maxCount = { 2, 4 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                name = "combine_soldier",
                prettyName = "A Combine Soldier",
                class = "terminator_nextbot_csoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 2, 4 },
                difficultyNeeded = { 25, 50 },
                countClass = genericCombineCounter,
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 10, 30 },
                name = "combine_shotgun_RARE", -- spawns early with a max count
                prettyName = "A Combine Shotgunner",
                class = "terminator_nextbot_cshotgunsoldier",
                spawnType = "hunter",
                difficultyCost = { 4, 8 },
                difficultyNeeded = { 25, 50 },
                countClass = "terminator_nextbot_cshotgunsoldier",
                maxCount = { 6 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 40, 60 },
                name = "combine_shotgun_COMMON",
                prettyName = "A Combine Shotgunner",
                class = "terminator_nextbot_cshotgunsoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 4, 6 },
                difficultyNeeded = { 75, 100 },
                countClass = genericCombineCounter,
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                hardRandomChance = { 5, 15 },
                name = "combine_elite_RARE", -- spawns early with a max count
                prettyName = "A Combine Elite",
                class = "terminator_nextbot_celitesoldier",
                spawnType = "hunter",
                difficultyCost = { 10, 20 },
                difficultyNeeded = { 25, 50 },
                countClass = "terminator_nextbot_celitesoldier",
                maxCount = { 2 },
                postSpawnedFuncs = { angerOnSpawn },
            },
            {
                name = "combine_elite_COMMON",
                prettyName = "A Combine Elite",
                class = "terminator_nextbot_celitesoldier",
                spawnType = "hunter",
                spawnSameZ = true,
                difficultyCost = { 5, 15 },
                difficultyNeeded = { 75, 100 },
                countClass = "terminator_nextbot_celitesoldier",
                maxCount = { 8 },
                postSpawnedFuncs = { angerOnSpawn },
            },
        }
    }
    table.Merge( set, setSv )

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )
    setHelpers.makeRebels( self )

    if CLIENT then return end

    setHelpers.addStartWeapon( self, { class = "weapon_smg1", purchaseClips = 3 } )

end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )