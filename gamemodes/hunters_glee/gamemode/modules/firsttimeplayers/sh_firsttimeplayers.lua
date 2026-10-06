
-- first time players get one cheap Divine Intervention, granted and spent in sv_firsttimeplayers.lua
local discountedItem = "resurrection"
local discountMul = 0.5

function GM:HasFirstTimeDiscount( ply )
    return ply:GetNW2Bool( "glee_firsttime_divinediscount", false )

end

hook.Add( "glee_shop_itemcostmul", "glee_firsttime_divinediscount", function( ply, itemData, adjust )
    if itemData.identifier ~= discountedItem then return end
    if not GAMEMODE:HasFirstTimeDiscount( ply ) then return end

    adjust.mul = adjust.mul * discountMul

end )

hook.Add( "glee_shop_itemdescription", "glee_firsttime_divinediscount", function( ply, itemData, adjust )
    if itemData.identifier ~= discountedItem then return end
    if not GAMEMODE:HasFirstTimeDiscount( ply ) then return end

    adjust.value = "SALE, 50% OFF\n" .. adjust.value

end )

hook.Add( "glee_PostShopItemPurchased", "glee_firsttime_spenddivinediscount", function( ply, toPurchase )
    if toPurchase ~= "resurrection" then return end
    if not GAMEMODE:HasFirstTimeDiscount( ply ) then return end
    ply:SetNW2Bool( "glee_firsttime_divinediscount", false )

end )
