--[[------------------------------------
    hl2: the default look, the suit hud's yellow on a faded black box.

    The base style: every chain ends here, so every field and every role a panel may
    ask any style for is listed here. An unregistered style draws as this one.
--]]-------------------------------------

local mediumLargeSize = 34

local fadedBackground = Color( 0, 0, 0, 0 )

terminator_Extras.glee_RegisterStyle( "hl2", {
    fontName   = "Trebuchet MS",
    fontWeight = 500,
    sizeMul    = 1,

    iconMaxSize = 128, -- real pixels, never scaled

    fonts = {
        small       = { size = 22, weight = 1000 },
        medium      = { size = 28, weight = 1000 },
        mediumLarge = { size = mediumLargeSize, weight = 2000, scanlines = 1 },
        placing     = { size = 40, weight = 1000 }, -- the readout while placing something

        -- A name is whatever the player typed, and the decorative faces lack the glyphs, so
        -- it names its own face. sizeMul 1 keeps it this size in a style that shrinks its face
        playerName = { size = mediumLargeSize, sizeMul = 1, font = "Trebuchet MS", weight = 1000 },

        -- the engine's own, sized by resolution band in ClientScheme.res
        targetID = "TargetID",

        -- a name over a player's head, the engine's own for the same reason as playerName
        nameTag = "TargetID",
    },

    metrics = {
        blockPadding    = 8, -- y-padding between box edge and text
        laneSpacing     = 6, -- gap between stacked hud boxes
        boxCornerRadius = 10,

        -- drawShadowedTextBetterData's own defaults, but scaled. Left unrounded by the build
        shadowOffsetX = 2.5,
        shadowOffsetY = 2,
    },

    colors = {
        text    = Color( 225, 200, 0, 220 ), -- also what an unknown role falls back to
        happy   = Color( 255, 230, 0, 220 ), -- full health, full battery
        alert   = Color( 255, 50, 50 ),      -- needs you now
        flash   = Color( 255, 50, 50, 200 ), -- a hud box's one-off flash
        jackpot = Color( 255, 255, 0 ),      -- something rare went your way
        hovered = Color( 255, 255, 255 ),
        chosen  = Color( 255, 255, 255 ),
        urgent  = Color( 255, 80, 80 ),      -- a countdown running out
    },

    -- A panel names the family, its state picks the entry, see handle:BackdropColor.
    -- Chosen is a hud box's flash and urgent blink
    backdrops = {
        bg         = Color( 0, 0, 0, 76 ), -- for hud elements that should fade into the background
        bgHovered  = Color( 100, 100, 50, 76 ),
        bgPressed  = Color( 100, 100, 50, 76 ),
        bgChosen   = Color( 100, 100, 50, 76 ),
        bgDisabled = Color( 0, 0, 0, 76 ),

        bgDark         = Color( 0, 0, 0, 175 ), -- for gui elements that need visibility
        bgDarkHovered  = Color( 100, 100, 50, 200 ),
        bgDarkPressed  = Color( 100, 100, 50, 200 ),
        bgDarkChosen   = Color( 100, 100, 50, 200 ),
        bgDarkDisabled = Color( 0, 0, 0, 200 ),
    },

    shadowColor = Color( 0, 0, 0, 200 ),

    -- layered over every style's own look, soulthought's and the decrees' included
    highContrast = {
        everyTextColor = Color( 255, 255, 255, 255 ),

        fontName   = "Trebuchet MS",
        fontWeight = 500,
        sizeMul    = 1,
    },

    -- see styleHandle:PlaySound. Pitches are the caller's, these are just what plays
    sounds = {
        switch = { "buttons/lightswitch2.wav" }, -- hovering onto and off of something pickable
        press  = { "common/wpn_select.wav" },
    },

    -- style is the built style, color the Color for the panel's family and state, unfaded.
    -- fade is 0 to 1, cache as handle:Background takes it
    background = function( _style, x, y, w, h, color, cornerRadius, fade, _cache )
        fadedBackground.r = color.r
        fadedBackground.g = color.g
        fadedBackground.b = color.b
        fadedBackground.a = math.floor( color.a * fade )

        draw.RoundedBox( cornerRadius, x, y, w, h, fadedBackground )

    end,
} )
