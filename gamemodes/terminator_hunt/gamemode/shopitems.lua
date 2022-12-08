
AddCSLuaFile( "shopitems.lua" )

termHunt_ShopItems = {}

local reviver = "termhunt_reviver"

local function revivePurchase( purchaser )
    local weap = purchaser:GetWeapon( reviver )
    local hasWeap = IsValid( weap )

    if hasWeap then
        weap:AddResurrect()

    else
        purchaser:Give( reviver, false )

    end
end
local function scorePurchase( purchaser )
    purchaser:SetFrags( purchaser:Frags() + 1000 )

end

function GM:SetupShopCatalouge()
    local defaultItems = {
        [ "score" ] = {
            name = "Score",
            desc = "Free score",
            cost = 0,
            doRepeat = true,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_SETUP,
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
                GAMEMODE.ROUND_LIMBO,
            },
            purchaseFunc = scorePurchase,
        },
        [ "revivekit" ] = {
            name = "Revive Kit",
            desc = "Revives dead players",
            cost = 50,
            markup = 2,
            doRepeat = true,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_SETUP,
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
                GAMEMODE.ROUND_LIMBO,
            },
            purchaseFunc = revivePurchase,
        },
        
    }
    
    local defaultCategories = {
        [ "Items" ] = 1,
        [ "Innate" ] = 2,
        [ "Undead" ] = 3,     
    }

    PrintTable( defaultItems )
    table.Merge( GAMEMODE.shopItems, defaultItems )
    table.Merge( GAMEMODE.shopCategories, defaultCategories )

end

function GM:SetupShop()
    GAMEMODE.shopItems = {}
    GAMEMODE.shopCategories = {}

end