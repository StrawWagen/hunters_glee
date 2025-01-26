local GAMEMODE = GAMEMODE or GM

local draw_RoundedBox = draw.RoundedBox

GAMEMODE.shopStandards = {}

local defaultShpScale = 0.9
local shopScaleVar = CreateClientConVar( "cl_huntersglee_guiscale", -1, true, false, "Shop scale. Below zero (-1) for default, " .. defaultShpScale , -1, 1 )

GAMEMODE.shopStandards.shpScale = nil

local function doShopScale()
    local currVar = shopScaleVar:GetFloat()
    if currVar < 0 then
        GAMEMODE.shopStandards.shpScale = defaultShpScale

    else
        GAMEMODE.shopStandards.shpScale = currVar

    end

    GAMEMODE.shopStandards.white = Color( 255,255,255 )
    GAMEMODE.shopStandards.whiteFaded = Color( 255, 255, 255, 230 )

    GAMEMODE.shopStandards.backgroundColor = Color( 37, 37, 37, 240 )
    GAMEMODE.shopStandards.invisibleColor = Color( 0, 0, 0, 0 )
    GAMEMODE.shopStandards.shopItemColor = Color( 73, 73, 73, 255 )
    GAMEMODE.shopStandards.cantAffordOverlay = Color( 0, 0, 0, 200 )
    GAMEMODE.shopStandards.scrollEndsOverlay = Color( 0, 0, 0, 100 )
    GAMEMODE.shopStandards.notHoveredOverlay = Color( 0, 0, 0, 45 )
    GAMEMODE.shopStandards.pressedItemOverlay = Color( 255, 255, 255, 25 )
    GAMEMODE.shopStandards.markupTextColor = Color( 140, 140, 140, 255 )

    GAMEMODE.shopStandards.switchSound = "buttons/lightswitch2.wav"
    GAMEMODE.shopStandards.openSound = "physics/wood/wood_crate_impact_soft3.wav"
    GAMEMODE.shopStandards.closeSound = "doors/wood_stop1.wav"

    GAMEMODE.shopStandards.borderDivisor = 40

    local scale = GAMEMODE.shopStandards.shpScale
    GAMEMODE.shopStandards.shopCategoryWidth, GAMEMODE.shopStandards.shopCategoryHeight = glee_sizeScaled( 1920 * scale, 300 * scale )

end

doShopScale()

local function setupShopFonts()
    -- YOUR CURRENT SCORE
    local fontData = {
        font = "Arial",
        extended = false,
        size = glee_sizeScaled( nil, 50 * GAMEMODE.shopStandards.shpScale ),
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
        size = glee_sizeScaled( nil, 50 * GAMEMODE.shopStandards.shpScale ),
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
        size = glee_sizeScaled( nil, 30 * GAMEMODE.shopStandards.shpScale ),
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
        size = glee_sizeScaled( nil, 25 * GAMEMODE.shopStandards.shpScale ),
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

    -- ITEMS IN SKULL SHOP
    fontData = {
        font = "Arial",
        extended = false,
        size = glee_sizeScaled( nil, 30 * GAMEMODE.shopStandards.shpScale ),
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
    surface.CreateFont( "termhuntSkullShopItemFont", fontData )

end

setupShopFonts()

cvars.AddChangeCallback( "cl_huntersglee_guiscale", function( _, _, _ )
    doShopScale()
    setupShopFonts()

end, "glee_shoprescale" )

LocalPlayer().MAINSHOPHOLDER = LocalPlayer().MAINSHOPHOLDER or nil
LocalPlayer().HOLDERSCROLLPANEL = LocalPlayer().HOLDERSCROLLPANEL or nil

function GAMEMODE:termHuntCloseShopHolder()
    local ply = LocalPlayer()
    if not IsValid( ply.MAINSHOPHOLDER ) then return end
    ply:EmitSound( GAMEMODE.shopStandards.closeSound, 50, 160, 0.25 )
    ply.MAINSHOPHOLDER:Remove()
    if ply.LoadingSound then
        ply.LoadingSound:Stop()

    end
end

function GAMEMODE:CreateScreenFillingPopup( scaleMul )
    scaleMul = scaleMul or 1
    local filler = vgui.Create( "DFrame" )

    local width, height = glee_sizeScaled( 1920 * scaleMul, 1080 * scaleMul )

    filler:SetSize( width, height )

    filler:Center()
    filler:MakePopup()
    filler:SetTitle( "" )

    -- make sure this NEVER gets stuck open
    terminator_Extras.easyClosePanel( filler )

    return filler, width, height

end

local enableShopVar = GetConVar( "huntersglee_enableshop" )
local doneDisabledHint

function GAMEMODE:ShopIsEnabled()
    if not enableShopVar:GetBool() then
        if not doneDisabledHint then
            doneDisabledHint = true
            LocalPlayer():PrintMessage( HUD_PRINTTALK, "Shop was disabled via \"huntersglee_enableshop 0\"" )

        end
        return

    end
    return true

end

GAMEMODE.shopStandards.isHovered = function( panel )
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
    if hovering == nil then hovering = false end

    return hovering

end

GAMEMODE.shopStandards.pressableThink = function( panel, hovering )
    hovering = hovering or GAMEMODE.shopStandards.isHovered( panel )

    if hovering ~= panel.hoveredOld then
        if hovering and not panel.hoveredOld and panel.OnBeginHovering then
            panel:OnBeginHovering()

        elseif not hovering and panel.hoveredOld and panel.RemoveCoolTooltip then
            panel:RemoveCoolTooltip()

        end

        if ( not panel.initialSetup ) or ( panel.itemData and not panel.pressable ) then
            -- not setup yet, or not purchasable, do nothing

        elseif not hovering and panel.hoveredOld then
            LocalPlayer():EmitSound( GAMEMODE.shopStandards.switchSound, 60, 80, 0.12 )

        elseif hovering and not panel.hoveredOld then
            LocalPlayer():EmitSound( GAMEMODE.shopStandards.switchSound, 60, 90, 0.12 )

        end
        panel.hoveredOld = hovering

    end
    panel.initialSetup = true

end

GAMEMODE.shopStandards.CreateStyledScroller = function( shopHolder, scrollsParent, panelName, dockType, widthMul )
    local shopStandards = GAMEMODE.shopStandards
    local STYLEDSCROLLER = vgui.Create( "DScrollPanel", scrollsParent, panelName )
    local ply = LocalPlayer()
    local _, height = shopHolder:GetSize()

    -- veritcal scrolling bar width, used for other stuff too so its pretty
    STYLEDSCROLLER.verticalScrollWidth = shopHolder.titleBarSize
    STYLEDSCROLLER.verticalScrollWidthPadded = shopHolder.titleBarSize + height / 80

    STYLEDSCROLLER:Dock( dockType )
    local scrollersWidth, scrollersHeight = scrollsParent:GetSize()
    STYLEDSCROLLER:SetSize( scrollersWidth * widthMul, scrollersHeight )

    local scrollBar = STYLEDSCROLLER:GetVBar()

    scrollBar:SetWide( STYLEDSCROLLER.verticalScrollWidth )

    -- make the scrollbar match the style!
    function scrollBar:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopHolder.shopItemColor )
        draw_RoundedBox( 0, 0, 0, w, h, shopHolder.cantAffordOverlay )
    end

    function scrollBar.btnUp:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopHolder.shopItemColor )
        if not self:IsHovered() then
            draw_RoundedBox( 0, 0, 0, w, h, shopHolder.notHoveredOverlay )
        end
    end

    function scrollBar.btnUp:Think()
        shopStandards.pressableThink( self )
    end

    function scrollBar.btnDown:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopHolder.shopItemColor )
        if not self:IsHovered() then
            draw_RoundedBox( 0, 0, 0, w, h, shopHolder.notHoveredOverlay )
        end
    end

    function scrollBar.btnDown:Think()
        shopStandards.pressableThink( self )
    end

    function scrollBar.btnGrip:Paint( w, h )
        draw_RoundedBox( 0, 0, 0, w, h, shopHolder.shopItemColor )

        draw_RoundedBox( 0, 0, 0, w, shopHolder.offsetNextToIdentifier, shopHolder.scrollEndsOverlay )
        draw_RoundedBox( 0, 0, h + -shopHolder.offsetNextToIdentifier, w, shopHolder.offsetNextToIdentifier + 1, shopHolder.scrollEndsOverlay )

        if not self:IsHovered() then
            draw_RoundedBox( 0, 0, 0, w, h, shopHolder.notHoveredOverlay )
        end
    end

    function scrollBar.btnGrip:Think()
        shopStandards.pressableThink( self )
    end

    -- fancy scrolling sounds
    scrollBar.oldSetScroll = scrollBar.SetScroll
    function scrollBar:SetScroll( newScroll )
        self:oldSetScroll( newScroll )

        local vertLastScroll = self.vertLastScroll or 0
        local currScrollTrue = self:GetScroll()

        local positions = ply.oldScrollPositions[ shopHolder.scrollingName ]
        positions[panelName] = currScrollTrue

        if math.abs( vertLastScroll - currScrollTrue ) > shopHolder.titleBarSize then
            local pitchOffset = ( vertLastScroll - currScrollTrue ) * 0.1
            ply:EmitSound( "physics/plastic/plastic_barrel_impact_soft5.wav", 60, 100 + pitchOffset, 0.2 )

            self.vertLastScroll = currScrollTrue

        end
    end

    local positions = ply.oldScrollPositions[ shopHolder.scrollingName ]
    scrollBar:AnimateTo( positions[panelName] or 0, 0, 0, -1 )

    -- w and s are scrolling shortcuts
    function scrollsParent:scrollUp()
        if not scrollBar then return end
        local oldScroll = scrollBar:GetScroll()
        scrollBar:SetScroll( oldScroll + -GAMEMODE.shopStandards.shopCategoryHeight )

    end

    function scrollsParent:scrollDown()
        if not scrollBar then return end
        local oldScroll = scrollBar:GetScroll()
        scrollBar:SetScroll( oldScroll + GAMEMODE.shopStandards.shopCategoryHeight )

    end

    local canvas = STYLEDSCROLLER:GetCanvas()
    canvas:DockPadding( 0, 0, 0, 0 )

    return STYLEDSCROLLER

end

local noDataMateiral = Material( "vgui/hud/gleenodata.png", "noclamp" )
local dataMaterial = Material( "vgui/hud/gleefulldata.png", "noclamp smooth" )
local deadDataMaterial = Material( "vgui/hud/deadshopicon.png", "noclamp smooth" )
local skullShopMaterial = Material( "vgui/hud/skullshopicon.png", "noclamp smooth" )

GAMEMODE.shopStandards.MAINSCROLLNAME = "main_scroll_window"
GAMEMODE.shopStandards.createShopHolder = function( data )
    local name = data.name
    local usesSignal = data.usesSignal
    local scrollersWidthMul = data.scrollerWMul
    local scrollersDockType = data.scrollersDockType

    local shopStandards = GAMEMODE.shopStandards
    local ply = LocalPlayer()
    ply.oldScrollPositions = ply.oldScrollPositions or {}
    ply.oldScrollPositions[name] = ply.oldScrollPositions[name] or {}

    ply:EmitSound( shopStandards.openSound, 50, 200, 0.45 )

    local scale = shopStandards.shpScale

    local shopHolder, width, height = GAMEMODE:CreateScreenFillingPopup( scale )
    shopHolder.finalWidth, shopHolder.finalHeight = width, height
    shopHolder.scrollingName = name
    ply.MAINSHOPHOLDER = shopHolder

    terminator_Extras.easyClosePanel( shopHolder, function() GAMEMODE:termHuntCloseShopHolder() end )

    shopHolder.white =               shopStandards.white
    shopHolder.whiteFaded =          shopStandards.whiteFaded

    shopHolder.backgroundColor =     shopStandards.backgroundColor
    shopHolder.invisibleColor =      shopStandards.invisibleColor
    shopHolder.shopItemColor =       shopStandards.shopItemColor
    shopHolder.cantAffordOverlay =   shopStandards.cantAffordOverlay
    shopHolder.scrollEndsOverlay =   shopStandards.scrollEndsOverlay
    shopHolder.notHoveredOverlay =   shopStandards.notHoveredOverlay
    shopHolder.pressedItemOverlay =  shopStandards.pressedItemOverlay
    shopHolder.markupTextColor =     shopStandards.markupTextColor

    shopHolder:SetSize( width, height / 6 )

    GAMEMODE:requestUnlockUpdate()

    shopHolder.bigTextPadding = height / 180
    shopHolder.borderPadding = height / shopStandards.borderDivisor
    local borderPadding = shopHolder.borderPadding

    shopHolder.whiteIdentifierLineWidth = height / 250 -- the white bar
    shopHolder.offsetNextToIdentifier = shopHolder.whiteIdentifierLineWidth * 4

    shopHolder.titleBarSize = height / 15

    shopHolder.costString = ""
    shopHolder.costColor = shopHolder.white

    shopHolder:DockPadding( borderPadding, shopHolder.titleBarSize + borderPadding * 1.5, borderPadding, borderPadding ) -- the little lighter bar at the top
    shopHolder:ShowCloseButton( false )

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
    function shopHolder:OnKeyCodePressed( pressed )
        if not shopHolder.finishedLoading then return end
        if pressed == clientsForwardKey then shopHolder:scrollUp() return end
        if pressed == clientsBackKey then shopHolder:scrollDown() return end

        self:KeyScrollingThink()

    end

    function shopHolder:KeyScrollingThink()
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
            if not IsValid( shopHolder ) then return end
            shopHolder:KeyScrollingThink()

        end )
    end

    shopHolder.Paint = function()
        draw_RoundedBox( 0, 0, 0, shopHolder:GetWide(), shopHolder:GetTall(), shopHolder.backgroundColor )
        local headerWidth = shopHolder:GetWide() - borderPadding * 2
        draw_RoundedBox( 0, borderPadding, borderPadding, headerWidth, shopHolder.titleBarSize, shopHolder.backgroundColor )
        draw_RoundedBox( 0, borderPadding, borderPadding, shopHolder.whiteIdentifierLineWidth, shopHolder.titleBarSize, shopHolder.whiteFaded )

        -- paint reception begin
        local lastStrength = shopHolder.lastSignalStrength
        local percent = shopHolder.loadPercent

        -- mess up the lerp a bit
        local nextLoad = shopHolder.nextLoad or 0
        local loadRate = shopHolder.loadRate or 0
        local oldLoadPercent = shopHolder.oldLoadPercent

        local subtProductAbsed = math.abs( CurTime() - nextLoad ) / loadRate^1.05
        local lerpedPercent = Lerp( 1 - subtProductAbsed, oldLoadPercent, percent )

        local progress = lerpedPercent / 100
        local widthMul = lastStrength / 100

        local drawExclamationMark
        local dataIconMat
        local loading
        local textFirstHalf = ""
        local textSecondHalf = ""

        if name == "pointShop" then
            if lastStrength <= 25 and ( CurTime() % 1 ) < 0.5 then
                drawExclamationMark = true

            end

            loading = not shopHolder.finishedLoading
            if loading then
                if percent < 45 then
                    textFirstHalf = "Establishing Uplink"

                elseif percent < 55 then
                    textFirstHalf = "Sending Credentials"

                elseif percent < 90 then
                    textFirstHalf = "Recieving Catalog"

                else
                    textFirstHalf = "Verifying Cache"

                end

                for _ = 1, ( CurTime() % 4 ) do
                    textFirstHalf = textFirstHalf .. "."

                end

            else
                local score = ply:GetScore()

                if shopHolder.scoreToAddFrame ~= shopHolder.oldScoreToAddFrame or shopHolder.oldScore ~= score then
                    -- create copy
                    local scoreToAddFrame = shopHolder.scoreToAddFrame or {}
                    local cost = GAMEMODE:shopItemCost( scoreToAddFrame.itemIdentifier, ply )

                    shopHolder.costString, shopHolder.costColor = GAMEMODE:translatedShopItemCost( ply, cost, scoreToAddFrame.itemIdentifier )

                end

                shopHolder.oldScore = score
                shopHolder.oldScoreToAddFrame = shopHolder.scoreToAddFrame


                textFirstHalf = score ..  " : "
                textSecondHalf = shopHolder.costString

            end
            dataIconMat = dataMaterial
            if ply:Health() <= 0 then
                dataIconMat = deadDataMaterial
                widthMul = 1

            end

        elseif name == "skullShop" then
            dataIconMat = skullShopMaterial
            skulls = ply:GetSkulls()
            textFirstHalf = skulls ..  " : Spend your skulls before they're gone..."
            widthMul = 1

        end

        surface.SetFont( "termhuntShopScoreFont" )
        local textW, textH = surface.GetTextSize( textFirstHalf )

        local centeringOffset = textH / 4
        local initialPadding = borderPadding + shopHolder.offsetNextToIdentifier

        if widthMul > 0 then
            surface.SetDrawColor( shopHolder.white )
            surface.SetMaterial( dataIconMat )

            surface.DrawTexturedRectUV( initialPadding, initialPadding - ( textH / 8 ), textH * widthMul, textH, 0, 0, widthMul, 1 )

        end
        if drawExclamationMark then
            surface.SetMaterial( noDataMateiral )
            surface.DrawTexturedRect( initialPadding, initialPadding - ( textH / 8 ), textH, textH )

        end

        local secondLinesHorizontalPos = initialPadding + textH + shopHolder.offsetNextToIdentifier
        draw_RoundedBox( 0, secondLinesHorizontalPos, borderPadding, shopHolder.whiteIdentifierLineWidth, shopHolder.titleBarSize, shopHolder.whiteFaded )

        -- paint reception end

        local iconPaddedSize = textH + borderPadding + shopHolder.whiteIdentifierLineWidth

        draw.DrawText( textFirstHalf, "termhuntShopScoreFont", initialPadding + iconPaddedSize, borderPadding + centeringOffset, shopHolder.white )
        draw.DrawText( textSecondHalf, "termhuntShopScoreFont", initialPadding + iconPaddedSize + textW, borderPadding + centeringOffset, shopHolder.costColor )

        if loading then
            local clampedBarWidth = math.Clamp( headerWidth * progress, 0, headerWidth )
            draw_RoundedBox( 0, borderPadding, borderPadding * 2 + shopHolder.titleBarSize, clampedBarWidth, shopHolder.titleBarSize / 4, shopHolder.white )

        end
    end

    shopHolder.loadPercent = 0
    shopHolder.startedLoading = CurTime()

    function shopHolder:AdditionalThink()
    end

    function shopHolder:Think()

        self:AdditionalThink()

        local nextLoad = shopHolder.nextLoad or 0
        local cur = CurTime()
        if nextLoad > cur then return end

        local strength = math.Clamp( ply:GetSignalStrength() ^ 1.05, 0, 100 )
        local invertedStrength = 100 - strength
        shopHolder.lastSignalStrength = strength
        shopHolder.lastDataRecieved = cur

        local maxRate = ( invertedStrength / 100 ) / 2
        local rate = math.Rand( 0.15, maxRate )
        shopHolder.loadRate = rate
        shopHolder.nextLoad = cur + rate

        if shopHolder.finishedLoading then return end

        if shopHolder.loadPercent < 100 then

            shopHolder.oldLoadPercent = shopHolder.loadPercent
            shopHolder.loadPercent = shopHolder.loadPercent + strength / 4

            local pit = 25 + strength * 0.6
            if not ply.LoadingSound or ( ply.LoadingSound and not ply.LoadingSound:IsPlaying() ) then
                ply.LoadingSound = CreateSound( ply, "ambient/machines/combine_terminal_loop1.wav" )
                ply.LoadingSound:PlayEx( 0.5, pit )

            else
                ply.LoadingSound:ChangePitch( pit )

            end
            return

        end

        ply.LoadingSound:Stop()
        ply.LoadingSound = nil
        ply:EmitSound( "buttons/button9.wav", 50, 95, 0.45 )

        shopHolder.FinishLoading()

    end

    function shopHolder.FinishLoading()

        shopHolder.oldLoadPercent = 100
        shopHolder.finishedLoading = true
        shopHolder:SetSize( width, height )

        ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 100, 0.45 )

        local scrollsParent = shopHolder
        local HOLDERSCROLLPANEL = GAMEMODE.shopStandards.CreateStyledScroller( shopHolder, scrollsParent, shopStandards.MAINSCROLLNAME, scrollersDockType, scrollersWidthMul )

        shopHolder.HOLDERSCROLLPANEL = HOLDERSCROLLPANEL
        ply.HOLDERSCROLLPANEL = HOLDERSCROLLPANEL

        if data.onFinishLoading then
            data.onFinishLoading( shopHolder )

        end

    end

    if not usesSignal then
        shopHolder.FinishLoading()

    end

    return shopHolder

end

local nextAsk = 0
local unlockedTableLocal = {}
function GAMEMODE:requestUnlockUpdate()
    if nextAsk > CurTime() then return end
    nextAsk = CurTime() + 5
    local currTbl = table.ToString( unlockedTableLocal )
    local CRC = util.CRC( currTbl )

    net.Start( "glee_askforunlockedupdate" )
        net.WriteInt( CRC, 32 )
    net.SendToServer()

end

function GAMEMODE:plyHasUnlockedItem( ply, itemName, data )
    if ply ~= LocalPlayer() then return end
    GAMEMODE:requestUnlockUpdate()

    data = data or self:GetShopItemData( itemName )
    if not data then return end
    if data.skullCost <= 0 then return true end

    local itemTable = unlockedTableLocal[ itemName ]
    if not itemTable then return false end

    return itemTable.bought

end

function GAMEMODE:plyHasEnabledItem( ply, itemName )
    if ply ~= LocalPlayer() then return end
    GAMEMODE:requestUnlockUpdate()

    local itemTable = unlockedTableLocal[ itemName ]
    if not itemTable then return nil end

    return itemTable.enabled

end

net.Receive( "glee_unlockedupdate", function()
    local count = net.ReadInt( 16 )
    count = math.Clamp( count, 0, GAMEMODE.shopItemCount )

    for _ = 1, count do
        local name = net.ReadString()
        local boughtIn = net.ReadBool()
        local enabledIn = net.ReadBool()
        unlockedTableLocal[ name ] = { bought = boughtIn, enabled = enabledIn }

    end

    hook.Run( "glee_cl_fullskullshopupdate", unlockedTableLocal )

end )

local nextShopClose = 0

net.Receive( "glee_closeshopholders", function()
    if nextShopClose > CurTime() then return end
    nextShopClose = CurTime() + 0.05

    if not IsValid( LocalPlayer().MAINSHOPHOLDER ) then return end
    GAMEMODE:termHuntCloseShopHolder()
    nextShopOpen = CurTime() + 0.1

end )
