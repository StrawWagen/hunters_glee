print( "GOOEY" )

local glee_sizeScaled = glee_sizeScaled

local function shopPanelName( identifier )
    return "termhunt_shoppanel_" .. identifier
end

local function shopCategoryName( identifier )
    return "termhunt_shopcategory_" .. identifier
end

local draw = draw
local surface = surface

local defaultShpScale = 0.9
local shopScaleVar = CreateClientConVar( "cl_huntersglee_shopscale", -1, true, false, "Shop scale. Below zero (-1) for default, " .. defaultShpScale , -1, 1 )

local shpScale = nil

local function doShopScale()
    local currVar = shopScaleVar:GetFloat()
    if currVar < 0 then
        shpScale = defaultShpScale

    else
        shpScale = currVar

    end
end

doShopScale()

local function setupShopFonts()
    -- YOUR CURRENT SCORE
    local fontData = {
        font = "Arial",
        extended = false,
        size = glee_sizeScaled( nil, 50 * shpScale ),
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
        size = glee_sizeScaled( nil, 50 * shpScale ),
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
        size = glee_sizeScaled( nil, 30 * shpScale ),
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
        size = glee_sizeScaled( nil, 25 * shpScale ),
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

end

setupShopFonts()

cvars.AddChangeCallback( "cl_huntersglee_shopscale", function( _, _, _ )
    doShopScale()
    setupShopFonts()

end, "glee_shoprescale" )

function GM:CreateScreenFillingPopup( scaleMul )
    scaleMul = scaleMul or 1
    local filler = vgui.Create( "DFrame" )

    local width, height = glee_sizeScaled( 1920 * scaleMul, 1080 * scaleMul )

    filler:SetSize( width, height )

    filler:Center()
    filler:MakePopup()
    filler:SetTitle( "" )

    return filler, width, height

end

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

local lastScroll = 0

local shopCategoryPanels = {}
local MAINSCROLLNAME = "main_scroll_window"

LocalPlayer().MAINSSHOPPANEL = LocalPlayer().MAINSSHOPPANEL or nil
LocalPlayer().MAINSCROLLPANEL = LocalPlayer().MAINSCROLLPANEL or nil

function termHuntCloseTheShop()
    if not IsValid( LocalPlayer().MAINSSHOPPANEL ) then return end
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
            -- not setup yet, or not purchasable, do nothing

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

    local ply = LocalPlayer()
    ply.oldScrollPositions = ply.oldScrollPositions or {}

    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    local shopFrame, _, height = GAMEMODE:CreateScreenFillingPopup( shpScale )
    ply.MAINSSHOPPANEL = shopFrame


    local bigTextPadding = height / 180
    local borderPadding = height / 40

    local whiteIdentifierLineWidth = height / 250 -- the white bar
    local offsetNextToIdentifier = whiteIdentifierLineWidth * 4

    local scrollWidth = height / 15
    local shopCategoryWidth, shopCategoryHeight = glee_sizeScaled( 1920 * shpScale, 300 * shpScale )


    shopFrame.titleBarSize = scrollWidth
    shopFrame.costString = ""
    shopFrame.costColor = white

    shopFrame:DockPadding( 0, shopFrame.titleBarSize, 0, 0 ) -- the little lighter bar at the top
    shopFrame:ShowCloseButton( false )


    local clientsMenuKey = input.LookupBinding( "+menu" )
    if clientsMenuKey then
        clientsMenuKey = input.GetKeyCode( clientsMenuKey )

    end

    local clientsForwardKey = input.LookupBinding( "+forward" )
    if clientsForwardKey then
        clientsForwardKey = input.GetKeyCode( clientsForwardKey )

    end

    local clientsBackKey = input.LookupBinding( "+back" )
    if clientsBackKey then
        clientsBackKey = input.GetKeyCode( clientsBackKey )

    end

    local clientsLeftKey = input.LookupBinding( "+moveleft" )
    if clientsLeftKey then
        clientsLeftKey = input.GetKeyCode( clientsLeftKey )

    end

    local clientsRightKey = input.LookupBinding( "+moveright" )
    if clientsRightKey then
        clientsRightKey = input.GetKeyCode( clientsRightKey )

    end

    -- if pressed button that opened shop, close the shop
    function shopFrame:OnKeyCodePressed( pressed )
        if pressed == clientsMenuKey then termHuntCloseTheShop() return end
        if pressed == clientsForwardKey then shopFrame:scrollUp() return end
        if pressed == clientsBackKey then shopFrame:scrollDown() return end

        self:KeyScrollingThink()

    end

    function shopFrame:KeyScrollingThink()
        local hovered = vgui.GetHoveredPanel()
        if not hovered or not hovered.CoolerScroll then return end
        local done

        if input.IsKeyDown( clientsLeftKey ) then
            hovered:CoolerScroll( 1, 3 )
            done = true

        elseif input.IsKeyDown( clientsRightKey ) then
            hovered:CoolerScroll( -1, 3 )
            done = true

        else
            lastScroll = 0
            return

        end

        if not done then return end

        local scrollTime = 0.2
        local since = CurTime() - lastScroll
        if since < 0.3 then
            scrollTime = 0.1

        end

        lastScroll = CurTime()

        timer.Create( "glee_keyscrollshop", scrollTime, 1, function()
            if not IsValid( shopFrame ) then return end
            shopFrame:KeyScrollingThink()

        end )
    end

    -- if pressed escape, uh, close the shop
    shopFrame.Think = function()
        if input.IsKeyDown( KEY_ESCAPE ) then termHuntCloseTheShop() return end

    end

    shopFrame.Paint = function()
        draw_RoundedBox( 0, 0, 0, shopFrame:GetWide(), shopFrame:GetTall(), Color( 37, 37, 37, 240 ) )
        draw_RoundedBox( 0, borderPadding, borderPadding, shopFrame:GetWide(), shopFrame.titleBarSize, Color( 50, 50, 50, 180 ) )
        draw_RoundedBox( 0, borderPadding, borderPadding, whiteIdentifierLineWidth, shopFrame.titleBarSize, whiteFaded )

        local score = ply:GetScore()

        if shopFrame.scoreToAddFrame ~= shopFrame.oldScoreToAddFrame or shopFrame.oldScore ~= score then
            -- create copy
            local scoreToAddFrame = shopFrame.scoreToAddFrame or {}
            local cost = GAMEMODE:shopItemCost( scoreToAddFrame.itemIdentifier, ply )

            shopFrame.costString, shopFrame.costColor = GAMEMODE:translatedShopItemCost( ply, cost, scoreToAddFrame.itemIdentifier )

        end

        shopFrame.oldScore = score
        shopFrame.oldScoreToAddFrame = shopFrame.scoreToAddFrame

        local costString = shopFrame.costString

        local currentScoreAndBridge = score ..  " : "

        surface.SetFont( "termhuntShopScoreFont" )
        local currentScoreW, currentScoreHeight = surface.GetTextSize( currentScoreAndBridge )
        local initialPadding = borderPadding + offsetNextToIdentifier

        draw.DrawText( currentScoreAndBridge, "termhuntShopScoreFont", initialPadding, borderPadding + currentScoreHeight / 4, white )
        draw.DrawText( costString, "termhuntShopScoreFont", currentScoreW + initialPadding, borderPadding + currentScoreHeight / 4, shopFrame.costColor )

    end


    local mainScrollPanel = vgui.Create( "DScrollPanel", shopFrame, MAINSCROLLNAME )
    ply.MAINSCROLLPANEL = mainScrollPanel

    -- removing this doesnt seem to change anything, leaving it just in case
    -- definitely a HACK!
    if not ply.MAINSCROLLPANEL and not ply.retriedShop then
        timer.Simple( 0.1, function()
            ply.retriedShop = true
            termHuntOpenTheShop()
        end )
        return
    end

    -- veritcal scrolling bar width, used for other stuff too so its pretty
    mainScrollPanel.verticalScrollWidth = scrollWidth
    mainScrollPanel.verticalScrollWidthPadded = scrollWidth + height / 80

    mainScrollPanel:DockMargin( borderPadding, borderPadding * 2, 0, borderPadding )
    mainScrollPanel:Dock( FILL )

    local scrollBar = mainScrollPanel:GetVBar()

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

    -- fancy scrolling sounds
    scrollBar.oldSetScroll = scrollBar.SetScroll
    function scrollBar:SetScroll( newScroll )
        self:oldSetScroll( newScroll )

        local vertLastScroll = self.vertLastScroll or 0
        local currScrollTrue = self:GetScroll()

        ply.oldScrollPositions["shopvertical"] = currScrollTrue

        if math.abs( vertLastScroll - currScrollTrue ) > scrollWidth then
            local pitchOffset = ( vertLastScroll - currScrollTrue ) * 0.1
            ply:EmitSound( "physics/plastic/plastic_barrel_impact_soft5.wav", 60, 100 + pitchOffset, 0.2 )

            self.vertLastScroll = currScrollTrue

        end
    end

    scrollBar:AnimateTo( ply.oldScrollPositions["shopvertical"] or 0, 0, 0, -1 )

    -- w and s are scrolling shortcuts
    function shopFrame:scrollUp()
        if not scrollBar then return end
        local oldScroll = scrollBar:GetScroll()
        scrollBar:SetScroll( oldScroll + -shopCategoryHeight )

    end

    function shopFrame:scrollDown()
        if not scrollBar then return end
        local oldScroll = scrollBar:GetScroll()
        scrollBar:SetScroll( oldScroll + shopCategoryHeight )

    end


    local canvas = mainScrollPanel:GetCanvas()
    canvas:DockPadding( 0, 0, 0, 0 )

    local sortedCategories = table.SortByKey( GAMEMODE.shopCategories, true )

    -- the scrollable things that hold shop items and have names like innate and undead
    for _, category in ipairs( sortedCategories ) do
        local horisScroller = vgui.Create( "DHorizontalScroller", ply.MAINSCROLLPANEL, shopCategoryName( category ) )

        --print( "createdcat " .. category .. " " .. tostring( horisScroller ) )
        shopCategoryPanels[ category ] = horisScroller

        ply.MAINSCROLLPANEL:AddItem( horisScroller )

        horisScroller:SetSize( shopCategoryWidth, shopCategoryHeight )

        horisScroller.btnRight.Paint = function() end
        horisScroller.btnLeft.Paint = function() end

        horisScroller.betweenCategorySpacing = height / 80
        horisScroller.titleBarTall = ply.MAINSCROLLPANEL.verticalScrollWidth -- same height as big scroll bar is wide
        horisScroller.topMargin = horisScroller.titleBarTall + horisScroller.betweenCategorySpacing * 2
        horisScroller.breathingRoom = horisScroller.titleBarTall * 0.1

        horisScroller.shopItemHeight = horisScroller:GetTall() + -horisScroller.topMargin
        horisScroller.shopItemWidth = ( whiteIdentifierLineWidth * 2 ) + ( horisScroller.shopItemHeight * 1.5 )

        horisScroller.titleBarWide = horisScroller.shopItemWidth * 1.5

        horisScroller.TextX = offsetNextToIdentifier
        horisScroller.TextY = bigTextPadding + horisScroller.betweenCategorySpacing

        horisScroller.Paint = function( self )
            -- the little shading under the category label
            draw_RoundedBox( 0, 0, self.betweenCategorySpacing, self.titleBarWide, self.titleBarTall, shopItemColor )
            -- lil white line
            draw_RoundedBox( 0, 0, self.betweenCategorySpacing, whiteIdentifierLineWidth, self.titleBarTall, whiteFaded )
            -- name of category, eg "Innate"
            draw.DrawText( category, "termhuntShopCategoryFont", self.TextX, self.TextY, white )

        end

        horisScroller.CoolerScroll = function( self, delta, stepScale )
            local oldOffset = self.OffsetX or 0
            local stepSize = self.shopItemWidth * stepScale

            local offsetStepped = math.Round( self.OffsetX + delta * -stepSize * 1.05 )
            self.OffsetX = offsetStepped
            self:InvalidateLayout( true )

            local newOffset = self.OffsetX or 0
            if newOffset ~= oldOffset then -- dont do anything if we reach the end of the scroller
                ply.oldScrollPositions[ category ] = newOffset
                self:RemoveCoolTooltip()
                local pitchOffset = ( oldOffset - newOffset ) * 0.1
                pitchOffset = pitchOffset / stepScale
                ply:EmitSound( "physics/plastic/plastic_barrel_impact_soft2.wav", 60, 100 + pitchOffset, 0.2 * stepScale )

            end

            return true

        end

        timer.Simple( 0, function()
            if not horisScroller then return end
            horisScroller:SetScroll( ply.oldScrollPositions[ category ] or 0 )

        end )

        horisScroller.OnMouseWheeled = function( self, delta )
            return self:CoolerScroll( delta, 1 )

        end

        horisScroller.RemoveCoolTooltip = function( self )
            if self.coolTooltip then
                self.coolTooltip:Remove()

            end
        end

        horisScroller:Dock( TOP )
        horisScroller:DockMargin( 0, 0, 0, 0 ) -- between categories

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
                ply:EmitSound( switchSound, 60, 50, 0.24 )
                self.purchased = nil

            elseif self.triedToPurchase then
                if shopItem.coolTooltip then
                    shopItem.coolTooltip.noPurchaseShakeTime = CurTime() + 1

                end
                self.triedToPurchase = nil

            end
            self.notDoneSetup = nil

        end

        -- tooltips!
        shopItem.OnBeginHovering = function()
            -- this is spaghetti
            local coolTooltip = vgui.Create( "DSizeToContents", ply.MAINSCROLLPANEL, shopPanelName( identifier ) .. "_cooltooltip" )
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
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItemColor )
                draw_RoundedBox( 0, 0, 0, whiteIdentifierLineWidth, self:GetTall(), whiteFaded )

            end

            coolTooltip.Think = function ( self )

                -- this is kind of bad
                if coolTooltip.descLabel and coolTooltip.markupLabel and coolTooltip.noBuyLabel and IsValid( coolTooltip.descLabel ) and IsValid( coolTooltip.markupLabel ) and IsValid( coolTooltip.noBuyLabel ) and not coolTooltip.gettingRemoved then
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

                    -- info on markups
                    local markupInfo = shopItem.coolTooltipMarkup
                    local markupLabel = coolTooltip.markupLabel

                    if markupInfo ~= "" then
                        markupLabel:SetTextInset( offsetNextToIdentifier, 0 )
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
                    markupLabel:SetSize( markupSizeX + -offsetNextToIdentifier, markupSizeY )
                    noBuyLabel:SetSize( noBSizeX + -offsetNextToIdentifier, noBSizeY + offsetNextToIdentifier )
                    coolTooltip.fakeButton:SetSize( descSizeX + markupSizeX + noBSizeX, descSizeY + markupSizeY + noBSizeY + offsetNextToIdentifier )

                    if coolTooltip.hasSetup then
                        descLabel:SetTextColor( itemDescriptionColor )
                        noBuyLabel:SetTextColor( itemDescriptionColor )
                        markupLabel:SetTextColor( itemDescriptionColor )

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

                if coolTooltip.noBuyLabel:IsValid() then
                    local shakeTime = self.noPurchaseShakeTime or 0
                    local noPurchaseShake = 0
                    if shakeTime > CurTime() then
                        local absed = math.abs( self.noPurchaseShakeTime - CurTime() )
                        noPurchaseShake = math.Rand( -absed, absed ) * 4
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


            local descLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_label" )

            descLabel:SetTextColor( invisibleColor )

            coolTooltip.descLabel = descLabel

            descLabel:SetSize( myCategoryPanel.shopItemWidth )
            descLabel:Dock( TOP )


            local markupLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_label" )

            markupLabel:SetTextColor( invisibleColor )

            coolTooltip.markupLabel = markupLabel

            markupLabel:SetSize( myCategoryPanel.shopItemWidth )
            markupLabel:Dock( TOP )


            local noBuyLabel = vgui.Create( "DLabel", tooltipTopButton, shopPanelName( identifier ) .. "_cooltooltip_label" )

            noBuyLabel:SetTextColor( invisibleColor )

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
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopItemColor )

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

            elseif not hovered then
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