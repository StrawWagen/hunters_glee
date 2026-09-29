--[[------------------------------------
    godlyDecree: the first time tutorial's and the round end screen's decrees.

    The same voice as god, louder and in a different hand. Everything it doesn't list,
    the sounds, the jitter, the spacing and the torn strip, is god's.
--]]-------------------------------------

terminator_Extras.glee_RegisterStyle( "godlyDecree", {
    inherits = "god",

    fontName = "Protest Revolution",
    fontWeight = 600,

    fonts = {
        huge       = { size = 150, antialias = false },
        triumphant = { size = 90 }, -- the round end verdict
        orders     = { size = 80 }, -- the divine chosen's marching orders
        -- player names need characters the decree font lacks, sized to sit with the verdict.
        -- A function because GLEE_FONT isn't set when this file loads, see cl_stylebuild.lua
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
        urgent    = Color( 255, 40, 20 ), -- grigori countdown's last thirty seconds
    },

    scaled = function( px )
        return {
            -- the text arrival animation, faint copies converging onto the text. Keyed by
            -- the font role they land on, see styleHandle:NewArrival
            ghosts = {
                triumphant = {
                    count = 4,
                    spreadMin = px( 12 ),
                    spreadMax = px( 55 ),
                    orbitMin = 40, -- degrees swept around the landing spot
                    orbitMax = 120,
                    startSpread = 0.2, -- how long until the last ghost shows up
                    mergeTime = 0.35,
                    peakAlpha = 90,
                },
                huge = {
                    count = 5,
                    spreadMin = px( 15 ),
                    spreadMax = px( 70 ),
                    orbitMin = 40, -- degrees swept around the landing spot
                    orbitMax = 120,
                    startSpread = 0.35, -- how long until the last ghost shows up
                    mergeTime = 0.45,
                    peakAlpha = 90,
                },
            },
        }
    end,
} )
