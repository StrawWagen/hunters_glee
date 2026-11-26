--[[
    Things you wear, goggles and helmets.
    Each one is a single SWEP, see glee_wearable_base, and hooks.

        SWEP.Base = "glee_wearable_base"
        SWEP.GleeWearSlot = "head"

        function SWEP.SetupWear( wear )
            wear:Hook( "ScalePlayerDamage", function( wep, ply, hitgroup, dmg )
                if ply ~= wear.wearer or hitgroup ~= HITGROUP_HEAD then return end
                dmg:ScaleDamage( 0.5 )

            end )
        end

    Carrying it is wearing it, picking it up puts it on.
    One per slot.

    SetupWear runs on the server, and on the wearer's client.
    Everything it does goes through the wear, and comes off with it, see sh_wearobject.lua:
        wear:Hook( hookName, fn ) -- fn( wep, ... ), the worn SWEP, then the hook's own arguments
        wear:OnRemove( fn ) -- for what the hooks made, eg a projected texture
        wear.wearer, wear.slot, wear.class
]]

local slotPrefix = "glee_worn_"

-- the worn class, one NW2String per slot, on the wearer
-- not on the SWEP, NW2 vars on Lua entities can get mixed up, see GM:EntityNetworkedVarChanged on the wiki
-- everyone's client reads it to draw what's worn, see the models below

local plyMeta = FindMetaTable( "Player" )

-- the class worn in slot, "" when nothing is
function plyMeta:GetGleeWornClass( slot )
    return self:GetNW2String( slotPrefix .. slot, "" )

end

-- key's value on class, or on the nearest of its bases that sets it
-- not weapons.Get, that's a whole copy, and it merges a class's WornOn list into its base's entry by entry
local function getWearableMember( class, key )
    local name = class
    while name do
        local stored = weapons.GetStored( name )
        if not stored then return end

        local value = stored[key]
        if value ~= nil then return value end

        if stored.Base == name then return end -- weapons.Get skips a base of itself too
        name = stored.Base

    end
end

-- does wearer have every bone and attachment these models go on
local function hasPlacesFor( wearer, models )
    for _, entry in ipairs( models ) do
        if entry.bone and not wearer:LookupBone( entry.bone ) then return false end
        if entry.attachment and wearer:LookupAttachment( entry.attachment ) <= 0 then return false end

    end
    return true

end

-- the models class is worn as on wearer, its WornOnBone, or its WornOnAttachment when they haven't got the bones
-- nil when they've got neither
local function wornModels( wearer, class )
    local onBone = getWearableMember( class, "WornOnBone" )
    if onBone and hasPlacesFor( wearer, onBone ) then return onBone end

    local onAttachment = getWearableMember( class, "WornOnAttachment" )
    if onAttachment and hasPlacesFor( wearer, onAttachment ) then return onAttachment end

end

-- could they put class on? false, reason if not, the reason's shown to them
-- shared, so the shop greys out when the server would refuse
function plyMeta:CanGleeWear( class )
    if not self:Alive() then return false end

    local slot = getWearableMember( class, "GleeWearSlot" )
    if not slot then return false end
    if self:GetGleeWornClass( slot ) ~= "" then return false, "You're already wearing one of these." end
    if not wornModels( self, class ) then return false, "There's nowhere on you to put this." end

    return true

end

if SERVER then
    -- only glee_wearable_base calls this, as it's picked up, dropped or removed
    function plyMeta:SetGleeWornClass( slot, class )
        self:SetNW2String( slotPrefix .. slot, class )

    end

    hook.Add( "PlayerCanPickupWeapon", "glee_wearing_canwear", function( ply, wep )
        if not wep.GleeWearSlot then return end
        if not ply:CanGleeWear( wep:GetClass() ) then return false end

    end )
end


-- Wears ----------------------------------------------------------------------

-- makes a wear for class, see sh_wearobject.lua, and runs its SetupWear
-- replaces whatever wear was in that slot
local function putOn( wearer, slot, class )
    local setupWear = getWearableMember( class, "SetupWear" )
    if not setupWear then return end

    -- [slot] = the last wear put on there, it may have removed itself since
    -- on the wearer, not a local here, so an autorefresh of this file can still find the old ones to remove
    local slots = wearer.glee_Wears or {}
    wearer.glee_Wears = slots

    -- the old one only takes itself off when one of its hooks runs, that may not have happened yet
    -- a full update also lands here, with the same class that's already on
    local old = slots[slot]
    if old then old:Remove() end

    local wear = include( "glee_wearing/sh_wearobject.lua" )
    wear.wearer = wearer
    wear.slot = slot
    wear.class = class
    wear._idPrefix = "glee_wear_" .. wearer:EntIndex() .. "_" .. slot .. "_"

    slots[slot] = wear

    -- from the class, not a carried SWEP
    -- clientside, the var can arrive before the weapon does
    setupWear( wear )

end


-- Models ---------------------------------------------------------------------

local updateWornModel

if CLIENT then
    -- everyone sees it on the wearer
    -- bone or attachment is picked as it's put on, a playermodel change after that keeps the pick
    function updateWornModel( wearer, key, class )
        local models = class ~= "" and wornModels( wearer, class )
        if not models then
            terminator_Extras.RemoveMyExtraModels( wearer, key )
            return

        end

        local worldModel = getWearableMember( class, "WorldModel" )
        local entries = {}
        for index, entry in ipairs( models ) do
            local copy = table.Copy( entry )
            copy.model = copy.model or worldModel
            -- it's dropped on death, the dropped one shouldn't have a twin riding the ragdoll
            copy.hideWhenDead = true
            entries[index] = copy

        end

        -- attaching again keeps the models that didn't change, only moving them, eg on autorefresh
        terminator_Extras.AttachMyExtraModels( wearer, entries, key )

    end
end


-- The var changing -----------------------------------------------------------

-- slot's worn class is now class, "" when it came off
-- everyone's client redoes the model, the wear is only made on the server and the wearer's client
local function wornChanged( wearer, slot, class )
    if CLIENT then
        updateWornModel( wearer, slotPrefix .. slot, class )
        if wearer ~= LocalPlayer() then return end

    end

    if class == "" then return end
    putOn( wearer, slot, class )

end

-- runs for every NW2 change on every entity, keep the bail cheap
hook.Add( "EntityNetworkedVarChanged", "glee_wearing", function( ent, name, _old, class )
    if name:find( slotPrefix, 1, true ) ~= 1 then return end
    wornChanged( ent, name:sub( #slotPrefix + 1 ), class )

end )

-- autorefresh, for tweaking a wearable's offsets or SetupWear live
-- the model and wear are only made as it's put on, so everyone wearing the refreshed class, or one based on it, puts it on again
-- off the class, not SWEP:OnReloaded, others' clients don't always have the worn SWEP to call that on
hook.Add( "PreRegisterSWEP", "glee_wearing_autorefresh", function( _swep, refreshed )
    if not weapons.GetStored( refreshed ) then return end -- first load, not a refresh

    -- next tick, the refreshed class isn't registered yet
    timer.Simple( 0, function()
        for _, ply in player.Iterator() do
            for name, var in pairs( ply:GetNW2VarTable() ) do
                local class = var.value
                local isWorn = name:find( slotPrefix, 1, true ) == 1 and isstring( class ) and class ~= ""
                if isWorn and ( class == refreshed or weapons.IsBasedOn( class, refreshed ) ) then
                    wornChanged( ply, name:sub( #slotPrefix + 1 ), class )

                end
            end
        end
    end )
end )
