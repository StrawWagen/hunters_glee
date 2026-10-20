--[[------------------------------------
    hl2: the default look, the suit hud's yellow on a faded black box.

    The base style: every chain ends here, so every field and every role a panel may
    ask any style for is listed here. An unregistered style draws as this one.
--]]-------------------------------------

local mediumLargeSize = 34

terminator_Extras.glee_RegisterStyle( "hl2", {
    fontName   = "Trebuchet MS",
    fontWeight = 500,
    sizeMul    = 1,

    iconMaxSize = 128, -- real pixels, never scaled

    fonts = {
        tiny        = { size = 16, weight = 1000 }, -- two lines of it fit beside a mediumLarge line
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
        nameTagBackdropInset = 0, -- see soulthought's

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
        damaged = Color( 150, 15, 15 ),      -- what was just lost, darker than alert so it shows beside it
        disabled = Color( 110, 95, 10, 200 ), -- what can't be picked right now, far darker than text
    },

    -- A panel names the family, its state picks the entry, see handle:BackdropColor.
    -- Chosen is a hud box's flash and urgent blink
    backdrops = {
        bg         = Color( 0, 0, 0, 76 ), -- for hud elements that should fade into the background
        bgHovered  = Color( 100, 100, 50, 76 ),
        bgPressed  = Color( 100, 100, 50, 76 ),
        bgChosen   = Color( 100, 100, 50, 76 ),
        bgDisabled = Color( 0, 0, 0, 140 ),

        bgDark         = Color( 0, 0, 0, 175 ), -- for gui elements that need visibility
        bgDarkHovered  = Color( 100, 100, 50, 200 ),
        bgDarkPressed  = Color( 100, 100, 50, 200 ),
        bgDarkChosen   = Color( 100, 100, 50, 200 ),
        bgDarkDisabled = Color( 0, 0, 0, 235 ),
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
        alert  = { "common/warning.wav" }, -- pay attention!
    },

    -- Fields that hold pixel sizes. The build calls this once per gui scale, px turns 1080p
    -- pixels into that scale's, and what it returns is layered over the fields above
    scaled = function( px )
        return {
            -- see handle:Entrance and handle:Exit. Seconds are the speed knobs.
            -- Taken whole, so a style changing one field lists them all
            entrance = {
                time      = 0.12,
                stagger   = 0.015, -- for things that come in in parts, like a wheel's wedges
                fadeFrom  = 0,
                scaleFrom = 0.85,
                slide     = px( 0 ),
            },
            exit = {
                time    = 0.1,
                stagger = 0,
                fadeTo  = 0,
                scaleTo = 0.85,
                slide   = px( 0 ),
            },
        }
    end,

    -- style is the built style, color the Color for the panel's family and state, unfaded.
    -- fade is 0 to 1, cache as handle:Background takes it. blur is nil, or how hard to blur
    -- what's behind the backdrop, as RNDX's blur intensity
    background = function( _style, x, y, w, h, color, cornerRadius, fade, _cache, blur )
        local RNDX = terminator_Extras.glee_RNDX

        if blur then
            RNDX.Rect( x, y, w, h ):Rad( cornerRadius ):Blur( blur * fade ):Draw()

        end

        RNDX.Rect( x, y, w, h ):Rad( cornerRadius ):Color( color.r, color.g, color.b, color.a * fade ):Draw()

    end,

    -- background's, for a piece of a ring, see handle:ArcBackground. The ring is centreX, centreY,
    -- between inner and outer, the piece startDeg to endDeg with gap pixels to its neighbours
    arcBackground = function( _style, centerX, centerY, inner, outer, startDeg, endDeg, gap, color, fade, _cache, blur )
        local arcShape = terminator_Extras.glee_HudHelpers.ArcShape

        if blur then
            local shape = arcShape( centerX, centerY, inner, outer, startDeg, endDeg, gap )
            if shape then shape:Blur( blur * fade ):Draw() end

        end

        local shape = arcShape( centerX, centerY, inner, outer, startDeg, endDeg, gap )
        if shape then shape:Color( color.r, color.g, color.b, color.a * fade ):Draw() end

    end,
} )
