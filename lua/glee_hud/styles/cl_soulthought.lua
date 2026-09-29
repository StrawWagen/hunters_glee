--[[------------------------------------
    soulthought: how the world reads to the dead.

    Swaps in for hl2 on the same panels the moment you die, so it keeps hl2's font roles
    and changes only the face, or every box would change shape.
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
    },

    shadowColor = Color( 0, 0, 0, 230 ),

    -- what the blot comes to at its centre, see glee_HudHelpers.DrawBlot
    backdrops = {
        bg         = Color( 6, 8, 2, 110 ),
        bgDisabled = Color( 6, 8, 2, 110 ),
        bgHovered  = Color( 20, 24, 8, 150 ),
        bgPressed  = Color( 34, 40, 14, 175 ),
        bgChosen   = Color( 44, 60, 10, 175 ),

        bgDark         = Color( 6, 8, 2, 215 ),
        bgDarkHovered  = Color( 20, 24, 8, 225 ),
        bgDarkPressed  = Color( 34, 40, 14, 235 ),
        bgDarkChosen   = Color( 44, 60, 10, 235 ),
        bgDarkDisabled = Color( 6, 8, 2, 215 ),
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
                -- corners round with the layer's height up to here, so a row is a soft pill
                -- and a whole frame is a rounded box rather than an oval
                maxCornerRadius = px( 20 ),
            },
        }
    end,

    -- a smudge rather than a box, so it ignores the corner radius it is handed
    background = function( style, x, y, w, h, color, _cornerRadius, fade, _cache )
        local oldMultiplier = surface.GetAlphaMultiplier()
        surface.SetAlphaMultiplier( oldMultiplier * fade )

        terminator_Extras.glee_HudHelpers.DrawBlot( style.blot, color, x, y, w, h )

        surface.SetAlphaMultiplier( oldMultiplier )

    end,
} )
