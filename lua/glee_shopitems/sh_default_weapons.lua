
local shopHelpers = GAMEMODE.shopHelpers

local loadoutLoadout = {
    "weapon_pistol",
    "weapon_shotgun",
    "weapon_smg1",
    "weapon_crossbow",
    "weapon_357",

}

local function canPurchaseSuitBattery( purchaser )
    local new = purchaser:Armor() + 15
    if new > purchaser:GetMaxArmor() then return false, "Your battery is full." end
    return true

end

local items = {
    -- lol you ran out of battery
    [ "armor" ] = {
        name = "Suit Battery",
        desc = "15 Suit Battery.",
        shCost = 15,
        markup = 6,
        markupPerPurchase = 0.5,
        cooldown = 0.5,
        tags = { "ITEMS" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -150,
        shPurchaseCheck = { shopHelpers.aliveCheck, canPurchaseSuitBattery },
        svOnPurchaseFunc = function( purchaser )
            local new = math.Clamp( purchaser:Armor() + 15, 0, purchaser:GetMaxArmor() )
            purchaser:SetArmor( new )

            purchaser:EmitSound( "ItemBattery.Touch" )

        end,
    },
    [ "rpg" ] = {
        name = "RPG",
        desc = "RPG + Rockets.\nRocketing a hunter can save you in a pinch.",
        shCost = 60,
        markup = 1.5,
        markupPerPurchase = 0.15,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -140,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_rpg",
                confirmSoundWeight = 1,
                ammoType = "RPG_Round",
                purchaseClips = 4,
                resupplyClips = 6,

            } )
        end,
    },
    [ "frag" ] = {
        name = "10 Grenades",
        desc = "10 Grenades.\nSimple explosives, useful for hordes!",
        shCost = 50,
        markup = 1.5,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_frag",
                confirmSoundWeight = 1,
                ammoType = "Grenade",
                purchaseClips = 9,
                resupplyClips = 10,

            } )
        end,
    },
    -- heal jooce
    [ "healthkit" ] = {
        name = "Medkit",
        desc = "Heals.\nYou gain score for healing players.\nHealing yourself is unweildy and slow.\nExcess health you find, will reload it.",
        shCost = 80,
        markup = 2,
        markupPerPurchase = 0.15,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -100,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            local medkit = "termhunt_medkit"
            local weap = purchaser:GetWeapon( medkit )
            local hasWeap = IsValid( weap )

            if hasWeap then
                weap:HealJuice( 200 )

            else
                purchaser:Give( medkit, false )
                shopHelpers.loadoutConfirm( purchaser, 1 )

            end
        end,
    },
    -- funny bear trap
    [ "beartrap" ] = {
        name = "Six Beartraps",
        desc = "Traps players, Terminators can easily overpower them.",
        shCost = 65,
        markup = 2,
        markupPerPurchase = 0.25,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 0,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_weapon_beartrap",
                confirmSoundWeight = 1,
                ammoType = "GLEE_BEARTRAP",
                purchaseClips = 5,
                resupplyClips = 6,

            } )
        end,
    },
    -- terminator doesnt like taking damage from this, will save your ass
    [ "ar2" ] = {
        name = "Ar2",
        desc = "Ar2 + Balls.\nIt takes 2 AR2 balls to kill a terminator.",
        shCost = 75,
        markup = 2,
        markupPerPurchase = 0.4,
        cooldown = 0.5,
        tags = { "ITEMS", "Weapon" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -150,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "weapon_ar2",
                confirmSoundWeight = 1,
                ammoType = "AR2",
                purchaseClips = 96,
                resupplyClips = 156,
                secondaryAmmoType = "AR2AltFire",
                purchaseSecondaryClips = 2,
                resupplySecondaryClips = 4,

            } )
        end,
    },
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
        svOnPurchaseFunc = function( purchaser )
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
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_weapon_hammer",
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
        svOnPurchaseFunc = function( purchaser )
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
        svOnPurchaseFunc = function( purchaser )
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
        svOnPurchaseFunc = function( purchaser )
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
        svOnPurchaseFunc = function( purchaser )
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
        svOnPurchaseFunc = function( purchaser )
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
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_taucannon",
                confirmSoundWeight = 4,
                ammoType = "Uranium_235",
                purchaseClips = 0,
                resupplyClips = 1,

            } )
        end,
    },
    -- john rambo ahh
    [ "ar3" ] = {
        name = "Emplacement Gun",
        desc = "Rapid fire, powerful, chews through flesh, but not metal...\nOverheats quickly...",
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
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "termhunt_ar3",
                confirmSoundWeight = 6,
                ammoType = "AR2",
                purchaseClips = 0,
                resupplyClips = 2,

            } )
        end,
    },
}

GAMEMODE:GobbleShopItems( items )