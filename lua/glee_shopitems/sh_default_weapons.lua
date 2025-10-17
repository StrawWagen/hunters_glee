
local shopHelpers = GAMEMODE.shopHelpers

local loadoutLoadout = {
    "weapon_pistol",
    "weapon_shotgun",
    "weapon_smg1",
    "weapon_crossbow",
    "weapon_357",

}

local items = {
    [ "guns" ] = {
        name = "Loadout",
        desc = "Normal guns.\n& Ammo!\nNot very useful against metal...",
        shCost = 45,
        markup = 1.5,
        markupPerPurchase = 0.25,
        cooldown = 1,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -95,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( _shopItem, purchaser )
            for _, currWep in ipairs( loadoutLoadout ) do
                shopHelpers.purchaseWeapon( purchaser, {
                    class = currWep,
                    confirmSoundWeight = 1,
                    ammoType = nil, -- auto
                    purchaseClips = 3,
                    resupplyClips = 4,

                } )
            end
        end,
    },
    [ "nailer" ] = {
        name = "Nailer",
        desc = "Nail things together!\nNailing is rather loud.",
        shCost = 45,
        markup = 3,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( _shopItem, purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_nailer",
                confirmSoundWeight = 2,
                ammoType = "GLEE_NAILS",
                purchaseClips = 0,
                resupplyClips = 2,

            } )
        end,
    },
    [ "gravitygun" ] = {
        name = "Gravity Gun",
        desc = "Gravity Gun",
        shCost = 60,
        markup = 2,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.aliveCheck, function( purchaser )
            local gravgun = purchaser:GetWeapon( "weapon_physcannon" )
            if IsValid( gravgun ) then return false, "You aready have a Gravity Gun!" end
            return true

        end },
        svOnPurchaseFunc = function( _shopItem, purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_physcannon",
                confirmSoundWeight = 2,

            } )
        end,
    },
    [ "flaregun" ] = {
        name = "Flaregun",
        desc = "Flaregun.\n+ 4 flares.",
        shCost = 45,
        markup = 1.25,
        markupPerPurchase = 0.15,
        cooldown = 1,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,

        },
        weight = 1,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( _shopItem, purchaser )
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
        shCost = 20,
        markup = 6,
        cooldown = 10,
        tags = { "ITEMS", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.aliveCheck, lockpickCanPurchase },
        svOnPurchaseFunc = function( _shopItem, purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_lockpick",
                confirmSoundWeight = 2,

            } )
        end,
    },
    [ "slams" ] = {
        name = "Slams",
        desc = "Some slams, 17 to be exact.",
        shCost = 60,
        markup = 2,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( _shopItem, purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_slam",
                confirmSoundWeight = 3,
                ammoType = "slam",
                purchaseClips = 14, -- spawns us with 3 extra slams
                resupplyClips = 17,

            } )
        end,
    },
    -- funny cam
    [ "crapvidcam" ] = {
        name = "Crappy Video Camera",
        desc = "Document the glee.",
        shCost = 0,
        skullCost = 1,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility", "Fun", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 900,
        shPurchaseCheck = { shopHelpers.aliveCheck,
            function( purchaser )
                if purchaser:HasWeapon( "weapon_glee_crapvidcam" ) then return false, "You already have a Crappy Video Camera." end
                return true

            end
        },
        svOnPurchaseFunc = function( _shopItem, purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_glee_crapvidcam",
                confirmSoundWeight = 1,

            } )
        end,
    },
    -- ka BOOOOOM
    [ "taucannon" ] = {
        name = "Tau Cannon",
        desc = "High risk, High reward.\nDon't let it overcharge!",
        shCost = 0,
        skullCost = 5,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 1000,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( _shopItem, purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_taucannon",
                confirmSoundWeight = 2,
                ammoType = "Uranium_235",
                purchaseClips = 0,
                resupplyClips = 1,

            } )
        end,
    },
}

GAMEMODE:GobbleShopItems( items )