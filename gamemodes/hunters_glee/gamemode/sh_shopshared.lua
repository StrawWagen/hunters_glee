include( "sh_shopitems.lua" )

if SERVER then
    include( "sv_shophandler.lua" )


elseif CLIENT then

    local purchaseSound = Sound( "209578_zott820_cash-register-purchase.wav" )
    local takeSound = Sound( "buttons/lever7.wav" )
    local getSound = Sound( "buttons/button6.wav" )

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
        if cost > 0 then
            local pitch = 100 + math.abs( cost - 100 )
            LocalPlayer():EmitSound( purchaseSound, 60, pitch, 0.50 )
        elseif cost == 0 then
            LocalPlayer():EmitSound( takeSound, 60, 120, 0.50 )
        elseif cost < 0 then
            LocalPlayer():EmitSound( getSound, 60, 120, 0.50 )
        end

        local isId = net.ReadBool()
        if not isId then return end

        local itemId = net.ReadString()
        if itemId == "" then return end

        hook.Run( "glee_cl_confirmedpurchase", LocalPlayer(), itemId )
        LocalPlayer().glee_DefinitelyPurchasedSomething = true

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

end

-- all below is shared

function GM:SetupShop()
    GAMEMODE.shopItems = {}
    GAMEMODE.shopCategories = {}
    GAMEMODE.invalidShopItems = {}

end

function GM:GetShopItemData( identifier )
    local dat = GAMEMODE.shopItems[ identifier ]
    if not istable( dat ) then return end
    return dat

end

local white = Vector( 255,255,255 )
local red = Color( 220,0,0 )
local yellow = Color( 255,255,0 )
local sadGreen = Color( 106,190,9 )

-- take cost number
-- return string that accurately describes what its gonna do
-- also return color
-- so cost -50 would be '+50' and yellow because it would give players 50 score for buying
-- cost 50 would be '-50' and depending on whether player can afford, green or red.
-- it reverses the number i know, it's stupid
function GM:translatedShopItemCost( purchaser, cost, compareType, identifier )

    if not cost then return "", white end

    local color = white
    local preTextSymbol = ""
    local theCost = ""
    local compareVal
    if compareType == "score" then
        compareVal = purchaser:GetScore()

    elseif compareType == "skull" then
        compareVal = purchaser:GetSkulls()

    end

    -- add difference between "not enough money" and "you bought this already"
    if identifier and purchaser and purchaser.shopItemCooldowns[ identifier ] == math.huge then
        return "---", white

    end

    if cost > 0 then
        preTextSymbol = "-"
        theCost = tostring( math.abs( cost ) )

        canAfford = ( compareVal + -cost ) >= 0

        if not canAfford then
            color = red

        else
            color = sadGreen

        end

    elseif cost < 0 then
        preTextSymbol = "+"
        theCost = tostring( math.abs( cost ) )
        color = yellow

    elseif cost == 0 then
        theCost = "N/A"
        color = white

    end

    local outString = preTextSymbol .. theCost

    return outString, color

end

function GM:purchaseCount( purchaser, toPurchase )
    local name = "huntersglee_purchasecount_" .. toPurchase
    -- use nw2int because this will never be set when player is not valid.. right?
    return purchaser:GetNW2Int( name, 0 )

end

function GM:shopMarkup( purchaser, toPurchase )
    local dat = GAMEMODE:GetShopItemData( toPurchase )
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

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

function GM:shopItemCost( toPurchase, purchaser )
    if not toPurchase then return end
    local dat = GAMEMODE:GetShopItemData( toPurchase )
    if not dat then return 0 end
    local costRaw = dat.shCost
    local cost = nil

    if isfunction( costRaw ) then
        local noErrors, returned = xpcall( costRaw, errorCatchingMitt, purchaser )
        if noErrors == false then
            GAMEMODE:invalidateShopItem( toPurchase )
            print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s cost function errored!!!!!!!!!!!" )
            return 0

        else
            cost = returned

        end
    else
        cost = costRaw
    end

    if not isnumber( cost ) then
        cost = 0

    end

    cost = cost * GAMEMODE:shopMarkup( purchaser, toPurchase )
    return math.Round( cost )

end

function GM:shopItemSkullCost( toPurchase, purchaser )
    if not toPurchase then return end
    local dat = GAMEMODE:GetShopItemData( toPurchase )
    if not dat then return end
    local skullCostRaw = dat.skullCost
    if not skullCostRaw then return end
    local skullCost = nil

    if isfunction( skullCostRaw ) then
        local noErrors, returned = xpcall( skullCostRaw, errorCatchingMitt, purchaser )
        if noErrors == false then
            GAMEMODE:invalidateShopItem( toPurchase )
            print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s SKULL cost function errored!!!!!!!!!!!" )
            return 0

        else
            skullCost = returned

        end
    else
        skullCost = skullCostRaw

    end

    if not skullCost then return end

    skullCost = skullCost * GAMEMODE:shopMarkup( purchaser, toPurchase )
    return math.Round( skullCost )

end

function GM:translateShopItemCooldown( ply, toPurchase, cooldownRaw )
    if not cooldownRaw then return end
    local cooldown = 0
    if isnumber( cooldownRaw ) then
        cooldown = cooldownRaw

    elseif isfunction( cooldownRaw ) then
        local noErrors, returned = xpcall( cooldownRaw, errorCatchingMitt, ply )
        if noErrors == false then
            GAMEMODE:invalidateShopItem( toPurchase )
            print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s cooldown function errored!!!!!!!!!!!" )
            return

        elseif not isnumber( returned ) and returned ~= nil then -- can be nil for no cooldown
            GAMEMODE:invalidateShopItem( toPurchase )
            print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s cooldown function returned a non-number!!!!!!!!!!!" )
            return

        else
            cooldown = returned

        end
    end
    return cooldown

end

function GM:translateShopItemDescription( ply, toPurchase, descriptionRaw )
    if not descriptionRaw then return end
    local description = ""
    if isstring( descriptionRaw ) then
        description = descriptionRaw

    elseif isfunction( descriptionRaw ) then
        local noErrors, returned = xpcall( descriptionRaw, errorCatchingMitt, ply )
        if noErrors == false then
            GAMEMODE:invalidateShopItem( toPurchase )
            print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s description function errored!!!!!!!!!!!" )
            return

        elseif not isstring( returned ) then -- description cannot be nil.
            GAMEMODE:invalidateShopItem( toPurchase )
            print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s description function returned a non-string!!!!!!!!!!!" )
            return

        else
            description = returned

        end
    end
    return description

end

function GM:doShopCooldown( ply, toPurchase, cooldown )
    if not isnumber( cooldown ) or cooldown <= 0 then return end
    ply.shopItemCooldowns[toPurchase] = CurTime() + cooldown

end

function GM:noShopCooldown( ply, toPurchase )
    ply.shopItemCooldowns[toPurchase] = 0

end

local shopEnabled = CreateConVar( "huntersglee_enableshop", 1, FCVAR_REPLICATED, "Enables the shop.", 0, 1 )

hook.Add( "glee_blockpurchaseitem", "glee_shopdisable", function()
    if not shopEnabled:GetBool() then return true, "The shop is disabled." end

end )