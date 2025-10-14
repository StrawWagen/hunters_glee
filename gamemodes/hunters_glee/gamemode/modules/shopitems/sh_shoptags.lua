local GM = GAMEMODE or GM
--local shopHelpers = GM.shopHelpers

hook.Add( "glee_PostShopItemPurchased", "glee_generictageffects", function( ply, _toPurchase, data )
    local tags = data.tags
    if tags["CloseShopOnPurchase"] then
        GAMEMODE:CloseShopOnPly( ply )

    end
end )