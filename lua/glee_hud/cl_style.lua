--[[------------------------------------
    A style is one table, listing only what it differs on from the style it inherits.
    Add one by adding a file to glee_hud/styles/ and a line to cl_gleehud.lua.

    hl2 is the root, styles/cl_hl2.lua. Every other style inherits from it unless it names
    another, so that file is where every field, metric and colour role is listed.

    Nothing draws from these tables. cl_stylebuild.lua builds each one, once per scale,
    into the tables handles read; see cl_stylehandle.lua. Nothing writes to them either,
    so styles may share tables freely.

    ---- inheriting -------------------------------------------------------------

    colors, fonts, metrics and sounds merge key by key down the inherits chain, so a style lists only the roles it changes. Every other field is
    taken whole from the nearest style that sets it.

    ---- the shape -------------------------------------------------------------

    inherits        styleName to inherit from, defaults to hl2. Any order of
                    registration works, parents are looked up at build time
    fontName        typeface every font uses unless its spec names another
    fontWeight      default weight, a font spec can override it
    sizeMul         whole style nudge, for a typeface that runs big or small
    fonts           fontRole -> a font spec, or the name of a font this system didn't
                    make. See cl_stylebuild.lua
    colors          colorRole -> Color, roles listed on hl2. Every background, box, blot
                    or strip, draws in the backdrop roles, bg and bgDark and their states
    metrics         name -> 1080p pixels, scaled by the build. Listed on hl2
    sounds          setName -> sound paths, see handle:PlaySound
    background      signature on hl2
    scaled          function( px ) returning more fields, for look data measured in pixels.
                    px turns 1080p pixels into the pixels of the scale being built
    highContrast    fields layered over the finished style while cl_huntersglee_highcontrast
                    is on, parents' first, so a child's overrides its parents'

    Look data with no method on the handle, read through handle:Settings() instead:
    blot, tornStrip, ghosts, jitter, arrival.
--]]-------------------------------------

terminator_Extras.glee_HudStyles = terminator_Extras.glee_HudStyles or {}
local styles = terminator_Extras.glee_HudStyles

-- the style every chain ends at, and what an unregistered style draws as
terminator_Extras.glee_RootStyleName = "hl2"

function terminator_Extras.glee_RegisterStyle( styleName, style )
    styles[styleName] = style

    -- unset on first load, where the build runs once every style is in. Set on autorefresh
    if terminator_Extras.glee_RebuildStylesSoon then
        terminator_Extras.glee_RebuildStylesSoon()

    end
end

include( "glee_hud/styles/cl_hl2.lua" )
