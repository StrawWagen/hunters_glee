--[[------------------------------------
    Builds every registered style's fonts. Has to load after all of them are registered,
    and runs again on glee_rebuildfonts.

    styles can be found in glee_hud/styles/

    A spec is a surface.CreateFont table with two differences:

        size        1080p pixels, scaled and multiplied by the style's sizeMul.
                    A function means final pixels instead, skipping both.
        any value   a function is called at build time, for anything the style file
                    can't know yet.

    Unset, font and weight come from the style, and antialias is on.
--]]-------------------------------------

local styles = terminator_Extras.glee_HudStyles
local fontNameFor = terminator_Extras.glee_FontNameFor

local function buildFont( style, fontName, spec )
    local size = spec.size

    if isfunction( size ) then
        size = size()

    else
        size = glee_sizeScaled( nil, size ) * style.sizeMul

    end

    local fontData = {
        font      = style.fontName,
        size      = size,
        weight    = style.fontWeight,
        antialias = true,
    }

    for key, value in pairs( spec ) do
        if key == "size" then continue end

        if isfunction( value ) then
            value = value()

        end

        fontData[key] = value

    end

    surface.CreateFont( fontName, fontData )

end

-- Writes style.fonts, which styleHandle:Font reads. borrowedFonts land there unbuilt
local function buildStyleFonts( styleName, style )
    local fonts = {}

    local function buildFrom( specs )
        for fontRole, spec in pairs( specs or {} ) do
            local fontName = fontNameFor( styleName, fontRole )
            buildFont( style, fontName, spec )
            fonts[fontRole] = fontName

        end
    end

    buildFrom( style.fontSizes )
    buildFrom( style.extraFontSizes )

    for fontRole, fontName in pairs( style.borrowedFonts or {} ) do
        fonts[fontRole] = fontName

    end

    style.fonts = fonts

end

local function buildAllStyleFonts()
    for styleName, style in pairs( styles ) do
        buildStyleFonts( styleName, style )

    end
end

buildAllStyleFonts()

hook.Add( "glee_rebuildfonts", "glee_rebuild_hudfonts", buildAllStyleFonts )
