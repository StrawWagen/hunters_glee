AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Timed TNT"
ENT.Author      = "TwoLemons"
ENT.Purpose     = ""
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/dav0r/tnt/tnttimed.mdl"

ENT.Damage = 70
ENT.Radius = 200
ENT.DelayMin = 2.5
ENT.DelayMax = 3.5
ENT.DamageMultNPC = 3 -- Applies to NPCs and NextBots.
ENT.EffectScale = 1.5


if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_timed_tnt", "vgui/hud/killicon/glee_timed_tnt.png" )

end


function ENT:Initialize()
    self:SetModel( self.Model )
    self.glee_IsTimedTNT = true -- Faster than a :GetClass() string comparison

    if CLIENT then
        self:EmitSound( "ambient/machines/ticktock.wav", 80, 255, 1 )
        return

    end

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:PhysWake()
    self:StartExplosionTimer()

end

function ENT:OnRemove()
    if SERVER then
        timer.Remove( "glee_timedtnt_explodetimer_" .. self:GetCreationID() )

    else
        self:StopSound( "ambient/machines/ticktock.wav" )

    end
end

function ENT:SetPosCentered( centerPos, ang )
    local pos = LocalToWorld( -self:OBBCenter(), Angle(), centerPos, ang or self:GetAngles() )
    if ang then self:SetAngles( ang ) end
    self:SetPos( pos )

end


if not SERVER then return end


function ENT:StartExplosionTimer()
    timer.Create( "glee_timedtnt_explodetimer_" .. self:GetCreationID(), math.Rand( self.DelayMin, self.DelayMax ), 1, function()
        if not IsValid( self ) then return end

        self:Detonate()

    end )
end

function ENT:Detonate()
    local pos = self:WorldSpaceCenter()
    util.BlastDamage( self, self, pos, self.Radius, self.Damage )

    local eff = EffectData()
    eff:SetOrigin( pos )
    eff:SetMagnitude( 1 )
    eff:SetScale( 1 )
    eff:SetFlags( 0 )
    util.Effect( "Explosion", eff )

    eff:SetScale( self.EffectScale )
    eff:SetNormal( Vector( 0, 0, 1 ) )
    util.Effect( "glee_huge_m9k_splode", eff )

    SafeRemoveEntity( self )

end

hook.Add( "EntityTakeDamage", "glee_timedtnt_scaledamage", function ( target, dmg )
    if not dmg:IsExplosionDamage() then return end

    local tnt = dmg:GetInflictor()
    if not IsValid( tnt ) then return end
    if not tnt.glee_IsTimedTNT then return end

    tnt.glee_TimedTNT_PreScaledDamage = dmg:GetDamage() -- For reading during PostEntityTakeDamage immediately after.

    if target:IsNPC() or target:IsNextBot() then
        dmg:ScaleDamage( tnt.DamageMultNPC )

    end
end )
