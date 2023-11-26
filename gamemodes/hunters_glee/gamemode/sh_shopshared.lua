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
        local itemId = net.ReadString()
        if cost > 0 then
            local pitch = 100 + math.abs( cost - 100 )
            LocalPlayer():EmitSound( purchaseSound, 60, pitch, 0.50 )
        elseif cost == 0 then
            LocalPlayer():EmitSound( takeSound, 60, 120, 0.50 )
        elseif cost < 0 then
            LocalPlayer():EmitSound( getSound, 60, 120, 0.50 )
        end

        hook.Run( "glee_cl_confirmedpurchase", LocalPlayer(), itemId )
        LocalPlayer().glee_DefinitelyPurchasedSomething = true

    end )
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
        [ "shopItemUniqueIdentifier" ] = {
            name = "Printed name that players see",
            desc = "Description",
            cost = "Cost, negative to give player score when purchasing, Can be a function",
            markup = "Optional. Price multipler to be applied when bought out of setup",
            markupPerPurchase = "Optional. additional markup per player per purchase of item",
            cooldown = "Optional. Cooldown between purchases, math.huge for one purchase per round",
            category = "What to place this with in the shop",
            purchaseTimes = "When this allowed to be bought, eg GAMEMODE.ROUND_ACTIVE ( hunting ), GAMEMODE.ROUND_INACTIVE ( right before hunting )",
            weight = "Optional. Where to order this relative to everything else in our category, accepts negative values.",
            purchaseCheck = "Optional. Table of, or single function checked to see if this is purchasable, ran clientside on every item when shop is open. ran once serverside when purchased",
            purchaseFunc = "What function to run when the item is bought, serverside",
            canShowInShop = "Optional. table of funcs or single func. Can this be seen in the shop? also prevents purchases."
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
    if not shopItemData.name then addShopFail( shopItemIdentifier, "invalid name" ) return end
    if not shopItemData.desc then addShopFail( shopItemIdentifier, "invalid desc ( description )" ) return end
    if not shopItemData.cost then addShopFail( shopItemIdentifier, "invalid cost" ) return end
    if not shopItemData.category then addShopFail( shopItemIdentifier, "invalid category, create a new category first" ) return end
    if not shopItemData.purchaseTimes or table.Count( shopItemData.purchaseTimes ) <= 0 then addShopFail( shopItemIdentifier, "purchaseTimes are not specified" ) return end
    if not shopItemData.purchaseFunc then addShopFail( shopItemIdentifier, "invalid purchaseFunc" ) return end

    -- if you reallllly want to override a shop item, fine!
    if GAMEMODE.shopItems[shopItemIdentifier] ~= nil and hook.Run( "glee_canoverrideshopitem", shopItemIdentifier ) == nil then addShopFail( shopItemIdentifier, "Tried to add a shop item that already exists" ) return end

    GAMEMODE.shopItems[shopItemIdentifier] = shopItemData

end

function GM:invalidateShopItem( identifier )
    GAMEMODE.invalidShopItems[identifier] = true
    if SERVER then


    end
end

function GM:addShopCategory( shopCategoryName, shopCategoryPriority )
    GAMEMODE.shopCategories[shopCategoryName] = shopCategoryPriority

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
function GM:translatedShopItemCost( purchaser, cost, identifier )

    if not cost then return "", white end

    local color = white
    local preTextSymbol = ""
    local theCost = ""
    local purchasersScore = purchaser:GetScore()

    -- add difference between "not enough money" and "you bought this already"
    if identifier and purchaser and purchaser.shopItemCooldowns[ identifier ] == math.huge then
        return "---", white

    end

    if cost > 0 then
        preTextSymbol = "-"
        theCost = tostring( math.abs( cost ) )

        canAfford = ( purchasersScore + -cost ) >= 0

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

        else
            cooldown = returned

        end
    end
    return cooldown

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

-- shared!

function GM:canPurchase( ply, toPurchase )
    local dat = GAMEMODE:GetShopItemData( toPurchase )
    if not dat then GAMEMODE:invalidateShopItem( _, toPurchase ) return false, REASON_INVALID end

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

    local frags = ply:GetScore()
    local cost = GAMEMODE:shopItemCost( toPurchase, ply )

    -- account for negative cost
    if cost >= 0 and frags < cost and cost ~= 0 then return nil, REASON_POOR end

    local nextPurchase = ply.shopItemCooldowns[toPurchase] or -20000
    local nextPurchasePresentable = math.Round( math.abs( nextPurchase - CurTime() ), 1 )
    local cooldownReason = "Cooldown, Purchasable in " .. tostring( nextPurchasePresentable )
    if nextPurchase == math.huge then
        cooldownReason = "This is only purchasable once per round."
    end

    if nextPurchase > CurTime() then return nil, cooldownReason end

    local hookResult, notPurchasableReason = hook.Run( "glee_canpurchaseitem", ply, self.itemIdentifier )

    if hookResult then return nil, notPurchasableReason end

    local currState = GAMEMODE:RoundState()
    local times = dat.purchaseTimes
    local goodTime = table.HasValue( times, currState )
    if not goodTime then return nil, badTimeReasonTranslation( currState, times ) end

    return true, ""
end