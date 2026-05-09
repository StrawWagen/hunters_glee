
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
            setupPlacable( "glee_tnt_crate", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
    ["winners_might"] = {
        name = "Winner's Might",
        desc = "Click and hold on a player to move them around.\n\nCost rises exponentially as it gets used.", -- Not actually exponential, but it gets the point across.
        shCost = 0,
        costDecorative = "-100",
        markup = 1,
        cooldown = 0.5,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_winners_might", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
}

GAMEMODE:GobbleShopItems( items )