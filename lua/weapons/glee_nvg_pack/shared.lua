-- The night vision pack, bought in the shop (see glee_shopitems/sh_nightvision.lua) for three skulls.
-- E with it out, and nothing usable in front, opens a use wheel: pick which pair of goggles comes out of
-- it, the GPNVG-18, the T-7 Thermal, or the PVS-14 Haptic. The haptic pair asks for one more skull on
-- top, checked and taken when it's picked. The pack is used up when a pair comes out.
-- Gone when you die, like the goggles themselves. The goggles are glee_nvg_base and its children.

SWEP.Base = "weapon_base"
SWEP.PrintName = "Night Vision Pack"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = false
SWEP.DrawWeaponInfoBox = false -- no tooltip in weapon select
SWEP.IsGleeNVGPack = true

SWEP.Slot = 5
SWEP.SlotPos = 5
SWEP.Weight = 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = true

SWEP.ViewModel = Model( "models/weapons/c_arms.mdl" )
SWEP.WorldModel = "models/props_junk/cardboard_box004a.mdl"
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

-- what the wheel offers, in wheel order. extraSkulls is charged on top of the pack's price, when picked
SWEP.Choices = {
    { key = "gpnvg", class = "glee_nvg_gpnvg", label = "GPNVG-18", extraSkulls = 0 },
    { key = "t7", class = "glee_nvg_t7", label = "T-7 Thermal", extraSkulls = 0 },
    { key = "pvs14", class = "glee_nvg_pvs14", label = "PVS-14 Haptic", extraSkulls = 1 },
}

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:Holster()
    return true

end

-- glee's weapon dropper asks this for both hold V and dying. throwable while alive, gone when you die
function SWEP:ShouldDropOnDie()
    local owner = self:GetOwner()
    return IsValid( owner ) and owner:Health() > 0

end
