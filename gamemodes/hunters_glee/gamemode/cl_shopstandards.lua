local GAMEMODE = GAMEMODE or GM

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
end
doShopScale()


local switchSound = Sound( "buttons/lightswitch2.wav" )
GAMEMODE.shopStandards.switchSound = switchSound

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

GAMEMODE.shopStandards.isHovered = isHovered

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

GAMEMODE.shopStandards.pressableThink = pressableThink


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

    fontData.shadow = true
    surface.CreateFont( "termhuntShopScoreFontShadowed", fontData )

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

    fontData.shadow = true
    surface.CreateFont( "termhuntShopItemFontShadowed", fontData )

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

end

setupShopFonts()

cvars.AddChangeCallback( "cl_huntersglee_guiscale", function( _, _, _ )
    doShopScale()
    setupShopFonts()

end, "glee_shoprescale" )

GAMEMODE.shopStandards.white = Color( 255, 255, 255 )
GAMEMODE.shopStandards.red = Color( 255, 0, 0 )
GAMEMODE.shopStandards.whiteFaded = Color( 255, 255, 255, 230 )

GAMEMODE.shopStandards.backgroundColor = Color( 37, 37, 37, 240 )
GAMEMODE.shopStandards.invisibleColor = Color( 0, 0, 0, 0 )
GAMEMODE.shopStandards.shopItemColor = Color( 73, 73, 73, 255 )
GAMEMODE.shopStandards.cantAffordOverlay = Color( 0, 0, 0, 200 )
GAMEMODE.shopStandards.scrollEndsOverlay = Color( 0, 0, 0, 100 )
GAMEMODE.shopStandards.notHoveredOverlay = Color( 0, 0, 0, 45 )
GAMEMODE.shopStandards.pressedItemOverlay = Color( 255, 255, 255, 25 )
GAMEMODE.shopStandards.markupTextColor = Color( 140, 140, 140, 255 )

GAMEMODE.shopStandards.whiteIdentifierLineWidthDiv = 250
GAMEMODE.shopStandards.shopCategoryHeight = 300