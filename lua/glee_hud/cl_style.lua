--[[------------------------------------
    A style is one table, listing only what it differs on from the style it inherits.
    Add one by adding a file to glee_hud/styles/ and a line to cl_gleehud.lua.

    Nothing draws from these tables. cl_stylebuild.lua builds each one, once per scale,
    into the tables handles read; see cl_stylehandle.lua. Nothing writes to them either,
    so styles may share tables freely.

    ---- inheriting -------------------------------------------------------------

    colors, fonts, metrics and sounds merge key by key down the inherits chain, so a
    style lists only the roles it changes. Every other field is taken whole from the
    nearest style that sets it.

    ---- the shape -------------------------------------------------------------

    inherits        styleName to inherit from, defaults to styleBase. Any order of
                    registration works, parents are looked up at build time
    fontName        typeface every font uses unless its spec names another
    fontWeight      default weight, a font spec can override it
    sizeMul         whole style nudge, for a typeface that runs big or small
    fonts           fontRole -> a font spec, or the name of a font this system didn't
                    make. See cl_stylebuild.lua
    colors          colorRole -> Color, roles listed on styleBase
    metrics         name -> 1080p pixels, scaled by the build. Listed on styleBase
    sounds          setName -> sound paths, see handle:PlaySound
    background      signature on styleBase
    scaled          function( px ) returning more fields, for look data measured in pixels.
                    px turns 1080p pixels into the pixels of the scale being built
    highContrast    fields layered over this style while cl_huntersglee_highcontrast is on

    Look data with no method on the handle, read through handle:Settings() instead:
    blot, tornStrip, ghosts, jitter, arrival.
--]]-------------------------------------

terminator_Extras.glee_HudStyles = terminator_Extras.glee_HudStyles or {}
local styles = terminator_Extras.glee_HudStyles

local fadedBackground = Color( 0, 0, 0, 0 )

terminator_Extras.glee_StyleBase = {
    fontWeight = 500,
    sizeMul    = 1,

    iconMaxSize = 128, -- real pixels, never scaled

    metrics = {
        blockPadding    = 8, -- y-padding between box edge and text
        laneSpacing     = 6, -- gap between stacked hud boxes
        boxCornerRadius = 10,

        -- drawShadowedTextBetterData's defaults are these unscaled, which is the whole
        -- reason to set them. The build leaves these two unrounded, see cl_stylebuild.lua
        shadowOffsetX = 2.5,
        shadowOffsetY = 2,
    },

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

        bg           = Color( 0, 0, 0, 76 ),   -- for hud elements that should fade into the background
        bgUrgent     = Color( 60, 60, 60, 76 ),
        bgDark       = Color( 0, 0, 0, 175 ),  -- for gui elements that need visibility
        bgDarkUrgent = Color( 60, 60, 60, 175 ),
    },

    -- see styleHandle:PlaySound. Pitches are the caller's, these are just what plays
    sounds = {
        switch = { "buttons/lightswitch2.wav" }, -- hovering onto and off of something pickable
        press  = { "common/wpn_select.wav" },
    },

    -- style is the built style, color is a resolved Color and unfaded, fade is 0 to 1.
    -- state and cache are as handle:Background takes them
    background = function( _style, x, y, w, h, color, cornerRadius, fade, _state, _cache )
        fadedBackground.r = color.r
        fadedBackground.g = color.g
        fadedBackground.b = color.b
        fadedBackground.a = math.floor( color.a * fade )

        draw.RoundedBox( cornerRadius, x, y, w, h, fadedBackground )

    end,
}

function terminator_Extras.glee_RegisterStyle( styleName, style )
    styles[styleName] = style

    -- unset on first load, where the build runs once every style is in. Set on autorefresh
    if terminator_Extras.glee_RebuildStylesSoon then
        terminator_Extras.glee_RebuildStylesSoon()

    end
end
