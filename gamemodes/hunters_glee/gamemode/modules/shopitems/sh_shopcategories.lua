
local GM = GAMEMODE or GM
local shopHelpers = GM.shopHelpers

function GM:SetupShopCategories()
    self.shopCategories = {
        ITEMS = { -- weapons, guns
            name = "Items",
            order = 1,
            canShowInShop = shopHelpers.aliveCheck
        },
        INNATE = { -- passive, innate abilities
            name = "Innate",
            order = 2,
            canShowInShop = shopHelpers.aliveCheck
        },
        DEADSACRIFICES = { -- things you can place to earn money while dead
            name = "Sacrifices",
            order = 3,
            canShowInShop = shopHelpers.undeadCheck
        },
        DEADGIFTS = { -- things you can place to spend money, do stuff while dead
            name = "Gifts",
            order = 4,
            canShowInShop = shopHelpers.undeadCheck
        },
        BANK = { -- banking
            name = "Bank",
            order = 5,
        }
    }

    self.shopCategoryIds = {}
    for category, _ in pairs( self.shopCategories ) do -- kinda dumb
        self.shopCategoryIds[ category ] = category

    end
end

function GM:GetShopCategoryData( categoryIdentifier )
    local dat = GAMEMODE.shopCategories[ categoryIdentifier ]
    if not istable( dat ) then return end
    return dat

end

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

function GM:CategoryCanShow( identifier, purchaser )
    local catData = GAMEMODE:GetShopCategoryData( identifier )
    if not catData then return false end

    local categoryCanShow = catData.canShowInShop
    if isfunction( categoryCanShow ) then
        categoryCanShow = { categoryCanShow }

    end
    if istable( categoryCanShow ) then
        for _, theCurrentShowFunc in ipairs( categoryCanShow ) do
            local noErrors, returned = xpcall( theCurrentShowFunc, errorCatchingMitt, purchaser )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( toPurchase )
                print( "GLEE: !!!!!!!!!! " .. toPurchase .. "'s canShowInShop function errored!!!!!!!!!!!" )
                return nil, REASON_ERROR

            else
                if returned ~= true then return false, "that item isn't purchasable right now." end

            end
        end
    end
    return true

end