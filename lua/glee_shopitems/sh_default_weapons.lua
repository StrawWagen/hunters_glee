
local shopHelpers = GAMEMODE.shopHelpers

local items = {
    [ "flaregun" ] = {
        name = "Flaregun",
        desc = "Flaregun.\n+ 4 flares.",
        cost = 45,
        markup = 1.25,
        markupPerPurchase = 0.15,
        cooldown = 1,
        category = GAMEMODE.shopCategoryIds.ITEMS,
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,

        },
        weight = 1,
        purchaseCheck = unUndeadCheck,
        onPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, "termhunt_aeromatix_flare_gun", { ammoType = "GLEE_FLAREGUN_PLAYER", purchaseClips = 0, resupplyClips = 4 } )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )