local function giveCrowbar( _spawnset, npc )
    npc.DefaultWeapon = "weapon_crowbar"
    npc.DefaultSidearms = { "weapon_crowbar" }

    local timerName = "glee_term_crowbar_give_" .. npc:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( npc ) then timer.Remove( timerName ) return end
        local primaryWeapon = npc:GetActiveWeapon()

        if IsValid( primaryWeapon ) and primaryWeapon:GetClass() == "weapon_crowbar" then return end
        local bar = npc:Give( "weapon_crowbar" )
        bar.terminator_IgnoreWeaponUtility = true

    end )
end

local function setFistsAsCrowbar( _spawnset, npc )
    npc.TERM_FISTS = "weapon_crowbar"

end

local defaultSpawnSet = {
    name = "hunters_glee_crowbars", -- unique name
    prettyName = "Crowbar's Glee",
    description = "Why would you ever want the Terminators to run out of crowbars?",
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
    chanceToBeVotable = 1,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator", -- unique name
            prettyName = "A Crowbar Slingin' Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
            minCount = { 2 }, -- will ALWAYS maintain this count
            preSpawnedFuncs = { giveCrowbar }, -- this can be nil
            postSpawnedFuncs = { setFistsAsCrowbar },
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
