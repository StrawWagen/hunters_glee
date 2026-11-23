AddCSLuaFile()

--[[
    The SWEP half of a wearable, see glee_wearing/sh_wearing.lua.

        SWEP.Base = "glee_wearable_base"
        SWEP.GleeWearSlot = "head"
        SWEP.WorldModel = "models/..."
        -- then where it sits on the wearer, below

    Worn while it's carried.
    Hold V with it out to throw it, and it's dropped on death, both through the gamemode's dropper.
]]

SWEP.Base = "weapon_base"
SWEP.Spawnable = false
SWEP.Category = "Hunter's Glee"
SWEP.DrawWeaponInfoBox = false

SWEP.Slot = 6 -- slot 7, nothing else uses it, so wearables never crowd the weapons
SWEP.SlotPos = 0
SWEP.Weight = 1
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = true

SWEP.ViewModel = Model( "models/weapons/c_arms.mdl" )
SWEP.UseHands = true
SWEP.HoldType = "slam" -- never "normal", the gamemode's dropper refuses to drop those
SWEP.DrawAmmo = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- one wearable per slot, any name, eg "eyes", "head"
SWEP.GleeWearSlot = nil

-- where WorldModel sits on the wearer
-- on this bone, or this attachment when their playermodel hasn't got the bone
-- each with its own offset, the two don't face the same way
-- nil skips either
SWEP.WornBone = nil
SWEP.WornBonePos = Vector( 0, 0, 0 )
SWEP.WornBoneAng = Angle( 0, 0, 0 )
SWEP.WornAttachment = nil
SWEP.WornAttachmentPos = Vector( 0, 0, 0 )
SWEP.WornAttachmentAng = Angle( 0, 0, 0 )

-- runs as it's put on, see the top of glee_wearing/sh_wearing.lua
function SWEP.SetupWear( _wear )
end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:ShouldDropOnDie()
    return true

end

if SERVER then
    function SWEP:Equip( owner )
        if not owner:IsPlayer() then return end

        self.glee_Wearer = owner
        owner:SetGleeWornClass( self.GleeWearSlot, self:GetClass() )

    end

    local function takeOff( wep )
        local wearer = wep.glee_Wearer
        wep.glee_Wearer = nil
        if not IsValid( wearer ) then return end

        wearer:SetGleeWornClass( wep.GleeWearSlot, "" )

    end

    -- not GetOwner, that's gone by OnDrop
    function SWEP:OnDrop()
        takeOff( self )

    end

    function SWEP:OnRemove()
        takeOff( self )

    end
end

if CLIENT then
    -- carried, it's drawn on the wearer instead, see glee_wearing's models
    function SWEP:DrawWorldModel()
        if IsValid( self:GetOwner() ) then return end
        self:DrawModel()

    end
end
