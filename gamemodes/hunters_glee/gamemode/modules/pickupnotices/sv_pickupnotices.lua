-- Health and armor pickups say what they gave, "Health +25", see sh_pickupnotices.lua

-- Notices by what went up, each with the icon of what usually gives it
local function notifyGain( ply, text, gained, iconClass )
    if gained <= 0 then return end

    huntersGlee_Notify( { ply }, {
        text = { alive = text .. " +{num}" },
        iconWeapon = { alive = iconClass },
        addNum = gained,
        time = huntersGlee_PickupNoticeTime,
    } )
end

-- No hook after a pickup, so it's whatever went up by the next tick.
-- One check for everything picked up this tick, each item's before is after the last one's
hook.Add( "PlayerCanPickupItem", "glee_statpickupnotices", function( ply, item )
    if not huntersGlee_StatPickups[item:GetClass()] then return end
    if ply.glee_statPickupBefore then return end

    ply.glee_statPickupBefore = { health = ply:Health(), armor = ply:Armor() }

    timer.Simple( 0, function()
        if not IsValid( ply ) then return end

        local before = ply.glee_statPickupBefore
        ply.glee_statPickupBefore = nil

        notifyGain( ply, "Health", ply:Health() - before.health, "item_healthkit" )
        notifyGain( ply, "Suit", ply:Armor() - before.armor, "item_battery" )

    end )
end )
