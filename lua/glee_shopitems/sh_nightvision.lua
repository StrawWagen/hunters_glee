local shopHelpers = GAMEMODE.shopHelpers

-- the night vision pack, see lua/weapons/glee_nvg_pack
-- one pack, three skulls. E with it out picks which pair of goggles comes out of it, and the haptic
-- pair wants one more skull on top of that, taken when it's picked

local packCost = 3

local function noPackAlready( purchaser )
    if IsValid( purchaser:GetGleeNVG() ) then return false, "You can only carry one pair of goggles." end
    if purchaser:HasWeapon( "glee_nvg_pack" ) then return false, "You're already carrying a pack." end
    return true

end

local items = {
    ["nvg_pack"] = {
        name = "Night Vision Pack",
        desc = "A small package with a device that allows easy traversal through the night",
        shCost = 0,
        shSkullCost = packCost,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 937, -- sits between Riot Shield (2 skulls, 925) and Annabelle (4, 950): this costs 3
        shPurchaseCheck = { shopHelpers.aliveCheck, noPackAlready },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = "glee_nvg_pack",
                confirmSoundWeight = 1,

            } )
        end,
    },
}

GAMEMODE:GobbleShopItems( items )
