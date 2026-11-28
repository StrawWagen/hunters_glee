-- Pickup notices, see cl_pickupnotices.lua. The server half, sv_pickupnotices.lua, does health and armor

huntersGlee_PickupNoticeTime = 5 -- gmod's own

-- Noticed by what they gave, not what they are.
-- The client can't tell, a kit at nearly full health gives less than 25
huntersGlee_StatPickups = {
    item_healthkit = true,
    item_healthvial = true,
    item_battery = true,
}
