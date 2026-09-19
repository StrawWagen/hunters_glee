-- hl2: the default look, the suit hud's yellow on a faded black box.
-- Every panel starts here, and an unregistered style draws as this one

local mediumLargeSize = 34

terminator_Extras.glee_HL2Hud = terminator_Extras.glee_RegisterStyle( "hl2", {
    fontName = "Trebuchet MS",

    fontSizes = {
        small       = { size = 22, weight = 1000 },
        medium      = { size = 28, weight = 1000 },
        mediumLarge = { size = mediumLargeSize, weight = 2000, scanlines = 1 },
        placing     = { size = 40, weight = 1000 }, -- the readout while placing something

        -- A name is whatever the player typed, so it names its typeface instead of taking
        -- the style's: the decorative faces have no glyphs for most of what turns up.
        -- Sized in final pixels, which skips sizeMul too, so it stays level with a
        -- mediumLarge label in a style that nudges its own face. See cl_fonts.lua
        playerName = {
            size = function() return glee_sizeScaled( nil, mediumLargeSize ) end,
            font = "Trebuchet MS",
            weight = 1000,
        },
    },

    -- TargetID is the engine's own, sized by resolution band in ClientScheme.res
    borrowedFonts = {
        targetID = "TargetID",
    },

    colors = {
        text  = Color( 225, 200, 0, 220 ),
        happy = Color( 255, 230, 0, 220 ),
        alert = Color( 255, 50, 50 ),
        flash = Color( 255, 50, 50, 200 ),

        bg           = Color( 0, 0, 0, 76 ),   -- for hud elements that should fade into the background
        bgUrgent     = Color( 100, 100, 50, 76 ),
        bgDark       = Color( 0, 0, 0, 175 ),  -- for gui elements that need visibility
        bgDarkUrgent = Color( 100, 100, 50, 175 ),

        innocent = Color( 200, 255, 140, 220 ), -- the clean end of the guilt scale, see sh_guilt.lua
    },
} )
