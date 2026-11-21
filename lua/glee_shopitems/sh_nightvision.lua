
local shopHelpers = GAMEMODE.shopHelpers

-- the three night vision goggles, see lua/weapons/glee_nvg_base

local skullCost = 7

local function noGogglesYet( purchaser )
    if IsValid( purchaser:GetGleeNVG() ) then return false, "You can only carry one pair of goggles." end
    return true

end

local function goggles( class, name, desc, weight )
    return {
        name = name,
        desc = desc .. "\nSits in slot 6, left click with them out to flip them down.\nHold V with them out to throw them down.\nOnly one pair at a time.",
        shCost = 0,
        shSkullCost = skullCost,
        cooldown = 0.5,
        tags = { "ITEMS", "Utility", "SkullCost" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = weight,
        shPurchaseCheck = { shopHelpers.aliveCheck, noGogglesYet },
        svOnPurchaseFunc = function( purchaser )
            shopHelpers.purchaseWeapon( purchaser, {
                class = class,
                confirmSoundWeight = 1,

            } )
        end,
    }
end

local items = {
    ["nvg_gpnvg"] = goggles( "glee_nvg_gpnvg", "GPNVG-18 Night Vision", "See in the dark.\nEverything turns black or green.", 1050 ),
    ["nvg_t7"] = goggles( "glee_nvg_t7", "T-7 Thermal", "See heat.\nAnything alive, and every body, glows red orange.", 1051 ),
    ["nvg_pvs14"] = goggles( "glee_nvg_pvs14", "PVS-14 Haptic Vision", "A light that lights up the dark, and stronger, redder colours.\nE with them out: radar on/off, its wavelength, or its cone.\nThe radar's rays go through walls, and show where in the cone they hit anything alive.", 1052 ),
}

GAMEMODE:GobbleShopItems( items )
