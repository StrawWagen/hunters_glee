AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Skull Pickup"
ENT.Author      = "StrawWagen"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

local IsValid = IsValid

ENT.TriggerBoundsNormal = 12
-- bigger when on a ragdoll to give players a strong hint about skulls in bodies
ENT.TriggerBoundsRagdoll = 56

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", 0, "IsTerminatorSkull" )

end
if SERVER then
    resource.AddFile( "materials/models/gibs/termskull.vmt" )
    resource.AddFile( "sound/hunters_glee/bones/skullcrush.wav" )
    resource.AddFile( "sound/hunters_glee/bones/break4.wav" )

end
util.PrecacheModel( "models/Gibs/HGIBS.mdl" )

--sandbox support
function ENT:SpawnFunction( ply, tr, ClassName )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 16

    local ent = ents.Create( ClassName )
    ent:SetPos( SpawnPos )
    ent:Spawn()

    -- sandbox support for ragdoll skulling, see modules/sv_skullmanager for how it happens in glee 
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        local stuff = ents.FindInSphere( tr.HitPos, 250 )
        for _, thing in ipairs( stuff ) do
            ent:AttachToRagdollsSkull( thing )

        end
    end )

    return ent

end

local farEnoughToNeverNotice = 1750^2

function ENT:Initialize()
    if SERVER then
        self.nextAmbientSkullSound = CurTime() + 5
        self.nextFreezingThink = CurTime() + 5
        self.DoNotDuplicate = true
        self.nextPickup = 0
        self.nextCrushRoll = 0

        self:SetModel( "models/Gibs/HGIBS.mdl" )

        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

        -- Wake up our physics object so we don't start asleep
        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:SetMass( 25 )
            phys:Wake()

            self:SetTrigger( true )
            self:UseTriggerBounds( true, self.TriggerBoundsNormal )

            if self:GetIsTerminatorSkull() then
                self:SetMaterial( "models/gibs/termskull" )
                phys:SetMaterial( "metal" )
                phys:SetBuoyancyRatio( 0 )

            else
                phys:SetMaterial( "Watermelon" )

            end
        end

        -- allow skulls to have different hints if players see them spawn
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            -- not from a just-dead term/player!
            if not self.fromSomethingWitnessable then return end
            self:UpdateExplainability()
        end )

        terminator_Extras.SmartSleepEntity( self, 10 )

        self:NextThink( CurTime() + 5 )

    end
end

function ENT:Think()
    if not SERVER then return end
    if self.nextAmbientSkullSound < CurTime() and not self:GetIsTerminatorSkull() then
        self.nextAmbientSkullSound = CurTime() + math.Rand( 2, 5 )
        -- make it easier to find skulls, dont be as obvious as scoreballs tho
        self:EmitSound( "d1_town.Flies" )

    end
    self:NextThink( CurTime() + 2 )
    return true

end

function ENT:CanHintPly( ply )
    if not self.plysThatKnowOurOrigin then return true end
    if self.plysThatKnowOurOrigin[ply:GetCreationID()] then return end

    return true

end

function ENT:GetScore()
    if self:GetIsTerminatorSkull() then return 2 end
    return 1

end

function ENT:DoScore( reciever )
    if not reciever:IsPlayer() then return end
    if reciever:Health() <= 0 then return end

    local parent = self:GetParent()
    if IsValid( parent ) then return end

    local blockPickup = hook.Run( "glee_blockskullpickup", reciever, self )
    if blockPickup == true then return end

    if self.skullUsed then return end
    self.skullUsed = true

    reciever:EmitSound( "npc/antlion/shell_impact4.wav", 72, 80 )

    if self:GetIsTerminatorSkull() then
        reciever:EmitSound( "physics/metal/metal_canister_impact_hard2.wav", 72, math.random( 110, 120 ) )
        util.ScreenShake( self:GetPos(), 5, 20, 0.75, 500 )

    else
        reciever:EmitSound( "physics/cardboard/cardboard_cup_impact_hard2.wav", 72, math.random( 75, 85 ) )
        util.ScreenShake( self:GetPos(), 1, 20, 0.5, 500 )

    end

    if not reciever.GivePlayerScore then SafeRemoveEntity( self ) return end

    reciever:GivePlayerSkulls( self:GetScore() )
    hook.Run( "glee_plypickedupskull", reciever, self )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        SafeRemoveEntity( self )

    end )

    if self.obviousOrigin then return end
    if self:GetIsTerminatorSkull() then
        if not reciever.glee_terminatorskullhint then
            reciever.glee_terminatorskullhint = true
            if self:CanHintPly( reciever ) then
                huntersGlee_Announce( { reciever }, 10, 10, "You found a metal skull.\nMust have been quite a fight to bring one of those down..." )

            else
                huntersGlee_Announce( { reciever }, 10, 10, "It's skull...\nSolid metal." )

            end
        end
    elseif not reciever.glee_selfskullhinted and self.skullSteamId and self.skullSteamId == reciever:SteamID64() then
        reciever.glee_selfskullhinted = true
        reciever.glee_skullhinted = true
        huntersGlee_Announce( { reciever }, 10, 10, "My skull...\nWhy did I come back here?" )
        GAMEMODE:GivePanic( purchaser, 80 )

    elseif not reciever.glee_skullhinted and self:CanHintPly( reciever ) then
        reciever.glee_skullhinted = true
        huntersGlee_Announce( { reciever }, 10, 10, "You found a skull.\nSomeone must have died here..." )
        GAMEMODE:GivePanic( purchaser, 40 )

    elseif not reciever.glee_skullhinted then
        reciever.glee_skullhinted = true
        if self.skullSteamId then
            huntersGlee_Announce( { reciever }, 10, 10, "That's their skull..." )
            GAMEMODE:GivePanic( purchaser, 60 )

        else
            huntersGlee_Announce( { reciever }, 10, 10, "That's it's skull..." )
            GAMEMODE:GivePanic( purchaser, 50 )

        end
    end
end

local closeEnoughToStepOn = 10^2

function ENT:Touch( touched )

    if self.nextPickup > CurTime() then return end

    if not IsValid( self:GetParent() ) then
        self:DoScore( touched )

    elseif touched:IsPlayer() and touched.glee_skullhinted and not touched.glee_skullInBodyHint then
        touched.glee_skullInBodyHint = true
        huntersGlee_Announce( { touched }, 11, 10, "A body...\nWith a skull...?" )

    end

    if self:GetIsTerminatorSkull() then return end
    -- just like in tha movie goyss!!!!
    if touched.isTerminatorHunterChummy and touched.ReallyHeavy and touched:GetPos():DistToSqr( self:WorldSpaceCenter() ) < closeEnoughToStepOn then
        if self.nextCrushRoll > CurTime() then return end
        self.nextCrushRoll = CurTime() + 10
        if math.random( 1, 100 ) < 75 then return end
        self:Crumble()

    end
end

function ENT:UpdateExplainability()
    self.plysThatKnowOurOrigin = nil
    local myPos = self:GetPos()
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() <= 0 then continue end
        if ply:GetPos():DistToSqr( myPos ) > farEnoughToNeverNotice then continue end
        if not ply:TestPVS( self ) then continue end
        if not terminator_Extras.PosCanSee( self:WorldSpaceCenter(), ply:GetShootPos(), MASK_SOLID_BRUSHONLY ) then continue end
        local plysThatKnowOurOrigin = self.plysThatKnowOurOrigin or {}

        plysThatKnowOurOrigin[ply:GetCreationID()] = true
        self.plysThatKnowOurOrigin = plysThatKnowOurOrigin

    end
end

function ENT:Crumble()
    if IsValid( self:GetParent() ) then
        self:Decapitate()

    end
    self:EmitSound( "hunters_glee/bones/skullcrush.wav", 76, 80 )

    util.ScreenShake( self:GetPos(), 0.2, 20, 0.2, 600, true )

    local crush = EffectData()
    crush:SetScale( 0.25 )
    crush:SetOrigin( self:WorldSpaceCenter() )
    util.Effect( "eff_huntersglee_skullcrush", crush )

    SafeRemoveEntity( self )

end

function ENT:Use( user )
    self:DoScore( user )

end

function ENT:OnTakeDamage( dmg )
    local parent = self:GetParent()
    if IsValid( parent ) then
        local _, ragdollsSkull, isSkeleton = glee_RagdollHasASkull( parent )

        local dealt = dmg:GetDamage()
        if parent.homeless_Awakened then -- they're awake
            dealt = dealt / 100

        end

        self.neckHealth = self.neckHealth + -dealt
        local pit = 120 + -( self.neckHealth / 4 ) + math.random( -5, 5 )

        if not isSkeleton then
            self:EmitSound( "physics/body/body_medium_break" .. math.random( 2, 4 ) .. ".wav", 70, pit )
            local blood = EffectData()
            blood:SetOrigin( self:GetPos() )
            util.Effect( "BloodImpact", blood )

        end

        self:EmitSound( "hunters_glee/bones/break4.wav", 70, pit )

        local objId = parent:TranslateBoneToPhysBone( ragdollsSkull )
        local obj = parent:GetPhysicsObjectNum( objId )
        if IsValid( obj ) then
            obj:ApplyForceCenter( dmg:GetDamageForce() )

        end

        if self.neckHealth > 0 then return end

        self:Decapitate()

    else
        self:TakePhysicsDamage( dmg )
        if self:GetIsTerminatorSkull() then return end
        if dmg:GetDamage() < 75 then return end
        self:Crumble()

    end
end

function ENT:PhysicsCollide( colData, _ )
    self:DoScore( colData.HitEntity )
    if colData.Speed < 30 then return end

    local volume = colData.Speed / 100

    local sndPath = "physics/cardboard/cardboard_cup_impact_hard2.wav"
    if self:GetIsTerminatorSkull() then
        sndPath = "physics/metal/metal_canister_impact_soft1.wav"

        local effScale = colData.Speed / 500
        effScale = math.max( effScale, math.Rand( 0, 0.5 ) )

        local Sparks = EffectData()
        Sparks:SetOrigin( colData.HitPos )
        Sparks:SetNormal( colData.HitNormal )
        Sparks:SetMagnitude( effScale )
        Sparks:SetScale( effScale )
        Sparks:SetRadius( effScale )
        util.Effect( "Sparks", Sparks )

    end

    self:EmitSound( sndPath, 65, 150 + -volume )

end

local angle_zero = Angle( 0, 0, 0 )

function glee_RagdollHasASkull( ragdoll )
    if ragdoll.glee_skulldecapitated then return end
    if ragdoll.glee_skullboneindex then
        return true, ragdoll.glee_skullboneindex, ragdoll.glee_skullisskeleton

    end

    if ragdoll:GetClass() ~= "prop_ragdoll" then return end
    local model = ragdoll:GetModel()

    if IsValid( ragdoll.glee_skullpickup ) then return false end
    if string.find( model, "zombie_soldier" ) then ragdoll.glee_skulldecapitated = true return end
    if string.find( model, "headcrab" ) then ragdoll.glee_skulldecapitated = true return end

    local ragdollsSkull
    local isSkeleton

    for boneIndex = 0, ragdoll:GetBoneCount() - 1 do
        local name = ragdoll:GetBoneName( boneIndex )
        name = string.lower( name )

        if string.find( name, "head1" ) or string.find( name, ".head" ) then
            ragdollsSkull = boneIndex

        end
    end

    if not ragdollsSkull then ragdoll.glee_skulldecapitated = true return end

    if string.find( model, "skeleton" ) then
        isSkeleton = true

    end

    ragdoll.glee_skullboneindex = ragdollsSkull
    ragdoll.glee_skullisskeleton = isSkeleton
    return true, ragdollsSkull, isSkeleton

end

local distToGotoSkull = 8^2

hook.Add( "EntityTakeDamage", "glee_hadaskullpickup", function( target, dmg )
    if not target.glee_hadaskullpickup then return end
    local theSkull = target.glee_skullpickup
    if not IsValid( theSkull ) then return end

    local dmgPos = dmg:GetDamagePosition()
    if not dmgPos then return end
    if dmgPos:DistToSqr( theSkull:WorldSpaceCenter() ) > distToGotoSkull then return end
    theSkull:TakeDamageInfo( dmg )

    return true

end )

function ENT:AttachToRagdollsSkull( ragdoll )
    local hasSkull, ragdollsSkull, isSkeleton = glee_RagdollHasASkull( ragdoll )

    if not hasSkull then return end

    ragdoll.glee_hadaskullpickup = true
    ragdoll.glee_skullpickup = self

    if isSkeleton then
        self.neckHealth = 10

    else
        self.neckHealth = 40

    end

    self:FollowBone( ragdoll, ragdollsSkull )
    self:SetPos( vector_origin )
    self:SetAngles( angle_zero )

    self:UseTriggerBounds( true, self.TriggerBoundsRagdoll )

    return true

end

local vec_zero = Vector( 0, 0, 0 )

function ENT:Decapitate()
    local parent = self:GetParent()
    local _, ragdollsSkull, isSkeleton = glee_RagdollHasASkull( parent )

    local skullsPos = parent:GetBonePosition( ragdollsSkull )

    parent:ManipulateBoneScale( ragdollsSkull, vec_zero )
    self:FollowBone( nil, ragdollsSkull )
    self:SetParent( nil )
    self:UseTriggerBounds( true, self.TriggerBoundsNormal )

    self.nextPickup = CurTime() + 1

    self.obviousOrigin = true
    parent.glee_skullpickup = nil
    parent.glee_skulldecapitated = true

    self:EmitSound( "physics/body/body_medium_impact_hard4.wav", 78, 100 )
    self:EmitSound( "garrysmod/balloon_pop_cute.wav", 88, 80 )
    self:EmitSound( "hunters_glee/bones/skullcrush.wav", 76, 100 )

    if not isSkeleton then
        for _ = 1, 10 do
            local blood = EffectData()
            blood:SetOrigin( self:GetPos() )
            blood:SetScale( 4 )
            util.Effect( "BloodImpact", blood )

        end
    end

    self:SetPos( skullsPos )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        local myObj = self:GetPhysicsObject()
        myObj:ApplyForceCenter( self:GetUp() * 10000 )

    end )
end

if not CLIENT then return end

function ENT:Draw()
    if IsValid( self:GetParent() ) then return end
    self:DrawModel()

end