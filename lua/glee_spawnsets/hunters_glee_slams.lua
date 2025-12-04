local function giveSlam( _spawnset, npc )
    npc.DefaultWeapon = "weapon_slam"
    npc.DefaultSidearms = { "weapon_slam" }

    local timerName = "glee_term_slam_give_" .. npc:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( npc ) then timer.Remove( timerName ) return end
        local primaryWeapon = npc:GetActiveWeapon()

        if IsValid( primaryWeapon ) and primaryWeapon:GetClass() == "weapon_slam" then return end
        local bar = npc:Give( "weapon_slam" )
        bar.terminator_IgnoreWeaponUtility = true

    end )
end

local function setFistsAsSlam( _spawnset, npc )
    npc.TERM_FISTS = "weapon_slam"

end

local defaultSpawnSet = {
    name = "hunters_glee_slams", -- unique name
    prettyName = "Artillery's Glee",
    description = "INCOOOOOOOOOMING!",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default*4", -- max of ten at 10 minutes
    startingSpawnCount = "default",
    maxSpawnCount = "default*2", -- hard cap on count
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default", -- the horn
    genericSpawnerRate = "default", -- speeds up or slows down the crate/beartrap/etc spawner
    chanceToBeVotable = 0.5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator", -- unique name
            prettyName = "A Slam Slingin' Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
            minCount = { 2 }, -- will ALWAYS maintain this count
            preSpawnedFuncs = { giveSlam }, -- this can be nil
            postSpawnedFuncs = { setFistsAsSlam },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
