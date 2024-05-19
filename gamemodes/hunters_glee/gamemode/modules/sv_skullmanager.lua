
local GAMEMODE = GAMEMODE or GM

function GM:SpawnASkull( pos, ang, termSkull, parent )
    local skull = ents.Create( "termhunt_skull_pickup" )
    if not IsValid( skull ) then return end
    if IsValid( parent ) then
        skull.persistientSkull = true

    end
    skull:SetPos( pos )
    skull:SetAngles( ang )
    if termSkull == true then
        skull:SetIsTerminatorSkull( true )

    end

    skull:Spawn()

    timer.Simple( 0, function()
        if not IsValid( skull ) then return end
        if not IsValid( parent ) then return end
        skull:GetPhysicsObject():SetVelocity( parent:GetVelocity() )

    end )

    return skull

end

hook.Add( "OnTerminatorKilledRagdoll", "glee_dropterminatorskulls", function( died, _, _ )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    local newSkull = GAMEMODE:SpawnASkull( died:GetShootPos(), died:GetAimVector():Angle(), true, died )

    -- makes "erm something must have died here" hints better
    newSkull.fromSomethingWitnessable = true

end )

hook.Add( "PlayerDeath", "glee_dropplayerskulls", function( died, _, attacker )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    if attacker == died then return end
    local newSkull = GAMEMODE:SpawnASkull( died:GetShootPos(), died:GetAimVector():Angle(), nil, died )

    newSkull.skullSteamId = died:SteamID64()
    newSkull.fromSomethingWitnessable = true

end )

GM.persistientSkulls = {}

-- skulls from dead players/terms stick around
hook.Add( "PreCleanupMap", "glee_savepersistientskulls", function()
    table.Empty( GAMEMODE.persistientSkulls )

    for _, skull in ipairs( ents.FindByClass( "termhunt_skull_pickup" ) ) do
        if not skull.persistientSkull then continue end
        local skullTbl = {}
        skullTbl.pos = skull:GetPos()
        skullTbl.ang = skull:GetAngles()
        skullTbl.persist = true
        skullTbl.termSkull = skull:GetIsTerminatorSkull()
        skullTbl.skullSteamId = skull.skullSteamId

        table.insert( GAMEMODE.persistientSkulls, skullTbl )

    end
end )

hook.Add( "huntersglee_round_into_active", "glee_loadpersistientskulls", function()
    -- restore skulls when hunt starts ( no cheeky skulls when setting up! )
    for _, skullTbl in pairs( GAMEMODE.persistientSkulls ) do
        local skull = ents.Create( "termhunt_skull_pickup" )
        if not IsValid( skull ) then return end
        if skullTbl.persist then
            skull.persistientSkull = true

        end
        skull.skullSteamId = skullTbl.skullSteamId
        skull:SetPos( skullTbl.pos )
        skull:SetAngles( skullTbl.ang )
        if skullTbl.termSkull == true then
            skull:SetIsTerminatorSkull( true )

        end

        skull:Spawn()
        timer.Simple( 0, function()
            if not IsValid( skull ) then return end
            if not IsValid( parent ) then return end
            skull:GetPhysicsObject():EnableMotion( false )

        end )
    end

    -- skull props!
    for _, skullProp in ipairs( ents.FindByModel( "models/Gibs/HGIBS.mdl" ) ) do
        local class = skullProp:GetClass()
        local goodClass = class == "prop_physics" or class == "prop_dynamic" or class == "gib"
        if not goodClass then continue end
        GAMEMODE:SpawnASkull( skullProp:GetPos(), skullProp:GetAngles() )

        --debugoverlay.Cross( skullProp:GetPos(), 100, 60, color_white, true )

        SafeRemoveEntity( skullProp )

    end

    -- a body, with a skull...?
    for _, skullRagdoll in ipairs( ents.FindByClass( "prop_ragdoll" ) ) do
        local canSkull = glee_RagdollHasASkull( skullRagdoll )
        if canSkull then
            --print( "erm skull", skullRagdoll )
            local skull = GAMEMODE:SpawnASkull( skullRagdoll:GetPos(), Angle( 0, 0, 0 ), nil )
            if not skull then continue end
            if not skull:AttachToRagdollsSkull( skullRagdoll ) then SafeRemoveEntity( skull ) continue end

        end
    end
end )

local nextSkullSpawnCheck = 0
local offsetFromGround = Vector( 0, 0, 25 )
-- placedalready INTENTIONALLY persists thru rounds
local placedAlready = {}
local mapSkullCount = 4

hook.Add( "glee_sv_validgmthink_active", "glee_addskulljobs", function()
    if nextSkullSpawnCheck > CurTime() then return end

    local skulls = ents.FindByClass( "termhunt_skull_pickup" )
    if #skulls >= mapSkullCount then nextSkullSpawnCheck = CurTime() + 15 return end

    local skullJob = {}
    skullJob.jobsName = "skull"

    -- spawn reliably around the terminators, but rarely around players
    if math.random( 1, 100 ) < 15 then
        local livePly = GAMEMODE:anAlivePlayer()
        if not IsValid( livePly ) then return end
        skullJob.posFindingOrigin = livePly:GetPos()
        skullJob.spawnRadius = 4000

    else
        local randomHunter = GAMEMODE:aRandomHunter()
        if not IsValid( randomHunter ) then return end
        skullJob.posFindingOrigin = randomHunter:GetPos()
        skullJob.spawnRadius = 2000

    end

    skullJob.originIsDefinitive = false
    skullJob.sortForNearest = false
    skullJob.placedAlready = placedAlready
    skullJob.areaFilteringFunction = function( currJob, area )
        if area:IsBlocked() then return end
        if area:IsUnderwater() then return end
        -- dont place skulls in spots twice per session!
        if currJob.placedAlready[ area:GetID() ] then return end
        return true

    end
    skullJob.hideFromPlayers = true
    skullJob.posDerivingFunc = function( _, area )
        local points = { area:GetRandomPoint() + offsetFromGround }
        for _, spot in ipairs( area:GetHidingSpots( 1 ) ) do
            table.insert( points, spot + offsetFromGround )

        end
        return points

    end
    skullJob.maxPositionsForScoring = 800
    skullJob.posScoringBudget = 2000
    skullJob.posScoringFunction = function( _, toCheckPos, budget )
        -- get nook score, the more nooked the point is, the bigger the score.
        local nookScore = terminator_Extras.GetNookScore( toCheckPos )

        budget = budget + - 1
        return nookScore

    end
    skullJob.onPosFoundFunction = function( _, bestPosition )
        local angle = VectorRand()
        angle.z = 0
        angle = angle:Angle()
        local rareTermSkull = math.random( 1, 100 ) <= 15
        local skull = GAMEMODE:SpawnASkull( bestPosition, angle, rareTermSkull )
        if not IsValid( skull ) then return false end

        skull:DropToFloor()
        hook.Run( "glee_procskulls_skullspawned", skull )

        -- remove skulls really far away from players
        -- keeps people discovering skulls
        -- only do for procedural ones to keep the strategy of other skull types!
        local timerName = "glee_proceduralskulls_removestale_" .. skull:GetCreationID()
        timer.Create( timerName, 120, 0, function()
            if not IsValid( skull ) then timer.Remove( timerName ) return end
            local skullsPos = skull:GetPos()
            if bit.band( util.PointContents( skullsPos ), CONTENTS_WATER ) ~= 0 then SafeRemoveEntity( skull ) timer.Remove( timerName ) return end
            local nearest, distSqr = GAMEMODE:nearestAlivePlayer( skullsPos )
            if not IsValid( nearest ) then SafeRemoveEntity( skull ) timer.Remove( timerName ) return end
            if distSqr > 5000^2 then SafeRemoveEntity( skull ) timer.Remove( timerName ) return end

        end )

        return true

    end

    GAMEMODE:addProceduralSpawnJob( skullJob )
    --print( "ADDED" )
    --PrintTable( skullJob )

    nextSkullSpawnCheck = CurTime() + 20

    if mapSkullCount <= 4 and #navmesh.GetAllNavAreas() > 4000 then
        mapSkullCount = 8

    end
end )

local function postPlaced( bestPosition )
    local placedArea = GAMEMODE:getNearestNav( bestPosition, 500 )
    if placedArea and placedArea.IsValid and placedArea:IsValid() then
        placedAlready[ placedArea:GetID() ] = true
        for _, area in ipairs( placedArea:GetAdjacentAreas() ) do
            placedAlready[ area:GetID() ] = true

        end
    end
end

hook.Add( "glee_procskulls_skullspawned", "tracklastskull", function( skull )
    postPlaced( skull:GetPos() )

end )

local nextCalculate = 0

local function checkSkulls()
    if nextCalculate > CurTime() then return end
    -- calc roughly once per tick
    nextCalculate = CurTime() + 0.05
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    if #player.GetAll() <= 1 then return end

    -- wait until the skull has finished setting up
    timer.Simple( 0, function()
        local winner, tieBroken = GAMEMODE:calculateWinner()
        SetGlobalEntity( "termHuntWinner", winner )
        SetGlobalBool( "termHuntWinnerTied", tieBroken )

    end )
end

hook.Add( "huntersglee_giveskulls", "glee_broadcastnewfinestprey", checkSkulls )

hook.Add( "huntersglee_round_into_active", "glee_broadcastnewfinestprey", checkSkulls )


hook.Add( "PlayerDeath", "glee_winnerdropsskulls", function( victim )
    local winner = GetGlobalEntity( "termHuntWinner" )

    if not IsValid( winner ) then return end
    if winner ~= victim then return end

    if #player.GetAll() <= 1 then return end
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

    local theirSkulls = victim:GetSkulls()
    skullsToDrop = theirSkulls / 10

    skullsToDrop = math.floor( skullsToDrop )

    if skullsToDrop <= 0 then return end

    victim:GivePlayerSkulls( -skullsToDrop )
    local sIfMultiple = ""
    if skullsToDrop > 1 then
        sIfMultiple = "s"

    end
    huntersGlee_Announce( { victim }, 1, 5, "You've died as the finest prey.\nDropping " .. skullsToDrop .. " extra skull" .. sIfMultiple .. "..." )

    while skullsToDrop > 0 do
        skullsToDrop = skullsToDrop + -1
        local droppedSkull = ents.Create( "termhunt_skull_pickup" )
        droppedSkull:SetPos( victim:GetPos() + vector_up * 25 )
        droppedSkull:SetAngles( AngleRand() )
        droppedSkull:Spawn()

        if IsValid( droppedSkull:GetPhysicsObject() ) then
            droppedSkull:GetPhysicsObject():SetVelocity( victim:GetVelocity() + ( VectorRand() * math.random( 10, 30 ) ) )

        end
    end
end )

hook.Add( "glee_plypickedupskull", "glee_skullpickupsinkillfeed", function( picker )
    local inflic = "glee_skullpickup"
    if not GAMEMODE.SendDeathNotice then return end
    GAMEMODE:SendDeathNotice( picker, inflic, nil, 0 )

end )

hook.Add( "glee_blockskullpickup", "glee_pickupwhenactive", function( picker )
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE then return end

    huntersGlee_Announce( { picker }, 1, 1, "You can only pick up skulls during the hunt." )
    return true

end )

hook.Add( "OnEntityCreated", "glee_detectotherskulls", function( ent )
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    local class = ent:GetClass()

    if class == "termhunt_skull_pickup" then return end
    if class == "glee_lightning" then return end

    -- need to timer.simple all ents ugh
    -- no model on the first tick they're created
    timer.Simple( 0, function()
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        if not IsValid( ent ) then return end
        if ent:GetModel() ~= "models/gibs/hgibs.mdl" then return end

        -- make barnacles not OP
        if class == "gib" and math.random( 1, 100 ) < 60 then SafeRemoveEntity( ent ) return end

        GAMEMODE:SpawnASkull( ent:GetPos(), ent:GetAngles() )
        SafeRemoveEntity( ent )

    end )
end )