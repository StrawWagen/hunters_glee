-- Items sharing a .slots entry are mutually exclusive, owning one blocks buying the others for the round.

local itemsInSlot = {} -- [slot] = { [identifier] = true }

hook.Add( "glee_shopitemadded", "glee_shopslots_index", function( identifier, itemData )
    -- re-added items may have changed their slots
    for _, slotItems in pairs( itemsInSlot ) do
        slotItems[identifier] = nil

    end

    if not itemData.slots then return end

    for _, slot in ipairs( itemData.slots ) do
        itemsInSlot[slot] = itemsInSlot[slot] or {}
        itemsInSlot[slot][identifier] = true

    end
end )

hook.Add( "glee_shop_canpurchase", "glee_shopslots_exclusive", function( purchaser, itemData )
    if not itemData.slots then return end

    for _, slot in ipairs( itemData.slots ) do
        for identifier in pairs( itemsInSlot[slot] ) do
            if identifier == itemData.identifier then continue end
            if GAMEMODE:purchaseCount( purchaser, identifier ) <= 0 then continue end

            local ownedData = GAMEMODE:GetShopItemData( identifier )
            local ownedName = ownedData and string.Replace( ownedData.name, "\n", " " ) or identifier
            return false, "Incompatible with " .. ownedName

        end
    end
end )
