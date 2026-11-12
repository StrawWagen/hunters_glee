-- Items sharing a .slots entry are mutually exclusive, owning one blocks buying the others for the round.

-- don't cache a slot index here
-- items can reach GAMEMODE.shopItems without glee_shopitemadded firing, see GM:GobbleShopItems
-- and autorefreshing this file would wipe the cache while the items stay
local function sharesASlot( slots, otherData )
    if not otherData.slots then return false end

    for _, slot in ipairs( slots ) do
        for _, otherSlot in ipairs( otherData.slots ) do
            if slot == otherSlot then return true end

        end
    end
    return false

end

hook.Add( "glee_shop_canpurchase", "glee_shopslots_exclusive", function( purchaser, itemData )
    if not itemData.slots then return end

    for identifier, otherData in pairs( GAMEMODE.shopItems ) do
        if identifier == itemData.identifier then continue end
        if not sharesASlot( itemData.slots, otherData ) then continue end
        if GAMEMODE:purchaseCount( purchaser, identifier ) <= 0 then continue end

        local ownedName = string.Replace( otherData.name, "\n", " " )
        return false, "Incompatible with " .. ownedName

    end
end )
