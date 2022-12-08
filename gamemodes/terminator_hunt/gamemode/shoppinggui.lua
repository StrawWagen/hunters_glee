print( "GOOEY" )

local function shopPanelName( identifier )
    return "termhunt_shoppanel_" .. identifier 
end

local function shopCategoryName( identifier )
    return "termhunt_shopcategory_" .. identifier 
end

local function SetupShopPanel()
    local PANEL = {}

    function PANEL:DoClick()
        RunConsoleCommand( "termhunt_purchase", self.itemIdentifier )
    end

    function PANEL:GetText() 
        return self.itemData.name or ""

    end

    vgui.Register( "termhunt_shopitem", PANEL, "DButton" ) 

end

local SETUP = nil

local ENT = LocalPlayer()
local shopPanelsSequential = {}
local shopCategoryPanels = {}
local hudPanel = GetHUDPanel()
local MAINSCROLLNAME = "main_scroll_window"
local MAINSCROLLPANEL = nil

SetupShopPanel()

function termHuntOpenTheShop()
    local count = 0

    if not SETUP then

        local frame = vgui.Create( "DFrame" )
        frame:SetSize( 1000, 500 )
        frame:Center()
        frame:MakePopup()

        local MAINSCROLLPANEL = vgui.Create( "DScrollPanel", frame, MAINSCROLLNAME )
        MAINSCROLLPANEL:DockPadding( 10,10,10,10 )
        MAINSCROLLPANEL:Dock( FILL )

        for category, _ in pairs( GAMEMODE.shopCategories ) do
            local horisScroller = vgui.Create( "DHorizontalScroller", MAINSCROLLPANEL, shopCategoryName( category ) )

            print( "createdcat " .. category .. " " .. tostring( horisScroller ) )
            shopCategoryPanels[ category ] = horisScroller
            
            MAINSCROLLPANEL:AddItem( horisScroller )
            horisScroller:DockMargin( 0, 0, 0, 25 )
            horisScroller:Dock( TOP )

        end

        for identifier, itemData in pairs( GAMEMODE.shopItems ) do
            local myCategoryPanel = shopCategoryPanels[ itemData.category ]

            local shopItem = vgui.Create( "termhunt_shopitem", myCategoryPanel, shopPanelName( identifier ) )
            shopItem.itemData = itemData
            shopItem.itemIdentifier = identifier
            print( identifier )
            myCategoryPanel:AddPanel( shopItem )

            print( "put " .. identifier .. " into " .. tostring( myCategoryPanel ) )

            shopItem:SetText( itemData.name )

            print( shopItem:GetParent() )

        end
    end
end

function termHuntCloseTheShop()
    for _, panel in ipairs( shopPanelsSequential ) do
        panel:SetVisible( false )
    end
end
