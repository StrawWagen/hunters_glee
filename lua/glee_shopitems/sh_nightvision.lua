local shopHelpers = GAMEMODE.shopHelpers

-- one random pair of goggles, three skulls. the haptic pair is in the pool too, no extra charge on top
-- the goggles themselves are lua/weapons/glee_nvg_base and its children

local goggles = {
    "glee_nvg_gpnvg",
    "glee_nvg_t7",
    "glee_nvg_pvs14",
}

local function noGogglesAlready( purchaser )
    if IsValid( purchaser:GetGleeNVG() ) then return false, "You can only carry one pair of goggles." end
    return true

end

local items = {
    ["nvg"] = {
        name = "NVG",
        desc = ":Random electro-optical combine surplus",
        shCost = 0,
        shSkullCost = 3,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 937, -- sits between Riot Shield (2 skulls, 925) and Annabelle (4, 950): this costs 3
        shPurchaseCheck = { shopHelpers.aliveCheck, noGogglesAlready },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = goggles[ math.random( #goggles ) ],
                confirmSoundWeight = 1,

            } )
        end,
    },
}

GAMEMODE:GobbleShopItems( items )
