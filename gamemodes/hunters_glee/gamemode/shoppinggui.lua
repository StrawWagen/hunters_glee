print( "GOOEY" )

local glee_sizeScaled = glee_sizeScaled

local function shopPanelName( identifier )
    return "termhunt_shoppanel_" .. identifier
end

local function shopCategoryName( identifier )
    return "termhunt_shopcategory_" .. identifier
end

-- YOUR CURRENT SCORE
local fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 40 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntShopScoreFont", fontData )

-- CATEGORY
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 50 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntShopCategoryFont", fontData )

-- ITEMS
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 25 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntShopItemFont", fontData )

-- ITEMS
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 22.5 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntShopItemSmallerFont", fontData )


local LocalPlayer = LocalPlayer
local draw_RoundedBox = draw.RoundedBox

local switchSound = Sound( "buttons/lightswitch2.wav" )

local white = Vector( 255,255,255 )

local invisibleColor = Color( 0, 0, 0, 0 )
local itemNameColor = Color( 255, 255, 255, 255 )
local itemDescriptionColor = Color( 255, 255, 255, 230 )
local whiteFaded = Color( 255, 255, 255, 240 )
local shopItemColor = Color( 73, 73, 73, 255 )

local cantAffordOverlay = Color( 0, 0, 0, 200 )
local scrollEndsOverlay = Color( 0, 0, 0, 100 )
local notHoveredOverlay = Color( 0, 0, 0, 45 )
local pressedItemOverlay = Color( 255, 255, 255, 25 )

local shopCategoryPanels = {}
local MAINSCROLLNAME = "main_scroll_window"

LocalPlayer().MAINSSHOPPANEL = LocalPlayer().MAINSSHOPPANEL or nil
LocalPlayer().MAINSCROLLPANEL = LocalPlayer().MAINSCROLLPANEL or nil

function termHuntCloseTheShop()
    LocalPlayer():EmitSound( "doors/wood_stop1.wav", 50, 160, 0.25 )
    LocalPlayer().MAINSSHOPPANEL:Remove()

end

local function isHovered( panel )
    local tooltipHovered = nil
    if panel.coolTooltip then
        tooltipHovered = panel.coolTooltip:IsHovered()

    end
    local hoveredCooler = nil
    local hovered = nil
    if panel.IsHoveredCooler then
        hoveredCooler = panel:IsHoveredCooler()

    else
        hovered = panel:IsHovered()

    end

    local hovering = hoveredCooler or tooltipHovered or hovered

    return hovering

end

local function pressableThink( panel, hovering )
    hovering = hovering or isHovered( panel )

    if hovering ~= panel.hoveredOld then

        if not panel.hoveredOld and panel.OnBeginHovering then
            panel:OnBeginHovering()

        elseif panel.hoveredOld and panel.RemoveCoolTooltip then
            panel:RemoveCoolTooltip()

        end

        if ( not panel.initialSetup ) or ( panel.itemData and not panel.purchasable ) then
            -- do nothing

        elseif panel.hoveredOld then
            LocalPlayer():EmitSound( switchSound, 60, 80, 0.12 )

        elseif not panel.hoveredOld then
            LocalPlayer():EmitSound( switchSound, 60, 90, 0.12 )

        end
        panel.hoveredOld = hovering

    end
    panel.initialSetup = true

end

function termHuntOpenTheShop()
    LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    local shopFrame = vgui.Create( "DFrame" )
    LocalPlayer().MAINSSHOPPANEL = shopFrame

    local width, height = glee_sizeScaled( 1920, 1080 )

    local clientsMenuKey = input.LookupBinding( "+menu" )
    clientsMenuKey = input.GetKeyCode( clientsMenuKey )

    -- if pressed button that opened shop, close the shop
    function shopFrame:OnKeyCodePressed( pressed )
        if pressed == clientsMenuKey then termHuntCloseTheShop() return end

    end

    -- if pressed escape, uh, close the shop
    shopFrame.Think = function()
        if input.IsKeyDown( KEY_ESCAPE ) then termHuntCloseTheShop() return end

    end

    shopFrame:ShowCloseButton( false )

    local bigTextPadding = height / 180

    local whiteIdentifierLineWidth = height / 250 -- the white bar
    local offsetNextToIdentifier = whiteIdentifierLineWidth * 4

    shopFrame:SetSize( width, height )
    shopFrame.titleBarSize = 50 -- the exit button isn't gonna rescale, and add space for score display
    shopFrame.costString = ""
    shopFrame.costColor = white

    shopFrame:DockPadding( 0, shopFrame.titleBarSize, 0, 0 ) -- the little lighter bar at the top

    shopFrame:Center()
    shopFrame:MakePopup()
    shopFrame:SetTitle( "" ) -- it's a shop, what else could it be!

    shopFrame.Paint = function()
        draw_RoundedBox( 0, 0, 0, shopFrame:GetWide(), shopFrame:GetTall(), Color( 37, 37, 37, 240 ) )
        draw_RoundedBox( 0, 0, 0, shopFrame:GetWide(), shopFrame.titleBarSize, Color( 50, 50, 50, 180 ) )

        local score = LocalPlayer():GetScore()

        if shopFrame.scoreToAddFrame ~= shopFrame.oldScoreToAddFrame or shopFrame.oldScore ~= score then
            -- create copy
            local scoreToAddFrame = shopFrame.scoreToAddFrame or {}
            local cost = GAMEMODE:shopItemCost( scoreToAddFrame.itemIdentifier, LocalPlayer() )

            shopFrame.costString, shopFrame.costColor = GAMEMODE:translatedShopItemCost( LocalPlayer(), cost, scoreToAddFrame.itemIdentifier )

        end

        shopFrame.oldScore = score
        shopFrame.oldScoreToAddFrame = shopFrame.scoreToAddFrame

        local costString = shopFrame.costString

        local currentScoreAndBridge = score ..  " : "

        surface.SetFont( "termhuntShopScoreFont" )
        local currentScoreW, _ = surface.GetTextSize( currentScoreAndBridge )
        local initialPadding = bigTextPadding + height / 20

        draw.DrawText( currentScoreAndBridge, "termhuntShopScoreFont", initialPadding, 5, white )

        draw.DrawText( costString, "termhuntShopScoreFont", currentScoreW + initialPadding, 5, shopFrame.costColor )

    end

    local mainScrollPanel = vgui.Create( "DScrollPanel", shopFrame, MAINSCROLLNAME )
    LocalPlayer().MAINSCROLLPANEL = mainScrollPanel

    -- removing this doesnt seem to change anything, leaving it just in case
    -- definitely a HACK!
    if not LocalPlayer().MAINSCROLLPANEL and not LocalPlayer().retriedShop then
        timer.Simple( 0.1, function()
            LocalPlayer().retriedShop = true
            termHuntOpenTheShop()
        end )
        return
    end

    -- veritcal scrolling bar width, used for other stuff too so its pretty
    local scrollWidth = height / 18
    mainScrollPanel.verticalScrollWidth = scrollWidth
    mainScrollPanel.verticalScrollWidthPadded = scrollWidth + height / 80

    mainScrollPanel:DockMargin( 0, height / 40, 0, 0 ) -- add negative right HERE when the shop has more than 3 categories!!! 
    mainScrollPanel:Dock( FILL )

    local scrollBar = mainScrollPanel:GetVBar()

    -- move to the other side
    scrollBar:Dock( LEFT )
    scrollBar:SetWide( mainScrollPanel.verticalScrollWidth )

    -- make the scrollbar match the style!
    function scrollBar:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopItemColor )
        draw_RoundedBox( 0, 0, 0, w, h, cantAffordOverlay )
    end

    function scrollBar.btnUp:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopItemColor )
        if not self:IsHovered() then
            draw_RoundedBox( 0, 0, 0, w, h, notHoveredOverlay )
        end
    end

    function scrollBar.btnUp:Think()
        pressableThink( self )
    end

    function scrollBar.btnDown:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopItemColor )
        if not self:IsHovered() then
            draw_RoundedBox( 0, 0, 0, w, h, notHoveredOverlay )
        end
    end

    function scrollBar.btnDown:Think()
        pressableThink( self )
    end

    function scrollBar.btnGrip:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopItemColor )

        draw_RoundedBox( 0, 0, 0, w, offsetNextToIdentifier, scrollEndsOverlay )
        draw_RoundedBox( 0, 0, h + -offsetNextToIdentifier, w, offsetNextToIdentifier + 1, scrollEndsOverlay )

        if not self:IsHovered() then
            draw_RoundedBox( 0, 0, 0, w, h, notHoveredOverlay )
        end
    end

    function scrollBar.btnGrip:Think()
        pressableThink( self )
    end

    local canvas = mainScrollPanel:GetCanvas()
    canvas:DockPadding( mainScrollPanel.verticalScrollWidthPadded, 0, 0, 0 )

    local sortedCategories = table.SortByKey( GAMEMODE.shopCategories, true )

    -- the scrollable things that hold shop items and have names like innate and undead
    for _, category in ipairs( sortedCategories ) do
        local horisScroller = vgui.Create( "DHorizontalScroller", LocalPlayer().MAINSCROLLPANEL, shopCategoryName( category ) )

        --print( "createdcat " .. category .. " " .. tostring( horisScroller ) )
        shopCategoryPanels[ category ] = horisScroller

        LocalPlayer().MAINSCROLLPANEL:AddItem( horisScroller )

        horisScroller:SetSize( glee_sizeScaled( 1920, 300 ) )

        horisScroller.titleBarTall = LocalPlayer().MAINSCROLLPANEL.verticalScrollWidth -- same height as big scroll bar is wide
        horisScroller.topMargin = horisScroller.titleBarTall + height / 80
        horisScroller.breathingRoom = horisScroller.titleBarTall * 0.1

        horisScroller.shopItemHeight = horisScroller:GetTall() + -horisScroller.topMargin
        horisScroller.shopItemWidth = ( whiteIdentifierLineWidth * 2 ) + ( horisScroller.shopItemHeight * 1.5 )

        horisScroller.titleBarWide = horisScroller.shopItemWidth * 1.5

        horisScroller.TextX = offsetNextToIdentifier
        horisScroller.TextY = bigTextPadding

        horisScroller.Paint = function( self )
            -- the long one the items sit on
            draw_RoundedBox( 0, 0, self.topMargin, self:GetWide(), self:GetTall() + self.titleBarTall, shopItemColor )
            -- the little shading under the category label
            draw_RoundedBox( 0, 0, 0, self.titleBarWide, self.titleBarTall, shopItemColor )
            -- lil white line
            draw_RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self.titleBarTall, whiteFaded )
            -- name of category, eg "Innate"
            draw.DrawText( category, "termhuntShopCategoryFont", self.TextX, self.TextY, white )

        end

        horisScroller.OnMouseWheeled = function( self, delta )
            local oldOffset = self.OffsetX or 0
            local stepSize = self.shopItemWidth

            local offsetStepped = math.Round( self.OffsetX + delta * -stepSize * 1.05 )
            self.OffsetX = offsetStepped
            self:InvalidateLayout( true )

            local newOffset = self.OffsetX or 0
            if newOffset ~= oldOffset then -- dont do anything if we reach the end of the scroller
                self:RemoveCoolTooltip()
                local pitchOffset = ( oldOffset - newOffset ) * 0.1
                LocalPlayer():EmitSound( "physics/plastic/plastic_barrel_impact_soft2.wav", 60, 100 + pitchOffset, 0.2 )

            end

            return true

        end

        horisScroller.RemoveCoolTooltip = function( self )
            if self.coolTooltip then
                self.coolTooltip:Remove()

            end
        end

        horisScroller:Dock( TOP )
        horisScroller:DockMargin( 0, 0, 0, height / 30 ) -- between categories

    end

    -- shop items
    for identifier, itemData in SortedPairsByMemberValue( GAMEMODE.shopItems, "weight", false ) do
        local myCategoryPanel = shopCategoryPanels[ itemData.category ]
        if not myCategoryPanel then ErrorNoHaltWithStack( "tried to add item " .. identifier .. " to invalid category, " .. itemData.category ) continue end

        if itemData.canShowInShop and not itemData.canShowInShop() then continue end

        local shopItem = vgui.Create( "DButton", myCategoryPanel, shopPanelName( identifier ) )

        myCategoryPanel:AddPanel( shopItem )

        shopItem.itemData = itemData
        shopItem.itemIdentifier = identifier

        shopItem:SetSize( myCategoryPanel.shopItemWidth, myCategoryPanel.shopItemHeight )
        shopItem:SetText( "" )

        shopItem.IsHoveredCooler = function( self )
            local tooltipHovered = nil
            if self.coolTooltip and self.coolTooltip.fakeButton then
                tooltipHovered = self.coolTooltip.fakeButton:IsHovered()

            end
            return self:IsHovered() or tooltipHovered

        end

        shopItem.Think = function( self )
            local hovering = isHovered( self )
            if not hovering then hovering = false end

            pressableThink( self, hovering )

            if hovering ~= self.hovered then
                if not self.hoveredScoreDisplay and hovering then
                    shopFrame.scoreToAddFrame = self

                elseif self.hoveredScoreDisplay and shopFrame.scoreToAddFrame == self then
                    shopFrame.scoreToAddFrame = nil

                end

                self.hoveredScoreDisplay = hovering
                self.hovered = hovering
            end

            if self.purchased then
                -- other half of the purchasing sounds are handled in sh_shopshared
                LocalPlayer():EmitSound( switchSound, 60, 50, 0.24 )
                self.purchased = nil

            end
            self.notDoneSetup = nil

        end

        -- tooltips!
        shopItem.OnBeginHovering = function( self )
            -- this is spaghetti
            local coolTooltip = vgui.Create( "DSizeToContents", LocalPlayer().MAINSCROLLPANEL, shopPanelName( identifier ) .. "_cooltooltip" )
            -- hide the jank setup bugs!
            coolTooltip.isSetupTime = CurTime() + 0.1

            shopItem.coolTooltip = coolTooltip
            myCategoryPanel.coolTooltip = coolTooltip

            local _, categorysY = myCategoryPanel:GetPos()

            local itemsX, itemsY = shopItem:GetPos()
            local tooltipsY = itemsY + categorysY
            local tooltipsX = itemsX + -myCategoryPanel.OffsetX + LocalPlayer().MAINSCROLLPANEL.verticalScrollWidthPadded
            coolTooltip.xPos, coolTooltip.yPos = tooltipsX, tooltipsY
            local yPosUnder = tooltipsY + shopItem.shopItemNameHPadded * 3.5

            coolTooltip:SetSize( myCategoryPanel.shopItemWidth, myCategoryPanel.shopItemHeight )
            -- up up and away!
            coolTooltip:SetPos( tooltipsX, -tooltipsY + -myCategoryPanel.shopItemHeight )

            coolTooltip.Paint = function ( self )
                if not self.hasSetup then return end
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItemColor )
                draw_RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self:GetTall(), whiteFaded )

            end

            coolTooltip.Think = function ( self )

                -- this is kind of bad
                if coolTooltip.descLabel and coolTooltip.noBuyLabel and IsValid( coolTooltip.descLabel ) and IsValid( coolTooltip.noBuyLabel ) and not coolTooltip.gettingRemoved then
                    local description = shopItem.coolTooltipDescription
                    local descLabel = coolTooltip.descLabel

                    -- item desc
                    descLabel:SetTextInset( offsetNextToIdentifier, offsetNextToIdentifier )
                    descLabel:SetFont( "termhuntShopItemSmallerFont" )
                    descLabel:SetText( description )
                    descLabel:SetContentAlignment( 7 )
                    descLabel:SetWrap( true )
                    descLabel:SizeToContentsY()
                    local descSizeX, descSizeY = descLabel:GetSize()

                    -- why you cant buy this, or markup info
                    local noPurchase = shopItem.coolTooltipNoPurchase
                    local noBuyLabel = coolTooltip.noBuyLabel

                    if noPurchase ~= "" then
                        noBuyLabel:SetTextInset( offsetNextToIdentifier, 0 )
                        noBuyLabel:SetFont( "termhuntShopItemSmallerFont" )
                        noBuyLabel:SetText( noPurchase )
                        noBuyLabel:SetContentAlignment( 7 )
                        noBuyLabel:SetWrap( true )
                        noBuyLabel:SizeToContentsY()

                    else
                        noBuyLabel:SetText( "" )
                        noBuyLabel:SetSize( myCategoryPanel.shopItemWidth, 0 )

                    end
                    local noBSizeX, noBSizeY = noBuyLabel:GetSize()

                    -- put them together with padding around the text
                    descLabel:SetSize( descSizeX + -offsetNextToIdentifier, descSizeY )
                    noBuyLabel:SetSize( noBSizeX + -offsetNextToIdentifier, noBSizeY + offsetNextToIdentifier )
                    coolTooltip.fakeButton:SetSize( descSizeX + noBSizeX, descSizeY + noBSizeY + offsetNextToIdentifier )

                    if coolTooltip.hasSetup then
                        descLabel:SetTextColor( itemDescriptionColor )
                        noBuyLabel:SetTextColor( itemDescriptionColor )

                    end
                end

                local _, scaledSizeY = self:GetSize()
                if scaledSizeY ~= 0 then
                    local bottomOfTip = yPosUnder + scaledSizeY + height / 10
                    if bottomOfTip > height then
                        yPosAbove = tooltipsY + -scaledSizeY
                        self:SetPos( tooltipsX, yPosAbove )
                        self.fakeButton:SetPos( tooltipsX, yPosAbove )
                    else
                        self:SetPos( tooltipsX, yPosUnder )
                        self.fakeButton:SetPos( tooltipsX, yPosAbove )
                    end
                end

                if self.isSetupTime > CurTime() then return end
                self.hasSetup = true

            end


            local tooltipTopButton = vgui.Create( "DButton", coolTooltip, shopPanelName( identifier ) .. "_cooltooltip_topbutton" )

            coolTooltip.fakeButton = tooltipTopButton
            tooltipTopButton:SetText( "" )
            tooltipTopButton:Dock( TOP )

            tooltipTopButton.Paint = function( _ )
            end

            tooltipTopButton.OnMousePressed = function( _, keyCode )
                shopItem:OnMousePressed( keyCode )

            end

            tooltipTopButton.OnMouseReleased = function( _, keyCode )
                shopItem:OnMouseReleased( keyCode )

            end

            tooltipTopButton.OnMouseWheeled = function( _, delta )
                myCategoryPanel:OnMouseWheeled( delta )
                return true

            end

            tooltipTopButton.PaintOver = function( self )
                if not coolTooltip.hasSetup then return end
                if shopItem.myOverlayColor then
                    draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItem.myOverlayColor )

                end
            end


            local descLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_label" )

            descLabel:SetTextColor( invisibleColor )

            coolTooltip.descLabel = descLabel

            descLabel:SetSize( myCategoryPanel.shopItemWidth )
            descLabel:Dock( TOP )


            local noBuyLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_label" )

            noBuyLabel:SetTextColor( invisibleColor )

            coolTooltip.noBuyLabel = noBuyLabel

            noBuyLabel:SetSize( myCategoryPanel.shopItemWidth )
            noBuyLabel:Dock( TOP )

        end

        shopItem.RemoveCoolTooltip = function( self )
            local tooltip = shopItem.coolTooltip
            if not tooltip then return end
            if tooltip.descLabel then
                tooltip.descLabel:Remove()

            end
            if tooltip.noBuyLabel then
                tooltip.noBuyLabel:Remove()

            end
            -- let the text remove so it NEVER flashes
            timer.Simple( 0, function()
                if not IsValid( tooltip ) then return end
                if tooltip.fakeButton then
                    tooltip.fakeButton:Remove()

                end
                tooltip:Remove()

            end )
        end

        -- tooltips end
        -- paint the shop item!
        shopItem.Paint = function( self )

            local score = LocalPlayer():GetScore()

            local nextBigCaching = self.nextBigCaching or 0

            if nextBigCaching < CurTime() or score ~= self.oldScore then

                local identifierPaint = self.itemIdentifier

                self.purchasable, self.notPurchasableReason = GAMEMODE:canPurchase( LocalPlayer(), identifierPaint )
                self.nextBigCaching = CurTime() + 0.1
                self.oldScore = score

                local cost = GAMEMODE:shopItemCost( identifierPaint, LocalPlayer() )
                self.costString, self.costColor = GAMEMODE:translatedShopItemCost( LocalPlayer(), cost, identifierPaint )

                -- markups applied
                self.markupString = ""
                local currentMarkup = GAMEMODE:shopMarkup( LocalPlayer(), identifierPaint )
                if currentMarkup ~= 1 then
                    self.markupString = "( " .. tostring( currentMarkup ) .. "x markup )"
                end

                -- handle tooltips
                local description = ""
                if self.itemData.desc and self.itemData.desc ~= "" then
                    description = self.itemData.desc

                end

                local additionalMarkupStr = ""
                local localizedMarkupPer = self.itemData.markupPerPurchase
                if localizedMarkupPer and isnumber( localizedMarkupPer ) then
                    local boughtCount = GAMEMODE:purchaseCount( LocalPlayer(), identifierPaint )
                    if boughtCount == 0 then
                        additionalMarkupStr = "\nCost is marked up +" .. localizedMarkupPer .. "x per purchase."
                    else
                        additionalMarkupStr = "\nBought " .. boughtCount .. ". Additional markup is +" .. localizedMarkupPer * boughtCount .. "x"
                    end
                end

                local noPurchaseReason = ""
                if self.notPurchasableReason and self.notPurchasableReason ~= "" then
                    noPurchaseReason = "\n" .. self.notPurchasableReason

                end

                self.coolTooltipDescription = description
                self.coolTooltipNoPurchase = additionalMarkupStr .. noPurchaseReason

                -- check after all the potentially custom functions had a chance to run  
                if GAMEMODE.invalidShopItems[ identifierPaint ] then self:Remove() return end

            end
            draw_RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self:GetTall(), whiteFaded )

            surface.SetFont( "termhuntShopItemFont" )
            local _, shopItemNameH = surface.GetTextSize( self.itemData.name )

            local shopItemNameHPadded = shopItemNameH * 1.2
            self.shopItemNameHPadded = shopItemNameHPadded

            --item name
            draw.DrawText( self.itemData.name, "termhuntShopItemFont", offsetNextToIdentifier, offsetNextToIdentifier, itemNameColor, TEXT_ALIGN_LEFT )
            --item cost
            draw.DrawText( self.costString, "termhuntShopItemFont", offsetNextToIdentifier, shopItemNameHPadded + offsetNextToIdentifier, self.costColor, TEXT_ALIGN_LEFT )
            -- current markup being applied
            draw.DrawText( self.markupString, "termhuntShopItemFont", offsetNextToIdentifier, shopItemNameHPadded + shopItemNameHPadded + offsetNextToIdentifier, Color( 140, 140, 140, 255 ), TEXT_ALIGN_LEFT )

            self.myOverlayColor = nil

            if not self.purchasable then
                self.myOverlayColor = cantAffordOverlay
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            elseif not self:IsHoveredCooler() then
                self.pressed = nil
                self.myOverlayColor = notHoveredOverlay
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            elseif self.pressed then
                self.myOverlayColor = pressedItemOverlay
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            end
        end

        -- buy the item!
        shopItem.OnMousePressed = function( self, keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = true

            if self.purchasable then -- purchasability is also checked on server! no cheesing!
                RunConsoleCommand( "termhunt_purchase", self.itemIdentifier )
                self.purchased = true

            end
        end

        shopItem.OnMouseReleased = function( self, keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = nil
        end

        shopItem:DockMargin( 0, myCategoryPanel.topMargin, 0, 0 )
        shopItem:Dock( LEFT )

        --print( "put " .. identifier .. " into " .. tostring( myCategoryPanel ) )

    end
end

-- yoinked from darkrp so we do it right
local FKeyBinds = {
    ["+menu"] = "ShowShop",

}

function GM:PlayerBindPress( _, bind, _ )
    if FKeyBinds[bind] then
        hook.Call( FKeyBinds[bind], GAMEMODE )

    end
end

LocalPlayer().openedHuntersGleeShop = nil
local nextShopOpen = 0

function GM:ShowShop()
    if nextShopOpen > CurTime() then return end
    if self:CanShowDefaultHud() then
        LocalPlayer().openedHuntersGleeShop = true
        termHuntOpenTheShop()

    end
end

local nextShopClose = 0

net.Receive( "glee_closetheshop", function()
    if nextShopClose > CurTime() then return end
    nextShopClose = CurTime() + 0.05

    if not IsValid( LocalPlayer().MAINSSHOPPANEL ) then return end
    termHuntCloseTheShop()
    nextShopOpen = CurTime() + 0.1

end )