local function giveCrowbar( _spawnset, npc )
    npc.DefaultWeapon = "weapon_crowbar"
    npc.DefaultSidearms = { "weapon_crowbar" }

    local timerName = "glee_term_crowbar_give_" .. npc:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( npc ) then timer.Remove( timerName ) return end
        local primaryWeapon = npc:GetActiveWeapon()

        if IsValid( primaryWeapon ) then
            if primaryWeapon:GetClass() == "weapon_crowbar" then
                return

            else
                primaryWeapon.terminatorCrappyWeapon = true -- dont use this again

            end
        end
        local bar = npc:Give( "weapon_crowbar" )
        bar.terminator_IgnoreWeaponUtility = true

    end )
end

local function setFistsAsCrowbar( _spawnset, npc )
    npc.TERM_FISTS = "weapon_crowbar"

end

local defaultSpawnSet = {
    name = "hunters_glee_crowbars",
    prettyName = "Crowbar's Glee",
    description = "Why would you ever want the Terminators to run out of crowbars?",
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
    roundEarlyStartSound = "default",
    genericSpawnerRate = "default",
    chanceToBeVotable = 1,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator",
            prettyName = "A Crowbar Slingin' Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 2 },
            preSpawnedFuncs = { giveCrowbar },
            postSpawnedFuncs = { setFistsAsCrowbar },
        },
    }
}

table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
