
local GAMEMODE = GAMEMODE or GM

local playerMeta = FindMetaTable( "Player" )

local glee_ActiveRappelRopes = {}
local glee_ActiveRappelRopeCount = 0

function playerMeta:RappelTo( ent, hitPos )
    if not IsValid( self ) then return end
    if not self:Alive() then return end
    if self:GetNWBool( "glee_IsRappelling", false ) then return end

    local isWorld = ent and ent:IsWorld()
    if not IsValid( ent ) and not isWorld then return end

    local rappelRope = ents.Create( "keyframe_rope" )
    rappelRope:SetParent( self, 0 )
    rappelRope:SetPos( self:GetPos() )
    rappelRope:SetColor( Color( 150, 150, 150 ) )

    rappelRope:SetEntity( "StartEntity", self )
    rappelRope:SetEntity( "EndEntity", Entity( 0 ) )
    rappelRope:SetKeyValue( "Width", "1" )
    rappelRope:SetKeyValue( "Collide", "0" )
    rappelRope:SetKeyValue( "RopeMaterial", "cable/cable" )
    rappelRope:SetKeyValue( "EndOffset", tostring( hitPos ) )
    rappelRope:SetKeyValue( "EndBone", "0" )

    self.glee_RappelRope = rappelRope
    self:DeleteOnRemove( rappelRope )
    self:SetNWBool( "glee_IsRappelling", true )
    self:SetNWFloat( "glee_RappelRopeLength", self:GetPos():Distance( hitPos ) )

    self:EmitSound( glee_RappelSettings.ropeAttachSound )

    if isWorld then
        local world = Entity( 0 )
        self:SetNWEntity( "glee_RappelSourceEnt", world )
        self:SetNWVector( "glee_RappelSourceOffset", hitPos )

        hook.Run( "OnPlayerStartRappellingTo", self, world, rappelRope )

        return

    end

    local localOffset = ent:WorldToLocal( hitPos )
    self:SetNWEntity( "glee_RappelSourceEnt", ent )
    self:SetNWVector( "glee_RappelSourceOffset", localOffset )


    local rappelingToVehicle = ent:IsVehicle() or ent.glee_IsTechincallyAVehicle

    local timerName = "glee_rappel_updateropepos_" .. self:SteamID64() .. "_" .. ent:GetCreationID()
    timer.Remove( timerName )

    timer.Create( timerName, 0.01, 0, function()
        if not IsValid( self ) or not IsValid( ent ) or not IsValid( rappelRope ) then
            if IsValid( self ) then self:StopRapelling() end
            timer.Remove( timerName )
            return

        end

        rappelRope:SetKeyValue( "EndOffset", tostring( ent:LocalToWorld( localOffset ) ) )

        if rappelingToVehicle then
            local plysShoot = self:GetShootPos()
            local nearestPointOnVehicle = ent:NearestPoint( plysShoot )

            -- find actual distance to vehicle
            local tr = util.TraceLine( {
                start  = plysShoot,
                endpos = nearestPointOnVehicle,
                filter = self,

            } )
            if tr.Entity ~= ent then return end
            if plysShoot:Distance( tr.HitPos ) > glee_RappelSettings.boardDistance then return end

            hook.Run( "OnPlayerRappelBoardVehicle", self, ent )

        end
    end )

    ent:CallOnRemove( "glee_rappel_entitycleanup_" .. self:SteamID64() .. "_" .. ent:GetCreationID(), function()
        self:StopRapelling()
        timer.Remove( timerName )

    end )

    ent.glee_stuffRappellingOffMe = ent.glee_stuffRappellingOffMe or {}
    ent.glee_stuffRappellingOffMe[self] = true
    self.glee_RappelSourceEnt = ent

    hook.Run( "OnPlayerStartRappellingTo", self, ent, rappelRope )

end

function playerMeta:StopRapelling()
    if not self:GetNWBool( "glee_IsRappelling", false ) then return end

    if IsValid( self.glee_RappelRope ) then
        self.glee_RappelRope:Remove()

    end

    self.glee_RappelRope = nil

    local sourceEnt = self.glee_RappelSourceEnt
    if IsValid( sourceEnt ) and sourceEnt.glee_stuffRappellingOffMe then
        sourceEnt.glee_stuffRappellingOffMe[self] = nil
    end
    self.glee_RappelSourceEnt = nil

    self:SetNWEntity( "glee_RappelSourceEnt", nil )
    self:SetNWVector( "glee_RappelSourceOffset", nil )
    self:SetNWFloat( "glee_RappelRopeLength", nil )
    self:SetNWBool( "glee_IsRappelling", false )

    hook.Run( "OnPlayerStopRappelling", self )

end

function playerMeta:RappelToVehicle( vehicle, anchorPos )
    vehicle.glee_IsTechincallyAVehicle = true
    anchorPos = anchorPos or vehicle:GetPos()
    self:RappelTo( vehicle, anchorPos )

end

local startDownOffset = 25

-- Drops a rope from a vehicle that players can +USE to start ascending.
-- Spawns two props: an anchor following the vehicle and a dangling physics
-- weight connected by a rope constraint.
function DropRappelRopeFromVehicle( vehicle, posOffset )
    if not IsValid( vehicle ) then return end

    local ropeLength = glee_RappelSettings.ropeDropFromVehicleLength
    posOffset = posOffset or vehicle:GetUp() * startDownOffset
    local anchorPos = vehicle:LocalToWorld( posOffset )

    -- Start prop: invisible anchor that follows the vehicle
    local startProp = ents.Create( "prop_physics" )
    startProp:SetModel( "models/props_junk/popcan01a.mdl" )
    startProp:SetPos( anchorPos )
    startProp:SetNoDraw( true )
    startProp:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    startProp:Spawn()
    startProp:GetPhysicsObject():EnableMotion( false )

    -- End prop: physics weight that dangles on the rope
    local endProp = ents.Create( "prop_physics" )
    endProp:SetModel( "models/props_c17/TrapPropeller_Lever.mdl" )
    endProp:SetPos( anchorPos - Vector( 0, 0, 10 ) )
    endProp:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    endProp:Spawn()

    local endPropsObj = endProp:GetPhysicsObject()
    if IsValid( endPropsObj ) then
        endPropsObj:SetMass( 100 )
        endPropsObj:SetDragCoefficient( 0 )

    end

    -- the rope
    local _ropeConstraint, _ropeVisual = constraint.Rope(
        startProp, endProp,
        0, 0,
        Vector( 0, 0, 0 ), Vector( 0, 5, 0 ),
        ropeLength, 0, 0, 1,
        "cable/cable", false
    )

    -- Mark dangling end prop with rappel data for FindUseEntity detection
    endProp.IsRappelDanglingProp = true
    endProp.RappelVehicle = vehicle
    endProp.RopeStartProp = startProp
    glee_ActiveRappelRopes[endProp] = true
    glee_ActiveRappelRopeCount = glee_ActiveRappelRopeCount + 1
    endProp:CallOnRemove( "glee_Rappel_DecrementRopeCount", function()
        glee_ActiveRappelRopeCount = glee_ActiveRappelRopeCount - 1
        glee_ActiveRappelRopes[endProp] = nil

    end )

    vehicle.glee_RappelDropSound = CreateSound( vehicle, glee_RappelSettings.ropeDropSound )
    vehicle.glee_RappelDropSound:PlayEx( 1, math.random( 90, 110 ) )
    timer.Simple( 2, function()
        if not IsValid( vehicle ) then return end
        if not vehicle.glee_RappelDropSound then return end
        vehicle.glee_RappelDropSound:FadeOut( 1 )

    end )

    local timerName = "glee_Rappel_VehicleRopeDropMaintain" .. vehicle:GetCreationID()

    local function cleanup()
        if IsValid( startProp ) then startProp:Remove() end
        if IsValid( endProp ) then endProp:Remove() end
        if IsValid( vehicle ) then
            if vehicle.glee_RappelDropSound then
                vehicle.glee_RappelDropSound:Stop()
                vehicle.glee_RappelDropSound = nil

            end
            vehicle.glee_RappelRopeCleanup = nil

        end
        timer.Remove( timerName )

    end

    endProp.RopeCleanup = cleanup
    vehicle.glee_RappelRopeCleanup = cleanup

    vehicle.glee_RappelRopeStartProp = startProp

    -- stick the start/end props to the ents!
    timer.Create( timerName, 0.01, 0, function()
        if not IsValid( vehicle ) or not IsValid( startProp ) then
            cleanup()
            return

        end

        -- Keep start prop anchored to vehicle
        local newAnchorPos = vehicle:LocalToWorld( posOffset )
        startProp:SetPos( newAnchorPos )

        local phys = startProp:GetPhysicsObject()
        if IsValid( phys ) then
            phys:SetPos( newAnchorPos )
            phys:SetVelocity( Vector( 0, 0, 0 ) )

        end

        if IsValid( endPropsObj ) then -- dampen swinging
            local oldVel = endPropsObj:GetVelocity()
            local dampenedVel = oldVel * 0.98
            endPropsObj:SetVelocity( dampenedVel )

        end
    end )

    vehicle:CallOnRemove( "glee_Rappel_CleanupDroppedRappelRope" .. vehicle:GetCreationID(), function()
        cleanup()

    end )

    hook.Run( "OnVehicleDroppedRope", vehicle, startProp )

    return startProp, endProp

end

-- find rappel rope when player tries to use something nearby
hook.Add( "FindUseEntity", "glee_Rappel_FindRappelRope", function( ply, _defaultEnt )
    if glee_ActiveRappelRopeCount == 0 then return end
    if ply:GetNWBool( "glee_IsRappelling", false ) then return end

    local plysShoot = ply:GetShootPos()

    for danglingProp in pairs( glee_ActiveRappelRopes ) do
        if not IsValid( danglingProp ) then
            glee_ActiveRappelRopes[danglingProp] = nil
            continue

        end

        local anchorProp = danglingProp.RopeStartProp
        if not IsValid( anchorProp ) then continue end

        local dist = util.DistanceToLine( anchorProp:GetPos(), danglingProp:GetPos(), plysShoot )
        if dist <= glee_RappelSettings.ropeUseAimTolerance then
            return danglingProp

        end
    end
end )

-- handle players +USEing the rappel rope
hook.Add( "PlayerUse", "glee_Rappel_DetectRappelUse", function( user, ent )
    if glee_ActiveRappelRopeCount == 0 then return end
    if not ent.IsRappelDanglingProp then return end
    if not user:IsPlayer() then return end

    local vehicle = ent.RappelVehicle
    local anchorProp = ent.RopeStartProp

    if not IsValid( vehicle ) or not IsValid( anchorProp ) then return end
    if user:GetNWBool( "glee_IsRappelling", false ) then return end

    if hook.Run( "PlayerBlockRappel", user, ent ) then return end

    user:RappelToVehicle( vehicle, anchorProp:GetPos() )

    if ent.RopeCleanup then ent.RopeCleanup() end

    return false

end )

function RemoveRappelRopeFromVehicle( vehicle )
    if not IsValid( vehicle ) then return end
    if not vehicle.glee_RappelRopeCleanup then return end

    vehicle.glee_RappelRopeCleanup()

    hook.Run( "OnVehicleRemovedRope", vehicle )

end


hook.Add( "PlayerNoClip", "glee_Rappel_RemoveOnNoclip", function( ply, state )
    if not state then return end

    ply:StopRapelling()

end )

hook.Add( "PostPlayerDeath", "glee_Rappel_RemoveOnDeath", function( ply )
    ply:StopRapelling()

end )

hook.Add( "PlayerEnteredVehicle", "glee_Rappel_RemoveOnEnterVehicle", function( ply, _veh, _role )
    ply:StopRapelling()

end )

hook.Add( "PlayerDisconnected", "glee_Rappel_RemoveOnDisconnect", function( ply )
    ply:StopRapelling()

end )

hook.Add( "OnNPCKilled", "glee_Rappel_CleanupOnNPCKilled", function( npc, attacker, _entity )
    if not IsValid( attacker ) or not attacker:IsPlayer() then return end

    local rappelEnt = attacker:GetNWEntity( "glee_RappelSourceEnt" )
    if not IsValid( rappelEnt ) then return end
    if rappelEnt ~= npc then return end

    attacker:StopRapelling()

end )


hook.Add( "PlayerBlockRappel", "glee_Rappel_Ratelimit", function( ply, rappelUseEnt )
    if not IsValid( ply ) then return true end
    if not IsValid( rappelUseEnt ) then return true end

    local last = ply.glee_LastStopRappeling or 0
    if last + 1 > CurTime() then
        return true

    end
end )

hook.Add( "OnPlayerStopRappelling", "glee_Rappel_RecordStopTime", function( ply )
    ply.glee_LastStopRappeling = CurTime()

end )