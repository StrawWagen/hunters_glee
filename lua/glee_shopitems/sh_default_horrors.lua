
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
        name = "Crate with Explosives",
        desc = "Supply crate rigged with explosives.\nGives score when it damages something.",
        shCost = 0,
        markup = 1,
        cooldown = 100,
        tags = { "HORRORS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 10,
        svOnPurchaseFunc = function( purchaser, itemIdentifier )
            setupPlacable( "glee_bomb_crate", purchaser, itemIdentifier )

        end,
        shCanShowInShop = shopHelpers.escapedCheck,
    },
}

GAMEMODE:GobbleShopItems( items )