local function maybeOverchargeThisDude( _spawnSet, spawned )
    local _, richestScore = GAMEMODE:GetRichestPlayer()

    local makeHimSmart = GAMEMODE.sessionDiffBump > 100 or richestScore > 5000
    if makeHimSmart then
        spawned:ReallyAnger( 60 )
        spawned:GetTheBestWeapon()

    end

    local overcharge = GAMEMODE.sessionDiffBump > 200 or richestScore > 10000
    if overcharge then
        glee_Overcharge( spawned )

        local lightning = ents.Create( "glee_lightning" )
        lightning:SetOwner( spawned )
        lightning:SetPos( spawned:GetPos() )
        lightning:SetPowa( 12 )
        lightning:Spawn()

        timer.Simple( 0.1, function()
            if not IsValid( spawned ) then return end
            spawned:SetHealth( spawned:GetMaxHealth() )

        end )

        if not GAMEMODE.roundExtraData.overchargedWarning then
            GAMEMODE.roundExtraData.overchargedWarning = true
            huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, "This hunt is off balance...\nThe hunter has been overcharged..." )

        end
    end
end

local set = {
    name = "hunters_glee_oneguy", -- unique name
    prettyName = "One Gleeful Hunter",
    description = "One Terminator, he'll always be back.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = 1,
    maxSpawnCount = 1,
    maxSpawnDist = { 2500, 3500 }, -- CLOSE!
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 1, -- and fade into the background if this host isn't challenged by this
    chanceToBeVotableWhenHard = 15, -- stick around
    spawns = {
        {
            hardRandomChance = nil,
            name = "theOneTerminator",
            prettyName = "The Terminator",
            class = "terminator_nextbot_snail",
            spawnType = "hunter",
            difficultyCost = 1,
            maxCount = 1,
            countClass = "terminator_nextbot_snail",
            postSpawnedFuncs = { maybeOverchargeThisDude },
            isBoss = true,
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
