print( "GOOEY" )

local function shopPanelName( identifier )
    return "termhunt_shoppanel_" .. identifier
end

local function shopCategoryName( identifier )
    return "termhunt_shopcategory_" .. identifier
end

-- Your score font
local fontData = {
    font = "Arial",
    extended = false,
    size = 40,
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
local fontData = {
    font = "Arial",
    extended = false,
    size = 50,
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
local fontData = {
    font = "Arial",
    extended = false,
    size = 25,
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
local fontData = {
    font = "Arial",
    extended = false,
    size = 22.5,
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


local _LocalPlayer = LocalPlayer

local uiScale = ScrH() / 1080

local function sizSc( sizeX, sizeY ) -- sizSc short for Size Scaled
    return sizeX * uiScale, sizeY * uiScale
end

local switchSound = Sound( "buttons/lightswitch2.wav" )

local invisibleColor = Color( 0, 0, 0, 0 )
local itemNameColor = Color( 255, 255, 255, 255 )
local itemDescriptionColor = Color( 255, 255, 255, 230 )
local whiteFaded = Color( 255, 255, 255, 240 )
local shopItemColor = Color( 73, 73, 73, 255 )

local shopCategoryPanels = {}
local MAINSCROLLNAME = "main_scroll_window"

_LocalPlayer().MAINSSHOPPANEL = _LocalPlayer().MAINSSHOPPANEL or nil
_LocalPlayer().MAINSCROLLPANEL = _LocalPlayer().MAINSCROLLPANEL or nil

local white = Vector( 255,255,255 )

function termHuntCloseTheShop()
    _LocalPlayer():EmitSound( "doors/wood_stop1.wav", 50, 160, 0.25 )
    _LocalPlayer().MAINSSHOPPANEL:Remove()

end

function termHuntOpenTheShop()
    _LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    local shopFrame = vgui.Create( "DFrame" )
    _LocalPlayer().MAINSSHOPPANEL = shopFrame

    local width, height = sizSc( 1920, 1080 )

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
    shopFrame:SetTitle( "" ) -- it's a shop, if people can't figure that out then i've failed as a designer

    shopFrame.Paint = function()
        draw.RoundedBox( 0, 0, 0, shopFrame:GetWide(), shopFrame:GetTall(), Color( 37, 37, 37, 240 ) )
        draw.RoundedBox( 0, 0, 0, shopFrame:GetWide(), shopFrame.titleBarSize, Color( 50, 50, 50, 180 ) )

        local score = _LocalPlayer():GetScore()

        if shopFrame.scoreToAddFrame ~= shopFrame.oldScoreToAddFrame or shopFrame.oldScore ~= score then
            -- create copy
            local scoreToAddFrame = shopFrame.scoreToAddFrame or {}
            local cost = GAMEMODE:shopItemCost( scoreToAddFrame.itemIdentifier, _LocalPlayer() )

            shopFrame.costString, shopFrame.costColor = GAMEMODE:translatedShopItemCost( score, cost, _LocalPlayer(), scoreToAddFrame.itemIdentifier )

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

    _LocalPlayer().MAINSCROLLPANEL = vgui.Create( "DScrollPanel", shopFrame, MAINSCROLLNAME )
    if not _LocalPlayer().MAINSCROLLPANEL and not _LocalPlayer().retriedShop then -- HACK
        timer.Simple( 0.1, function()
            _LocalPlayer().retriedShop = true
            termHuntOpenTheShop()
        end )
        return
    end
    _LocalPlayer().MAINSCROLLPANEL:DockMargin( height / 20, height / 40, 0, 0 )
    _LocalPlayer().MAINSCROLLPANEL:Dock( FILL )


    local sortedCategories = table.SortByKey( GAMEMODE.shopCategories, true )

    for _, category in ipairs( sortedCategories ) do
        local horisScroller = vgui.Create( "DHorizontalScroller", _LocalPlayer().MAINSCROLLPANEL, shopCategoryName( category ) )

        --print( "createdcat " .. category .. " " .. tostring( horisScroller ) )
        shopCategoryPanels[ category ] = horisScroller

        _LocalPlayer().MAINSCROLLPANEL:AddItem( horisScroller )

        horisScroller:SetSize( sizSc( 1728, 300 ) )

        horisScroller.titleBarTall = height / 18
        horisScroller.topMargin = horisScroller.titleBarTall + height / 80
        horisScroller.breathingRoom = horisScroller.titleBarTall * 0.1

        horisScroller.shopItemHeight = horisScroller:GetTall() + -horisScroller.topMargin
        horisScroller.shopItemWidth = ( whiteIdentifierLineWidth * 2 ) + ( horisScroller.shopItemHeight * 1.5 )

        horisScroller.titleBarWide = horisScroller.shopItemWidth * 1.5

        horisScroller.TextX = offsetNextToIdentifier
        horisScroller.TextY = bigTextPadding

        horisScroller.Paint = function( self )
            -- the long one the items sit on
            draw.RoundedBox( 0, 0, self.topMargin, self:GetWide(), self:GetTall() + self.titleBarTall, shopItemColor )
            -- the little shading under the category label
            draw.RoundedBox( 0, 0, 0, self.titleBarWide, self.titleBarTall, Color( 73, 73, 73, 240 ) )
            -- lil white line
            draw.RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self.titleBarTall, whiteFaded )
            -- name of category, eg "Innate"
            draw.DrawText( category, "termhuntShopCategoryFont", self.TextX, self.TextY, Color( 255,255,255 ) )

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
                _LocalPlayer():EmitSound( "physics/plastic/plastic_barrel_impact_soft2.wav", 60, 100 + pitchOffset, 0.2 )

            end

            return true

        end

        horisScroller.RemoveCoolTooltip = function( self )
            if self.coolTooltip then
                self.coolTooltip:Remove()

            end
        end

        horisScroller:Dock( TOP )
        horisScroller:DockMargin( 0, 0, 0, height / 40 ) -- between categories

    end

    for identifier, itemData in SortedPairsByMemberValue( GAMEMODE.shopItems, "weight", false ) do
        local myCategoryPanel = shopCategoryPanels[ itemData.category ]
        if not myCategoryPanel then ErrorNoHaltWithStack( "tried to add item " .. identifier .. " to invalid category, " .. itemData.category ) continue end

        if itemData.canShowInShop and not itemData.canShowInShop() then continue end

        local shopItem = vgui.Create( "DButton", myCategoryPanel, shopPanelName( identifier ) )

        myCategoryPanel:AddPanel( shopItem )

        shopItem.itemData = itemData
        shopItem.itemIdentifier = identifier

        shopItem.initialSetup = true

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
            local tooltipHovered = nil
            if self.coolTooltip then
                tooltipHovered = self.coolTooltip:IsHovered()

            end
            local hovering = self:IsHoveredCooler() or tooltipHovered
            if hovering ~= self.hovered then
                if not self.purchasable and not self.initialSetup then
                    -- do nothing
                elseif hovering and not self.hovered then
                    self:OnBeginHovering()
                elseif self.hovered then
                    self:RemoveCoolTooltip()
                    _LocalPlayer():EmitSound( switchSound, 60, 80, 0.12 )

                elseif not self.initialSetup then
                    _LocalPlayer():EmitSound( switchSound, 60, 120, 0.25 )

                end

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
                _LocalPlayer():EmitSound( switchSound, 60, 50, 0.24 )
                self.purchased = nil

            end
            self.notDoneSetup = nil

        end

        shopItem.OnBeginHovering = function( self )
            -- this is spaghetti
            local coolTooltip = vgui.Create( "DSizeToContents", _LocalPlayer().MAINSCROLLPANEL, shopPanelName( identifier ) .. "_cooltooltip" )
            -- hide the jank setup bugs!
            coolTooltip.isSetupTime = CurTime() + 0.1

            shopItem.coolTooltip = coolTooltip
            myCategoryPanel.coolTooltip = coolTooltip

            local _, categorysY = myCategoryPanel:GetPos()
            local itemsX, itemsY = shopItem:GetPos()
            local tooltipsY = itemsY + categorysY
            local tooltipsX = itemsX + -myCategoryPanel.OffsetX
            coolTooltip.xPos, coolTooltip.yPos = tooltipsX, tooltipsY
            local yPosUnder = tooltipsY + shopItem.shopItemNameHPadded * 3.5

            coolTooltip:SetSize( myCategoryPanel.shopItemWidth, myCategoryPanel.shopItemHeight )
            -- up up and away!
            coolTooltip:SetPos( tooltipsX, -tooltipsY + -myCategoryPanel.shopItemHeight )

            coolTooltip.Paint = function ( self )
                if not self.hasSetup then return end
                draw.RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItemColor )
                draw.RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self:GetTall(), whiteFaded )

            end

            coolTooltip.Think = function ( self )
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

            end

            tooltipTopButton.PaintOver = function( self )
                if not coolTooltip.hasSetup then return end
                if shopItem.myOverlayColor then
                    draw.RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItem.myOverlayColor )

                end
            end


            local textLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_label" )

            textLabel:SetTextColor( invisibleColor )

            coolTooltip.textLabel = textLabel

            textLabel:SetSize( myCategoryPanel.shopItemWidth )
            textLabel:Dock( LEFT )
            textLabel:Dock( TOP )

            textLabel.Think = function( self )
                if coolTooltip.gettingRemoved then return end
                self:SetTextInset( offsetNextToIdentifier, offsetNextToIdentifier )
                self:SetFont( "termhuntShopItemSmallerFont" )
                self:SetText( shopItem.coolTooltipString )
                self:SetContentAlignment( 7 )
                self:SetWrap( true )
                self:SizeToContentsY()
                local sizeX, sizeY = self:GetSize()

                self:SetSize( sizeX + -offsetNextToIdentifier, sizeY + offsetNextToIdentifier )
                coolTooltip.fakeButton:SetSize( sizeX, sizeY + offsetNextToIdentifier )

                if coolTooltip.hasSetup then
                    self:SetTextColor( itemDescriptionColor )

                end

            end
        end

        shopItem.RemoveCoolTooltip = function( self )
            local tooltip = shopItem.coolTooltip
            if not tooltip then return end
            if tooltip.textLabel then
                tooltip.textLabel:Remove()

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

        shopItem.Paint = function( self )

            local score = _LocalPlayer():GetScore()

            local nextBigCaching = self.nextBigCaching or 0

            if nextBigCaching < CurTime() or score ~= self.oldScore then

                local identifierPaint = self.itemIdentifier

                self.purchasable, self.notPurchasableReason = GAMEMODE:canPurchase( _LocalPlayer(), identifierPaint )
                self.nextBigCaching = CurTime() + 0.1
                self.oldScore = score

                local cost = GAMEMODE:shopItemCost( identifierPaint, _LocalPlayer() )
                self.costString, self.costColor = GAMEMODE:translatedShopItemCost( score, cost, _LocalPlayer(), identifierPaint )

                -- markups applied
                self.markupString = ""
                local currentMarkup = GAMEMODE:shopMarkup( _LocalPlayer(), identifierPaint )
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
                    local boughtCount = GAMEMODE:purchaseCount( _LocalPlayer(), identifierPaint )
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

                local tooltip = description .. additionalMarkupStr .. noPurchaseReason

                self.coolTooltipString = tooltip

                -- check after all the potentially custom functions had a chance to run  
                if GAMEMODE.invalidShopItems[ identifierPaint ] then self:Remove() return end

            end
            draw.RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self:GetTall(), Color( 255, 255, 255, 240 ) )

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
                self.myOverlayColor = Color( 0, 0, 0, 200 )
                draw.RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            elseif not self:IsHoveredCooler() then
                self.pressed = nil
                self.myOverlayColor = Color( 0, 0, 0, 45 )
                draw.RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            elseif self.pressed then
                self.myOverlayColor = Color( 255, 255, 255, 25 )
                draw.RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            end
        end

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