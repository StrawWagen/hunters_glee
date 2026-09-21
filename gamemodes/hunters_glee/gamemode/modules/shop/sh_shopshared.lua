
if CLIENT then

    local purchaseSound = Sound( "hunters_glee/209578_zott820_cash-register-purchase.wav" )
    local takeSound = Sound( "buttons/lever7.wav" )
    local getSound = Sound( "buttons/button6.wav" )
    local debtSound = Sound( "buttons/combine_button2.wav" )

    local nextResetShopCooldownsRecieve = 0

    net.Receive( "glee_resetplayershopcooldowns", function()
        if nextResetShopCooldownsRecieve > CurTime() then return end
        nextResetShopCooldownsRecieve = CurTime() + 0.01

        LocalPlayer().shopItemCooldowns = {}

    end )

    local nextRecieveShopCooldown = 0

    net.Receive( "glee_sendshopcooldowntoplayer", function()

        if nextRecieveShopCooldown > CurTime() then return end
        nextRecieveShopCooldown = CurTime() + 0.01

        local cooldown = net.ReadFloat()
        cooldown = math.Round( cooldown, 2 )
        if cooldown >= 2147483645 then
            cooldown = math.huge
        end
        local toPurchase = net.ReadString()

        GAMEMODE:doShopCooldown( LocalPlayer(), toPurchase, cooldown )

    end )

    local nextInvalidateShopCooldown = 0

    net.Receive( "glee_invalidateshopcooldown", function()

        if nextInvalidateShopCooldown > CurTime() then return end
        nextInvalidateShopCooldown = CurTime() + 0.01

        local toPurchase = net.ReadString()

        GAMEMODE:noShopCooldown( LocalPlayer(), toPurchase )

    end )

    net.Receive( "glee_confirmpurchase", function()
        local cost = net.ReadFloat()
        local us = LocalPlayer()

        if cost > 0 then
            local pitch = 100 + math.abs( cost - 100 )
            us:EmitSound( purchaseSound, 60, pitch, 0.50 )

        elseif cost == 0 then
            us:EmitSound( takeSound, 60, 120, 0.50 )

        elseif cost < 0 then
            us:EmitSound( getSound, 60, 120, 0.50 )

        end

        local isId = net.ReadBool()
        if not isId then return end

        local itemId = net.ReadString()
        if itemId == "" then return end

        local itemData = GAMEMODE:GetShopItemData( itemId )
        if itemData and itemData.canGoInDebt and cost < 0 and us:GetScore() < 0 then
            us:EmitSound( debtSound, 60, 120, 0.50 )

        end

        hook.Run( "glee_cl_confirmedpurchase", us, itemId )
        us.glee_DefinitelyPurchasedSomething = true

    end )

    local function autoComplete( _, stringargs )
        local items = table.GetKeys( GAMEMODE.shopItems )

        --- Trim the arguments & make them lowercase.
        stringargs = string.Trim( stringargs:lower() )

        --- Create a new table.
        local tbl = {}
        for _, item in pairs( items ) do
            if item:lower():find( stringargs ) then
                --- Add the player's name into the auto-complete.
                theComplete = "cl_termhunt_purchase \"" .. item .. "\""
                table.insert( tbl, theComplete )

            end
        end
        --- Return the table for auto-complete.
        return tbl

    end

    -- ew ew gross formatting
    concommand.Add( "cl_termhunt_purchase", function( _, _, args, _ )
        RunConsoleCommand( "termhunt_purchase", args[1] )

    end, autoComplete, "purchase an item" )
    -- ew ew


    -- take cost number
    -- return string that accurately describes what its gonna do
    -- also return color
    -- so cost -50 would be '+50' and yellow because it would give players 50 score for buying
    -- cost 50 would be '-50' and depending on whether player can afford, green or red.
    -- it reverses the number i know, it's stupid
    function GM:translatedShopItemCost( purchaser, cost, compareType, identifier )
        local standards = GAMEMODE.shopStandards

        if not cost then return "", standards.shopCostNormal end

        local color = standards.shopCostNormal
        local preTextSymbol = ""
        local theCost = ""
        local compareVal
        if compareType == "score" then
            compareVal = purchaser:GetScore()

        elseif compareType == "skull" then
            compareVal = purchaser:GetSkulls()

        end

        -- add difference between "not enough money" and "you bought this already"
        if identifier and purchaser and purchaser.shopItemCooldowns[identifier] == math.huge then
            return "---", standards.shopCostNormal

        end

        if cost > 0 then
            preTextSymbol = "-"
            theCost = tostring( math.abs( cost ) )

            canAfford = ( compareVal + -cost ) >= 0

            if not canAfford then
                color = standards.shopCostTooPoor

            else
                color = standards.shopCostCanBuy

            end

        elseif cost < 0 then
            preTextSymbol = "+"
            theCost = tostring( math.abs( cost ) )
            color = standards.shopCostGivesMoney

        elseif cost == 0 then
            theCost = "N/A"
            color = standards.shopCostNormal

        end

        local outString = preTextSymbol .. theCost

        return outString, color

    end

end


-- all below is shared

function GM:GetShopItemData( identifier )
    local dat = GAMEMODE.shopItems[identifier]
    if not istable( dat ) then return end
    return dat

end

function GM:purchaseCount( purchaser, toPurchase )
    local name = "huntersglee_purchasecount_" .. toPurchase
    -- use nw2int because this will never be set when player is not valid.. right?
    return purchaser:GetNW2Int( name, 0 )

end

function GM:shopMarkup( purchaser, toPurchase )
    local dat = GAMEMODE:GetShopItemData( toPurchase )
    if not dat then return 1 end
    if not dat.markup then return 1 end
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE then
        if dat.markupPerPurchase then
            return dat.markup + dat.markupPerPurchase * GAMEMODE:purchaseCount( purchaser, toPurchase )

        else
            return dat.markup

        end
    end
    return 1
end

local shopHelpers = GM.shopHelpers

-- see shopHelpers.resolveItemField for what a spec is
local costSpec = {
    default = 0,
    check = isnumber,
    typeName = "number",
    markup = true,
    round = true,
    hook = "glee_shop_itemcostmul",
}

function GM:shopItemCost( toPurchase, purchaser )
    if not toPurchase then return end

    -- hook.Run( "glee_shop_itemcostmul", ply, itemData, adjust ) -- adjust.value is the marked-up shCost, adjust.mul scales it
    return shopHelpers.resolveItemField( toPurchase, "shCost", purchaser, costSpec )

end

-- nil, not 0. Nothing means no skull price, and the shop shows the score one instead
local skullCostSpec = {
    default = nil,
    check = isnumber,
    typeName = "number",
    markup = true,
    round = true,
    hook = "glee_shop_itemskullcostmul",
}

function GM:shopItemSkullCost( toPurchase, purchaser )
    if not toPurchase then return end
    if purchaser == nil then
        ErrorNoHaltWithStack( "GLEE: shopItemSkullCost has no purchaser for " .. tostring( toPurchase ) .. ", its markup can't be read\n" )
        return

    end

    -- hook.Run( "glee_shop_itemskullcostmul", ply, itemData, adjust ) -- adjust.value is the marked-up shSkullCost, adjust.mul scales it
    return shopHelpers.resolveItemField( toPurchase, "shSkullCost", purchaser, skullCostSpec )

end

local cooldownSpec = {
    default = nil, -- nil is a real answer here, it means no cooldown
    check = isnumber,
    typeName = "number",
    hook = "glee_shop_itemcooldownmul",
}

function GM:shopItemCooldown( ply, toPurchase )
    if not toPurchase then return end

    -- hook.Run( "glee_shop_itemcooldownmul", ply, itemData, adjust ) -- adjust.value is the cooldown, adjust.mul scales it
    return shopHelpers.resolveItemField( toPurchase, "cooldown", ply, cooldownSpec )

end

-- doShopCooldown takes whatever number it's handed. This runs glee_shop_itemcooldownmul over it
-- first, so a misery's multiplier reaches placables that re-arm themselves with their own number.
-- Leave cooldown out to use the item's own field.
function GM:applyShopItemCooldown( ply, toPurchase, cooldown )
    if cooldown then
        local itemData = GAMEMODE:GetShopItemData( toPurchase )
        if not itemData then return end

        cooldown = shopHelpers.runAdjustHook( toPurchase, cooldownSpec, ply, itemData, cooldown )

    else
        cooldown = self:shopItemCooldown( ply, toPurchase )

    end

    self:doShopCooldown( ply, toPurchase, cooldown )

end

local descriptionSpec = {
    default = "",
    check = isstring,
    typeName = "string",
    hook = "glee_shop_itemdescription",
}

function GM:shopItemDescription( ply, toPurchase )
    if not toPurchase then return end

    -- hook.Run( "glee_shop_itemdescription", ply, itemData, adjust ) -- adjust.value is the desc, write it to replace it
    return shopHelpers.resolveItemField( toPurchase, "desc", ply, descriptionSpec )

end

function GM:doShopCooldown( ply, toPurchase, cooldown )
    if not isnumber( cooldown ) or cooldown <= 0 then return end
    ply.shopItemCooldowns[toPurchase] = CurTime() + cooldown

    if not SERVER then return end
    net.Start( "glee_sendshopcooldowntoplayer" )
        local cooldownClamped = math.Clamp( cooldown, 0, 2147483645 ) -- if cooldown == 2147483645 then assume infinite, and only allow one purchase per round.
        net.WriteFloat( cooldownClamped )
        net.WriteString( toPurchase )
    net.Send( ply )

end

function GM:noShopCooldown( ply, toPurchase )
    ply.shopItemCooldowns[toPurchase] = 0

end

if SERVER then
    concommand.Add( "glee_test_resetcooldowns", function()
        GAMEMODE:ResetShopItemCooldowns()

    end, nil, "Reset all shop cooldowns", FCVAR_CHEAT )
end

local shopEnabled = CreateConVar( "huntersglee_enableshop", 1, FCVAR_REPLICATED, "Enables the shop.", 0, 1 )

hook.Add( "glee_blockpurchaseitem", "glee_shopdisable", function()
    if not shopEnabled:GetBool() then return true, "The shop is disabled." end

end )