
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
            shCanShowInShop =     "Optional. Function or table of functions checked to decide if this can be seen in the shop. Also prevents purchases.",
            costDecorative =    "Optional. Fake cost string to display in the shop, or a function which returns a string and color."

            --[[ Auto-generated fields: (for internal use/reference)
            categories = "Auto-generated. A lookup table of this ite'ms tags that match shop categories."
            identifier = "Auto-generated. The item's unique identifier.",
            --]]
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
    if shopItemData.shCanShowInShop and not isfunction( shopItemData.shCanShowInShop ) and not istable( shopItemData.shCanShowInShop ) then addShopFail( shopItemIdentifier, "invalid .shCanShowInShop" ) return end

    GAMEMODE:ConvertItemTags( shopItemData )

    local foundAHome = GAMEMODE:PutItemInProperCategories( shopItemData )
    if not foundAHome then addShopFail( shopItemIdentifier, "wasnt put in a category!!, check sh_shopcategories.lua for full category list" ) return end

    GAMEMODE.shopItems[shopItemIdentifier] = shopItemData
    shopItemData.identifier = shopItemIdentifier -- Replicate identifier for easier access

    return true

end

function GM:ConvertItemTags( shopItemData ) -- convert indexed table to mask
    if not istable( shopItemData.tags ) then return end
    local newTags = {}
    for _, tag in ipairs( shopItemData.tags ) do
        newTags[ tag ] = true

    end
    shopItemData.tags = newTags
end

function GM:PutItemInProperCategories( shopItemData ) -- put item in categories based on tags
    local foundAHome
    local categories = GAMEMODE.shopCategories
    for tag, _ in pairs( shopItemData.tags ) do
        if categories[ tag ] then
            --print( "Putting " .. shopItemData.name .. " in category " .. tag )
            shopItemData.categories = shopItemData.categories or {}
            shopItemData.categories[tag] = true
            foundAHome = true

        end
    end
    return foundAHome

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

local function runChecks( ply, itemData, hookName, checkFuncs, funcName )
    local itemID = itemData.identifier

    -- Run hook
    local success, returned, reason = xpcall( hook.Run, errorCatchingMitt, hookName, ply, itemData )
    if not success then
        GAMEMODE:invalidateShopItem( itemID )
        print( "GLEE: !!!!!!!!!! " .. hookName .. " errored for " .. itemID .. "!!!!!!!!!!!" )
        return false, REASON_ERROR

    end
    if returned == false then return false, reason end -- Blocked

    -- Run checker funcs
    if isfunction( checkFuncs ) then
        checkFuncs = { checkFuncs }

    end
    if istable( checkFuncs ) then
        for _, checkFunc in ipairs( checkFuncs ) do
            success, returned, reason = xpcall( checkFunc, errorCatchingMitt, ply )
            if not success then
                GAMEMODE:invalidateShopItem( itemID )
                print( "GLEE: !!!!!!!!!! " .. itemID .. "'s " .. funcName .. " function errored!!!!!!!!!!!" )
                return false, REASON_ERROR

            else
                if returned == true then continue end
                return false, reason

            end

        end

    end

    return true

end


-- shared!

function GM:canShowInShop( ply, itemID )
    if not itemID or itemID == "" then return false, REASON_INVALID end
    local itemData = GAMEMODE:GetShopItemData( itemID )
    if not itemData then return false, REASON_INVALID end

    -- Check categories first
    local wasValidCategory = false
    local lastNotPurchasableReason = REASON_INVALIDCATEGORY

    for categoryIdentifier, _ in pairs( itemData.categories ) do
        local purchasableCategory, reason = self:CategoryCanShow( categoryIdentifier, ply )
        if purchasableCategory then
            wasValidCategory = true

        else
            lastNotPurchasableReason = reason

        end
    end

    if not wasValidCategory then return false, lastNotPurchasableReason end

    return runChecks( ply, itemData, "glee_shop_canshow", itemData.shCanShowInShop, "shCanShowInShop" )
end

function GM:canPurchase( ply, itemID )
    if not itemID or itemID == "" then return end
    local itemData = GAMEMODE:GetShopItemData( itemID )
    if not itemData then return false, REASON_INVALID end

    local nextPurchase = ply.shopItemCooldowns[ itemID ] or -20000
    if nextPurchase == math.huge then return false, "You've already bought this." end

    local allowed, failReason = self:canShowInShop( ply, itemID )
    if not allowed then return false, failReason end

    allowed, failReason = runChecks( ply, itemData, "glee_shop_canpurchase", itemData.shPurchaseCheck, "shPurchaseCheck" )
    if not allowed then return false, failReason end

    local score = ply:GetScore()
    local cost = GAMEMODE:shopItemCost( itemID, ply )
    local canGoInDebt = itemData.canGoInDebt

    -- account for negative cost
    local costsTooMuch = score < cost and not canGoInDebt

    if cost >= 0 and costsTooMuch and cost ~= 0 then
        local cannotBuyReason = REASON_POOR
        if score < 0 then
            cannotBuyReason = REASON_DEBT

        end
        return false, cannotBuyReason

    end

    local skullCost = GAMEMODE:shopItemSkullCost( itemID, ply )
    if skullCost then
        local skulls = ply:GetSkulls()
        local skullCostsTooMuch = skulls < skullCost and not canGoInDebt
        if skullCost >= 0 and skullCostsTooMuch and skullCost ~= 0 then
            local difference = skullCost - skulls
            if difference == 1 then
                return false, REASON_SKULLPOOR_1SKULL

            end
            local cannotBuySkullsReason = REASON_SKULLPOOR
            if skulls < 0 then
                cannotBuySkullsReason = REASON_SKULLDEBT

            end
            return false, cannotBuySkullsReason

        end
    end

    if nextPurchase > CurTime() then
        local nextPurchasePresentable = math.Round( math.abs( nextPurchase - CurTime() ), 1 )
        local cooldownReason = "Cooldown, Purchasable in " .. tostring( nextPurchasePresentable )
        return false, cooldownReason

    end

    local hookResult, notPurchasableReason = hook.Run( "glee_blockpurchaseitem", ply, self.itemIdentifier )

    if hookResult then return false, notPurchasableReason end

    local currState = GAMEMODE:RoundState()
    local times = itemData.purchaseTimes
    local goodTime = table.HasValue( times, currState )
    if not goodTime then return false, badTimeReasonTranslation( currState, times ) end

    return true, ""

end