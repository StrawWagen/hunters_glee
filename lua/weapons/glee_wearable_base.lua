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
    Left click with it out offers its actions, see glee_actions, Take off is on every wearable.
]]

SWEP.Base = "weapon_base"
DEFINE_BASECLASS( "weapon_base" )
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

-- the click that picked it off the weapon selector is still down, it's not for it
function SWEP:Deploy()
    local owner = self:GetOwner()
    self.glee_AttackBlocked = IsValid( owner ) and owner:KeyDown( IN_ATTACK )
    return BaseClass.Deploy( self )

end

function SWEP:Think()
    if not self.glee_AttackBlocked then return end
    if self:GetOwner():KeyDown( IN_ATTACK ) then return end
    self.glee_AttackBlocked = nil

end

-- what left click offers, each key's run by OnGleeAction, below
-- wearables with more add theirs to this, see glee_nvg_base
-- a new table every call, so they can
function SWEP:GetGleeActions()
    return {
        { key = "takeoff", label = "Take off" },
    }
end

-- one action just runs, several open the wheel, held while attack is
function SWEP:PrimaryAttack()
    if self.glee_AttackBlocked then return end

    local actions = self:GetGleeActions()
    if #actions == 1 then
        if SERVER then terminator_Extras.glee_Actions.Pick( self:GetOwner(), "held", self, actions[1].key ) end
        return

    end

    if SERVER then
        -- singleplayer never runs it clientside on its own
        if game.SinglePlayer() then self:CallOnClient( "PrimaryAttack" ) end
        return

    end

    if not IsFirstTimePredicted() then return end
    terminator_Extras.glee_Actions.OpenWheel( "held", self, "+attack" )

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

    -- TODO: conflicts with the gamemode's V drop, see glee_dropcurrentweapon in sv_weapondropper.lua
    -- that drop is a progress bar filled while V is held, then a cooldown, nextDropWeaponThink
    -- a pick is one click, so Take off skips both. Wearables need a take off time and delay that fit both
    -- one of GetGleeActions' keys, glee_actions has checked it's offered
    -- wearables with more handle theirs, then hand the rest to this
    function SWEP:OnGleeAction( ply, key )
        if key ~= "takeoff" then return end

        -- the gamemode's dropper keeps the ammo and throws it, outside the gamemode there's only the engine's
        if ply.DropWeaponKeepAmmo then
            ply:DropWeaponKeepAmmo( self )

        else
            ply:DropWeapon( self )

        end

        return true

    end
end

if CLIENT then
    -- carried, it's drawn on the wearer instead, see glee_wearing's models
    function SWEP:DrawWorldModel()
        if IsValid( self:GetOwner() ) then return end
        self:DrawModel()

    end
end
