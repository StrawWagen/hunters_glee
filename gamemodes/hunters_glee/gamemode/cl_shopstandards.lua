local GAMEMODE = GAMEMODE or GM

GAMEMODE.defaultColors = {}

local defaultShpScale = 0.9
local shopScaleVar = CreateClientConVar( "cl_huntersglee_guiscale", -1, true, false, "Shop scale. Below zero (-1) for default, " .. defaultShpScale , -1, 1 )

GAMEMODE.defaultColors.shpScale = nil

local function doShopScale()
    local currVar = shopScaleVar:GetFloat()
    if currVar < 0 then
        GAMEMODE.defaultColors.shpScale = defaultShpScale

    else
        GAMEMODE.defaultColors.shpScale = currVar

    end
end

doShopScale()

local function setupShopFonts()
    -- YOUR CURRENT SCORE
    local fontData = {
        font = "Arial",
        extended = false,
        size = glee_sizeScaled( nil, 50 * GAMEMODE.defaultColors.shpScale ),
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
        size = glee_sizeScaled( nil, 50 * GAMEMODE.defaultColors.shpScale ),
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
        size = glee_sizeScaled( nil, 30 * GAMEMODE.defaultColors.shpScale ),
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
        size = glee_sizeScaled( nil, 25 * GAMEMODE.defaultColors.shpScale ),
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

GAMEMODE.defaultColors.white = Color( 255,255,255 )
GAMEMODE.defaultColors.whiteFaded = Color( 255, 255, 255, 230 )

GAMEMODE.defaultColors.backgroundColor = Color( 37, 37, 37, 240 )
GAMEMODE.defaultColors.invisibleColor = Color( 0, 0, 0, 0 )
GAMEMODE.defaultColors.shopItemColor = Color( 73, 73, 73, 255 )
GAMEMODE.defaultColors.cantAffordOverlay = Color( 0, 0, 0, 200 )
GAMEMODE.defaultColors.scrollEndsOverlay = Color( 0, 0, 0, 100 )
GAMEMODE.defaultColors.notHoveredOverlay = Color( 0, 0, 0, 45 )
GAMEMODE.defaultColors.pressedItemOverlay = Color( 255, 255, 255, 25 )
GAMEMODE.defaultColors.markupTextColor = Color( 140, 140, 140, 255 )