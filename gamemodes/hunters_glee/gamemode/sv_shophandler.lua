function GM:purchaseItem( ply, argStr )
    --print( ply, argStr )
    local purchasable, notPurchasableReason = GAMEMODE:canPurchase( ply, argStr )
    if not purchasable then
        ply:PrintMessage( HUD_PRINTTALK, notPurchasableReason )
        return
    end
    local dat = GAMEMODE.shopItems[argStr]
    local purchaseFunc = dat.purchaseFunc
    if purchaseFunc then
        if isfunction( purchaseFunc ) then
            local noErrors, _ = pcall( purchaseFunc, ply )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( argStr )
                ErrorNoHaltWithStack( argStr .. "'s purchaseFunc function errored." )
                return

            end
        elseif purchaseFunc ~= true then
            return

        end
    end

    local name = "huntersglee_purchasecount_" .. argStr
    -- use nw2 because this will never be set when player is not valid clientside
    local oldCount = ply:GetNW2Int( name, 0 )
    if oldCount == 0 then
        -- clean this up when round restarts
        GAMEMODE:RunFunctionOnProperCleanup( function() ply:SetNW2Int( name, 0 ) end, ply )

    end
    ply:SetNW2Int( name, oldCount + 1 )

    if dat.cooldown and dat.cooldown > 0 then
        GAMEMODE:doShopCooldown( ply, argStr, dat.cooldown )

        net.Start( "sendshopcooldowntoplayer" )
            local cooldownClamped = math.Clamp( dat.cooldown, 0, 2147483645 ) -- if cooldown == 2147483645 then assume infinite, and only allow one purchase per round.
            net.WriteFloat( cooldownClamped )
            net.WriteString( argStr )
        net.Send( ply )

    end

    local cost = GAMEMODE:shopItemCost( argStr, ply )

    net.Start( "gleeconfirmpurchase" )
        net.WriteFloat( cost )
        net.WriteString( argStr )
    net.Send( ply )

    ply:GivePlayerScore( -cost )

    if game.IsDedicated() then
        -- 'log' shop item purchases 
        local nameAndId = ply:GetName() .. "[" .. ply:SteamID() .. "]"
        print( nameAndId .. " Bought: " .. dat.name  )

    end
end

local function autoComplete( cmd, stringargs )
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