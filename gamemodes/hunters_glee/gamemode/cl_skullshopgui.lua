local GAMEMODE = GAMEMODE or GM

local draw = draw

local LocalPlayer = LocalPlayer
local draw_RoundedBox = draw.RoundedBox

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

local onFinishLoading = function( shopHolder )
    local ply = LocalPlayer()
    local GAMEMODE = GAMEMODE
    local plyHasUnlockedItem = GAMEMODE.plyHasUnlockedItem
    local plyHasEnabledItem = GAMEMODE.plyHasEnabledItem
    local shopStandards = GAMEMODE.shopStandards
    local shopItems = GAMEMODE.shopItems
    shopHolder.items = {}

    local scroller = shopHolder.HOLDERSCROLLPANEL
    local scrollerW = scroller:GetSize()
    local internalWidth = scrollerW + -scroller.verticalScrollWidth + -shopHolder.borderPadding
    local itemHeight = internalWidth / 6
    local itemWidth = internalWidth / 4
    local holder = vgui.Create( "DIconLayout", scroller, "glee_skullshop_holder" )

    shopHolder.itemHolder = holder

    holder:Dock( FILL )
    holder:SetSpaceY( shopHolder.offsetNextToIdentifier ) -- Space in between the panels on the Y Axis

    local unlockedCache = {}
    local sortedItems = {}
    local instructions = {}
    local wasUnlockedItem
    local wasLockedItem

    for identifier, itemData in SortedPairsByMemberValue( shopItems, "skullCost", false ) do

        local skullIdentifier
        if itemData.unlockMirror then
            skullIdentifier = itemData.unlockMirror
            itemData = nil

        else
            skullIdentifier = identifier

        end
        local unlocked = plyHasUnlockedItem( GAMEMODE, ply, skullIdentifier, itemData )
        unlockedCache[skullIdentifier] = unlocked

        table.insert( sortedItems, skullIdentifier )

        if unlocked then
            wasUnlockedItem = true

        else
            wasLockedItem = true

        end
    end

    for _, identifier in ipairs( sortedItems ) do
        table.insert( instructions, { id = identifier, inUnlockedHalf = true } )

    end

    if wasUnlockedItem and wasLockedItem then
        table.insert( instructions, { id = "splitter" } )

    end

    for _, identifier in ipairs( sortedItems ) do
        table.insert( instructions, { id = identifier, inUnlockedHalf = nil } )

    end

    -- shop items
    for ind, data in ipairs( instructions ) do
        local identifier = data.id

        if identifier == "splitter" then
            local splitter = holder:Add( "DPanel" )
            shopHolder.items[identifier .. ind] = splitter
            splitter.OwnLine = true -- The magic variable that specifies this item has its own line all for itself
            splitter:SetSize( internalWidth, shopHolder.whiteIdentifierLineWidth )
            function splitter:Paint()
                draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.whiteFaded )

            end
        else
            local itemData = shopItems[identifier]
            if itemData.canShowInShop and not itemData.canShowInShop( ply ) then continue end

            -- hacky, but it doesnt stutter when items are purchased
            local shopItem = holder:Add( "DButton" )
            local itemsWithName = shopHolder.items[identifier]
            if not itemsWithName then
                itemsWithName = {}
                shopHolder.items[identifier] = itemsWithName

            end

            table.insert( itemsWithName, shopItem )

            shopItem.itemData = itemData
            shopItem.itemIdentifier = identifier

            shopItem:DockPadding( shopHolder.offsetNextToIdentifier, shopHolder.offsetNextToIdentifier, shopHolder.offsetNextToIdentifier, shopHolder.offsetNextToIdentifier )

            shopItem:SetSize( itemWidth, itemHeight )
            shopItem:SetText( "" )

            local itemsName = vgui.Create( "DLabel", shopItem )
            itemsName:Dock( TOP )
            itemsName:SetWrap( true )
            itemsName:SetAutoStretchVertical( true )
            itemsName:SetTextColor( shopStandards.white )
            itemsName:SetFont( "termhuntSkullShopItemFont" )
            itemsName:SetText( itemData.name )

            local itemsCost = vgui.Create( "DLabel", shopItem )
            itemsCost:DockMargin( 0, shopHolder.offsetNextToIdentifier / 2, 0, 0 )
            itemsCost:Dock( TOP )
            itemsCost:SetWrap( true )
            itemsCost:SetAutoStretchVertical( true )
            itemsCost:SetTextColor( shopStandards.white )
            itemsCost:SetFont( "termhuntSkullShopItemFont" )

            shopItem.inUnlockedHalf = data.inUnlockedHalf

            if unlockedCache[identifier] then
                shopItem.unlocked = true

            end

            if shopItem.unlocked and not shopItem.inUnlockedHalf then
                shopItem:SetVisible( false )

            elseif not shopItem.unlocked and shopItem.inUnlockedHalf then
                shopItem:SetVisible( false )

            end

            function shopItem:TextThink()
                local costText

                if shopItem.inUnlockedHalf then
                    local enabled = plyHasEnabledItem( GAMEMODE, ply, identifier )
                    if enabled then
                        costText = "☑"

                    else
                        costText = "☐"

                    end
                else
                    local cost = itemData.skullCost
                    if cost <= 0 or shopItem.unlocked then
                        costText = ""

                    else
                        costText = cost

                    end
                end
                itemsCost:SetText( costText )
            end

            shopItem:TextThink()

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

                local canUnlock, cantUnlockReason = GAMEMODE:canUnlock( ply, self.itemIdentifier )
                self.unlockable = canUnlock
                self.cantUnlockReason = cantUnlockReason

            end

            -- paint the shop item!
            function shopItem:Paint()
                local hovered = self:IsHovered()

                if hovered then
                    draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.shopItemColor )

                end

                draw_RoundedBox( 0, 0, 0, shopHolder.whiteIdentifierLineWidth, self:GetTall(), shopHolder.whiteFaded )

            end

            function shopItem:PaintOver()
                local isFocus = shopHolder.currentFocus and shopHolder.currentFocus == self
                local myOverlayColor = nil

                if not shopItem.unlocked and not self.unlockable then
                    draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.cantAffordOverlay )

                end

                if not isFocus then
                    draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.notHoveredOverlay )

                elseif isFocus then
                    draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.cantAffordOverlay )

                end
                if myOverlayColor then
                    return true

                end
            end

            -- select the item!
            shopItem.OnMousePressed = function( self, keyCode )
                if keyCode ~= MOUSE_LEFT then return end
                if shopHolder.currentFocus and shopHolder.currentFocus == self then
                    shopHolder.currentFocus = nil
                    ply:EmitSound( shopStandards.switchSound, 60, 30, 0.24 )

                else
                    shopHolder.currentFocus = self
                    shopHolder.infoHolder:SetVisible( true )
                    shopHolder.infoHolder.bigItemButton:SetVisible( true )
                    ply:EmitSound( shopStandards.switchSound, 60, 50, 0.24 )

                end
            end

            shopItem.initialSetup = true
            shopItem.pressable = true

        end
    end

    function shopHolder:AdditionalThink()
        local hasFocus = shopHolder.currentFocus
        if not hasFocus then return end

    end


    local bigItemButton = vgui.Create( "DButton", shopHolder )
    local leftRightPadding = shopHolder.titleBarSize * 2
    bigItemButton:DockMargin( shopHolder.borderPadding + leftRightPadding, 0, shopHolder.borderPadding + leftRightPadding, 0 )
    bigItemButton:SetSize( 1, shopHolder.titleBarSize * 2 )
    bigItemButton:Dock( BOTTOM )
    bigItemButton:SetWrap( true )
    bigItemButton:SetText( "" )
    bigItemButton:SetTextColor( shopStandards.white )
    bigItemButton:SetFont( "termhuntSkullShopItemFont" )
    bigItemButton:SetVisible( false )
    bigItemButton:DockPadding( shopHolder.borderPadding, shopHolder.borderPadding, shopHolder.borderPadding, shopHolder.borderPadding )

    local bigButtonsText = vgui.Create( "DLabel", bigItemButton )
    bigItemButton.bigButtonsText = bigButtonsText
    bigButtonsText:Dock( FILL )
    bigButtonsText:SetWrap( true )
    bigButtonsText:SetAutoStretchVertical( true )
    bigButtonsText:SetTextColor( shopStandards.white )
    bigButtonsText:SetFont( "termhuntShopScoreFont" )
    bigButtonsText:SetText( "" )

    bigItemButton.Think = function( self )
        local hovering = shopStandards.isHovered( self )
        shopStandards.pressableThink( self, hovering )

        local currentFocus = shopHolder.currentFocus
        if not currentFocus then return end

        if currentFocus.unlocked then
            self.pressable = true
            local enabled = plyHasEnabledItem( GAMEMODE, ply, currentFocus.itemIdentifier )
            if enabled then
                bigButtonsText:SetText( "Disable" )

            else
                bigButtonsText:SetText( "Enable" )

            end
        else
            bigButtonsText:SetText( "Unlock" )
            local canUnlock, cantUnlockReason = GAMEMODE:canUnlock( ply, currentFocus.itemIdentifier )
            self.pressable = canUnlock
            self.cantUnlockReason = cantUnlockReason

        end
    end

    -- paint the button!
    function bigItemButton:Paint()
        local hovered = self:IsHovered()

        if hovered then
            draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.shopItemColor )

        end

        draw_RoundedBox( 0, 0, 0, shopHolder.whiteIdentifierLineWidth, self:GetTall(), shopHolder.whiteFaded )

    end

    function bigItemButton:PaintOver()
        if not self.pressable then
            draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.cantAffordOverlay )

        end

        if not isFocus then
            draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.notHoveredOverlay )

        elseif isFocus then
            draw_RoundedBox( 0, 0, 0, self:GetWide(), self:GetTall(), shopHolder.cantAffordOverlay )

        end
        if myOverlayColor then
            return true

        end
    end

    function bigItemButton:OnMousePressed( keyCode )
        if keyCode ~= MOUSE_LEFT then return end
        ply:EmitSound( shopStandards.switchSound, 60, 30, 0.24 )
        self.pressed = true

        local currentFocus = shopHolder.currentFocus
        if not currentFocus then return end

        if currentFocus.unlocked then
            RunConsoleCommand( "cl_termhunt_enabletoggle", currentFocus.itemIdentifier )

        elseif GAMEMODE:canUnlock( ply, currentFocus.itemIdentifier ) then
            RunConsoleCommand( "cl_termhunt_unlock", currentFocus.itemIdentifier )

        end
    end

    local infoHolder = vgui.Create( "DPanel", shopHolder, "glee_skullshop_infoholder" )
    shopHolder.infoHolder = infoHolder
    infoHolder.bigItemButton = bigItemButton

    infoHolder:DockMargin( shopHolder.borderPadding, 0, 0, 0 )
    infoHolder:Dock( FILL )
    infoHolder:SetVisible( false )

    function infoHolder:Paint()
    end

    local itemsName = vgui.Create( "DLabel", infoHolder )
    infoHolder.itemsName = itemsName
    itemsName:DockMargin( 0, 0, 0, shopHolder.borderPadding )
    itemsName:Dock( TOP )
    itemsName:SetWrap( true )
    itemsName:SetText( "" )
    itemsName:SetAutoStretchVertical( true )
    itemsName:SetTextColor( shopStandards.white )
    itemsName:SetFont( "termhuntShopScoreFont" )

    local descriptionScroller = GAMEMODE.shopStandards.CreateStyledScroller( shopHolder, infoHolder, "skullshopitemdescription", FILL, 1 )

    local itemsSkullCost = vgui.Create( "DLabel", descriptionScroller )
    infoHolder.itemsSkullCost = itemsSkullCost
    itemsSkullCost:DockMargin( 0, 0, 0, shopHolder.borderPadding )
    itemsSkullCost:Dock( TOP )
    itemsSkullCost:SetWrap( true )
    itemsSkullCost:SetText( "" )
    itemsSkullCost:SetAutoStretchVertical( true )
    itemsSkullCost:SetTextColor( shopStandards.white )
    itemsSkullCost:SetFont( "termhuntSkullShopItemFont" )

    local itemsShopCost = vgui.Create( "DLabel", descriptionScroller )
    itemsShopCost:DockMargin( 0, 0, 0, shopHolder.borderPadding )
    infoHolder.itemsShopCost = itemsShopCost
    itemsShopCost:Dock( TOP )
    itemsShopCost:SetWrap( true )
    itemsShopCost:SetText( "" )
    itemsShopCost:SetAutoStretchVertical( true )
    itemsShopCost:SetTextColor( shopStandards.white )
    itemsShopCost:SetFont( "termhuntSkullShopItemFont" )

    local itemsMarkupInfo = vgui.Create( "DLabel", descriptionScroller )
    itemsMarkupInfo:DockMargin( 0, 0, 0, shopHolder.borderPadding )
    infoHolder.itemsMarkupInfo = itemsMarkupInfo
    itemsMarkupInfo:Dock( TOP )
    itemsMarkupInfo:SetWrap( true )
    itemsMarkupInfo:SetText( "" )
    itemsMarkupInfo:SetAutoStretchVertical( true )
    itemsMarkupInfo:SetTextColor( shopStandards.white )
    itemsMarkupInfo:SetFont( "termhuntSkullShopItemFont" )

    local itemsDescription = vgui.Create( "DLabel", descriptionScroller )
    itemsDescription:DockMargin( 0, 0, 0, shopHolder.borderPadding )
    infoHolder.itemsDescription = itemsDescription
    itemsDescription:Dock( TOP )
    itemsDescription:SetWrap( true )
    itemsDescription:SetText( "" )
    itemsDescription:SetAutoStretchVertical( true )
    itemsDescription:SetTextColor( shopStandards.white )
    itemsDescription:SetFont( "termhuntSkullShopItemFont" )

    local itemsSkullDescription = vgui.Create( "DLabel", descriptionScroller )
    itemsSkullDescription:DockMargin( 0, 0, 0, shopHolder.borderPadding )
    infoHolder.itemsSkullDescription = itemsSkullDescription
    itemsSkullDescription:Dock( TOP )
    itemsSkullDescription:SetWrap( true )
    itemsSkullDescription:SetText( "" )
    itemsSkullDescription:SetAutoStretchVertical( true )
    itemsSkullDescription:SetTextColor( shopStandards.white )
    itemsSkullDescription:SetFont( "termhuntSkullShopItemFont" )


    function infoHolder:Think()
        local currentFocus = self.currentFocus
        if shopHolder.currentFocus ~= currentFocus then -- changed item focus, dont return
            currentFocus = shopHolder.currentFocus
            self.currentFocus = currentFocus

        else -- didnt change item forcus, return
            return

        end
        if not IsValid( currentFocus ) then -- un-selected
            if self:IsVisible() then
                self:SetVisible( false )
                self.bigItemButton:SetVisible( false )

            end
            return

        end

        if not self:IsVisible() then
            self:SetVisible( true )
            self.bigItemButton:SetVisible( true )

        end

        local data = currentFocus.itemData
        local identifier = currentFocus.itemIdentifier


        local name = data.name
        itemsName:SetText( name )

        itemsSkullCost:SetVisible( false )
        local skullCost = tonumber( data.skullCost )
        local skullText = ""
        if not plyHasUnlockedItem( GAMEMODE, ply, identifier, data ) and skullCost >= 1 then
            itemsSkullCost:SetVisible( true )
            local sOrNoS = "s"
            if skullCost == 1 then
                sOrNoS = ""

            end
            skullText = skullCost .. " skull" .. sOrNoS .. " to unlock."
        end

        itemsSkullCost:SetText( skullText )

        local shopCost = 0
        local costText = ""
        itemsShopCost:SetVisible( false )

        if isfunction( data.cost ) then
            local noErrors, _, costData = xpcall( data.cost, errorCatchingMitt, ply )
            if noErrors == false then
                GAMEMODE:invalidateShopItem( identifier )
                return

            elseif costData then
                costText = costData
                itemsShopCost:SetVisible( true )

            else
                ErrorNoHaltWithStack( "AAAH NO .cost FUNCTION SECOND RETURNED ARG FOR " .. identifier )

            end
        else
            shopCost = tonumber( data.cost )

            if shopCost < 0 then
                costText = "Buying this pays you out " .. math.abs( shopCost ) .. " score."
                itemsShopCost:SetVisible( true )

            elseif shopCost > 0 then
                costText = "Costs " .. math.abs( shopCost ) .. " score."
                itemsShopCost:SetVisible( true )

            end
        end
        itemsShopCost:SetText( costText )

        local currentsMarkup = data.markup
        local markupPerPurchase = data.markupPerPurchase
        local markupText = ""
        itemsMarkupInfo:SetVisible( false )
        if currentsMarkup and currentsMarkup ~= 1 then
            markupText = "Markup " .. currentsMarkup .. "x. "
            itemsMarkupInfo:SetVisible( true )

            if currentsMarkup > 1 then
                if shopCost > 1 then
                    markupText = markupText .. "( Costs more when bought during the hunt. )"

                elseif shopCost < 1 then
                    markupText = markupText .. "( More payout if the hunt's already started. )"

                end
            elseif currentsMarkup < 1 then
                if shopCost > 1 then
                    markupText = markupText .. "( Costs less when bought during the hunt. )"

                elseif shopCost < 1 then
                    markupText = markupText .. "( Less payout if the hunt's already started. )"

                end
            end
        end
        itemsMarkupInfo:SetText( markupText )

        local descriptionReturned = GAMEMODE:translateShopItemDescription( ply, identifier, data.desc )
        local rebuilt = ""
        local brokenUp = string.Explode( "\n", descriptionReturned, false )
        local max = #brokenUp
        for ind, text in ipairs( brokenUp ) do
            rebuilt = rebuilt .. "\"" .. text .. "\""
            if ind < max then
                rebuilt = rebuilt .. "\n"

            end
        end
        itemsDescription:SetText( rebuilt )

        local skullDescriptionReturned = ""
        if data.skullDesc then
            skullDescriptionReturned = GAMEMODE:translateShopItemDescription( ply, identifier, data.skullDesc )

        end
        itemsSkullDescription:SetText( skullDescriptionReturned )

    end

    hook.Add( "glee_cl_fullskullshopupdate", shopHolder, function( _, unlockedTableLocal )
        local changedSomething
        local items = shopHolder.items
        for identifier, data in pairs( unlockedTableLocal ) do
            local unlocked = data.bought
            unlockedCache[identifier] = unlocked

            local itemsWithName = items[identifier]
            if not itemsWithName then continue end

            for _, currItem in ipairs( itemsWithName ) do
                currItem.unlocked = unlocked
                currItem.enabled = data.enabled

                if currItem.unlocked and not currItem.inUnlockedHalf then
                    currItem:SetVisible( false )
                    changedSomething = true

                elseif currItem.unlocked and currItem.inUnlockedHalf then
                    currItem:SetVisible( true )
                    currItem:TextThink()
                    changedSomething = true

                elseif not currItem.unlocked and currItem.inUnlockedHalf then
                    currItem:SetVisible( false )
                    changedSomething = true

                elseif not currItem.unlocked and not currItem.inUnlockedHalf then
                    currItem:SetVisible( true )
                    currItem:TextThink()
                    changedSomething = true

                end
            end
        end
        if changedSomething then
            shopHolder.itemHolder:InvalidateLayout()

        end
    end )
end

function GM:termHuntOpenTheSkullShop()
    local shopStandards = GAMEMODE.shopStandards

    local data = {
        name = "skullShop",
        usesSignal = false,
        onFinishLoading = onFinishLoading,
        scrollerWMul = 0.55,
        scrollersDockType = LEFT,
    }

    local shopHolder = shopStandards.createShopHolder( data )

    terminator_Extras.easyClosePanel( shopHolder, termHuntCloseShopHolder )

end

LocalPlayer().openedHuntersGleeShop = nil

function GM:ShowSkullShop()
    if not GAMEMODE:ShopIsEnabled() then return end
    if GAMEMODE:CanShowDefaultHud() then
        LocalPlayer().openedHuntersGleeShop = true

        self:termHuntOpenTheSkullShop()

    end
end