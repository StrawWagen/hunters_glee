AddCSLuaFile()

DEFINE_BASECLASS( "termhunt_flare" )

local GAMEMODE = GAMEMODE or GM

ENT.Category    = "Hunter's Glee"
ENT.PrintName   = "Signal Flare"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Flares"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/plates/plate.mdl"

local className = "termhunt_signalflare"
if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, className, "vgui/hud/killicon/" .. className .. ".png" )

end

local heliModel = "models/glee/combine_helicopter_glee.mdl"

--sandbox support
function ENT:SpawnFunction( ply, tr )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 20

    local ent = ents.Create( "termhunt_signalflare" )
    ent:Spawn()
    ent:SetPos( SpawnPos )
    ent:SetOwner( ply )

    return ent

end

if SERVER and terminator_Extras then

    local EntityPairs

    do
        local e

        -- Custom iterator, similar to ipairs, but made to iterate
        -- over a table of entities, while skipping invalid entities.
        -- CREDIT GLIDE, STYLED
        local function EntIterator( array, i )
            i = i + 1
            e = array[i]

            while e and not ( e.IsValid and e:IsValid() ) do
                i = i + 1
                e = array[i]
            end

            if e then
                return i, e
            end
        end

        function EntityPairs( array )
            return EntIterator, array, 0
        end
    end

    local debugging = CreateConVar( "huntersglee_debug_escapeheli", "0", { FCVAR_NONE }, "Enable debug info for the escape heli?" )

    util.PrecacheModel( heliModel )

    ENT.SteppedTooCloseDist = 2000 -- start at 2k dist
    ENT.MinTooCloseDist = 400 -- step down to 400 if we dont find any good corridors to spawn heli at
    ENT.SteppedDirMaxZ = 0.15 -- start at 0.15
    ENT.MaxDirMaxZ = 0.75 -- stepped up every failure until it reaches this

    local function angerEverything()
        for _, ent in ents.Iterator() do
            if not ent.ReallyAnger then continue end
            ent:ReallyAnger( 120 )

        end
    end

    local cachedTriggerPushes = {}
    local triggerPushCacheTime = 0

    local function rayHitsTriggerPush( origin, offset )
        local cur = CurTime()
        if triggerPushCacheTime < cur then
            cachedTriggerPushes = ents.FindByClass( "trigger_push" )
            triggerPushCacheTime = cur + 25

        end
        if #cachedTriggerPushes == 0 then return false end

        for _, push in ipairs( cachedTriggerPushes ) do
            if not IsValid( push ) then
                triggerPushCacheTime = 0
                return

            end
            if util.IntersectRayWithOBB( origin, offset, push:GetPos(), push:GetAngles(), push:OBBMins(), push:OBBMaxs() ) then
                return true

            end
        end
    end

    local zHeightToStartCalling = 350

    local heli_SpeedLimit = 4000
    local heli_CloseToObstacleSpeedLimit = 250
    local heli_TooFarFromGround = 1250
    local heli_TooCloseToGround = 300
    local heli_ExitPos = Vector( 0, 0, -100 )
    local heli_RopeOriginOffset = Vector( -7.1, 50.8, -40.5 )

    -- hullsize for finding a corridor from flare to sky 
    local callingHeliMaxs = 450
    local callingHeliMins = -callingHeliMaxs

    -- hullsize for nav traces
    local wayfindingHeliMaxs = 325
    local wayfindingHeliMins = -wayfindingHeliMaxs

    -- when flying less than heli_CloseToObstacleSpeedLimit, do smaller nav traces
    local slowMovingHeliMaxs = 175
    local slowMovingHeliMins = -slowMovingHeliMaxs

    local invisCol = Color( 255, 255, 255, 1 )

    local heli_seatPositions = {
        { pos = Vector( -51.1, 1.1, -19.8 ), ang = Angle( 0, -90, -15 ) },
        { pos = Vector( -51.1, 28.9, -19.8 ), ang = Angle( 0, -90, -15 ) },
        { pos = Vector( -51.1, -26.8, -19.8 ), ang = Angle( 0, -90, -15 ) },
        { pos = Vector( 59.6, -0.4, -48 ), ang = Angle( 0, 90, 15 ) },
        { pos = Vector( 61, 26, -47.4 ), ang = Angle( 15, -0.3, 0 ) },
        { pos = Vector( 61.5, -26.9, -47.6 ), ang = Angle( -15, -179.7, 0 ) },
    }

    local rescueTimerName = "glee_rescueheli_countdown"

    function ENT:AdditionalThink()
        if self.calledForHeli then return end
        if IsValid( terminator_Extras.glee_CurrentRescueHeli ) then return end
        if timer.Exists( rescueTimerName ) then return end -- already called, just waiting

        local myPos = self:GetPos()

        if not self.HitSkyboxAtLeastOnce then
            local startPos = self.StartingPos
            if not startPos then return end

            local heightFromStart = myPos.z - startPos.z

            if heightFromStart < zHeightToStartCalling then return end

        end

        local randDir = VectorRand()
        randDir.z = math.Rand( -0.05, self.SteppedDirMaxZ ) -- dont call heli upwards
        randDir:Normalize()

        local offset = randDir * 20000

        -- if EVERY direction is trigger pushed, just go ahead and ignore them
        local doHitPushCheck = not self.triggerPushHits or self.triggerPushHits < 25
        if doHitPushCheck and rayHitsTriggerPush( myPos, offset ) then
            self.triggerPushHits = ( self.triggerPushHits or 0 ) + 1
            return

        end

        local currMins = math.random( wayfindingHeliMins, callingHeliMins )
        local currMaxs = math.random( wayfindingHeliMaxs, callingHeliMaxs )

        local myPosOffsetted = myPos + randDir * math.random( 25, callingHeliMaxs )

        local traceData = {
            start = myPosOffsetted,
            endpos = myPos + offset,
            mask = MASK_NPCSOLID_BRUSHONLY,
            mins = Vector( currMins, currMins, currMins / 4 ),
            maxs = Vector( currMaxs, currMaxs, currMaxs / 4 ),

        }
        local callTraceResult = util.TraceHull( traceData )

        local boxColor = Color( 0, 255, 0, 100 )
        if callTraceResult.HitSky then
            boxColor = Color( 0, 255, 0, 255 )

        end

        if debugging:GetBool() then
            debugoverlay.SweptBox(
                traceData.start,
                callTraceResult.HitPos,
                traceData.mins,
                traceData.maxs,
                Angle( 0, 0, 0 ),
                5,
                boxColor
            )

        end

        if callTraceResult.HitPos:Distance( myPos ) < self.SteppedTooCloseDist then -- too close!
            self.SteppedTooCloseDist = math.max( self.SteppedTooCloseDist - 250, self.MinTooCloseDist )
            self.SteppedDirMaxZ = math.Clamp( self.SteppedDirMaxZ + 0.05, 0, self.MaxDirMaxZ )
            return

        end

        if not callTraceResult.HitSky then return end

        angerEverything()
        self.calledForHeli = true

        local heliSpawnDelay = 70
        if not GAMEMODE.IsReallyHuntersGlee then
            heliSpawnDelay = 30

        end
        local diffBump

        local spawnPos = callTraceResult.HitPos
        local goalPos = myPos

        local firstWait = 3
        local secondWait = 10

        local shooter = self.MyOwner

        timer.Create( rescueTimerName, 1, heliSpawnDelay, function()
            local repsLeft = timer.RepsLeft( rescueTimerName )
            if repsLeft == heliSpawnDelay - firstWait then
                local name
                if shooter.Nick and isstring( shooter:Nick() ) then
                    name = shooter:Nick()

                else
                    name = GAMEMODE:GetNameOfBot( shooter )

                end
                huntersGlee_AnnounceDramatic( player.GetAll(), 500, secondWait - firstWait, name .. "\nHAS CALLED FOR RESCUE!" )
                if GAMEMODE.IsReallyHuntersGlee then
                    GAMEMODE:SendSolidSound( GAMEMODE:GetASoundTrack( "heliEvac" ) )
                    local _, spawnSet = GAMEMODE:GetSpawnSet()
                    diffBump = spawnSet.diffBumpWhenWaveKilled / 2
                    GAMEMODE:BumpRoundDifficulty( diffBump ) -- send the spawner into overdrive
                    angerEverything()

                end
            end

            if repsLeft == heliSpawnDelay - secondWait then
                huntersGlee_AnnounceDramatic( player.GetAll(), 501, 10, "Rescue, entering the map in T-" .. heliSpawnDelay - secondWait .. " seconds..." )

                if not diffBump then return end
                GAMEMODE:BumpRoundDifficulty( diffBump ) -- send the spawner into overdrive
                angerEverything()

            end
            if repsLeft == 10 then
                huntersGlee_Announce( player.GetAll(), 100, 5, "T-10 seconds till map entry..." )

                if not diffBump then return end
                GAMEMODE:BumpRoundDifficulty( diffBump )
                angerEverything()

            end
            if repsLeft == 0 then
                huntersGlee_AnnounceDramatic( player.GetAll(), 100, 10, "Rescue has entered the map..." )
                terminator_Extras.glee_SpawnTheRescueHeli( spawnPos, -randDir, goalPos )

                if not diffBump then return end
                GAMEMODE:BumpRoundDifficulty( diffBump )
                angerEverything()

            end
        end )

        hook.Add( "huntersglee_round_leave_limbo", "glee_cancelrescuehelitimer_limboend", function()
            if not timer.Exists( rescueTimerName ) then return end
            timer.Remove( rescueTimerName )

        end )

        hook.Add( "huntersglee_round_into_limbo", "glee_cancelrescuehelitimer_limboend", function()
            if not timer.Exists( rescueTimerName ) then return end
            timer.Remove( rescueTimerName )

        end )

        hook.Add( "glee_PostRealCleanupMap", "glee_cancelrescuehelitimer_cleanup", function()
            if not timer.Exists( rescueTimerName ) then return end
            timer.Remove( rescueTimerName )

        end )

    end

    local function makeHeliFriendlyWith( heli, thing )
        if not IsValid( heli ) then return end
        if not IsValid( thing ) then return end
        heli:AddEntityRelationship( thing, D_LI, 99 )

    end

    local function makeFeudWith( heli, thing )
        if not IsValid( heli ) then return end
        if not IsValid( thing ) then return end
        heli:AddEntityRelationship( thing, D_HT, 99 )
        if not thing.AddEntityRelationship then return end
        thing:AddEntityRelationship( heli, D_HT, 999 )

    end

    local function heliGetFreeSeat( heli )
        for i, seat in EntityPairs( heli.glee_Seats ) do
            if not IsValid( seat:GetDriver() ) then
                return seat, i
            end
        end
    end

    local function heliGetRiders( heli )
        local riders = {}
        for _, seat in EntityPairs( heli.glee_Seats ) do
            local driver = seat:GetDriver()
            if IsValid( driver ) then
                table.insert( riders, driver )

            end
        end
        return riders

    end

    local function heliAllSeatsFull( heli )
        for _, seat in EntityPairs( heli.glee_Seats ) do
            if not IsValid( seat:GetDriver() ) then
                return false

            end
        end
        return true

    end

    local function heliKillAllRiders( heli )
        for _, seat in EntityPairs( heli.glee_Seats ) do
            local driver = seat:GetDriver()
            if IsValid( driver ) then
                driver:Kill()

            end
        end
    end

    -- trimmed glide code 👀
    local function heliSpawnSeat( heli, offset, angle )
        local index = #heli.glee_Seats + 1

        local seat = ents.Create( "prop_vehicle_prisoner_pod" )

        if not IsValid( seat ) then
            heli:Remove()
            error( "Failed to spawn rescue helicopter seat!" )

            return
        end

        seat:SetModel( "models/nova/airboat_seat.mdl" )
        seat:SetPos( heli:LocalToWorld( offset or Vector() ) )
        seat:SetAngles( heli:LocalToWorldAngles( angle or Angle( 0, 270, 10 ) ) )
        seat:SetMoveType( MOVETYPE_NONE )
        seat:SetOwner( heli )
        seat:Spawn()
        seat:Activate()

        seat:SetKeyValue( "limitview", 0 )
        seat:SetNotSolid( true )
        seat:SetParent( heli )
        seat:DrawShadow( false )
        seat:PhysicsDestroy()
        seat:SetColor( invisCol )
        seat:SetRenderMode( RENDERMODE_TRANSALPHA )

        seat.PhysgunDisabled = true
        seat.DoNotDuplicate = true
        seat.DisableDuplicator = true

        heli:DeleteOnRemove( seat )

        heli.glee_Seats[index] = seat
        seat.isARescueHeliSeat = true

        return seat

    end

    local function manageHeliSpeedLimit( heli, idealMovePos, loveSkybox )
        local helisPos = heli:GetPos()
        local distToGoal = helisPos:Distance( idealMovePos )

        local newSpeed = math.Clamp( distToGoal * 1.5, heli_CloseToObstacleSpeedLimit, heli_SpeedLimit )

        local heliVel = heli:GetVelocity()
        local heliDir = heliVel:GetNormalized()
        local curSpeed = heliVel:Length()

        if curSpeed <= 150 then
            heliDir = heli:GetForward()

        end

        local range = math.min( distToGoal + 500, curSpeed * 4 )

        local blockedTrData = {
            start = helisPos,
            endpos = helisPos + heliDir * range,
            mask = MASK_SOLID_BRUSHONLY,
            mins = Vector( callingHeliMins, callingHeliMins, callingHeliMins / 4 ),
            maxs = Vector( callingHeliMaxs, callingHeliMaxs, callingHeliMaxs / 4 ),

        }
        local blockedTrResult = util.TraceHull( blockedTrData )

        if loveSkybox and blockedTrResult.HitSky then
            newSpeed = heli_SpeedLimit

        elseif blockedTrResult.Hit then
            newSpeed = heli_CloseToObstacleSpeedLimit

        end

        if debugging:GetBool() then
            debugoverlay.SweptBox(
                blockedTrData.start,
                blockedTrResult.HitPos,
                blockedTrData.mins,
                blockedTrData.maxs,
                Angle( 0, 0, 0 ),
                1,
                Color( 255, 0, 0 )
            )

        end

        heli:SetSaveValue( "m_flPathMaxSpeed", newSpeed )
        return newSpeed

    end

    local heli_TryAndRescueDuration = 120
    -- try and find people for 2 minutes
    -- afterwards we switch to flying towards any skybox we can find, or where we spawned

    function terminator_Extras.glee_SpawnTheRescueHeli( spawnPos, faceDir, targetPos )
        local heli = ents.Create( "npc_helicopter" )
        if not IsValid( heli ) then return end

        local track = ents.Create( "path_track" )
        if not IsValid( track ) then
            SafeRemoveEntity( heli )
            return

        end

        heli:SetPos( spawnPos )
        heli:SetAngles( faceDir:Angle() )

        -- fly towards valuable sounds when wandering
        terminator_Extras.RegisterListener( heli )
        function heli:SaveSoundHint( source, valuable, emitterEnt )
            if not valuable then return end
            if IsValid( emitterEnt ) and not emitterEnt:IsPlayer() then return end
            self.lastHeardSoundPos = source

        end


        local topSpeed = manageHeliSpeedLimit( heli, targetPos )
        if topSpeed >= heli_SpeedLimit * 0.5 then
            heli:Fire( "MoveTopSpeed", 1, 0.1 )

        end

        heli:Fire( "EnableDeadlyShooting", 1, 0.1 )

        track:SetPos( targetPos )

        heli.ourPathTrack = track
        track.glee_HeliTrack_TargetName = "glee_rescuehelipath_" .. heli:GetCreationID()
        track:SetKeyValue( "targetname", track.glee_HeliTrack_TargetName )

        heli.glee_HeliTrack_TargetName = track.glee_HeliTrack_TargetName

        heli.isGleeRescueHeli = true
        heli:SetNWBool( "isGleeRescueHeli", true )

        heli:Spawn()

        local mins, maxs = heli:GetCollisionBounds()

        heli:SetModel( heliModel )
        heli:SetCollisionBounds( mins, maxs )
        heli:Activate()

        heli.heli_Missiles = {}

        -- missile hardpoint support
        local mountingRight = terminator_Extras.AttachParentedDetail( heli, "models/props_trainstation/mount_connection001a.mdl", Vector( 44.5, -83.2, -17.8 ), Angle( 0, -89.9, 164 ) )
        if IsValid( mountingRight ) then
            local missileRight = ents.Create( "glee_helimissile" )
            missileRight:SetStartsInactive( true )
            missileRight:SetAttacker( heli )
            missileRight:SetInflictor( missileRight )
            missileRight:SetOwner( heli )
            terminator_Extras.AttachParentedDetail( heli, missileRight, Vector( 40.6, -106.3, -31.5 ), Angle( 16, 0, 90 ) )

            table.insert( heli.heli_Missiles, missileRight )

        end

        local mountingLeft = terminator_Extras.AttachParentedDetail( heli, "models/props_trainstation/mount_connection001a.mdl", Vector( 45, 83.2, -17.9 ), Angle( 0, 89.9, -164 ) )
        if IsValid( mountingLeft ) then
            local missileLeft = ents.Create( "glee_helimissile" )
            missileLeft:SetStartsInactive( true )
            missileLeft:SetAttacker( heli )
            missileLeft:SetInflictor( missileLeft )
            missileLeft:SetOwner( heli )
            terminator_Extras.AttachParentedDetail( heli, missileLeft, Vector( 40.7, 106.3, -31.4 ), Angle( 16, 0, -90 ) )

            table.insert( heli.heli_Missiles, missileLeft )

        end

        heli.nextMissileFire = 0

        for _, ply in player.Iterator() do
            makeHeliFriendlyWith( heli, ply )

        end

        heli:Fire( "SetTrack", track.glee_HeliTrack_TargetName )

        heli.giveUpAndRunAwayTime = CurTime() + heli_TryAndRescueDuration
        heli.rescueHeliArrivedFromPos = spawnPos
        heli.originalRescuePos = targetPos
        heli.currentHeliGoal = "rescue"
        heli.nextAngerEverything = CurTime() + 10

        heli.glee_Seats = {}

        heli.glee_PrettyName = "The Rescue Heli"

        for _, data in ipairs( heli_seatPositions ) do
            heliSpawnSeat( heli, data.pos, data.ang )

        end

        hook.Add( "PlayerUse", heli, function( self, ply, ent )
            if ent ~= self then return end

            if ply:KeyDown( IN_WALK ) then return end

            local nextInteract = ply.glee_nextHeliSeatInteract or 0
            if CurTime() < nextInteract then return end
            ply.glee_nextHeliSeatInteract = CurTime() + 1

            local freeSeat = heliGetFreeSeat( self )
            if freeSeat then
                ply:SetAllowWeaponsInVehicle( false )
                ply:EnterVehicle( freeSeat )

            end
        end )

        -- don't exit IMMEDIATELY after entering
        hook.Add( "CanExitVehicle", heli, function( self, vehicle, ply )
            if vehicle:GetParent() ~= self then return end

            local nextInteract = ply.glee_nextHeliSeatInteract or 0
            if CurTime() < nextInteract then return false end
            ply.glee_nextHeliSeatInteract = CurTime() + 1

        end )

        hook.Add( "PlayerLeaveVehicle", heli, function( self, ply, vehicle )
            if vehicle:GetParent() ~= self then return end
            ply.glee_nextHeliSeatInteract = CurTime() + 1

            timer.Simple( 0, function()
                if not IsValid( ply ) then return end
                if not IsValid( vehicle ) then return end
                if not ply.TeleportTo then return end
                local exitPos = vehicle:LocalToWorld( heli_ExitPos )
                ply:TeleportTo( exitPos )

            end )
        end )

        hook.Add( "OnPlayerRappelBoardVehicle", heli, function( self, ply, vehicle )
            if vehicle ~= self then return end

            if ply:KeyDown( IN_WALK ) then return end

            local freeSeat = heliGetFreeSeat( self )
            if freeSeat then
                ply:SetAllowWeaponsInVehicle( false )
                ply:EnterVehicle( freeSeat )

            end
        end )

        hook.Add( "OnNPCKilled", heli, function( self, npc )
            if npc ~= self then return end

            heliKillAllRiders( self )

        end )

        local timerName = "glee_rescuehelithink_" .. heli:GetCreationID()
        timer.Create( timerName, 1, 0, function()
            if not IsValid( heli ) then
                timer.Remove( timerName )
                return
            end

            ProtectedCall( terminator_Extras.glee_RescueHeliThink, heli )

        end )

        -- buff its damage when it decides to shoot
        local hookName = "glee_rescuehelishoot_" .. heli:GetCreationID()
        hook.Add( "EntityTakeDamage", hookName, function( _target, dmgInfo )
            if not IsValid( heli ) then
                hook.Remove( "EntityTakeDamage", hookName )
                return

            end
            local attacker = dmgInfo:GetAttacker()
            if attacker ~= heli then return end
            if not IsValid( attacker ) then return end

            dmgInfo:ScaleDamage( 10 )

        end )

        terminator_Extras.glee_CurrentRescueHeli = heli

        return heli

    end

    concommand.Add( "huntersglee_debug_spawnrescueheli", function( ply, cmd, args )
        if not ply:IsAdmin() then return end
        local spawnPos = ply:GetPos() + Vector( 0, 0, 50 )
        local faceDir = -ply:GetForward()
        local targetPos = spawnPos + faceDir * 500

        terminator_Extras.glee_SpawnTheRescueHeli( spawnPos, faceDir, targetPos )

    end )

    local function heliManageRope( self )
        local currGoal = self.currentHeliGoal
        local rapelling = IsValid( self.glee_RappelRopeStartProp )

        -- goal is to rescue, valid target too
        if currGoal == "rescue" and IsValid( self.currentRescueTarget ) then
            local nextRappelRope = self.glee_NextRappelRope or 0
            if not rapelling and CurTime() >= nextRappelRope then
                local distToRescue = self:GetPos():Distance( self.currentRescueTarget:GetPos() )
                if distToRescue < glee_RappelSettings.ropeDropFromVehicleLength then
                    self.glee_NextRappelRope = CurTime() + 5
                    DropRappelRopeFromVehicle( self, heli_RopeOriginOffset )

                end
            end
        -- lost our target, rescued everyone, basically time to leave
        elseif rapelling then
            RemoveRappelRopeFromVehicle( self )

        end
    end

    local function heliManageAngering( self )
        if CurTime() < self.nextAngerEverything then return end
        self.nextAngerEverything = CurTime() + 10

        angerEverything()

    end

    local function heliManageMissileAttacking( self, enemy )
        local nextFire = self.nextMissileFire
        if CurTime() < nextFire then return end

        if enemy:Health() <= 0 then return end

        local hostilesAroundEnemy = 0
        local friendliesAroundEnemy = 0
        for _, thing in ipairs( ents.FindInSphere( enemy:GetPos(), 1250 ) ) do
            if not ( thing:IsPlayer() or thing:IsNPC() or thing:IsNextBot() ) then continue end
            local dispToThing = self:Disposition( thing )
            if dispToThing == D_HT then
                hostilesAroundEnemy = hostilesAroundEnemy + 1

            elseif dispToThing == D_LI then
                friendliesAroundEnemy = friendliesAroundEnemy + 1

            end
        end

        if friendliesAroundEnemy > 1 then return end
        -- shoot if lots of enemies, or enemy is tanky
        local stronk = enemy:Health() > 1500 or enemy.ReallyHeavy
        if not stronk and hostilesAroundEnemy < 2 then return end

        local missiles = self.heli_Missiles
        if not missiles or #missiles == 0 then return end
        for _, missile in ipairs( missiles ) do
            if not IsValid( missile ) then continue end
            if not IsValid( missile:GetParent() ) then continue end
            if not terminator_Extras.PosCanSeeComplex( missile:GetPos(), enemy:GetPos(), { self, missile } ) then continue end

            local missilesPreUnparentedPos = missile:GetPos()
            missile:SetParent( NULL )
            missile:SetPos( missilesPreUnparentedPos )
            missile:SetCollisionGroup( COLLISION_GROUP_PROJECTILE )

            local dirToEnemy = terminator_Extras.dirToPos( missilesPreUnparentedPos, enemy:GetPos() )
            missile:SetAngles( dirToEnemy:Angle() )

            missile:MissileActivate()
            self.nextMissileFire = CurTime() + 15
            break

        end
    end

    local vecUp400 = Vector( 0, 0, 400 )
    local vecUp200 = Vector( 0, 0, 200 )

    function terminator_Extras.glee_RescueHeliThink( self )
        local rescueTarget = self.currentRescueTarget
        local myPos = self:GetPos()
        local ourVel = self:GetVelocity()
        local validRescueTarget = IsValid( rescueTarget ) and rescueTarget:Alive()
        local visibleRescueTarget = validRescueTarget and self:Visible( rescueTarget )
        local trySwitchRescueTarget = not validRescueTarget or not visibleRescueTarget
        local obscuredRescueTarget = validRescueTarget and not visibleRescueTarget and myPos:Distance( rescueTarget:GetPos() ) > 3500
        local rescuedRescueTarget = validRescueTarget and IsValid( rescueTarget:GetVehicle() ) and rescueTarget:GetVehicle():GetParent() == self
        local badRescueTarget = not validRescueTarget or obscuredRescueTarget or rescuedRescueTarget

        if validRescueTarget and visibleRescueTarget then
            self.lastSawARescueTargetPos = rescueTarget:GetPos()

        end
        if badRescueTarget then
            self.currentRescueTarget = nil
            rescueTarget = nil

        end
        if trySwitchRescueTarget then
            local closestDist = math.huge
            for _, ply in player.Iterator() do
                if not ply:Alive() then continue end
                local plysPos = ply:GetShootPos()
                local dist = myPos:Distance( plysPos )
                if dist > closestDist then continue end
                if not terminator_Extras.PosCanSeeComplex( myPos, plysPos, self ) then continue end
                if IsValid( ply:GetVehicle() ) and ply:GetVehicle():GetParent() == self then continue end

                rescueTarget = ply
                closestDist = dist

            end
            if IsValid( rescueTarget ) then
                self.currentRescueTarget = rescueTarget

            end
        end

        local currEnemy = self:GetEnemy()
        if IsValid( currEnemy ) then
            if currEnemy:IsPlayer() then
                makeHeliFriendlyWith( self, currEnemy )

            end
            if currEnemy.ReallyAnger and not currEnemy:IsAngry() then
                currEnemy:ReallyAnger( 30 )

            end

            makeFeudWith( self, currEnemy )

            local enemysPos = currEnemy:GetPos()

            local visibleEnem = self:Visible( currEnemy )
            local facingEnemy = self:GetForward():Dot( ( enemysPos - myPos ):GetNormalized() ) > 0.97

            if not visibleEnem then
                self:SetEnemy( NULL )

            elseif facingEnemy then
                heliManageMissileAttacking( self, currEnemy )

            end
        end

        local idealMovePos
        local skysTheLimit

        local currGoal = self.currentHeliGoal
        -- fly towards originalRescuePos
        -- then once we get close
        -- start flying to rescue target
        -- OR fly to where we last saw one
        -- OR fly to sound hint
        if currGoal == "rescue" then
            local allPlayersAreEscaping = true
            for _, ply in player.Iterator() do
                if not ply:Alive() then continue end
                if IsValid( ply:GetVehicle() ) and ply:GetVehicle():GetParent() == self then continue end
                allPlayersAreEscaping = false
                break

            end
            -- bail
            if CurTime() > self.giveUpAndRunAwayTime or allPlayersAreEscaping or heliAllSeatsFull( self ) then
                self.currentHeliTask = "rescue_switchToEscape"
                self.currentHeliGoal = "escape"

            elseif self.originalRescuePos then
                self.currentHeliTask = "rescue_flyToFlare"

                local distToOriginalRescuePos = myPos:Distance( self.originalRescuePos )
                if self:VisibleVec( self.originalRescuePos ) and distToOriginalRescuePos < 3000 then
                    self.originalRescuePos = nil

                elseif distToOriginalRescuePos < 1500 then
                    self.originalRescuePos = nil

                else
                    idealMovePos = self.originalRescuePos

                end

            elseif IsValid( rescueTarget ) and rescueTarget:GetNWEntity( "glee_RappelSourceEnt", NULL ) == self then
                self.currentHeliTask = "rescue_waitForRescueTargetToRappel"
                idealMovePos = myPos

            -- approach rescue target!
            elseif IsValid( rescueTarget ) then
                self.currentHeliTask = "rescue_approachRescueTarget"

                local rescueTargetsPos = rescueTarget:GetPos()
                local floorOfRescueTarget = terminator_Extras.getFloorTr( rescueTargetsPos ).HitPos
                idealMovePos = floorOfRescueTarget + vecUp400

                -- go way above them if they're on the ground, just a bit above if they're high up
                idealMovePos.z = math.max( idealMovePos.z, rescueTargetsPos.z + 200 )

            -- fly towards last place we saw a rescue target
            elseif self.lastSawARescueTargetPos then
                self.currentHeliTask = "rescue_approachLastSeenRescueTarget"

                local distToLastSaw = myPos:Distance( self.lastSawARescueTargetPos )
                if self:VisibleVec( self.lastSawARescueTargetPos ) and distToLastSaw < 1500 then
                    self.lastSawARescueTargetPos = nil

                elseif distToLastSaw < 800 then
                    self.lastSawARescueTargetPos = nil

                else
                    idealMovePos = self.lastSawARescueTargetPos + vecUp200 + VectorRand() * 200

                end
            -- go towards last sound hint
            elseif self.lastHeardSoundPos then
                self.currentHeliTask = "rescue_approachSoundHint"

                local distToHint = myPos:Distance( self.lastHeardSoundPos )
                if self:VisibleVec( self.lastHeardSoundPos ) and distToHint < 1500 then
                    self.lastHeardSoundPos = nil

                elseif distToHint < 800 then
                    self.lastHeardSoundPos = nil

                end
                idealMovePos = self.lastHeardSoundPos + vecUp200 + VectorRand() * 200

            -- just wander forward
            else
                self.currentHeliTask = "rescue_wanderForward"
                local curMoveDir = ourVel:GetNormalized()
                curMoveDir.z = math.Clamp( curMoveDir.z, -0.5, 0.5 ) -- dont go upwards too much when wandering
                curMoveDir.z = curMoveDir.z * 0.5
                curMoveDir:Normalize()
                local forOffset = curMoveDir * 2000
                local randOffset = VectorRand() * 150
                idealMovePos = myPos + forOffset + randOffset

            end
        -- fly towards any skybox surfaces next to us
        -- if no skybox surfaces, fly towards where we spawned
        elseif currGoal == "escape" then
            local nearestSkyboxPos = self.nearestSkyboxPos
            local attempts = 10
            local trStruc = {
                start = myPos,
                endpos = nil,
                mask = MASK_SOLID_BRUSHONLY,
                mins = Vector( callingHeliMins, callingHeliMins, callingHeliMins / 4 ),
                maxs = Vector( callingHeliMaxs, callingHeliMaxs, callingHeliMaxs / 4 ),

            }
            for _ = 1, attempts do
                local offset = VectorRand()
                offset.z = math.Rand( -0.25, 0.25 ) -- dont look upwards
                offset = offset * 40000
                trStruc.endpos = myPos + offset

                local trResult = util.TraceHull( trStruc )
                if not trResult.HitSky then continue end

                local myDistToNew = myPos:Distance( trResult.HitPos )
                if rayHitsTriggerPush( myPos, offset ) then -- STRONGLY avoid trigger_push(es)
                    myDistToNew = myDistToNew * 10

                end

                if not nearestSkyboxPos or myDistToNew < myPos:Distance( nearestSkyboxPos ) then
                    if debugging:GetBool() then
                        debugoverlay.Line( myPos, trResult.HitPos, 1, Color( 255, 255, 0 ), true )

                    end
                    nearestSkyboxPos = trResult.HitPos
                    self.nearestSkyboxPos = nearestSkyboxPos

                end
            end
            if nearestSkyboxPos then
                self.currentHeliTask = "rescue_flyToBestSkybox"

                local dirToSkybox = ( nearestSkyboxPos - myPos ):GetNormalized()

                idealMovePos = nearestSkyboxPos + dirToSkybox * 2000
                skysTheLimit = true

                if myPos:Distance( nearestSkyboxPos ) < 450 then
                    hook.Run( "glee_rescueheliescape", self )
                    SafeRemoveEntityDelayed( self, 0.1 )

                end
            else
                self.currentHeliTask = "rescue_flyToWhereWeArrived"

                idealMovePos = self.rescueHeliArrivedFromPos

            end
        end

        heliManageRope( self )
        heliManageAngering( self )

        -- ideal movepos!
        -- we now find somewhere that will get us closer to the ideal movepos
        if idealMovePos then
            if debugging:GetBool() then
                debugoverlay.Sphere( idealMovePos, 25, 1, Color( 0, 255, 255 ), true )
                debugoverlay.Line( myPos, idealMovePos, 1, Color( 0, 255, 255 ), true )

            end

            local curSpeed = ourVel:Length()
            local distToIdeal = myPos:Distance( idealMovePos )
            local distance = math.min( curSpeed * 8, heli_SpeedLimit * 2, distToIdeal * 1.5 )
            local moveDir = ourVel:GetNormalized()
            local dirToIdeal = ( idealMovePos - myPos ):GetNormalized()
            local trCheckDir = ( moveDir * 0.5 ) + ( dirToIdeal * 0.5 )

            local mins = wayfindingHeliMins
            local maxs = wayfindingHeliMaxs
            if curSpeed <= heli_CloseToObstacleSpeedLimit then
                mins = slowMovingHeliMins
                maxs = slowMovingHeliMaxs

            end

            local traceDataMove = {
                start = myPos,
                endpos = nil,
                mask = MASK_SOLID_BRUSHONLY,
                mins = Vector( mins, mins, mins ),
                maxs = Vector( maxs, maxs, maxs ),

            }
            local function getPenaltyForPos( pos, traceResult, rayCheck )
                local penalty = pos:Distance( idealMovePos )

                local floorTr = terminator_Extras.getFloorTr( pos )
                local floorDist = floorTr.HitPos:Distance( pos )
                if traceResult and rayHitsTriggerPush( myPos, rayCheck ) then
                    penalty = penalty * 10

                end

                if floorDist > heli_TooFarFromGround then
                    penalty = penalty + floorDist * 0.25 -- the higher this is? the worse the penalty

                elseif floorDist < heli_TooCloseToGround then
                    penalty = penalty * 1.5

                end
                if traceResult and skysTheLimit and traceResult.HitSky then
                    penalty = penalty * 0.9

                elseif traceResult and traceResult.Hit then
                    penalty = penalty * 4

                end
                return penalty

            end

            local count = 30
            local results = {}
            local lastBest = self.heli_lastBestPos
            if lastBest then
                local penalty = getPenaltyForPos( lastBest, nil, idealMovePos - myPos )
                if self.heli_lastBestPosPenalty then
                    penalty = math.max( penalty, self.heli_lastBestPosPenalty )

                end
                results[penalty * 1.15] = lastBest

            end
            local oneWasClear

            for i = 1, count do
                local currDist = distance
                if i > 2 then
                    currDist = currDist * math.Rand( 0.75, 1.25 )

                else
                    currDist = currDist * 1.25

                end

                -- bigger angle checks the further into the loop we are
                local integral = i / count

                -- if we're going slow, way less velocity bias
                if i > 2 and curSpeed < 500 then
                    integral = 2

                end
                local offset = VectorRand()
                offset:Mul( integral )

                local offsetedDir = trCheckDir + offset
                offsetedDir:Normalize()

                traceDataMove.endpos = myPos + offsetedDir * currDist
                local traceResult = util.TraceHull( traceDataMove )

                -- dont add this if it's starting in a wall
                if traceResult.StartSolid then continue end
                oneWasClear = true

                local penalty = getPenaltyForPos( traceResult.HitPos, traceResult, offsetedDir * currDist )

                if debugging:GetBool() then
                    debugoverlay.Line( myPos, traceResult.HitPos, 0.5, Color( 255, 0, 0 ), true )

                end

                results[penalty] = traceResult.HitPos

            end

            local bestPos = nil

            if not oneWasClear and self:VisibleVec( idealMovePos ) and distToIdeal < 500 then
                bestPos = idealMovePos
                self.heli_lastBestPos = nil
                self.heli_lastBestPosPenalty = nil

            -- stuck!
            elseif not oneWasClear then
                -- is there somewhere next to us we can go to?
                for _ = 1, 25 do
                    local dir = VectorRand()
                    local offfsettedPos1 = myPos + dir * 200
                    if not util.IsInWorld( offfsettedPos1 ) then continue end
                    local offfsettedPos2 = myPos + dir * 400
                    if not util.IsInWorld( offfsettedPos2 ) then continue end

                    bestPos = offfsettedPos2

                    self.heli_lastBestPos = nil
                    self.heli_lastBestPosPenalty = nil
                    break

                end

                -- are we smashing into a wall?
                local collisionCheckTrace = util.TraceHull( {
                    start = myPos,
                    endpos = bestPos,
                    mask = MASK_SOLID_BRUSHONLY,
                    mins = self:OBBMins() * 1.05,
                    maxs = self:OBBMaxs() * 1.05,

                } )
                -- dont explode if we're crashing into what we want to hit
                local goodHit = collisionCheckTrace.HitSky and skysTheLimit

                local colliding = collisionCheckTrace.Hit and not goodHit
                local trySoftUnstuckOffset
                if bestPos then
                    trySoftUnstuckOffset = terminator_Extras.dirToPos( myPos, bestPos ) * 15

                end
                -- we're smashing into a wall!!!
                -- try just nudging us out a bit
                if colliding and curSpeed < 250 and bestPos and terminator_Extras.PosCanSee( myPos, myPos + trySoftUnstuckOffset ) then
                    self:SetPos( myPos + trySoftUnstuckOffset )

                -- too fast or too stuck? taking damage time
                elseif colliding then
                    local damageInfo = DamageInfo()
                    damageInfo:SetDamage( 100 )
                    damageInfo:SetDamageType( DMG_BLAST )
                    damageInfo:SetAttacker( self )
                    damageInfo:SetInflictor( self )
                    damageInfo:SetDamagePosition( collisionCheckTrace.HitPos )
                    self:TakeDamageInfo( damageInfo )

                end
            -- not stuck, find best result
            else
                local smallestPenalty = math.huge
                for penalty, pos in pairs( results ) do
                    if penalty > smallestPenalty then continue end
                    smallestPenalty = penalty
                    bestPos = pos

                end

                self.heli_lastBestPos = bestPos
                self.heli_lastBestPosPenalty = smallestPenalty

            end

            -- bestPos is sometimes nil
            if bestPos then
                SafeRemoveEntityDelayed( self.ourPathTrack, 0.1 )
                local newTrack = ents.Create( "path_track" )
                newTrack:SetPos( bestPos )
                newTrack:SetKeyValue( "targetname", self.glee_HeliTrack_TargetName )
                self.ourPathTrack = newTrack
                self:Fire( "SetTrack", self.glee_HeliTrack_TargetName )

                if debugging:GetBool() then
                    debugoverlay.Line( myPos, bestPos, 1, Color( 0, 255, 0 ), true )

                end
            end

            manageHeliSpeedLimit( self, idealMovePos, skysTheLimit )

        end
    end

    --terminator_Extras.glee_SpawnTheRescueHeli( Entity(1):GetPos(), VectorRand(), Entity(1):GetEyeTrace().HitPos )
end

if not CLIENT then return end

local lifetime = 20

local signalFlaresThatPierceFog = {}

local bigFlareMatId = surface.GetTextureID( "effects/strider_bulge_dudv_dx60" )
local flareColorBig = Color( 255, 255, 255, 255 )
local smallFlareMatId = surface.GetTextureID( "effects/huntermuzzle" )
local flareColorSmall = Color( 150, 150, 255, 255 )

hook.Add( "RenderScreenspaceEffects", "glee_predraw_fogpiercing_signalflares", function()

    if not next( signalFlaresThatPierceFog ) then return end

    local me = LocalPlayer()
    local eyePos = EyePos()

    for _, flare in pairs( signalFlaresThatPierceFog ) do
        local sizeMul = 400

        local flaresRealPos = flare:WorldSpaceCenter()
        local pos2d = flaresRealPos:ToScreen()

        if not pos2d.visible then continue end

        local distanceToIt = eyePos:Distance( flaresRealPos )
        if distanceToIt < 450 then
            sizeMul = sizeMul * 2

        end

        local canSee = terminator_Extras.PosCanSeeComplex( eyePos, flaresRealPos, me )
        if not canSee then continue end

        -- magic num
        local distBite = math.log( distanceToIt, 4 ) * 5

        local timeToDeath = math.abs( flare:GetDeathTime() - CurTime() )
        local size = math.Clamp( timeToDeath / lifetime, 0, 1 )
        size = size * sizeMul

        local width = size + -distBite
        local height = size + -distBite

        local bigJitter = width * 0.05
        local bigJitterx = math.Rand( -bigJitter, bigJitter )
        local bigJittery = math.Rand( -bigJitter, bigJitter )
        local halfWidth = width / 2

        -- draw big dim one
        local bigStruc = {
            texture = bigFlareMatId,
            color   = flareColorBig,
            x 	= pos2d.x + -halfWidth + bigJitterx,
            y 	= pos2d.y + -halfWidth + bigJittery,
            w 	= width,
            h 	= height
        }

        draw.TexturedQuad( bigStruc )

        -- draw small bright one

        local smallWidth = width / 6
        local smallJitter = smallWidth * 0.05
        local smallJitterx = math.Rand( -smallJitter, smallJitter )
        local smallJittery = math.Rand( -smallJitter, smallJitter )
        local smallWidthHalf = smallWidth / 2

        local smallStruc = {
            texture = smallFlareMatId,
            color = flareColorSmall,
            x = pos2d.x + -smallWidthHalf + smallJitterx / 2,
            y = pos2d.y + -smallWidthHalf + smallJittery / 2,
            w = smallWidth,
            h = smallWidth
        }

        draw.TexturedQuad( smallStruc )

    end
end )

function ENT:Think()
    local myId = self:GetCreationID()

    if not signalFlaresThatPierceFog[myId] then
        signalFlaresThatPierceFog[myId] = self

    end
end

function ENT:OnRemove()
    signalFlaresThatPierceFog[self:GetCreationID()] = nil

end

-- rescue heli spotlight
-- from Dynamic Combine Flashlights by Zelektra
-- been optimized to hell and back
local nextBlinkToggle = 0
local blinkInterval = 0.5
local flashlightSprite = Material( "engine/lightsprite" )
local warningLightSprite = Material( "effects/blueflare1" )
local flashlightMaterial = Material( "glee/FlashlightBeam" )

local function CreateProjectedTextureForHelicopter( helicopter )
    if not IsValid( helicopter ) then return end

    if not helicopter.ProjectedTexture then
        helicopter.ProjectedTexture = ProjectedTexture()

    end

    local attachmentIndex = helicopter:LookupAttachment( "Spotlight" )

    if attachmentIndex then
        local attachment = helicopter:GetAttachment( attachmentIndex )
        if attachment then
            helicopter.ProjectedTexture:SetPos( attachment.Pos )
            helicopter.ProjectedTexture:SetAngles( attachment.Ang )

        else
            helicopter.ProjectedTexture:SetPos( helicopter:GetPos() )
            helicopter.ProjectedTexture:SetAngles( helicopter:GetAngles() )

        end
    else
        -- Fallback to helicopter position if attachment is not valid
        helicopter.ProjectedTexture:SetPos( helicopter:GetPos() )
        helicopter.ProjectedTexture:SetAngles( helicopter:GetAngles() )

    end

    helicopter.ProjectedTexture:SetNearZ( 200 )
    helicopter.ProjectedTexture:SetFarZ( 5000 ) -- Increased range for helicopters
    helicopter.ProjectedTexture:SetFOV( 40 )
    helicopter.ProjectedTexture:SetBrightness( 1 )
    helicopter.ProjectedTexture:SetTexture( "effects/spotlight" )
    helicopter.ProjectedTexture:Update()

end

local function RemoveProjectedTextureForHelicopter( helicopter )
    if not helicopter.ProjectedTexture then return end
    helicopter.ProjectedTexture:Remove()
    helicopter.ProjectedTexture = nil

end

local function DrawHelicopterBeams( npc, bDepth, bSkybox )
    if bSkybox then return end
    if bDepth then return end

    local spotlightOn = npc.spotlightOn
    if spotlightOn then

        -- Get the muzzle attachment
        local attachmentIndex = npc:LookupAttachment( "Spotlight" )
        if attachmentIndex == 0 then return end

        local attachment = npc:GetAttachment( attachmentIndex )
        if not attachment then return end

        local attachmentsForward = attachment.Ang:Forward()
        local startPos = attachment.Pos + ( attachmentsForward * 5 ) - ( attachment.Ang:Up() * 4 )
        local endPos = startPos + attachmentsForward * 2000

        -- Calculate dot product for scaling and visibility
        local dir = attachment.Ang:Forward() * -1
        local viewDir = ( startPos - EyePos() ):GetNormalized()
        local dotProduct = dir:Dot( viewDir )
        dotProduct = math.Clamp( dotProduct, 0, 1 ) -- Clamp to avoid very small or very large sizes

        local flaslightSpriteCheckResult = util.TraceLine( {
            start = EyePos(),
            endpos = startPos,
            filter = { npc, LocalPlayer() }
        } )

        if dotProduct > 0 and not flaslightSpriteCheckResult.Hit then -- Only draw for visible sprites
            local size = dotProduct * 400 -- Adjust base size multiplier as needed

            render.SetMaterial( flashlightSprite )
            render.DrawSprite( startPos, size, size, Color( 255, 255, 255, 255 * dotProduct ) )

        end

        local spotlightCheck = util.TraceLine( {
            start = startPos,
            endpos = endPos,
            filter = { npc },
            mask = MASK_OPAQUE
        } )

        render.SetMaterial( flashlightMaterial )
        render.DrawBeam( startPos, spotlightCheck.HitPos, 1000, 0, spotlightCheck.Fraction, Color( 255, 255, 255, ( 255 * 5 ) * ( 1 - dotProduct ) ) )

    end
    if blinkState == true then
        local attachmentIndexWarn1 = npc:LookupAttachment( "Light_Red0" )
        if attachmentIndexWarn1 == 0 then return end

        local attachmentWarn1 = npc:GetAttachment( attachmentIndexWarn1 )
        if not attachmentWarn1 then return end

        local startPosWarn = attachmentWarn1.Pos

        render.SetMaterial( warningLightSprite )
        render.DrawSprite( startPosWarn, 50, 50, Color( 255, 0, 0, 50 ) )

        local attachmentIndexWarn2 = npc:LookupAttachment( "Light_Red1" )
        if attachmentIndexWarn2 == 0 then return end

        local attachmentWarn2 = npc:GetAttachment( attachmentIndexWarn2 )
        if not attachmentWarn2 then return end

        local startPosWarn2 = attachmentWarn2.Pos

        render.DrawSprite( startPosWarn2, 50, 50, Color( 0, 255, 0, 50 ) )

        local attachmentIndexWarn3 = npc:LookupAttachment( "Light_Red2" )
        if attachmentIndexWarn3 == 0 then return end

        local attachmentWarn3 = npc:GetAttachment( attachmentIndexWarn3 )
        if not attachmentWarn3 then return end

        local startPosWarn3 = attachmentWarn3.Pos

        render.DrawSprite( startPosWarn3, 50, 50, Color( 255, 0, 0, 50 ) )

    end

    if CurTime() > nextBlinkToggle then
        nextBlinkToggle = CurTime() + blinkInterval
        if blinkState == false then
            blinkState = true

        else
            blinkState = false

        end
    end
end

local function CheckHelicopterLightLevel( helicopter )
    -- Check the light level around the helicopter.
    local lightLevel = render.ComputeLighting( helicopter:GetPos(), Vector( 0, 0, 1 ) ):Length()

    if lightLevel < 0.4 then
        CreateProjectedTextureForHelicopter( helicopter )
        helicopter.spotlightOn = true

    else
        RemoveProjectedTextureForHelicopter( helicopter )
        helicopter.spotlightOn = false

    end
end

local activeRescueHeli = NULL

local function stopRescueHeliHooks()
    RemoveProjectedTextureForHelicopter( activeRescueHeli )
    hook.Remove( "PostDrawTranslucentRenderables", "DrawHelicopterBeams" )
    hook.Remove( "Think", "CheckHelicopterLightLevel" )
    activeRescueHeli = NULL

end

local function startRescueHeliHooks( heli )
    activeRescueHeli = heli

    hook.Add( "PostDrawTranslucentRenderables", "DrawHelicopterBeams", function( bDepth, bSkybox )
        if not IsValid( activeRescueHeli ) then
            stopRescueHeliHooks()
            return

        end
        DrawHelicopterBeams( activeRescueHeli, bDepth, bSkybox )

    end )

    hook.Add( "Think", "CheckHelicopterLightLevel", function()
        if not IsValid( activeRescueHeli ) then
            stopRescueHeliHooks()
            return
        end
        CheckHelicopterLightLevel( activeRescueHeli )

    end )
end

local entMeta = FindMetaTable( "Entity" )

hook.Add( "NetworkEntityCreated", "glee_detectRescueHeli", function( ent )
    if entMeta.GetClass( ent ) ~= "npc_helicopter" then return end
    timer.Simple( 1, function() -- NWVars dont get there instantly :(
        if not IsValid( ent ) then return end
        if not ent:GetNWBool( "isGleeRescueHeli" ) then return end
        startRescueHeliHooks( ent )

    end )
end )