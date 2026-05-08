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

ENT.Damage = 250
ENT.Radius = 400
ENT.DelayMin = 4
ENT.DelayMax = 4.5
ENT.EffectScale = 1.5
ENT.WarnNPCsInterval = 1

ENT.glee_AlwaysFullPVPDamage = true

if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_timed_tnt", "vgui/hud/killicon/glee_timed_tnt.png" )

end


function ENT:Initialize()
    self:SetModel( self.Model )
    self.glee_IsTimedTNT = true -- Faster than a :GetClass() string comparison

    if CLIENT then return end

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:PhysWake()

    local delay = math.Rand( self.DelayMin, self.DelayMax )
    self.glee_DetonateAt = CurTime() + delay
    self.glee_NextWarnNPCs = 0

    self.tickSnd = CreateSound( self, "ambient/machines/ticktock.wav" )
    self.tickSnd:PlayEx( 1, math.random( 120, 125 ) )
    self.tickSnd:ChangePitch( 200, delay )

end

local MEMORY_DAMAGING = terminator_Extras.botMemoryTypes.MEMORY_DAMAGING

function ENT:terminatorHunterInnateReaction()
    return MEMORY_DAMAGING

end

function ENT:SetPosCentered( centerPos, ang )
    local pos = LocalToWorld( -self:OBBCenter(), Angle(), centerPos, ang or self:GetAngles() )
    if ang then self:SetAngles( ang ) end
    self:SetPos( pos )

end


if not SERVER then return end


function ENT:Think()
    local cur = CurTime()
    if cur < self.glee_NextWarnNPCs then
        self.glee_NextWarnNPCs = cur + self.WarnNPCsInterval
        sound.EmitHint( SOUND_DANGER, self:GetPos(), self.Radius * 1.25, 1, self )

    end

    if cur < self.glee_DetonateAt then return end

    self:Detonate()

end

function ENT:Detonate()
    local pos = self:WorldSpaceCenter()
    local attacker = IsValid( self.glee_BombCrate_player ) and self.glee_BombCrate_player or self
    terminator_Extras.GleeFancySplode( pos, self.Damage, self.Radius, attacker, self )

    self:EmitSound( "C4.Explode" )

    local eff = EffectData()
    eff:SetScale( self.EffectScale )
    eff:SetNormal( Vector( 0, 0, 1 ) )
    util.Effect( "glee_huge_m9k_splode", eff )

    SafeRemoveEntity( self )

end
