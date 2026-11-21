
local shopHelpers = GAMEMODE.shopHelpers

-- the three night vision goggles, see lua/autorun/sh_glee_nightvision.lua

local skullCost = 7

local function noGogglesYet( purchaser )
    if IsValid( purchaser:GetGleeNVG() ) then return false, "You can only carry one pair of goggles." end
    return true

end

local function goggles( class, desc, weight )
    return {
        name = GleeNVG.kinds[class].name,
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
    ["nvg_gpnvg"] = goggles( "glee_nvg_gpnvg", "See in the dark.\nEverything turns black or light green.", 1050 ),
    ["nvg_t7"] = goggles( "glee_nvg_t7", "See heat.\nAnything alive, and every body, glows white mint.", 1051 ),
    ["nvg_pvs14"] = goggles( "glee_nvg_pvs14", "A green light that lights up the dark.\nE with them out: radar on/off, or change its wavelength.\nThe radar's bouncing rays leave a blip on anything alive they hit.", 1052 ),
}

GAMEMODE:GobbleShopItems( items )
