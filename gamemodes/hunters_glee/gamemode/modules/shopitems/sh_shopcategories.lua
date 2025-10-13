
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
        SACRIFICES = { -- things you can place to earn money while dead
            name = "Sacrifices",
            order = 3,
            canShowInShop = shopHelpers.undeadCheck
        },
        GIFTS = { -- things you can place to spend money, do stuff while dead
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