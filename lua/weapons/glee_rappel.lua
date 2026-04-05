
AddCSLuaFile()

if CLIENT then
    SWEP.PrintName = "Rappelling Gear"
    SWEP.DrawAmmo = false
    SWEP.DrawCrosshair = false

end

SWEP.Category = "Rappelling"
SWEP.Author = "wowm0d"
SWEP.Instructions = "Primary Fire: Attach/Cut Rope"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.IsEonRappel = true

SWEP.ViewModelFOV = 45
SWEP.ViewModelFlip = false
SWEP.AnimPrefix = "rpg"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = ""

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = ""

SWEP.ViewModel = Model( "models/weapons/c_arms_animations.mdl" )
SWEP.WorldModel = ""

SWEP.UseHands = false

SWEP.IsAlwaysLowered  = true
SWEP.FireWhenLowered = true
SWEP.HoldType = "passive"

SWEP.MaxDistance = 300

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
end

function SWEP:PrimaryAttack()
    if not SERVER then return end

    local ply = self:GetOwner()
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return end

    if ply:GetNWBool( "glee_IsRappelling", false ) then
        ply:StopRapelling()
        return

    end

    local eyeTrace = ply:GetEyeTrace()

    if hook.Run( "PlayerBlockRappel", ply, eyeTrace ) then return end
    if eyeTrace.HitPos:Distance( ply:GetPos() ) >= self.MaxDistance then return end

    local traceEnt = eyeTrace.Entity
    local hitPos = eyeTrace.HitPos
    ply:RappelTo( traceEnt, hitPos )

end

function SWEP:SecondaryAttack()
end