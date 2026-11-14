local GAMEMODE = GAMEMODE or GM

GM.IdealEscapingTime = 5 * 60 -- escaping should always take at least this long

hook.Add( "glee_ply_escaped", "glee_escapersinkillfeed", function( picker )
    local inflic = "glee_escapeicon"
    if not GAMEMODE.SendDeathNotice then return end
    GAMEMODE:SendDeathNotice( picker, inflic, nil, 0 )

end )

local function potentialEscapersCount()
    local escapablePlyCount = 0
    for _, ply in player.Iterator() do
        if ply:Alive() and ply:GetNWInt( "glee_spectateteam", 0 ) == GAMEMODE.TEAM_PLAYING then
            escapablePlyCount = escapablePlyCount + 1

        end
    end

    return escapablePlyCount

end

local function allRidersOf( vehicle )
    local riders = {}
    local riderLookup = {}
    local explored = {}

    local function recurse( ent )
        if explored[ent] or not IsValid( ent ) then return end
        explored[ent] = true

        if ent.GetDriver then
            local rider = ent:GetDriver()

            if not riderLookup[rider] and IsValid( rider ) and rider:IsPlayer() and rider:Alive() then
                riderLookup[rider] = true
                table.insert( riders, rider )

            end
        end

        for _, child in pairs( ent:GetChildren() ) do
            recurse( child )

        end
    end

    recurse( vehicle )

    local rappellers = vehicle.glee_stuffRappellingOffMe
    if rappellers then
        for rappeller, _ in pairs( rappellers ) do
            if not IsValid( rappeller ) then continue end
            if not rappeller:Alive() then continue end
            if not rappeller:IsPlayer() then continue end
            if riderLookup[rappeller] then continue end

            riderLookup[rappeller] = true
            table.insert( riders, rappeller )

        end
    end

    return riders

end

local textDisplayDuration = 8
local textDisplayDurationNobodyLeft = 4

function GM:escapifyVehicle( vehicle )
    local driver
    if vehicle.GetDriver then
        driver = vehicle:GetDriver()

    end
    local riders = allRidersOf( vehicle )
    local ridersMask = {}
    local escapedRiders = {}
    local actualRidersNoDriver = {}
    local everyoneElse = {}
    local riderCount = 0

    if #riders <= 0 then return end

    for _, rider in ipairs( riders ) do
        if not self:CanEscape( rider ) then continue end

        local blockEscape = hook.Run( "glee_blockescape_invehicle", rider, vehicle )
        if blockEscape == true then continue end

        ridersMask[rider] = true
        table.insert( escapedRiders, rider )
        self:escapifyPlayer( rider )
        if rider ~= driver then
            riderCount = riderCount + 1
            table.insert( actualRidersNoDriver, rider )

        end
    end

    if #escapedRiders <= 0 then return end

    -- with nobody left, the round ends as soon as this text is gone
    local nobodyLeft = potentialEscapersCount() <= 0
    local displayDuration = nobodyLeft and textDisplayDurationNobodyLeft or textDisplayDuration

    local delayUntil = CurTime() + displayDuration + 0.15
    self:DelayRoundEndingUntil( delayUntil )

    for _, ply in player.Iterator() do
        if ridersMask[ply] then continue end

        table.insert( everyoneElse, ply )

    end

    if riderCount > 0 then
        if IsValid( driver ) then
            huntersGlee_AnnounceDramatic( actualRidersNoDriver, 1000, displayDuration, table.concat( {
                "You've escaped!\n",
                "You can finally leave this all behind, thanks to...\n",
                driver:Nick(),
            } ) )

            local increase = riderCount * self:GetEscapeRewardPerRider()
            driver:GivePlayerScore( increase )

            local sOrNoS = riderCount == 1 and "" or "s"
            huntersGlee_AnnounceDramatic( { driver }, 1000, displayDuration, table.concat( {
                "You helped ", riderCount, " soul", sOrNoS, " escape...\n",
                "+", increase, " Score.",
            } ) )

            GAMEMODE:IncrementPersistentGuilt( driver, -( riderCount * 0.35 ), "They escaped because of you...\nYou feel a bit less guilty already." )

            huntersGlee_NotifyLivingAndDead( everyoneElse, {
                text = "WARNING: SOUL UPLIFT DETECTED",
                description = driver:Nick() .. " helped " .. riderCount .. " soul" .. sOrNoS .. " escape...",
                kind = "alert",
                time = displayDuration,
            }, {
                text = driver:Nick() .. " helped " .. riderCount .. " soul" .. sOrNoS .. " escape...",
                kind = "good",
                time = displayDuration,
            } )

        else
            if not nobodyLeft then
                huntersGlee_AnnounceDramatic( escapedRiders, 1000, displayDuration, "You've escaped!\nBut who did you leave behind?" )

            else
                huntersGlee_AnnounceDramatic( escapedRiders, 1000, displayDuration, "You've escaped!\nYou can finally leave this all behind..." )

            end
            local sOrNoS = riderCount == 1 and "" or "s"
            local veOrS = riderCount == 1 and "s" or "ve"
            huntersGlee_NotifyLivingAndDead( everyoneElse, {
                text = "WARNING: SOUL UPLIFT DETECTED",
                description = riderCount .. " soul" .. sOrNoS .. " ha" .. veOrS .. " escaped the hunt...",
                kind = "alert",
                time = displayDuration,
            }, {
                text = riderCount .. " soul" .. sOrNoS .. " ha" .. veOrS .. " escaped the hunt...",
                kind = "good",
                time = displayDuration,
            } )
        end
    else
        if not nobodyLeft then
            huntersGlee_AnnounceDramatic( { driver }, 1000, displayDuration, "You've escaped!\nBut who did you leave behind?" )

        else
            huntersGlee_AnnounceDramatic( { driver }, 1000, displayDuration, "You've escaped!\nYou can finally leave this all behind..." )

        end

        huntersGlee_NotifyLivingAndDead( everyoneElse, {
            text = "WARNING: SOUL UPLIFT DETECTED",
            description = driver:Nick() .. " has escaped...",
            kind = "alert",
            time = displayDuration,
        }, {
            text = driver:Nick() .. " has escaped!",
            kind = "good",
            time = displayDuration,
        } )
    end

    SafeRemoveEntity( vehicle )

end


GAMEMODE.glee_EscapableVehicles = GAMEMODE.glee_EscapableVehicles or {}

hook.Add( "PlayerEnteredVehicle", "glee_findescapablevehicles", function( _driver, vehicle )
    local trueVehicle = vehicle
    local parent = vehicle:GetParent()

    while IsValid( parent ) and parent.GetDriver do
        trueVehicle = parent
        parent = trueVehicle:GetParent()

    end

    if GAMEMODE.glee_EscapableVehicles[trueVehicle] then return end

    trueVehicle.glee_oldPhysicsCollide = trueVehicle.PhysicsCollide
    trueVehicle.PhysicsCollide = function( self, data, phys )
        if data.TheirSurfaceProps ~= 76 then -- we hit non-skybox! (default_silent) 
            return self:glee_oldPhysicsCollide( data, phys )

        end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        if self.glee_IsWaitingForGas then return end -- need gas to start? need gas to escape
        GAMEMODE:escapifyVehicle( self )

    end
    GAMEMODE.glee_EscapableVehicles[trueVehicle] = true
    trueVehicle:CallOnRemove( function()
        GAMEMODE.glee_EscapableVehicles[trueVehicle] = nil

    end )
end )

-- gleeVehicles, eg the rescue heli
hook.Add( "glee_vehicle_depart", "glee_escapeviagleevehicle", function( host )
    if not IsValid( host ) then return end
    GAMEMODE:escapifyVehicle( host )

end )

hook.Add( "PlayerEnteredVehicle", "glee_escapeseat_entertime", function( ply )
    if not terminator_Extras.gleeVehicles.IsInEscapeSeat( ply ) then return end
    ply.glee_escapeSeatEnterTime = CurTime()

end )

-- base toggles third person on crouch, blocked briefly after boarding an escape vehicle
local escapeSeatThirdPersonBlockTime = 5

function GM:VehicleMove( ply, vehicle, mv )
    if terminator_Extras.gleeVehicles.IsInEscapeSeat( ply ) and ( ply.glee_escapeSeatEnterTime or 0 ) + escapeSeatThirdPersonBlockTime > CurTime() then return end
    return self.BaseClass.VehicleMove( self, ply, vehicle, mv )

end

hook.Add( "glee_onescapehelicalled", "glee_escapehelicalled_lesson", function( caller )
    if not caller:IsPlayer() then return end
    GAMEMODE:LearnLesson( caller, "SuccessfullyCalledHeli" )

end )


local white = Color( 255, 255, 255 )

GAMEMODE:RegisterStatusEffect( "boss_defeat_resistance",
    function( self, _owner )
        self:SetPlyRemoveOnDeath( true )
        self:HookOnce( "EntityTakeDamage", function( target, dmg )
            if not target.HasStatusEffect then return end
            if not target:HasStatusEffect( "boss_defeat_resistance" ) then return end

            dmg:ScaleDamage( 0.05 )

        end )
    end
)

hook.Add( "glee_onboss_defeated", "glee_escapeviabossdefeat", function( boss, attacker )
    local playerCount = player.GetCount()
    local header
    if playerCount <= 1 then
        header = table.concat( {
            "You've HUNTED ", GAMEMODE:GetNameOfBot( boss ), "\n",
        } )

    else
        header = table.concat( {
            GAMEMODE:GetNameOfBot( boss ), "\n",
            "WAS KILLED BY\n",
            GAMEMODE:GetNameOfBot( attacker ), "\n",
        } )
    end

    local escapedPlys = {}
    local deadPlys = {}
    local livingPlys = {}
    for _, ply in player.Iterator() do
        if ply:HasEscaped() then
            table.insert( escapedPlys, ply )

        elseif not ply:Alive() or ply:Health() <= 0 then
            table.insert( deadPlys, ply )

        else
            table.insert( livingPlys, ply )

        end
    end

    huntersGlee_AnnounceDramatic( livingPlys, 1000, 8, header .. "You're finally, truly safe..." )
    huntersGlee_AnnounceDramatic( deadPlys, 1000, 8, header .. "If only you were still alive..." )
    huntersGlee_AnnounceDramatic( escapedPlys, 1000, 8, header .. "They'll be joining you now..." )

    local alivePlayers = GAMEMODE:getAlivePlayers()
    for _, ply in ipairs( alivePlayers ) do
        ply:GiveStatusEffect( "boss_defeat_resistance" )

        timer.Simple( 2, function()
            if not IsValid( ply ) then return end
            if ply:Health() <= 0 then return end

            ply:ScreenFade( SCREENFADE.OUT, white, 5, 1 )
            timer.Simple( 5, function()
                if not IsValid( ply ) then return end
                if ply:Health() <= 0 then return end
                GAMEMODE:escapifyPlayer( ply )
                GAMEMODE:ForceRoundEnd()

            end )
        end )
    end
end )

hook.Add( "glee_onboss_crappydefeated", "glee_escapeviabossdefeat", function( boss )
    local msg = table.concat( {
        GAMEMODE:GetNameOfBot( boss ), "\n",
        "Has died an ungleeful death...",
    } )

    huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 8, msg )

end )


-- begin escaping rewards

--[[---------------------------------------------------------
    GM:IsBoonable
    @desc Did everyone escape? That's a boon.
      Astrally projected players chose to leave their body, so they don't rob everyone else of it.
    @param isImpendingEscaper: Optional, returns true for a player who's about to escape, so they count as escaped already.
    @return: True if the round would end in a boon
--]]---------------------------------------------------------
function GM:IsBoonable( isImpendingEscaper )
    local someoneEscaped = false
    for _, ply in player.Iterator() do
        if ply:HasEscaped() or ( isImpendingEscaper and isImpendingEscaper( ply ) ) then
            someoneEscaped = true

        elseif not ply:HasStatusEffect( "astrallyprojected" ) then
            return false

        end
    end
    -- a round where everyone astrally projected isn't a round where everyone escaped
    return someoneEscaped

end

-- flat 50% discount on all shop items if EVERYONE escaped
-- hook.Add( "huntersglee_round_pre_into_inactive", )

local skullCashoutDelay = 8

function GM:GiveEscapeRewardTo( ply )
    local setName = GAMEMODE:GetSpawnSet()

    local _mapsMul, mapsEscCount = GAMEMODE:GetMapsEscapeMultiplier( game.GetMap() )
    local _spawnsetsMul, spawnsetsEscCount = GAMEMODE:GetSpawnsetsEscapeMultiplier( setName )

    local mapModesMultiplier = self:GetEscapeMultiplier()

    local theMultiplier, envoyHelpedCount = self:GetEnvoysEscapeMultiplier( ply, mapModesMultiplier )

    local mapHasNeverEscaped = mapsEscCount <= 1
    local spawnsetHasNeverEscaped = spawnsetsEscCount <= 1


    local everyoneEscaped = GAMEMODE.roundExtraData.everyoneEscaped

    local baseReward = self:GetEscapeReward()
    if everyoneEscaped then
        baseReward = baseReward + self:GetEscapeRewardBoon()

    end
    baseReward = baseReward * theMultiplier


    timer.Simple( 2, function()
        if not IsValid( ply ) then return end

        if mapHasNeverEscaped or spawnsetHasNeverEscaped then
            local neverBoth = mapHasNeverEscaped and spawnsetHasNeverEscaped
            local subject   = neverBoth and "This Map and Misery have" or mapHasNeverEscaped and "This map has" or "This Misery has"
            huntersGlee_AnnounceDramatic( { ply }, 1001, 4, subject .. " never been escaped before!" )
            return

        end

        local difficulty
        if mapModesMultiplier > 4 then
            difficulty = "impossible..."

        elseif mapModesMultiplier > 3 then
            difficulty = "a nightmare"

        elseif mapModesMultiplier > 2 then
            difficulty = "horrible"

        elseif mapModesMultiplier > 1 then
            difficulty = "hard"

        elseif mapModesMultiplier >= 0.5 then
            difficulty = "easy"

        else
            difficulty = "trivial"

        end

        local msg = "Escaping here was " .. difficulty .. "..."
        huntersGlee_AnnounceDramatic( { ply }, 999, 2, msg )

    end )

    timer.Simple( 4, function()
        if not IsValid( ply ) then return end
        local msgParts = { "You escaped!\n+", baseReward, " Score..." }

        if envoyHelpedCount > 0 then
            table.insert( msgParts, everyoneEscaped and "\nDOUBLE BOON!!!" or "\nEnvoy's Boon!" )

            local holders = envoyHelpedCount == 1 and " Prospective Account Holder" or " Prospective Account Holders"
            huntersGlee_Notify( { ply }, {
                text = "Envoy's Boon: " .. envoyHelpedCount .. holders .. " tasted emerging Freedom, thanks to you.",
                description = "Escape Multiplier " .. math.Round( mapModesMultiplier, 2 ) .. "x -> " .. math.Round( theMultiplier, 2 ) .. "x",
                kind = "jackpot",
                time = 18,
            } )

        end

        ply:GivePlayerScore( baseReward )

        huntersGlee_AnnounceDramatic( { ply }, 1000, 4, table.concat( msgParts ) )

    end )

    local hasGains = ply:HasBankItem( "skull_gains" )
    local hasLoophole = hasGains and ply:HasBankItem( "skull_loophole" )

    local skullReward = self:GetSkullReward()
    if hasGains then
        skullReward = self:GetSkullRewardGains()
        if everyoneEscaped then
            skullReward = skullReward + self:GetSkullRewardGainsBoon()

        end
        if hasLoophole then
            skullReward = skullReward * self:GetSkullRelayMultiplier()

        end

        skullReward = skullReward * theMultiplier

    end


    local timerName = "glee_escaping_skullrewardgobbler_" .. ply:EntIndex()
    local totalSkulls = ply:GetSkulls()
    local totalSkullsToReward = totalSkulls
    local rewardedSkulls = 0
    local ranCount = 0
    local rewardHinted
    timer.Create( timerName, skullCashoutDelay, 0, function()
        if not IsValid( ply ) then
            timer.Remove( timerName )
            return

        end
        if rewardedSkulls >= totalSkullsToReward then
            timer.Remove( timerName )
            return

        end
        if not rewardHinted then
            rewardHinted = true
            local sOrNoS = totalSkulls == 1 and "" or "s"
            local skullMsg
            if hasLoophole then
                skullMsg = table.concat( {
                    "Relaying your ", totalSkulls, " cashed out skull", sOrNoS, " off-world...\n",
                    "Straight into your bank...",
                } )

            elseif hasGains then
                skullMsg = "Cashing out your " .. totalSkulls .. " skull" .. sOrNoS .. ", with Skull Gains..."

            else
                skullMsg = "Cashing out your " .. totalSkulls .. " skull" .. sOrNoS .. ", for an ungainly pittance..."

            end
            huntersGlee_AnnounceDramatic( { ply }, 1001, 4, skullMsg )

        end

        local filterOnlyThem = RecipientFilter()
        filterOnlyThem:AddPlayer( ply )

        local kachingPitch = 80
        local add = -( ranCount / 10 )
        kachingPitch = kachingPitch + add
        ply:EmitSound( "hunters_glee/209578_zott820_cash-register-purchase.wav", 75, kachingPitch, 1, CHAN_STATIC, SND_NOFLAGS, 0, filterOnlyThem )

        local skullPitch = math.random( 75, 85 ) + -( ranCount / 5 )
        local skullSound = "physics/cardboard/cardboard_cup_impact_hard" .. math.random( 1, 3 ) .. ".wav"
        ply:EmitSound( skullSound, 75, skullPitch, 1, CHAN_BODY, SND_NOFLAGS, 0, filterOnlyThem )

        ranCount = ranCount + 1
        local newDelay = 1 / ranCount
        timer.Adjust( timerName, newDelay, 0, nil )

        if hasLoophole then
            ply:BankDepositNoFee( skullReward )

        else
            ply:GivePlayerScore( skullReward )

        end
        rewardedSkulls = rewardedSkulls + 1

    end )
end
