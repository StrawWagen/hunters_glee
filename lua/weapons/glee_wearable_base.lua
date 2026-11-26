AddCSLuaFile()

--[[
    The SWEP half of a wearable, see glee_wearing/sh_wearing.lua.

        SWEP.Base = "glee_wearable_base"
        SWEP.GleeWearSlot = "head"
        SWEP.WorldModel = "models/..."
        SWEP.WornOnBone = {
            { bone = "ValveBiped.Bip01_Head1", pos = Vector( 0, 0, 0 ), ang = Angle( 0, 0, 0 ) },
        }

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

-- the models it's worn as, terminator_Extras entries, see ENT.MyExtraModels in terminator_nextbot
-- on bones, or on attachments when the wearer's playermodel hasn't got the bones
-- each list has its own offsets, bones and attachments don't face the same way
-- an entry without a model is the WorldModel
-- save with it on to see a change, autorefresh puts it on again
SWEP.WornOnBone = nil
SWEP.WornOnAttachment = nil

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

    -- not OnDrop, that misses the drop on death
    -- the old owner's gone by now, so it's the wearer Equip remembered that comes off
    function SWEP:OwnerChanged()
        if self:GetOwner() == self.glee_Wearer then return end
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
