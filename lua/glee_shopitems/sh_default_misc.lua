
local shopHelpers = GAMEMODE.shopHelpers

local items = {
    [ "score" ] = {
        name = "Score",
        desc = "Free score, Cheat!",
        shCost = -1000,
        tags = { "INNATE", "DEADGIFTS", "Cheat" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        svOnPurchaseFunc = function() end,
        shCanShowInShop = shopHelpers.isCheats,
    },
}

GAMEMODE:GobbleShopItems( items )