local shopHelpers = GAMEMODE.shopHelpers

-- one random pair of goggles for 600 points. the haptic pair is in the pool too, no extra charge on top
-- the goggles themselves are lua/weapons/glee_nvg_base and its children

local goggles = {
    "glee_nvg_gpnvg",
    "glee_nvg_t7",
    "glee_nvg_pvs14",
}

-- every pair, it's random which they get
local function canWearGoggles( purchaser )
    for _, class in ipairs( goggles ) do
        local canWear, reason = purchaser:CanGleeWear( weapons.Get( class ) )
        if not canWear then return false, reason end

    end
    return true

end

local items = {
    ["nvg"] = {
        name = "NVG",
        desc = "Random electro-optical combine surplus??",
        shCost = 600,
        shSkullCost = 0,
        -- flat price, forever: markup stays at 1x even mid-hunt, and there is no markupPerPurchase
        -- here at all, so buying a second pair later costs the same 600 as the first
        markup = 1,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 780, -- 600 points is the priciest plain item, so it sits at the end of the point-priced run, before the skull-cost block (925+)
        shPurchaseCheck = { shopHelpers.aliveCheck, canWearGoggles },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = goggles[ math.random( #goggles ) ],
                confirmSoundWeight = 1,

            } )
        end,
    },
}

GAMEMODE:GobbleShopItems( items )
