
local shopHelpers = GAMEMODE.shopHelpers

local items = {
    [ "flaregun" ] = {
        name = "Flaregun",
        desc = "Flaregun.\n+ 4 flares.",
        cost = 45,
        markup = 1.25,
        markupPerPurchase = 0.15,
        cooldown = 1,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,

        },
        weight = 1,
        purchaseCheck = shopHelpers.aliveCheck,
        onPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_aeromatix_flare_gun",
                confirmSoundWeight = 2,
                ammoType = "GLEE_FLAREGUN_PLAYER",
                purchaseClips = 0,
                resupplyClips = 4,

            } )
        end,
    },
    -- lets people mess with locked rooms
    [ "lockpick" ] = {
        name = "Lockpick",
        desc = "Lockpick, for doors.\nCan also open things like crates,\n( relatively ) quietly.",
        cost = 20,
        markup = 6,
        cooldown = 10,
        tags = { "ITEMS", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        purchaseCheck = { shopHelpers.aliveCheck, lockpickCanPurchase },
        onPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_lockpick",
                confirmSoundWeight = 2,

            } )
        end,
    },
}

GAMEMODE:GobbleShopItems( items )