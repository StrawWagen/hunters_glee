-- hl2: the default look, the suit hud's yellow on a faded black box.
-- Every panel starts here, and an unregistered style draws as this one

local mediumLargeSize = 34

terminator_Extras.glee_RegisterStyle( "hl2", {
    fontName = "Trebuchet MS",

    fonts = {
        small       = { size = 22, weight = 1000 },
        medium      = { size = 28, weight = 1000 },
        mediumLarge = { size = mediumLargeSize, weight = 2000, scanlines = 1 },
        placing     = { size = 40, weight = 1000 }, -- the readout while placing something

        -- A name is whatever the player typed, so it names its typeface instead of taking
        -- the style's: the decorative faces have no glyphs for most of what turns up.
        -- Its own sizeMul keeps it level with a mediumLarge label in a style that nudges
        -- its own face
        playerName = { size = mediumLargeSize, sizeMul = 1, font = "Trebuchet MS", weight = 1000 },

        -- the engine's own, sized by resolution band in ClientScheme.res
        targetID = "TargetID",

        -- a name over a player's head. The engine's own for the same reason as playerName,
        -- and at TargetID's size to sit with the targetID lines under it
        nameTag = "TargetID",
    },

    colors = {
        text  = Color( 225, 200, 0, 220 ),
        happy = Color( 255, 230, 0, 220 ),
        alert = Color( 255, 50, 50 ),
        flash = Color( 255, 50, 50, 200 ),

        bgUrgent     = Color( 100, 100, 50, 76 ),
        bgDarkUrgent = Color( 100, 100, 50, 175 ),

        innocent = Color( 200, 255, 140, 220 ), -- the clean end of the guilt scale, see sh_guilt.lua
    },
} )
