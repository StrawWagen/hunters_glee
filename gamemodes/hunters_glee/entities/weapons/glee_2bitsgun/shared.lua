-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=158421055
-- glee'd by dedactedlife, 12 Nov 2026

AddCSLuaFile()

SWEP.PrintName = "Sexyness"
SWEP.Author = "2-bit, glee'd by dedactedlife & IndefiniteXD"
SWEP.Category = "Hunter's Glee"

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_2bitsgun", "materials/vgui/hud/killicon/glee_2bitsgun.png" )

end

SWEP.Base = "weapon_base"

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.HoldType = "pistol"

SWEP.ViewModel = "models/glee/weapons/sexyness/v_pist_weagon.mdl"
SWEP.WorldModel = "models/glee/weapons/sexyness/w_pist_weagon.mdl"
SWEP.ViewModelFlip = true

SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.Primary.Sound = Sound( "weapons/automag/deagle-1.wav" )
SWEP.Primary.Damage = 99999999999
SWEP.Primary.Force = 1000000
SWEP.Primary.NumShots = 75
SWEP.Primary.Spread = 0.025
SWEP.Primary.Delay = 0.05

-- secondary spends primary ammo too
SWEP.Primary.Ammo = "Pistol"
SWEP.Primary.Automatic = true
SWEP.Primary.ClipSize = 9999999
SWEP.Primary.DefaultClip = 9999999

SWEP.Secondary.Sound = Sound( "weapons/automag/deagle-1.wav" )
SWEP.Secondary.Delay = 0.05

SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Automatic = true
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end

    local owner = self:GetOwner()
    local spread = self.Primary.Spread

    local bullet = {}
    bullet.Num = self.Primary.NumShots
    bullet.Src = owner:GetShootPos()
    bullet.Dir = owner:GetAimVector()
    bullet.Spread = Vector( spread, spread, 0 )
    bullet.Tracer = 0
    bullet.Force = self.Primary.Force
    bullet.Damage = self.Primary.Damage
    bullet.AmmoType = self.Primary.Ammo

    self:ShootEffects()
    owner:FireBullets( bullet )
    self:EmitSound( self.Primary.Sound )
    self:TakePrimaryAmmo( 1 )

    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
    self:SetNextSecondaryFire( CurTime() + self.Primary.Delay )

end

-- an explosion wherever you're looking
function SWEP:SecondaryAttack()
    if not self:CanPrimaryAttack() then return end

    self:ShootEffects()
    self:EmitSound( self.Secondary.Sound )
    self:TakePrimaryAmmo( 1 )

    self:SetNextPrimaryFire( CurTime() + self.Secondary.Delay )
    self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )

    if not SERVER then return end

    local owner = self:GetOwner()

    local explosion = ents.Create( "env_explosion" )
    explosion:SetPos( owner:GetEyeTrace().HitPos )
    explosion:SetOwner( owner )
    explosion:SetKeyValue( "iMagnitude", "175" )
    explosion:Spawn()
    explosion:Fire( "Explode" )
    explosion:EmitSound( "weapon_AWP.Single", 400, 400 )

end
