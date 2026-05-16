local GM = GAMEMODE or GM
--local shopHelpers = GM.shopHelpers

hook.Add( "glee_PostShopItemPurchased", "glee_generictageffects", function( ply, _toPurchase, data )
    local tags = data.tags
    if tags["CloseShopOnPurchase"] then
        GAMEMODE:CloseShopOnPly( ply )

    end
end )

hook.Add( "glee_shop_canpurchase", "glee_shoptags_unpurchaseable", function( _, itemData )
    if itemData.tags.unpurchaseable then return false, itemData.unpurchaseableReason or "This item cannot be purchased" end

end )
