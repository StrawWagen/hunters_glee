
function GM:sendPurchaseConfirm( ply, cost, toPurchase )
    net.Start( "glee_confirmpurchase" )
        net.WriteFloat( cost )
        if toPurchase then
            net.WriteBool( true )
            net.WriteString( toPurchase )

        else
            net.WriteBool( false )

        end
    net.Send( ply )
end

function GM:purchaseItem( ply, toPurchase )
    local delay = 100 - ply:GetSignalStrength()
    delay = delay / 200

    timer.Simple( delay, function() -- delay purchase since people could get around the shop loading with the console command
        if not IsValid( ply ) then return end

        --print( ply, toPurchase )
        local purchasable, notPurchasableReason = self:canPurchase( ply, toPurchase )
        if not purchasable then
            if not notPurchasableReason then return end
            if ply:IsBot() then
                print( notPurchasableReason ) -- we need to know WHY!!!

            else
                ply:PrintMessage( HUD_PRINTTALK, notPurchasableReason )

            end
            hook.Run( "glee_CouldntPurchase", ply, toPurchase, notPurchasableReason )
            return

        end

        local dat = self.shopItems[toPurchase]

        local noErrors, _ = ProtectedCall( function( dat2, ply2 )
            dat2.svOnPurchaseFunc( ply2, toPurchase )
        end, dat, ply )

        if not noErrors then
            self:invalidateShopItem( toPurchase )

        end

        local theCooldown
        if dat.cooldown then
            theCooldown = self:translateShopItemCooldown( ply, toPurchase, dat.cooldown )

        end
        if theCooldown and theCooldown > 0 then
            self:doShopCooldown( ply, toPurchase, theCooldown )

            net.Start( "glee_sendshopcooldowntoplayer" )
                local cooldownClamped = math.Clamp( theCooldown, 0, 2147483645 ) -- if cooldown == 2147483645 then assume infinite, and only allow one purchase per round.
                net.WriteFloat( cooldownClamped )
                net.WriteString( toPurchase )
            net.Send( ply )

        end

        local cost = self:shopItemCost( toPurchase, ply )

        -- cool purchase sound, kaching!
        self:sendPurchaseConfirm( ply, cost, toPurchase )

        if not dat.fakeCost then
            ply:GivePlayerScore( -cost )

        end

        local skullCost = self:shopItemSkullCost( toPurchase, ply )
        if skullCost then
            ply:GivePlayerSkulls( -skullCost )

        end

        -- increment purchase count.. AFTER the cost is calculated...
        local name = "huntersglee_purchasecount_" .. toPurchase
        -- use nw2 because this will never be set when player is not valid clientside
        local oldCount = ply:GetNW2Int( name, 0 )
        local newCount = oldCount + 1

        ply:SetNW2Int( name, newCount )

        ply.glee_ShopItemPurchaseCounts = ply.glee_ShopItemPurchaseCounts or {}
        ply.glee_ShopItemPurchaseCounts[name] = newCount

        if game.IsDedicated() then -- 'log' shop item purchases 
            local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
            print( nameAndId .. " Bought: " .. dat.name  )

        end

        hook.Run( "glee_PostShopItemPurchased", ply, toPurchase, dat )

    end )
end

hook.Add( "huntersglee_player_reset", "glee_shophandler_resetpurchasecounts", function( ply )
    local counts = ply.glee_ShopItemPurchaseCounts
    if not counts then return end

    for name, _count in pairs( counts ) do
        ply:SetNW2Int( name, 0 )

    end
    counts = {}

end )


function GM:RefundShopItemCooldown( ply, toPurchase )
    GAMEMODE:noShopCooldown( ply, toPurchase )
    net.Start( "glee_invalidateshopcooldown" )
        net.WriteString( toPurchase )
    net.Send( ply )

end


concommand.Add( "termhunt_purchase", function( ply, _, args, _ )
    GAMEMODE:purchaseItem( ply, args[1] )

end )

concommand.Add( "termhunt_bots_purchase", function( ply, _, args, _ )
    if not ply:IsAdmin() then return end
    local bots = player.GetBots()
    if #bots <= 0 then return end
    for _, bot in ipairs( bots ) do
        GAMEMODE:purchaseItem( bot, args[1] )

    end
end, nil, "Makes all bots attempt to purchase the specified shop item." )


function GM:CloseShopOnPly( ply )
    net.Start( "glee_closetheshop" )
    net.Send( ply )

end

-- time for new shop categories, close shop because it's not setup to refresh categories
hook.Add( "PlayerSpawn", "glee_closeshopwhenspawning", function( spawned )
    net.Start( "glee_closetheshop" )
    net.Send( spawned )

end )
hook.Add( "PlayerDeath", "glee_closeshopwhendead", function( died )
    net.Start( "glee_closetheshop" )
    net.Send( died )

end )