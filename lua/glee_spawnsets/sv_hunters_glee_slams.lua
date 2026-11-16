local function giveSlam( _spawnset, npc )
    npc.DefaultWeapon = "weapon_slam"
    npc.DefaultSidearms = { "weapon_slam" }

    local timerName = "glee_term_slam_give_" .. npc:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( npc ) then timer.Remove( timerName ) return end
        local primaryWeapon = npc:GetActiveWeapon()

        if IsValid( primaryWeapon ) then
            if primaryWeapon:GetClass() == "weapon_slam" then
                return

            else
                primaryWeapon.terminatorCrappyWeapon = true -- dont use this again

            end
        end
        local bar = npc:Give( "weapon_slam" )
        bar.terminator_IgnoreWeaponUtility = true

    end )
end

local function setFistsAsSlam( _spawnset, npc )
    npc.TERM_FISTS = "weapon_slam"

end

local defaultSpawnSet = {
    name = "hunters_glee_slams",
    prettyName = "Artillery's Glee",
    description = "INCOOOOOOOOOMING!",
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
    chanceToBeVotable = 0.5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator",
            prettyName = "A Slam Slingin' Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 2 },
            preSpawnedFuncs = { giveSlam },
            postSpawnedFuncs = { setFistsAsSlam },
        },
    }
}

table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
