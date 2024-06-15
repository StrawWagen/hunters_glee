local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

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

    timer.Simple( delay, function()
        if not IsValid( ply ) then return end
        --print( ply, toPurchase )
        local purchasable, notPurchasableReason = self:canPurchase( ply, toPurchase )
        if not purchasable then
            if not notPurchasableReason then return end
            ply:PrintMessage( HUD_PRINTTALK, notPurchasableReason )
            return
        end

        local dat = self.shopItems[toPurchase]
        local purchaseFunc = dat.purchaseFunc
        if purchaseFunc then
            if isfunction( purchaseFunc ) then
                local noErrors, _ = xpcall( purchaseFunc, errorCatchingMitt, ply, toPurchase )
                if noErrors == false then
                    self:invalidateShopItem( toPurchase )
                    print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s purchaseFunc function errored!!!!!!!!!!!" )
                    return

                end
            elseif purchaseFunc ~= true then
                return

            end
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

        -- increment purchase count.. AFTER the cost is calculated...
        local name = "huntersglee_purchasecount_" .. toPurchase
        -- use nw2 because this will never be set when player is not valid clientside
        local oldCount = ply:GetNW2Int( name, 0 )
        if oldCount == 0 then
            -- clean this up when round restarts
            self:RunFunctionOnProperCleanup( function() ply:SetNW2Int( name, 0 ) end, ply )

        end
        ply:SetNW2Int( name, oldCount + 1 )

        if game.IsDedicated() then
            -- 'log' shop item purchases 
            local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
            print( nameAndId .. " Bought: " .. dat.name  )

        end
    end )
end

function GM:RefundShopItemCooldown( ply, toPurchase )
    GAMEMODE:noShopCooldown( ply, toPurchase )
    net.Start( "glee_invalidateshopcooldown" )
        net.WriteString( toPurchase )
    net.Send( ply )

end

function GM:CloseShopOnPly( ply )
    net.Start( "glee_closetheshop" )
    net.Send( ply )

end

concommand.Add( "termhunt_purchase", function( ply, _, args, _ )
    GAMEMODE:purchaseItem( ply, args[1] )

end )

hook.Add( "PlayerSpawn", "glee_closeshopwhenspawning", function( spawned )
    net.Start( "glee_closetheshop" )
    net.Send( spawned )

end )

hook.Add( "PlayerDeath", "glee_closeshopwhendead", function( died )
    net.Start( "glee_closetheshop" )
    net.Send( died )

end )