--[[------------------------------------
    A style is one table, listing only what it differs on. Add one by adding a file to
    glee_hud/styles/ and a line to cl_gleehud.lua. Consumers never read one; see
    cl_stylehandle.lua.

    Fields inherit whole, not merged, so a style wanting one different colour still lists
    every role it uses. Colours are the exception and fall back per role.

    ---- the shape -------------------------------------------------------------

    inherits        styleName to fall back to, defaults to styleBase
    fontName        typeface every generated font uses, and the one field with no default
    fontWeight      default weight, a fontSizes entry can override it
    sizeMul         whole style nudge, for a typeface that runs big or small
    fontSizes       fontRole -> font spec, see cl_fonts.lua
    extraFontSizes  more of the same, for a style that shares a fontSizes table
    borrowedFonts   fontRole -> a font name this system did not make
    colors          colorRole -> Color, roles listed on styleBase
    background      signature on styleBase
    shadowOffsetX/Y how far a shadow sits off its text, already scaled

    Look data with no method on the handle, read through handle:Settings() instead:
    blot, tornStrip, ghosts, jitter, arrival, sounds, and the paddings.
--]]-------------------------------------

terminator_Extras.glee_HudStyles = terminator_Extras.glee_HudStyles or {}
local styles = terminator_Extras.glee_HudStyles

-- Callers ask a handle for a role. This is only how the builder and the resolver agree
function terminator_Extras.glee_FontNameFor( styleName, fontRole )
    return "glee_" .. styleName .. "_" .. fontRole

end

local fadedBackground = Color( 0, 0, 0, 0 )

-- The metrics live here because they size the boxes, not the look inside them
terminator_Extras.glee_StyleBase = {
    iconMaxSize     = 128,
    boxCornerRadius = 10,
    blockPadding    = glee_sizeScaled( nil, 8 ), -- y-padding between box edge and text
    laneSpacing     = glee_sizeScaled( nil, 6 ), -- gap between stacked hud boxes

    fontWeight = 500,
    sizeMul    = 1,

    -- drawShadowedTextBetterData's defaults are these unscaled, which is the whole
    -- reason to set them: on the vertical axis, like the text they sit behind
    shadowOffsetX = glee_sizeScaledExact( nil, 2.5 ),
    shadowOffsetY = glee_sizeScaledExact( nil, 2 ),

    -- The whole role vocabulary. These are deliberately plain, so an omission shows
    colors = {
        text    = Color( 255, 255, 255 ), -- also what an unknown role falls back to
        happy   = Color( 255, 255, 255 ), -- full health, full battery
        alert   = Color( 255, 80, 80 ),   -- needs you now
        flash   = Color( 255, 80, 80 ),   -- a hud box's one-off flash
        jackpot = Color( 255, 255, 0 ),   -- something rare went your way
        hovered = Color( 255, 255, 255 ),
        chosen  = Color( 255, 255, 255 ),
        urgent  = Color( 255, 80, 80 ),   -- a countdown running out
        shadow  = Color( 0, 0, 0, 200 ),
    },

    -- color is unfaded, fade is 0 to 1, highlighted means flashing or picked
    background = function( x, y, w, h, color, cornerRadius, fade, _highlighted )
        fadedBackground.r = color.r
        fadedBackground.g = color.g
        fadedBackground.b = color.b
        fadedBackground.a = math.floor( color.a * fade )

        draw.RoundedBox( cornerRadius, x, y, w, h, fadedBackground )

    end,
}

local styleBase = terminator_Extras.glee_StyleBase

-- Returns the style, for a file to keep a local on. A parent has to be registered
-- already, so include order is inheritance order
function terminator_Extras.glee_RegisterStyle( styleName, style )
    local parent = styleBase

    if style.inherits then
        parent = styles[style.inherits]

        if not parent then
            ErrorNoHaltWithStack( "glee_hud: style \"" .. styleName .. "\" inherits \"" .. style.inherits .. "\", which is not registered yet\n" )
            parent = styleBase

        end
    end

    style.styleName = styleName
    styles[styleName] = setmetatable( style, { __index = parent } )

    return style

end
