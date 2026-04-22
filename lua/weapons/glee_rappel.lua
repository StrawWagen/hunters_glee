
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

SWEP.IsGleeRappel = true

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

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end
    if not owner:IsPlayer() then return end

    if owner:GetNWBool( "glee_IsRappelling", false ) then
        owner:StopRapelling()
        return

    end

    local eyeTrace = owner:GetEyeTrace()

    if hook.Run( "PlayerBlockRappel", owner, eyeTrace ) then return end

    print("hi")
    if eyeTrace.HitPos:Distance( owner:GetPos() ) >= self.MaxDistance then return end

    local traceEnt = eyeTrace.Entity
    local hitPos = eyeTrace.HitPos
    owner:RappelTo( traceEnt, hitPos )

end

function SWEP:SecondaryAttack()
end