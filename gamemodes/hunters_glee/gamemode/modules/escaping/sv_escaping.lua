
local defaultScorePerEscapedRider = 500
local scorePerRiderCvar = CreateConVar( "glee_score_perescaped_rider", -1, FCVAR_ARCHIVE, "How much score to give per escaped rider. Set to -1 to use the default of " .. defaultScorePerEscapedRider )

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

local textDisplayDuration = 4

function GM:escapifyVehicle( vehicle )
    local driver
    if vehicle.GetDriver then
        driver = vehicle:GetDriver()

    end
    local riders = allRidersOf( vehicle )
    local ridersMask = {}
    local actualRidersNoDriver = {}
    local everyoneElse = {}
    local riderCount = 0

    if #riders <= 0 then return end

    local delayUntil = CurTime() + textDisplayDuration + 0.15
    GAMEMODE:DelayRoundEndingUntil( delayUntil )

    for _, rider in ipairs( riders ) do
        ridersMask[rider] = true
        GAMEMODE:escapifyPlayer( rider )
        if rider ~= driver then
            riderCount = riderCount + 1
            table.insert( actualRidersNoDriver, rider )

        end
    end

    for _, ply in player.Iterator() do
        if ridersMask[ply] then continue end

        table.insert( everyoneElse, ply )

    end

    if riderCount > 0 then
        if IsValid( driver ) then
            huntersGlee_AnnounceDramatic( actualRidersNoDriver, 1000, textDisplayDuration, "You've escaped!\nYou can finally leave this all behind, thanks to...\n" .. driver:Nick() )

            local scorePerRider = scorePerRiderCvar:GetInt()
            if scorePerRider < 0 then
                scorePerRider = defaultScorePerEscapedRider

            end
            local increase = riderCount * scorePerRider
            driver:GivePlayerScore( increase )

            local sOrNoS = riderCount == 1 and "" or "s"
            huntersGlee_AnnounceDramatic( { driver }, 1000, textDisplayDuration, "You helped " .. riderCount .. " soul" .. sOrNoS .. " escape...\n+" .. increase .. " Score." )

            huntersGlee_AnnounceDramatic( everyoneElse, 50, textDisplayDuration, driver:Nick() .. " helped " .. riderCount .. " soul" .. sOrNoS .. " escape..." )

        else
            local escapablePlyCount = potentialEscapersCount()
            if escapablePlyCount > 0 then
                huntersGlee_AnnounceDramatic( riders, 1000, textDisplayDuration, "You've escaped!\nBut who did you leave behind?" )

                local sOrNoS = riderCount == 1 and "" or "s"
                local veOrS = riderCount == 1 and "s" or "ve"
                huntersGlee_AnnounceDramatic( everyoneElse, 50, textDisplayDuration, riderCount .. " soul" .. sOrNoS .. " ha" .. veOrS .. " escaped the hunt..." )

            else
                huntersGlee_AnnounceDramatic( riders, 1000, textDisplayDuration, "You've escaped!\nYou can finally leave this all behind..." )

            end
        end
    else
        local escapablePlyCount = potentialEscapersCount()
        if escapablePlyCount > 0 then
            huntersGlee_AnnounceDramatic( { driver }, 1000, textDisplayDuration, "You've escaped!\nBut who did you leave behind?" )
            huntersGlee_AnnounceDramatic( everyoneElse, 50, textDisplayDuration, driver:Nick() .. " has escaped!" )

        else
            huntersGlee_AnnounceDramatic( { driver }, 1000, textDisplayDuration, "You've escaped!\nYou can finally leave this all behind..." )

        end
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

-- rescue heli npc
hook.Add( "glee_rescueheliescape", "glee_escapeviarescueheli", function( heli )
    if not IsValid( heli ) then return end
    GAMEMODE:escapifyVehicle( heli )

end )


local white = Color( 255, 255, 255 )

-- TODO: make everyone invincible after the boss is defeated?

hook.Add( "glee_onbossdefeated", "glee_escapeviabossdefeat", function( boss, attacker )
    local msg = GAMEMODE:GetNameOfBot( boss ) .. "\nWAS KILLED BY\n" .. attacker:Nick() .. "\nYou're finally, truly safe..."
    huntersGlee_AnnounceDramatic( player.GetAll(), 1000, 10, msg )

    local alivePlayers = GAMEMODE:getAlivePlayers()
    for _, ply in ipairs( alivePlayers ) do
        timer.Simple( 0.5, function()
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


-- begin escaping rewards

-- flat 50% discount on all shop items if EVERYONE escaped
-- hook.Add( "huntersglee_round_pre_into_inactive", )

-- reward for escaping
local flatEscapingReward = 500
local rewardEveryoneEscaped = 1000 -- additional if everyone escaped
local rewardPerSkull = 100
local perSkullEveryoneEscaped = 200 -- additional per skull if everyone escaped

function GM:GiveEscapeRewardTo( ply )
    local setName = GAMEMODE:GetSpawnSet()

    local mapsEscapeMultiplier, mapsEscCount, mapsRemCount = GAMEMODE:GetMapsEscapeMultiplier( game.GetMap() )
    local spawnsetsEscapeMultiplier, spawnsetsEscCount, spawnsetsRemCount = GAMEMODE:GetSpawnsetsEscapeMultiplier( setName )

    local theMultiplier = mapsEscapeMultiplier * spawnsetsEscapeMultiplier

    local mapHasNeverEscaped = mapsEscCount <= 1
    local spawnsetHasNeverEscaped = spawnsetsEscCount <= 1


    local everyoneEscaped = GAMEMODE.roundExtraData.everyoneEscaped

    local baseReward = flatEscapingReward
    if everyoneEscaped then
        baseReward = baseReward + rewardEveryoneEscaped

    end
    baseReward = baseReward * theMultiplier


    local skullReward = rewardPerSkull
    if everyoneEscaped then
        skullReward = skullReward + perSkullEveryoneEscaped

    end
    skullReward = skullReward * theMultiplier


    timer.Simple( 2, function()
        if not IsValid( ply ) then return end

        if mapHasNeverEscaped or spawnsetHasNeverEscaped then
            local neverBoth = mapHasNeverEscaped and spawnsetHasNeverEscaped
            local subject   = neverBoth and "This map and spawnset have" or mapHasNeverEscaped and "This map has" or "This spawnset has"
            huntersGlee_AnnounceDramatic( { ply }, 1001, 4, subject .. " never been escaped before!" )
            return

        end

        local difficulty
        if theMultiplier > 4 then
            difficulty = "impossible..."

        elseif theMultiplier > 3 then
            difficulty = "a nightmare"

        elseif theMultiplier > 2 then
            difficulty = "horrible"

        elseif theMultiplier > 1 then
            difficulty = "hard"

        elseif theMultiplier >= 0.5 then
            difficulty = "easy"

        else
            difficulty = "trivial"

        end

        huntersGlee_AnnounceDramatic( { ply }, 999, 2, "Escaping here was " .. difficulty .. "..." )

    end )

    timer.Simple( 4, function()
        if not IsValid( ply ) then return end
        local msg = "+" .. baseReward .. " Score..."
        ply:GivePlayerScore( baseReward )

        huntersGlee_AnnounceDramatic( { ply }, 1000, 4, "You escaped!\n" .. msg )

    end )

    local timerName = "glee_escaping_skullrewardgobbler_" .. ply:EntIndex()
    local totalSkulls = ply:GetSkulls()
    local totalSkullsToReward = totalSkulls
    local ranCount = 0
    local rewardHinted
    timer.Create( timerName, 8, 0, function()
        if not IsValid( ply ) then
            timer.Remove( timerName )
            return

        end
        if totalSkullsToReward <= 0 then
            timer.Remove( timerName )
            return

        end
        if not rewardHinted then
            rewardHinted = true
            local sOrNoS = totalSkulls == 1 and "" or "s"
            local skullMsg = "Cashing out your " .. totalSkulls .. " skull" .. sOrNoS .. "..."
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

        ply:GivePlayerScore( skullReward )
        totalSkullsToReward = totalSkullsToReward - 1

    end )
end
