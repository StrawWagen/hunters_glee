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

-- yes, you can just add shop items!
function GM:getDebugShopItemStructureTable()
    -- example item
    local theItemTable = {
        [ "slams" ] = {
            name = "Slams",
            desc = "Some slams, 17 to be exact.",
            cost = 80,
            markup = 2,
            cooldown = 1,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 0,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = slamsPurchase,
        }
    }
    local theDescriptorTable = {
        -- all fields should be identical on server/client
        [ "shopItemUniqueIdentifier" ] = {
            name =              "Printed name that players see",
            desc =              "Description. Accepts a function or string.",
            cost =              "Cost, negative to give player score when purchasing, Accepts a function.",
            can_goindebt =      "Optional. Can this item be bought when the player has no score? Can force players to buy innate debuffs, etc.",
            fakeCost =          "Optional. Whether to skip applying the cost within the purchasing system. Good if you want a shop item to more dynamically apply costs, but still show a cost.",
            simpleCostDisplay = "Optional. Client. Skip the coloring + formatting of an item's cost in the shop.",
            markup =            "Optional. Price multipler to be applied when bought during the hunt, motivates people buy when the round's setting up.",
            markupPerPurchase = "Optional. Additional markup per player per purchase of item. Makes items less and less worth it.",
            cooldown =          "Optional. Cooldown between purchases, math.huge for one purchase per round. Can be a number, or a function.",
            category =          "What to place this with in the shop. Innate, Undead, etc.",
            purchaseTimes =     "Item will only be purchasble in the round states specified by this table. Eg GAMEMODE.ROUND_ACTIVE ( hunting ).",
            weight =            "Optional. Where to order this relative to everything else in our category, accepts negative values.",
            purchaseCheck =     "Optional. Function or table of functions checked to see if this is purchasable, ran clientside on every item, every frame when shop is open. ran once serverside when purchased",
            purchaseFunc =      "Server. What function to run when the item is bought.",
            canShowInShop =     "Optional. Can this be seen in the shop? also prevents purchases. Accepts a single function, or a table of functions."
        }
    }
    return theItemTable, theDescriptorTable

end

local function addShopFail( shopItemIdentifier, reason )
    ErrorNoHaltWithStack( "HUNTER'S GLEE: GAMEMODE:addShopItem( " .. shopItemIdentifier .. ", \"shopItemData\" ) failed for reason... " .. reason )

end

-- add VIA this function!
function GM:addShopItem( shopItemIdentifier, shopItemData )
    -- check all the non-optional stuff
    if not istable( shopItemData ) then addShopFail( shopItemIdentifier, "data table is not a table" ) return end
    if not shopItemData.name then addShopFail( shopItemIdentifier, "invalid .name" ) return end
    if not shopItemData.desc then addShopFail( shopItemIdentifier, "invalid .desc ( description )" ) return end
    if not shopItemData.cost then addShopFail( shopItemIdentifier, "invalid .cost" ) return end
    if not shopItemData.category then addShopFail( shopItemIdentifier, "invalid .category, create a new category first?" ) return end
    if not shopItemData.purchaseTimes or table.Count( shopItemData.purchaseTimes ) <= 0 then addShopFail( shopItemIdentifier, ".purchaseTimes are not specified" ) return end
    if not shopItemData.purchaseFunc then addShopFail( shopItemIdentifier, "invalid .purchaseFunc" ) return end

    GAMEMODE.shopItems[shopItemIdentifier] = shopItemData

end

function GM:invalidateShopItem( identifier )
    GAMEMODE.invalidShopItems[identifier] = true
    if SERVER then --????


    end
end

function GM:addShopCategory( shopCategoryName, shopCategoryData )
    GAMEMODE.shopCategories[shopCategoryName] = shopCategoryData

end

function GM:GetShopItemData( identifier )
    local dat = GAMEMODE.shopItems[ identifier ]
    if not istable( dat ) then return end
    return dat

end
function GM:GetShopCategoryData( identifier )
    local dat = GAMEMODE.shopCategories[ identifier ]
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
    -- use nw2bool because this will never be set when player is not valid.. right?
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
    local costRaw = dat.cost
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

local timeTranslations = {
    [-1] = "No navmesh", -- tell people to install a navmesh
    [0]  = "Initial setup", -- wait until the navmesh has definitely spawned
    [1]  = "Hunting", -- death has consequences and score can accumulate
    [2]  = "Preparation", -- let players run around and prevent death
    [3]  = "Podium", -- just display winners
}

local function badTimeReasonTranslation( currentTime, validStages )
    local currentTimeTranslation = timeTranslations[ currentTime ]

    validTranslations = {}
    for _, validStage in pairs( validStages ) do
        table.insert( validTranslations, timeTranslations[ validStage ] )

    end

    local validStageTranslationsString = table.concat( validTranslations, "\n" )

    return "This can't be bought during the " .. currentTimeTranslation .. " stage. \nValid stages are \n" .. validStageTranslationsString

end



local REASON_ERROR = "ERROR"
local REASON_INVALID = "That isn't a real thing for sale."
local REASON_POOR = "You are too poor to afford this."
local REASON_DEBT = "You can't buy this.\nYou're in Debt."
local REASON_SKULLPOOR = "You need more skulls to buy this."
local REASON_SKULLDEBT = "You can't buy this, You're in Skull debt."

-- shared!

function GM:canPurchase( ply, toPurchase )
    if not toPurchase or toPurchase == "" then return end
    local dat = GAMEMODE:GetShopItemData( toPurchase )
    if not dat then GAMEMODE:invalidateShopItem( _, toPurchase ) return false, REASON_INVALID end

    local catData = GAMEMODE:GetShopCategoryData( dat.category )
    if not catData then return false, REASON_INVALID end

    local categoryCanShow = catData.canShowInShop
    if isfunction( categoryCanShow ) then
        categoryCanShow = { categoryCanShow }

    end
    if istable( categoryCanShow ) then
        for _, theCurrentShowFunc in ipairs( categoryCanShow ) do
            local noErrors, returned = xpcall( theCurrentShowFunc, errorCatchingMitt, ply )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( toPurchase )
                print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s canShowInShop function errored!!!!!!!!!!!" )
                return nil, REASON_ERROR

            else
                if returned ~= true then return nil, "that shop item isn't for sale!" end

            end
        end
    end

    local canEvenShow = dat.canShowInShop
    if isfunction( canEvenShow ) then
        canEvenShow = { canEvenShow }

    end
    if istable( canEvenShow ) then
        for _, theCurrentShowFunc in ipairs( canEvenShow ) do
            local noErrors, returned = xpcall( theCurrentShowFunc, errorCatchingMitt, ply )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( toPurchase )
                print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s canShowInShop function errored!!!!!!!!!!!" )
                return nil, REASON_ERROR

            else
                if returned ~= true then return nil, "that shop item isn't for sale!" end

            end
        end
    end

    -- do this first
    local checkFunc = dat.purchaseCheck
    if isfunction( checkFunc ) then
        checkFunc = { checkFunc }

    end
    if istable( checkFunc ) then
        for _, theCurrentCheckFunc in ipairs( checkFunc ) do
            local noErrors, returned, reason = xpcall( theCurrentCheckFunc, errorCatchingMitt, ply )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( toPurchase )
                print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s purchaseCheck function errored!!!!!!!!!!!" )
                return nil, REASON_ERROR

            else
                if returned == true then continue end
                return nil, reason

            end
        end
    end

    local nextPurchase = ply.shopItemCooldowns[toPurchase] or -20000
    if nextPurchase == math.huge then return nil, "You've already bought this." end

    local score = ply:GetScore()
    local cost = GAMEMODE:shopItemCost( toPurchase, ply )
    local canGoInDebt = dat.can_goindebt

    -- account for negative cost
    local costsTooMuch = score < cost and not canGoInDebt

    if cost >= 0 and costsTooMuch and cost ~= 0 then
        local cannotBuyReason = REASON_POOR
        if score < 0 then
            cannotBuyReason = REASON_DEBT

        end
        return nil, cannotBuyReason

    end

    local skullCost = GAMEMODE:shopItemSkullCost( toPurchase, ply )
    if skullCost then
        local skulls = ply:GetSkulls()
        local skullCostsTooMuch = skulls < skullCost and not canGoInDebt
        if skullCost >= 0 and skullCostsTooMuch and skullCost ~= 0 then
            local cannotBuySkullsReason = REASON_SKULLPOOR
            if score < 0 then
                cannotBuySkullsReason = REASON_SKULLDEBT

            end
            return nil, cannotBuySkullsReason

        end
    end

    if nextPurchase > CurTime() then
        local nextPurchasePresentable = math.Round( math.abs( nextPurchase - CurTime() ), 1 )
        local cooldownReason = "Cooldown, Purchasable in " .. tostring( nextPurchasePresentable )
        return nil, cooldownReason

    end

    local hookResult, notPurchasableReason = hook.Run( "glee_blockpurchaseitem", ply, self.itemIdentifier )

    if hookResult then return nil, notPurchasableReason end

    local currState = GAMEMODE:RoundState()
    local times = dat.purchaseTimes
    local goodTime = table.HasValue( times, currState )
    if not goodTime then return nil, badTimeReasonTranslation( currState, times ) end

    return true, ""

end

local shopEnabled = CreateConVar( "huntersglee_enableshop", 1, FCVAR_REPLICATED, "Enables the shop.", 0, 1 )

hook.Add( "glee_blockpurchaseitem", "glee_shopdisable", function()
    if not shopEnabled:GetBool() then return true, "The shop is disabled." end

end )