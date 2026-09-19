--[[------------------------------------
    godlyDecree: the first time tutorial's and the round end screen's decrees.

    The same voice as god, louder and in a different hand. Everything it doesn't list,
    the sounds, the jitter, the spacing and the torn strip, is god's.

    Its fontSizes replace god's outright rather than adding to them, so it has no small,
    medium or large. Ask it for one and handle:Font warns.
--]]-------------------------------------

terminator_Extras.godlyDecreeHud = terminator_Extras.glee_RegisterStyle( "godlyDecree", {
    inherits = "god",

    fontName = "Protest Revolution",
    fontWeight = 600,

    fontSizes = {
        huge       = { size = 150, antialias = false },
        triumphant = { size = 90 }, -- the round end verdict
        orders     = { size = 80 }, -- the divine chosen's marching orders
        -- player names need characters the decree font lacks, sized to sit with the verdict.
        -- GLEE_FONT is read at build time because it isn't set yet when this file loads
        playerName = {
            size = 65,
            weight = 500,
            font = function() return GAMEMODE and GAMEMODE.GLEE_FONT or "Arial" end,
        },
    },

    colors = {
        text      = Color( 200, 0, 0 ),
        endscreen = Color( 200, 25, 25 ),
        doom      = Color( 100, 0, 0 ), -- bad news, like nobody escaping
        boon      = Color( 255, 165, 0 ), -- good news, like everybody escaping
        shadow    = Color( 0, 0, 0, 255 ),
        urgent    = Color( 255, 40, 20 ), -- grigori countdown's last thirty seconds
    },

    -- the text arrival animation, faint copies converging onto the text. Keyed by the
    -- font role they land on, see styleHandle:NewArrival
    ghosts = {
        triumphant = {
            count = 4,
            spreadMin = glee_sizeScaled( nil, 12 ),
            spreadMax = glee_sizeScaled( nil, 55 ),
            orbitMin = 40, -- degrees swept around the landing spot
            orbitMax = 120,
            startSpread = 0.2, -- how long until the last ghost shows up
            mergeTime = 0.35,
            peakAlpha = 90,
        },
        huge = {
            count = 5,
            spreadMin = glee_sizeScaled( nil, 15 ),
            spreadMax = glee_sizeScaled( nil, 70 ),
            orbitMin = 40, -- degrees swept around the landing spot
            orbitMax = 120,
            startSpread = 0.35, -- how long until the last ghost shows up
            mergeTime = 0.45,
            peakAlpha = 90,
        },
    },
} )
