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

-- where wearable goes on wearer, its WornBone, or its WornAttachment when they haven't got the bone
-- returns "bone" or "attachment", the name, then that one's offset
-- nil when they've got neither
local function wornPlace( wearer, wearable )
    local bone = wearable.WornBone
    if bone and wearer:LookupBone( bone ) then
        return "bone", bone, wearable.WornBonePos, wearable.WornBoneAng

    end

    local attachment = wearable.WornAttachment
    if attachment and wearer:LookupAttachment( attachment ) > 0 then
        return "attachment", attachment, wearable.WornAttachmentPos, wearable.WornAttachmentAng

    end
end

-- could they put wearable on? false, reason if not, the reason's shown to them
-- wearable is a wearable SWEP, or a weapons.Get of its class, eg for the shop
-- shared, so the shop greys out when the server would refuse
function plyMeta:CanGleeWear( wearable )
    if not self:Alive() then return false end

    local slot = wearable.GleeWearSlot
    if not slot then return false end
    if self:GetGleeWornClass( slot ) ~= "" then return false, "You're already wearing one of these." end
    if not wornPlace( self, wearable ) then return false, "There's nowhere on you to put this." end

    return true

end

if SERVER then
    -- only glee_wearable_base calls this, as it's picked up, dropped or removed
    function plyMeta:SetGleeWornClass( slot, class )
        self:SetNW2String( slotPrefix .. slot, class )

    end

    hook.Add( "PlayerCanPickupWeapon", "glee_wearing_canwear", function( ply, wep )
        if not wep.GleeWearSlot then return end
        if not ply:CanGleeWear( wep ) then return false end

    end )
end


-- Wears ----------------------------------------------------------------------

-- [wearer][slot] = the last wear put on there, it may have removed itself since
local wears = setmetatable( {}, { __mode = "k" } )

-- makes a wear for class, see sh_wearobject.lua, and runs its SetupWear
-- replaces whatever wear was in that slot
local function putOn( wearer, slot, class )
    local stored = weapons.Get( class )
    if not stored then return end

    local slots = wears[wearer] or {}
    wears[wearer] = slots

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
    stored.SetupWear( wear )

end


-- Models ---------------------------------------------------------------------

local updateWornModel

if CLIENT then
    -- everyone sees it on the wearer
    -- placed once as it's put on, a playermodel change after that keeps the place
    function updateWornModel( wearer, key, class )
        terminator_Extras.RemoveMyExtraModels( wearer, key )
        if class == "" then return end

        local stored = weapons.Get( class )
        if not stored then return end

        local kind, name, pos, ang = wornPlace( wearer, stored )
        if not kind then return end

        terminator_Extras.AttachMyExtraModels( wearer, {
            {
                model = stored.WorldModel,
                [kind] = name,
                pos = pos,
                ang = ang,
                hideWhenDead = true,
            },
        }, key )
    end
end


-- The var changing -----------------------------------------------------------

-- runs for every NW2 change on every entity, keep the bail cheap
hook.Add( "EntityNetworkedVarChanged", "glee_wearing", function( ent, name, _old, class )
    if name:find( slotPrefix, 1, true ) ~= 1 then return end
    local slot = name:sub( #slotPrefix + 1 )

    if CLIENT then
        updateWornModel( ent, name, class )
        if ent ~= LocalPlayer() then return end

    end

    if class == "" then return end
    putOn( ent, slot, class )

end )
