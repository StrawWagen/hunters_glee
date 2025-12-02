
local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

-- yes, you can just add shop items!
function GM:getDebugShopItemStructureTable()
    -- example item
    local theItemTable = {
        [ "slams" ] = {
            name = "Slams",
            desc = "Some slams, 17 to be exact.",
            shCost = 80,
            markup = 2,
            cooldown = 1,
            tags = { "ITEMS", "Weapon" },
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 0,
            shPurchaseCheck = GAMEMODE.shopHelpers.aliveCheck,
            svOnPurchaseFunc = slamsPurchase,
        }
    }
    local theDescriptorTable = {
        -- all fields should be identical on server/client
        [ "shopItemUniqueIdentifier" ] = {
            name =              "Printed name that players see",
            desc =              "Description. Accepts a function or string.",
            shCost =              "Cost, negative to give player score when purchasing, Accepts a function.",
            canGoInDebt =       "Optional. Can this item be bought when the player has no score? Can force players to buy innate debuffs, etc.",
            fakeCost =          "Optional. Whether to skip applying the cost within the purchasing system. Good if you want a shop item to more dynamically apply costs, but still show a cost.",
            simpleCostDisplay = "Optional. Client. Skip the coloring + formatting of an item's cost in the shop.",
            markup =            "Optional. Price multipler to be applied when bought during the hunt, motivates people buy when the round's setting up.",
            markupPerPurchase = "Optional. Additional markup per player per purchase of item. Makes items less and less worth it.",
            cooldown =          "Optional. Cooldown between purchases, math.huge for one purchase per round. Can be a number, or a function.",
            tags =              "Tags that define attributes of this item, categories included. Accepts an indexed table of strings, converted to a mask after adding.",
            purchaseTimes =     "Item will only be purchasble in the round states specified by this table. Eg GAMEMODE.ROUND_ACTIVE ( hunting ).",
            weight =            "Optional. Where to order this relative to everything else in our category, accepts negative values.",
            shPurchaseCheck =     "Optional. Function or table of functions checked to see if this is purchasable, ran clientside on every item, every frame when shop is open. ran once serverside when purchased",
            svOnPurchaseFunc =    "Server. What function to run when the item is bought.",
            shCanShowInShop =     "Optional. Can this be seen in the shop? also prevents purchases. Accepts a single function, or a table of functions."
        }
    }
    return theItemTable, theDescriptorTable

end

local function addShopFail( shopItemIdentifier, reason )
    ErrorNoHaltWithStack( "HUNTER'S GLEE: GAMEMODE:addShopItem( " .. shopItemIdentifier .. ", \"shopItemData\" ) failed for reason... " .. reason )

end

-- add VIA this function!
function GM:AddShopItem( shopItemIdentifier, shopItemData )
    -- check all the non-optional stuff
    if not istable( shopItemData ) then addShopFail( shopItemIdentifier, "data table is not a table" ) return end
    if not shopItemData.name then addShopFail( shopItemIdentifier, "invalid .name" ) return end
    if not shopItemData.desc then addShopFail( shopItemIdentifier, "invalid .desc ( description )" ) return end
    if not shopItemData.shCost then addShopFail( shopItemIdentifier, "invalid .shCost" ) return end
    if not shopItemData.tags then addShopFail( shopItemIdentifier, "invalid .tags" ) return end
    if shopItemData.category or shopItemData.categories then addShopFail( shopItemIdentifier, "do not set .category or .categories, categories are determined by .tags" ) return end
    if not shopItemData.purchaseTimes or table.Count( shopItemData.purchaseTimes ) <= 0 then addShopFail( shopItemIdentifier, ".purchaseTimes are not specified" ) return end
    if not shopItemData.svOnPurchaseFunc then addShopFail( shopItemIdentifier, "invalid .svOnPurchaseFunc" ) return end

    GAMEMODE:ConvertItemTags( shopItemData )
    GAMEMODE:PutItemInProperCategories( shopItemData )

    GAMEMODE.shopItems[shopItemIdentifier] = shopItemData

    return true

end

function GM:ConvertItemTags( shopItemData )
    if not istable( shopItemData.tags ) then return end
    local newTags = {}
    for _, tag in ipairs( shopItemData.tags ) do
        newTags[ tag ] = true

    end
    shopItemData.tags = newTags
end

function GM:PutItemInProperCategories( shopItemData )
    local categories = GAMEMODE.shopCategories
    for tag, _ in pairs( shopItemData.tags ) do
        if categories[ tag ] then
            --print( "Putting " .. shopItemData.name .. " in category " .. tag )
            shopItemData.categories = shopItemData.categories or {}
            shopItemData.categories[tag] = true

        end
    end
end

function GM:invalidateShopItem( identifier )
    GAMEMODE.invalidShopItems[identifier] = true
    if SERVER then --????


    end
end




local timeTranslations = { -- translations for just the time reasons below
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
local REASON_INVALIDCATEGORY = "That item is in an invalid category."
local REASON_POOR = "You are too poor to afford this."
local REASON_DEBT = "You can't buy this.\nYou're in Debt."
local REASON_SKULLPOOR = "You need more skulls to buy this."
local REASON_SKULLPOOR_1SKULL = "You need a skull to buy this."
local REASON_SKULLDEBT = "You can't buy this, You're in Skull debt."

-- shared!

function GM:canPurchase( ply, toPurchase )
    if not toPurchase or toPurchase == "" then return end
    local dat = GAMEMODE:GetShopItemData( toPurchase )
    if not dat then return false, REASON_INVALID end

    local wasValidCategory = false
    local lastNotPurchasableReason = REASON_INVALIDCATEGORY

    for categoryIdentifier, _ in pairs( dat.categories ) do
        local purchasableCategory, reason = self:CategoryCanShow( categoryIdentifier, ply )
        if purchasableCategory then
            wasValidCategory = true

        else
            lastNotPurchasableReason = reason

        end
    end

    if not wasValidCategory then return nil, lastNotPurchasableReason end

    -- do this first
    local checkFunc = dat.shPurchaseCheck
    if isfunction( checkFunc ) then
        checkFunc = { checkFunc }

    end
    if istable( checkFunc ) then
        for _, theCurrentCheckFunc in ipairs( checkFunc ) do
            local noErrors, returned, reason = xpcall( theCurrentCheckFunc, errorCatchingMitt, ply )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( toPurchase )
                print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s shPurchaseCheck function errored!!!!!!!!!!!" )
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
    local canGoInDebt = dat.canGoInDebt

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
            local difference = skullCost - skulls
            if difference == 1 then
                return nil, REASON_SKULLPOOR_1SKULL

            end
            local cannotBuySkullsReason = REASON_SKULLPOOR
            if skulls < 0 then
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