--[[------------------------------------
    soulthought: a soul thinking, how the world reads to the dead.

    Swaps in for hl2 on the same panels mid-round, so it has to fill the same roles at
    the same sizes, or a box would resize the moment its player died.
--]]-------------------------------------

local ghostHud -- assigned below; the background closure needs a name to reach the blot by

terminator_Extras.ghostHud = terminator_Extras.glee_RegisterStyle( "soulthought", {
    fontName = "Acidic",
    sizeMul = 0.85, -- Acidic is bigger than Trebuchet

    -- hl2's own table, not a copy, so the two can never drift out of step
    fontSizes = terminator_Extras.glee_HL2Hud.fontSizes,

    extraFontSizes = {
        -- TargetID's size is picked by resolution band in ClientScheme.res, so copy its
        -- height rather than guess the band. See cl_fonts.lua for what a function size means
        targetID = {
            size = function() return draw.GetFontHeight( "TargetID" ) end,
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

    -- see glee_HudHelpers.DrawBlot
    blot = {
        layers = 8,
        spillX = glee_sizeScaled( nil, 10 ),
        spillY = glee_sizeScaled( nil, 6 ),
        insetX = glee_sizeScaled( nil, 2 ), -- per side, per layer
        insetY = glee_sizeScaled( nil, 1 ),
        -- per layer, so the centre stacks darker
        colors = {
            idle = Color( 6, 8, 2, 27 ),
            -- this style only draws idle and chosen, bring these back for something pickable
            -- hovered = Color( 20, 24, 8, 34 ),
            -- pressed = Color( 34, 40, 14, 38 ),
            chosen = Color( 44, 60, 10, 38 ),
        },
    },

    -- a smudge rather than a box, so it ignores the colour and corner radius it is handed
    background = function( x, y, w, h, _color, _cornerRadius, fade, highlighted )
        local oldMultiplier = surface.GetAlphaMultiplier()
        surface.SetAlphaMultiplier( oldMultiplier * fade )

        local blotState = "idle"
        if highlighted then
            blotState = "chosen"

        end

        terminator_Extras.glee_HudHelpers.DrawBlot( ghostHud.blot, x, y, w, h, blotState )

        surface.SetAlphaMultiplier( oldMultiplier )

    end,
} )

ghostHud = terminator_Extras.ghostHud
