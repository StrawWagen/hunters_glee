--[[------------------------------------
    Styles: the look of the hud and glee's menus, as data.

    A style lists only what it changes from the style it inherits. hl2, styles/cl_hl2.lua,
    is the base every chain ends at, so every field and shared role is listed there.
    A new style needs a file in glee_hud/styles/, an include in cl_gleehud.lua and an
    AddCSLuaFile in sh_gleehud.lua.

    Only cl_stylebuild.lua reads these tables, building each into the ones handles hand
    out, see cl_stylehandle.lua. Nothing writes to them, so styles may share tables.

    colors, backdrops, fonts, metrics and sounds merge key by key down the chain. Every
    other field is taken whole from the nearest style that sets it.

    inherits        styleName, defaults to hl2. Looked up at build time, so include order
                    doesn't matter
    fontName        typeface for every font whose spec doesn't name one
    fontWeight      default weight, a font spec can override it
    sizeMul         scales every font, for a typeface that runs big or small
    fonts           fontRole -> a font spec, see cl_stylebuild.lua, or an existing font's name
    colors          colorRole -> Color. The foreground: text, icons, fills
    backdrops       family .. state -> Color, what every background draws in, see
                    handle:BackdropColor
    shadowColor     behind text drawn through handle:Draw
    metrics         name -> 1080p pixels, scaled by the build
    sounds          setName -> sound paths, see handle:PlaySound
    background      draws a backdrop, and blurs behind it when asked, signature on hl2
    scaled          function( px ) returning more fields, for look data in pixels. px turns
                    1080p pixels into pixels at the scale being built
    highContrast    fields layered, parents' first, over the whole built style while
                    cl_huntersglee_highcontrast is on. Its everyTextColor replaces every
                    colors entry

    Read off handle:Settings(), having no method: smudge, tornStrip, ghosts, jitter, arrival.
--]]-------------------------------------

terminator_Extras.glee_HudStyles = terminator_Extras.glee_HudStyles or {}
local styles = terminator_Extras.glee_HudStyles

-- the style every chain ends at
terminator_Extras.glee_BaseStyleName = "hl2"

function terminator_Extras.glee_RegisterStyle( styleName, style )
    styles[styleName] = style

    -- only exists once the first build has run, so this is a late one, like an autorefresh
    if terminator_Extras.glee_RebuildStylesSoon then
        terminator_Extras.glee_RebuildStylesSoon()

    end
end

include( "glee_hud/styles/cl_hl2.lua" )
