
-- Base of the night vision goggles, bought in the shop (see glee_shopitems/sh_nightvision.lua), kept in weapon slot 6.
-- Left click with them out flips them down or up, that's the only way. Hold V with them out to throw them down,
-- through glee's own weapon dropper. Dropped when you die, flipped down or not. Only one pair carried at a time, whatever the kind.
-- Models and sounds come from Neosun's Cooler Nightvision, workshop 3425531829, copied into
-- models/glee/nvg, materials/models/glee/nvg and sound/hunters_glee/nvg, so only glee is needed.
-- The .mdl files had their internal name and texture folder paths repointed there.
--
-- Each goggle weapon sets its own SWEP.GleeNVG, how its vision looks, see the comment below.
-- The server holds who has them on in the player's "glee_nvg_on" NW2String (the weapon class, "" when off),
-- so everyone sees the goggles on that player's head (cl_init.lua), and the wearer's client draws the vision.

SWEP.Base = "weapon_base"
SWEP.PrintName = "Night Vision"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = false
SWEP.DrawWeaponInfoBox = false -- no tooltip in weapon select
SWEP.IsGleeNVG = true

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

-- SWEP.GleeNVG, the vision, every field optional:
-- lamp = brightness of a light from the eyes, only the wearer sees it, lights pitch black. nil for none
-- lampColor = colour of that light, white if nil
-- gain = the picture is multiplied by this, bigger blows lit areas out sooner. nil skips the colour pass
-- saturation = 0 turns the picture grey, 1 keeps the map's colours, above 1 makes them stronger
-- bloom = glare around bright spots
-- tint = the picture is then multiplied by this, black stays black and white becomes this colour
-- heatColor = draw living npcs, players and nextbots in this colour on top; ragdolls get a flat grey
SWEP.GleeNVG = {}

-- each goggle file has to set these on its own table, the spawnmenu reads that and not the base's:
-- SWEP.PrintName, SWEP.Category = "Hunter's Glee", SWEP.Spawnable = true, SWEP.WorldModel, SWEP.GleeNVG

local nwKey = "glee_nvg_on"
SWEP.GleeNVGOnSound = "hunters_glee/nvg/nvg_on_1.wav"
SWEP.GleeNVGOffSound = "hunters_glee/nvg/nvg_off_1.wav"

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

-- glee's weapon dropper asks this for both hold V and dying. throwable while alive, and dropped on death
-- too, whether the pair was flipped down on their head or just sitting in the inventory
function SWEP:ShouldDropOnDie()
    return true

end

-- player helpers -------------------------------------------------------------------

local plyMeta = FindMetaTable( "Player" )

-- the goggle weapon this player is carrying, nil if none
function plyMeta:GetGleeNVG()
    for _, wep in ipairs( self:GetWeapons() ) do
        if wep.IsGleeNVG then return wep end

    end
end

-- the vision table, class and stored weapon table of the goggles this player has flipped down, nil if off
function plyMeta:GetGleeNVGOn()
    if not self:Alive() then return end
    local class = self:GetNW2String( nwKey, "" )
    if class == "" then return end
    local stored = weapons.GetStored( class )
    if not stored then return end
    return stored.GleeNVG or {}, class, stored

end

function plyMeta:GetGleeNVGOnClass()
    return self:GetNW2String( nwKey, "" )

end
