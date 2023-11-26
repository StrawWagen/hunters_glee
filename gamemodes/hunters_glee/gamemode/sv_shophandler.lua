local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

function GM:purchaseItem( ply, toPurchase )
    --print( ply, toPurchase )
    local purchasable, notPurchasableReason = GAMEMODE:canPurchase( ply, toPurchase )
    if not purchasable then
        ply:PrintMessage( HUD_PRINTTALK, notPurchasableReason )
        return
    end
    local dat = GAMEMODE.shopItems[toPurchase]
    local purchaseFunc = dat.purchaseFunc
    if purchaseFunc then
        if isfunction( purchaseFunc ) then
            local noErrors, _ = xpcall( purchaseFunc, errorCatchingMitt, ply, toPurchase )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( toPurchase )
                print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s purchaseFunc function errored!!!!!!!!!!!" )
                return

            end
        elseif purchaseFunc ~= true then
            return

        end
    end

    local theCooldown
    if dat.cooldown then
        theCooldown = GAMEMODE:translateShopItemCooldown( ply, toPurchase, dat.cooldown )

    end
    if theCooldown and theCooldown > 0 then
        GAMEMODE:doShopCooldown( ply, toPurchase, theCooldown )

        net.Start( "glee_sendshopcooldowntoplayer" )
            local cooldownClamped = math.Clamp( theCooldown, 0, 2147483645 ) -- if cooldown == 2147483645 then assume infinite, and only allow one purchase per round.
            net.WriteFloat( cooldownClamped )
            net.WriteString( toPurchase )
        net.Send( ply )

    end

    local cost = GAMEMODE:shopItemCost( toPurchase, ply )

    -- cool purchase sound, kaching!
    net.Start( "glee_confirmpurchase" )
        net.WriteFloat( cost )
        net.WriteString( toPurchase )
    net.Send( ply )

    ply:GivePlayerScore( -cost )

    -- increment purchase count.. AFTER the cost is calculated...
    local name = "huntersglee_purchasecount_" .. toPurchase
    -- use nw2 because this will never be set when player is not valid clientside
    local oldCount = ply:GetNW2Int( name, 0 )
    if oldCount == 0 then
        -- clean this up when round restarts
        GAMEMODE:RunFunctionOnProperCleanup( function() ply:SetNW2Int( name, 0 ) end, ply )

    end
    ply:SetNW2Int( name, oldCount + 1 )

    if game.IsDedicated() then
        -- 'log' shop item purchases 
        local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
        print( nameAndId .. " Bought: " .. dat.name  )

    end
end

local function autoComplete( _, stringargs )
    local items = table.GetKeys( GAMEMODE.shopItems )

    --- Trim the arguments & make them lowercase.
    stringargs = string.Trim( stringargs:lower() )

    --- Create a new table.
    local tbl = {}
    for _, item in pairs( items ) do
        if item:lower():find( stringargs ) then
            --- Add the player's name into the auto-complete.
            theComplete = "termhunt_purchase \"" .. item .. "\""
            table.insert( tbl, theComplete )

        end
    end
    --- Return the table for auto-complete.
    return tbl

end

concommand.Add( "termhunt_purchase", function( ply, _, args, _ )
    GAMEMODE:purchaseItem( ply, args[1] )

end, autoComplete, "purchase an item", FCVAR_NONE )

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