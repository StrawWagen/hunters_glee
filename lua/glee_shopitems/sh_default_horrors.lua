
local shopHelpers = GAMEMODE.shopHelpers

local function setupPlacable( class, purchaser, itemIdentifier )
    local thing = ents.Create( class )
    thing.itemIdentifier = itemIdentifier
    thing:SetOwner( purchaser )
    thing:Spawn()

    return thing

end


local items = {
    ["point_and_click"] = {
        name = "Point and Click",
        desc = "Click on players, or hunters!\nCosts climb, the farther you drag...\n\nWARNING: do NOT use on stick figures.",
        shCost = 0,
        costDecorative = "-50 / -100",
        markup = 1,
        cooldown = 0.5,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -100,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_point_and_click", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["heavy_weapons_crate"] = {
        name = "Heavy Weapons Crate",
        desc = "Crate full of heavy weapons.\nPlace far from players for more score.",
        shCost = 0,
        markup = 1,
        cooldown = 60,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 50,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_crate_heavyweapons", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["score_crate"] = {
        name = "Score Crate",
        desc = "Crate full of score.\nIt contains as much score as you get from placing it.",
        shCost = 0,
        markup = 1,
        cooldown = 15,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 50,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_crate_score", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["bomb_crate"] = {
        name = "Timed TNT Crate",
        desc = "Supply crate with Timed TNT inside it.\nGives score when the TNT damages stuff.",
        shCost = 0,
        markup = 1,
        cooldown = 90,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 55,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_crate_tnt", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["ghostly_wind"] = {
        name = "Ghostly Wind",
        desc = "Summon a strange gust of wind...",
        shCost = 0,
        costDecorative = "-75",
        markup = 1,
        cooldown = 0.5,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 100,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_escapee_wind", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["barnacle"] = {
        name = "Barnacle",
        desc = "Barnacle.\nYou gain 100 score the first time it grabs someone, and 45 score every further second it has someone grabbed.\nCosts more to place in groups, or place too close to players.",
        shCost = 5,
        markup = 1,
        cooldown = 0.5,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 100,
        shPurchaseCheck = { shopHelpers.deadCheck, ghostCanPurchase },
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "placable_barnacle", purchaser, itemIdentifier )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
