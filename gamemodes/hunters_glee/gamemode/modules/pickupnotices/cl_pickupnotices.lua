--[[------------------------------------
    Pickups land in the notice feed, instead of gmod's own list down the right.

    A weapon shows its icon, see glee_WeaponIcon in glee_hud/cl_icons.lua, and its slot.
    SWEP.Weight keeps it up longer, a big gun's worth noticing.
    A weapon you've never held stays up until you hold it, so it's not forgotten in the inventory.
    SWEP.glee_NoticePickupIcon = false shows no notice, for weapons that come with something that has its own.
    Ammo and items keep a running count, the same pickup again adds to it.
    Health and armor items are the server's, see sv_pickupnotices.lua.
    Only the living pick things up, so it's all alive only.
--]]-------------------------------------

local PICKUP_TIME = huntersGlee_PickupNoticeTime

-- Heavier weapons stay up longer, as multiples of PICKUP_TIME
local DEFAULT_WEIGHT = 5 -- weapon_base's, it and anything lighter get PICKUP_TIME
local TIME_PER_WEIGHT = 0.2 -- each weight above DEFAULT_WEIGHT, up to LINEAR_WEIGHT, adds this
local LINEAR_WEIGHT = 10
local MAX_TIME_SCALE = 10
local HALVING_WEIGHT = 150 -- past LINEAR_WEIGHT, the time left to MAX_TIME_SCALE halves every this much, 999 lands just under it

local function weightTimeScale( weight )
    weight = math.max( weight, DEFAULT_WEIGHT )

    local linear = 1 + ( math.min( weight, LINEAR_WEIGHT ) - DEFAULT_WEIGHT ) * TIME_PER_WEIGHT
    if weight <= LINEAR_WEIGHT then return linear end

    local remaining = MAX_TIME_SCALE - linear
    return linear + remaining * ( 1 - 0.5 ^ ( ( weight - LINEAR_WEIGHT ) / HALVING_WEIGHT ) )

end

-- "#weapon_crowbar" and "weapon_crowbar" alike, a name with no phrase comes back as it is
local function phrase( token )
    return language.GetPhrase( string.TrimLeft( token, "#" ) )

end

local function holding( ply, class )
    local active = ply:GetActiveWeapon()
    return IsValid( active ) and active:GetClass() == class

end

-- Until you've held one of these at least once, its notice stays at its full time while it sits unheld in your inventory,
-- and fades the moment you switch to it. Learned then too.
-- Auto switched to on pickup, it's in your hands, so it's learned and the notice counts down like any other.
-- The switch comes in the same update as the pickup, so it's already active by now
local function untilFirstHeld( class, time )
    local lesson = "SeenAndEquipped_" .. class
    if GAMEMODE:HasLearnedLesson( lesson ) then return end

    if holding( LocalPlayer(), class ) then
        GAMEMODE:LearnLesson( lesson )
        return

    end

    local done
    return function( notice )
        if done then return end

        local ply = LocalPlayer()
        if holding( ply, class ) then
            GAMEMODE:LearnLesson( lesson )
            notice:Cancel()
            return

        end

        -- dropped or stripped before it was ever held, counts down like any other
        if not ply:HasWeapon( class ) then
            done = true
            return

        end

        notice:SetTimeLeft( time )

    end
end

function GM:HUDWeaponPickedUp( wep )
    if not IsValid( wep ) or not isfunction( wep.GetPrintName ) then return end
    if wep.glee_NoticePickupIcon == false then return end

    local class = wep:GetClass()
    local time = PICKUP_TIME * weightTimeScale( wep:GetWeight() )

    huntersGlee_Notify( nil, {
        text = { alive = phrase( wep:GetPrintName() ) },
        iconWeapon = { alive = class },
        iconBadge = { alive = tostring( wep:GetSlot() + 1 ) }, -- the number key that selects it
        time = time,
        think = { alive = untilFirstHeld( class, time ) },
    } )
end

function GM:HUDAmmoPickedUp( name, amount )
    huntersGlee_Notify( nil, {
        text = { alive = phrase( name .. "_ammo" ) .. " +{num}" },
        addNum = amount,
        time = PICKUP_TIME,
    } )
end

function GM:HUDItemPickedUp( class )
    if huntersGlee_StatPickups[class] then return end

    huntersGlee_Notify( nil, {
        text = { alive = phrase( class ) .. " +{num}" },
        iconWeapon = { alive = class },
        addNum = 1,
        time = PICKUP_TIME,
    } )
end

-- still run for addons hooking it, gmod's own list just has nothing left to draw
function GM:HUDDrawPickupHistory()
end
