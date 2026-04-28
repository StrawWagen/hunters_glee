local function giveRPG( _spawnset, npc )
    npc.DefaultWeapon = "weapon_rpg"
    npc.DefaultSidearms = { "weapon_rpg" }

    local timerName = "glee_term_rpg_give_" .. npc:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( npc ) then timer.Remove( timerName ) return end
        local primaryWeapon = npc:GetActiveWeapon()

        if IsValid( primaryWeapon ) then
            if primaryWeapon:GetClass() == "weapon_rpg" then
                return

            else
                primaryWeapon.terminatorCrappyWeapon = true

            end
        end
        local bar = npc:Give( "weapon_rpg" )
        bar.terminator_IgnoreWeaponUtility = true

    end )
end

local function setFistsAsRPG( _spawnset, npc )
    npc.TERM_FISTS = "weapon_rpg"

end

local function giveTau( _spawnset, npc )
    npc.DefaultWeapon = "termhunt_taucannon"
    npc.DefaultSidearms = { "termhunt_taucannon" }

    local timerName = "glee_term_tau_give_" .. npc:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( npc ) then timer.Remove( timerName ) return end
        local primaryWeapon = npc:GetActiveWeapon()

        if IsValid( primaryWeapon ) then
            if primaryWeapon:GetClass() == "termhunt_taucannon" then
                return

            else
                primaryWeapon.terminatorCrappyWeapon = true

            end
        end
        local bar = npc:Give( "termhunt_taucannon" )
        bar.terminator_IgnoreWeaponUtility = true

    end )
end

local function setFistsAsTau( _spawnset, npc )
    npc.TERM_FISTS = "termhunt_taucannon"

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
        {
            hardRandomChance = nil,
            name = "tau_terminator",
            prettyName = "A Tau Campin' Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 1 },
            preSpawnedFuncs = { giveTau },
            postSpawnedFuncs = { setFistsAsTau },
        },
        {
            hardRandomChance = nil,
            name = "rpg_terminator",
            prettyName = "A RPG Campin' Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = { 10 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 1 },
            preSpawnedFuncs = { giveRPG },
            postSpawnedFuncs = { setFistsAsRPG },
        },
    }
}

table.insert( GLEE_SPAWNSETS, campersDelightSpawnSet )
