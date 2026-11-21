AddCSLuaFile()

-- Base of the three night vision goggles, see lua/autorun/sh_glee_nightvision.lua for how they work.
-- Sits in slot 6. Left click with them out flips them down or up. Hold V with them out to throw them down.

SWEP.Base = "weapon_base"
SWEP.PrintName = "Night Vision"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = false
SWEP.DrawWeaponInfoBox = false -- no tooltip in weapon select

SWEP.Slot = 5
SWEP.SlotPos = 5
SWEP.Weight = 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = true

SWEP.ViewModel = Model( "models/weapons/c_arms.mdl" )
SWEP.WorldModel = "models/glee/nvg/nvg_gpnvg.mdl"
SWEP.UseHands = true
SWEP.HoldType = "slam" -- glee's weapon dropper won't throw "normal" holdtypes
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire( CurTime() + 0.5 )
    if not SERVER then return end
    local owner = self:GetOwner()
    if IsValid( owner ) and owner:IsPlayer() then owner:ToggleGleeNVG() end

end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Holster()
    return true

end

-- glee's weapon dropper asks this for both hold V and dying. throwable while alive, gone when you die, like the radio
function SWEP:ShouldDropOnDie()
    local owner = self:GetOwner()
    return IsValid( owner ) and owner:Health() > 0

end

if SERVER then
    local function turnOff( self, owner )
        if not IsValid( owner ) or not owner:IsPlayer() then return end
        if owner:GetNW2String( GleeNVG.nwKey, "" ) ~= self:GetClass() then return end
        owner:SetGleeNVGOn( nil, true )

    end

    function SWEP:OnDrop()
        turnOff( self, self.glee_LastNVGOwner )

    end

    function SWEP:OnRemove()
        turnOff( self, self:GetOwner() )

    end

    function SWEP:Equip( owner )
        self.glee_LastNVGOwner = owner

    end

    return

end

-- not drawn in the hand, they're on your head when flipped down
function SWEP:DrawWorldModel()
    if IsValid( self:GetOwner() ) then return end
    self:DrawModel()

end
