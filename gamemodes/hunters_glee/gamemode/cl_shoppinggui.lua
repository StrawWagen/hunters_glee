local GAMEMODE = GAMEMODE or GM

local function shopPanelName( identifier )
    return "termhunt_shoppanel_" .. identifier
end

local function shopCategoryName( identifier )
    return "termhunt_shopcategory_" .. identifier
end

local draw = draw
local surface = surface

local LocalPlayer = LocalPlayer
local draw_RoundedBox = draw.RoundedBox

local onFinishLoading = function( shopHolder )
    local ply = LocalPlayer()
    local plyHasUnlockedItem = GAMEMODE.plyHasUnlockedItem
    local plyHasEnabledItem = GAMEMODE.plyHasEnabledItem
    local shopStandards = GAMEMODE.shopStandards
    local height = shopHolder.finalHeight

    local shopCategoriesBlocked = {}
    local shopCategoryPanels = {}
    local categories = table.Copy( GAMEMODE.shopCategories )
    -- the scrollable things that hold shop items and have names like innate and undead
    for category, stuff in SortedPairsByMemberValue( categories, "order", false ) do
        if stuff.canShowInShop and not stuff.canShowInShop( ply ) then shopCategoriesBlocked[ category ] = true continue end

        local horisScroller = vgui.Create( "DHorizontalScroller", ply.HOLDERSCROLLPANEL, shopCategoryName( category ) )

        --print( "createdcat " .. category .. " " .. tostring( horisScroller ) )
        shopCategoryPanels[ category ] = horisScroller

        ply.HOLDERSCROLLPANEL:AddItem( horisScroller )

        horisScroller:SetSize( GAMEMODE.shopStandards.shopCategoryWidth, GAMEMODE.shopStandards.shopCategoryHeight )

        horisScroller.btnRight.Paint = function() end
        horisScroller.btnLeft.Paint = function() end

        horisScroller.betweenCategorySpacing = height / 80
        horisScroller.titleBarTall = ply.HOLDERSCROLLPANEL.verticalScrollWidth -- same height as big scroll bar is wide
        horisScroller.topMargin = horisScroller.titleBarTall + horisScroller.betweenCategorySpacing * 2
        horisScroller.breathingRoom = horisScroller.titleBarTall * 0.1

        horisScroller.shopItemHeight = horisScroller:GetTall() + -horisScroller.topMargin
        horisScroller.shopItemWidth = ( shopHolder.whiteIdentifierLineWidth * 2.5 ) + ( horisScroller.shopItemHeight * 1.5 )

        horisScroller.titleBarWide = horisScroller.shopItemWidth * 1.5

        horisScroller.TextX = shopHolder.offsetNextToIdentifier
        horisScroller.TextY = shopHolder.bigTextPadding + horisScroller.betweenCategorySpacing

        horisScroller.Paint = function( self )
            -- the little shading under the category label
            draw_RoundedBox( 0, 0, self.betweenCategorySpacing, self.titleBarWide, self.titleBarTall, shopHolder.shopItemColor )
            -- lil white line
            draw_RoundedBox( 0, 0, self.betweenCategorySpacing, shopHolder.whiteIdentifierLineWidth, self.titleBarTall, shopHolder.whiteFaded )
            -- name of category, eg "Innate"
            draw.DrawText( category, "termhuntShopCategoryFont", self.TextX, self.TextY, shopHolder.white )

        end

        horisScroller.CoolerScroll = function( self, delta, stepScale )
            local oldOffset = self.OffsetX or 0
            local stepSize = self.shopItemWidth * stepScale

            local offsetStepped = math.Round( self.OffsetX + delta * -stepSize * 1.05 )
            self.OffsetX = offsetStepped
            self:InvalidateLayout( true )

            local newOffset = self.OffsetX or 0
            if newOffset ~= oldOffset then -- dont do anything if we reach the end of the scroller
                ply.oldScrollPositions.pointShop[ category ] = newOffset
                self:RemoveCoolTooltip()
                local pitchOffset = ( oldOffset - newOffset ) * 0.1
                pitchOffset = pitchOffset / stepScale
                ply:EmitSound( "physics/plastic/plastic_barrel_impact_soft2.wav", 60, 100 + pitchOffset, 0.2 * stepScale )

            end

            return true

        end

        horisScroller.Think = function( self )
            if self.fixedScroll then return end
            self.fixedScroll = nil
            self:SetScroll( ply.oldScrollPositions.pointShop[ category ] or 0 )

        end

        horisScroller.OnMouseWheeled = function( self, delta )
            return self:CoolerScroll( delta, 1 )

        end

        horisScroller.RemoveCoolTooltip = function( self )
            if self.coolTooltip then
                self.coolTooltip:Remove()

            end
        end

        horisScroller:Dock( TOP )

    end

    -- shop items
    for identifier, itemData in SortedPairsByMemberValue( GAMEMODE.shopItems, "weight", false ) do
        local myCategory = itemData.category
        if shopCategoriesBlocked[ myCategory ] then continue end

        local myCategoryPanel = shopCategoryPanels[ myCategory ]
        if not myCategoryPanel then ErrorNoHaltWithStack( "tried to add item " .. identifier .. " to invalid category, " .. myCategory ) continue end

        if itemData.canShowInShop and not itemData.canShowInShop( ply ) then continue end

        if itemData.skullCost > 0 and not plyHasUnlockedItem( GAMEMODE, ply, identifier ) then continue end
        if not plyHasEnabledItem( GAMEMODE, ply, identifier ) then continue end

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
            local hovering = shopStandards.isHovered( self )
            shopStandards.pressableThink( self, hovering )

            if hovering ~= self.hovered then
                if not self.hoveredScoreDisplay and hovering then
                    shopHolder.scoreToAddFrame = self

                elseif self.hoveredScoreDisplay and shopHolder.scoreToAddFrame == self then
                    shopHolder.scoreToAddFrame = nil

                end

                self.hoveredScoreDisplay = hovering
                self.hovered = hovering
            end

            if self.purchased then
                -- button pressing sound
                -- other half of the purchasing sounds are handled in sh_shopshared
                ply:EmitSound( shopStandards.switchSound, 60, 50, 0.24 )
                self.purchased = nil

            elseif self.triedToPurchase then
                if shopItem.coolTooltip then
                    local oldTime = shopItem.coolTooltip.noPurchaseShakeTime or 0
                    shopItem.coolTooltip.noPurchaseShakeTime = math.max( CurTime() + 0.5, oldTime + 0.1 )

                end
                self.triedToPurchase = nil

            end
        end

        -- tooltips!
        shopItem.OnBeginHovering = function()
            -- this is spaghetti
            local coolTooltip = vgui.Create( "DSizeToContents", ply.HOLDERSCROLLPANEL, shopPanelName( identifier ) .. "_cooltooltip" )
            -- hide the jank setup bugs!
            coolTooltip.isSetupTime = CurTime() + 0.1

            shopItem.coolTooltip = coolTooltip
            myCategoryPanel.coolTooltip = coolTooltip

            local _, categorysY = myCategoryPanel:GetPos()

            local itemsX, itemsY = shopItem:GetPos()
            local tooltipsY = itemsY + categorysY
            local tooltipsX = itemsX + -myCategoryPanel.OffsetX
            coolTooltip.xPos, coolTooltip.yPos = tooltipsX, tooltipsY
            -- pos under the text, not under the item
            local yPosUnder = tooltipsY + shopItem.shopItemNameHPadded * 3.5

            coolTooltip:SetSize( myCategoryPanel.shopItemWidth, myCategoryPanel.shopItemHeight )
            -- up up and away!
            coolTooltip:SetPos( tooltipsX, -tooltipsY + -myCategoryPanel.shopItemHeight )

            coolTooltip.Paint = function ( self )
                if not self.hasSetup then return end
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.shopItemColor )
                draw_RoundedBox( 0, 0, 0, shopHolder.whiteIdentifierLineWidth, self:GetTall(), shopHolder.whiteFaded )

            end

            coolTooltip.Think = function ( self )

                -- this is kind of bad
                if coolTooltip.descLabel and coolTooltip.markupLabel and coolTooltip.noBuyLabel and IsValid( coolTooltip.descLabel ) and IsValid( coolTooltip.markupLabel ) and IsValid( coolTooltip.noBuyLabel ) and not coolTooltip.gettingRemoved then
                    local description = shopItem.coolTooltipDescription
                    local descLabel = coolTooltip.descLabel

                    -- item desc
                    descLabel:SetTextInset( shopHolder.offsetNextToIdentifier, shopHolder.offsetNextToIdentifier )
                    descLabel:SetFont( "termhuntShopItemSmallerFont" )
                    descLabel:SetText( description )
                    descLabel:SetContentAlignment( 7 )
                    descLabel:SetWrap( true )
                    descLabel:SizeToContentsY()
                    local descSizeX, descSizeY = descLabel:GetSize()

                    -- info on markups
                    local markupInfo = shopItem.coolTooltipMarkup
                    local markupLabel = coolTooltip.markupLabel

                    if markupInfo ~= "" then
                        markupLabel:SetTextInset( shopHolder.offsetNextToIdentifier, 0 )
                        markupLabel:SetFont( "termhuntShopItemSmallerFont" )
                        markupLabel:SetText( markupInfo )
                        markupLabel:SetContentAlignment( 7 )
                        markupLabel:SetWrap( true )
                        markupLabel:SizeToContentsY()

                    else
                        markupLabel:SetText( "" )
                        markupLabel:SetSize( myCategoryPanel.shopItemWidth, 0 )

                    end
                    local markupSizeX, markupSizeY = markupLabel:GetSize()

                    -- why you cant buy this
                    local noPurchase = shopItem.coolTooltipNoPurchase
                    local noBuyLabel = coolTooltip.noBuyLabel

                    if noPurchase ~= "" then
                        noBuyLabel:SetTextInset( shopHolder.offsetNextToIdentifier, 0 )
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
                    descLabel:SetSize( descSizeX + -shopHolder.offsetNextToIdentifier, descSizeY )
                    markupLabel:SetSize( markupSizeX + -shopHolder.offsetNextToIdentifier, markupSizeY )
                    noBuyLabel:SetSize( noBSizeX + -shopHolder.offsetNextToIdentifier, noBSizeY + shopHolder.offsetNextToIdentifier )
                    coolTooltip.fakeButton:SetSize( descSizeX + markupSizeX + noBSizeX, descSizeY + markupSizeY + noBSizeY + shopHolder.offsetNextToIdentifier )

                    if coolTooltip.hasSetup then
                        descLabel:SetTextColor( shopHolder.whiteFaded )
                        noBuyLabel:SetTextColor( shopHolder.whiteFaded )
                        markupLabel:SetTextColor( shopHolder.whiteFaded )

                    end
                end

                local _, scaledSizeY = self:GetSize()
                if scaledSizeY ~= 0 then
                    local bottomOfTip = yPosUnder + scaledSizeY + height / 5
                    if bottomOfTip > height then
                        yPosAbove = tooltipsY + -scaledSizeY
                        self:SetPos( tooltipsX, yPosAbove )
                        self.fakeButton:SetPos( tooltipsX, yPosAbove )
                    else
                        self:SetPos( tooltipsX, yPosUnder )
                        self.fakeButton:SetPos( tooltipsX, yPosAbove )
                    end
                end

                if coolTooltip.noBuyLabel:IsValid() then
                    local shakeTime = self.noPurchaseShakeTime or 0
                    local noPurchaseShake = 0
                    if shakeTime > CurTime() then
                        local absed = math.abs( self.noPurchaseShakeTime - CurTime() )
                        noPurchaseShake = math.Rand( -absed, absed ) * 8
                    end

                    local noBuyLabel = coolTooltip.noBuyLabel
                    noBuyLabel:DockMargin( 0, noPurchaseShake, 0, noPurchaseShake )
                    noBuyLabel:Dock( TOP )

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

            tooltipTopButton.CoolerScroll = function( _, delta, stepScale )
                myCategoryPanel:CoolerScroll( delta, stepScale )

            end

            tooltipTopButton.PaintOver = function( self )
                if not coolTooltip.hasSetup then return end
                if shopItem.myOverlayColor then
                    draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItem.myOverlayColor )

                end
            end


            local descLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_desclabel" )

            descLabel:SetTextColor( shopHolder.invisibleColor )

            coolTooltip.descLabel = descLabel

            descLabel:SetSize( myCategoryPanel.shopItemWidth )
            descLabel:Dock( TOP )


            local markupLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_markuplabel" )

            markupLabel:SetTextColor( shopHolder.invisibleColor )

            coolTooltip.markupLabel = markupLabel

            markupLabel:SetSize( myCategoryPanel.shopItemWidth )
            markupLabel:Dock( TOP )


            local noBuyLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_nobuylabel" )

            noBuyLabel:SetTextColor( shopHolder.invisibleColor )

            coolTooltip.noBuyLabel = noBuyLabel

            noBuyLabel:SetSize( myCategoryPanel.shopItemWidth )
            noBuyLabel:Dock( TOP )

        end

        shopItem.RemoveCoolTooltip = function()
            local tooltip = shopItem.coolTooltip
            if not tooltip then return end
            if tooltip.descLabel then
                tooltip.descLabel:Remove()

            end
            if tooltip.markupLabel then
                tooltip.markupLabel:Remove()

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

            local score = ply:GetScore()

            local nextBigCaching = self.nextBigCaching or 0

            if nextBigCaching < CurTime() or score ~= self.oldScore then

                local identifierPaint = self.itemIdentifier

                self.purchasable, self.notPurchasableReason = GAMEMODE:canPurchase( ply, identifierPaint )
                self.pressable = self.purchasable
                self.nextBigCaching = CurTime() + 0.1
                self.oldScore = score

                -- add newline before no buy reason
                local noPurchaseReason = ""
                if self.notPurchasableReason and self.notPurchasableReason ~= "" then
                    noPurchaseReason = "\n" .. self.notPurchasableReason

                end

                local cost = GAMEMODE:shopItemCost( identifierPaint, ply )

                -- "decorative" cost that isn't applied when purchased
                local decorativeCost = itemData.costDecorative
                if decorativeCost then
                    self.costString = itemData.costDecorative

                elseif itemData.simpleCostDisplay then
                    self.costString = tostring( cost )

                else
                    self.costString, self.costColor = GAMEMODE:translatedShopItemCost( ply, cost, identifierPaint )

                end

                -- markups applied
                self.markupString = ""
                local currentMarkup = GAMEMODE:shopMarkup( ply, identifierPaint )
                if currentMarkup ~= 1 then
                    self.markupString = "( " .. tostring( currentMarkup ) .. "x markup )"
                end

                -- handle tooltips
                local description = ""
                local descriptionReturned = GAMEMODE:translateShopItemDescription( ply, identifierPaint, self.itemData.desc )
                if descriptionReturned and descriptionReturned ~= "" then
                    description = descriptionReturned

                end

                local additionalMarkupStr = ""
                local localizedMarkupPer = self.itemData.markupPerPurchase
                if localizedMarkupPer and isnumber( localizedMarkupPer ) then
                    local boughtCount = GAMEMODE:purchaseCount( ply, identifierPaint )
                    if boughtCount == 0 then
                        additionalMarkupStr = "\nCost is marked up +" .. localizedMarkupPer .. "x per purchase."
                    else
                        additionalMarkupStr = "\nBought " .. boughtCount .. ". Additional markup is +" .. localizedMarkupPer * boughtCount .. "x"
                    end
                end

                self.coolTooltipDescription = description
                self.coolTooltipMarkup = additionalMarkupStr
                self.coolTooltipNoPurchase = noPurchaseReason

                -- check after all the potentially custom functions had a chance to run  
                if GAMEMODE.invalidShopItems[ identifierPaint ] then self:Remove() return end

            end

            local hovered = self:IsHoveredCooler()

            if hovered then
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.shopItemColor )

            end

            draw_RoundedBox( 0, 0, 0, shopHolder.whiteIdentifierLineWidth, self:GetTall(), shopHolder.whiteFaded )

            surface.SetFont( "termhuntShopItemFont" )
            local _, shopItemNameH = surface.GetTextSize( self.itemData.name )

            local shopItemNameHPadded = shopItemNameH * 1.2
            self.shopItemNameHPadded = shopItemNameHPadded

            --item name
            draw.DrawText( self.itemData.name, "termhuntShopItemFont", shopHolder.offsetNextToIdentifier, shopHolder.offsetNextToIdentifier, white, TEXT_ALIGN_LEFT )
            --item cost
            draw.DrawText( self.costString, "termhuntShopItemFont", shopHolder.offsetNextToIdentifier, shopItemNameHPadded + shopHolder.offsetNextToIdentifier, self.costColor, TEXT_ALIGN_LEFT )
            -- current markup being applied
            draw.DrawText( self.markupString, "termhuntShopItemFont", shopHolder.offsetNextToIdentifier, shopItemNameHPadded + shopItemNameHPadded + shopHolder.offsetNextToIdentifier, shopHolder.markupTextColor, TEXT_ALIGN_LEFT )

            self.myOverlayColor = nil

            if not self.purchasable then
                self.myOverlayColor = shopHolder.cantAffordOverlay

            elseif not hovered then
                self.pressed = nil
                self.myOverlayColor = shopHolder.notHoveredOverlay

            elseif self.pressed then
                self.myOverlayColor = shopHolder.pressedItemOverlay

            end

            if self.myOverlayColor then
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), self.myOverlayColor )

            end
        end

        -- buy the item!
        shopItem.OnMousePressed = function( self, keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = true

            if self.purchasable then -- purchasability is also checked on server! no cheesing!
                RunConsoleCommand( "cl_termhunt_purchase", self.itemIdentifier )
                self.purchased = true

            else
                self.triedToPurchase = true

            end
        end

        shopItem.OnMouseReleased = function( self, keyCode )
            if keyCode ~= MOUSE_LEFT then return end
            self.pressed = nil
        end

        shopItem.CoolerScroll = function( _, delta, stepScale )
            myCategoryPanel:CoolerScroll( delta, stepScale )

        end

        shopItem:DockMargin( 0, myCategoryPanel.topMargin, 0, 0 )
        shopItem:Dock( LEFT )

        --print( "put " .. identifier .. " into " .. tostring( myCategoryPanel ) )

    end
end

function GM:termHuntOpenTheShop()

    local ply = LocalPlayer()
    local shopStandards = GAMEMODE.shopStandards

    local data = {
        name = "pointShop",
        usesSignal = ply:Health() > 0,
        onFinishLoading = onFinishLoading,
        scrollerWMul = 1,
        scrollersDockType = FILL,
    }

    shopStandards.createShopHolder( data )

end

LocalPlayer().openedHuntersGleeShop = nil

function GM:ShowShop()
    if not GAMEMODE:ShopIsEnabled() then return end
    if GAMEMODE:CanShowDefaultHud() then
        LocalPlayer().openedHuntersGleeShop = true

        GAMEMODE:termHuntOpenTheShop()

    end
end