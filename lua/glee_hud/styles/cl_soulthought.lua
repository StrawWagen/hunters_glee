--[[------------------------------------
    soulthought: a soul thinking, how the world reads to the dead.

    Swaps in for hl2 on the same panels mid-round, so it inherits hl2's font roles
    rather than listing its own, or a box would change shape the moment its player died.
--]]-------------------------------------

terminator_Extras.glee_RegisterStyle( "soulthought", {
    inherits = "hl2",

    fontName = "Acidic",
    sizeMul = 0.85, -- Acidic is bigger than Trebuchet

    fonts = {
        -- TargetID's size is picked by resolution band in ClientScheme.res, so copy its
        -- height rather than guess the band
        targetID = {
            size = function( scale ) return draw.GetFontHeight( "TargetID" ) * scale end,
            weight = 700,
            shadow = true, -- TargetID has dropshadow
        },
    },

    colors = {
        text    = Color( 193, 199, 159 ),
        happy   = Color( 233, 240, 188 ),
        alert   = Color( 206, 108, 90 ),
        flash   = Color( 206, 108, 90 ),
        jackpot = Color( 211, 228, 121 ),
        shadow  = Color( 0, 0, 0, 230 ),
    },

    scaled = function( px )
        return {
            -- see glee_HudHelpers.DrawBlot
            blot = {
                layers = 8,
                spillX = px( 10 ),
                spillY = px( 6 ),
                insetX = px( 2 ), -- per side, per layer
                insetY = px( 1 ),
                -- per layer, so the centre stacks darker
                colors = {
                    idle = Color( 6, 8, 2, 27 ),
                    hovered = Color( 20, 24, 8, 34 ),
                    pressed = Color( 34, 40, 14, 38 ),
                    chosen = Color( 44, 60, 10, 38 ),
                },
            },
        }
    end,

    -- a smudge rather than a box, so it ignores the colour and corner radius it is handed
    background = function( style, x, y, w, h, _color, _cornerRadius, fade, state, _cache )
        local oldMultiplier = surface.GetAlphaMultiplier()
        surface.SetAlphaMultiplier( oldMultiplier * fade )

        terminator_Extras.glee_HudHelpers.DrawBlot( style.blot, x, y, w, h, state )

        surface.SetAlphaMultiplier( oldMultiplier )

    end,
} )
