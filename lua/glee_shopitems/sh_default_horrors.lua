
local shopHelpers = GAMEMODE.shopHelpers

local function setupPlacable( class, purchaser, itemIdentifier )
    local thing = ents.Create( class )
    thing.itemIdentifier = itemIdentifier
    thing:SetOwner( purchaser )
    thing:Spawn()

    return thing

end


local items = {
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
        weight = 10,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_escapee_wind", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["bomb_crate"] = {
        name = "Timed TNT Crate",
        desc = "Supply crate with Timed TNT inside it.\nGives score when the TNT damages stuff.",
        shCost = 0,
        markup = 1,
        cooldown = 100,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_crate_tnt", purchaser, itemIdentifier )

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
        weight = 10,
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
        weight = 10,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_crate_score", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
}

GAMEMODE:GobbleShopItems( items )
