--[[------------------------------------
    god: decrees, what the gods have decided or are deciding. Text torn out of a page.

    Its backdrop is the torn strip. The Misery vote draws its strips itself, through
    handle:Settings(), because they slide in narrower than their panels.
--]]-------------------------------------

terminator_Extras.glee_RegisterStyle( "god", {
    fontName = "Sparkplucked",
    fontWeight = 200, -- brush strokes chew up any heavier

    fonts = {
        large  = { size = 70 },
        medium = { size = 35 },
        small  = { size = 30 },
    },

    colors = {
        text    = Color( 235, 110, 20 ),
        hovered = Color( 255, 150, 50 ),
        chosen  = Color( 255, 200, 90 ),
        urgent  = Color( 200, 25, 5 ),
    },

    shadowColor = Color( 0, 0, 0, 255 ),

    -- the torn strip. One look, so both families share it
    backdrops = {
        bg         = Color( 10, 5, 0, 170 ),
        bgHovered  = Color( 30, 15, 4, 200 ),
        bgPressed  = Color( 48, 24, 6, 220 ),
        bgChosen   = Color( 70, 34, 6, 220 ),
        bgDisabled = Color( 10, 5, 0, 170 ),

        bgDark         = Color( 10, 5, 0, 170 ),
        bgDarkHovered  = Color( 30, 15, 4, 200 ),
        bgDarkPressed  = Color( 48, 24, 6, 220 ),
        bgDarkChosen   = Color( 70, 34, 6, 220 ),
        bgDarkDisabled = Color( 10, 5, 0, 170 ),
    },

    metrics = {
        textPaddingX = 8,
        textPaddingY = 1,
        lineGap = 4, -- between stacked lines, like the Misery vote's options
    },

    -- see styleHandle:PlaySound
    sounds = {
        arrival = { -- played as text comes into view
            "physics/nearmiss/whoosh_huge2.wav",
            "physics/nearmiss/whoosh_large1.wav",
        },
        landing = { -- played when it stops moving
            "physics/cardboard/cardboard_box_impact_bullet1.wav",
            "physics/cardboard/cardboard_box_impact_bullet3.wav",
            "physics/cardboard/cardboard_box_impact_bullet5.wav",
        },
    },

    -- god's hand isn't steady, see glee_HudHelpers.DoJitter
    jitter = {
        pixels = 1,
        interval = { 1 / 25, 1 / 18 },
    },

    scaled = function( px )
        return {
            -- see glee_HudHelpers.DrawTornStrip
            tornStrip = {
                tearSegment = px( 6 ), -- width of each jag along the top and bottom
                tearDepth = px( 3 ),
                ripRowStep = px( 3 ), -- height of each jag down the ripped ends
                ripReachMax = px( 14 ), -- how far past the strip an end can be torn
                ripNoise = px( 2 ),
            },

            -- the text arrival animation, faint copies converging onto the text. Keyed by
            -- the font role they land on, see styleHandle:NewArrival
            ghosts = {
                medium = {
                    count = 2,
                    spreadMin = px( 6 ),
                    spreadMax = px( 18 ),
                    orbitMin = 0,
                    orbitMax = 0,
                    startSpread = 0.1,
                    mergeTime = 0.3,
                    peakAlpha = 70,
                },
            },

            -- see glee_HudHelpers.ArrivalProgress
            arrival = {
                slideDistance = px( 40 ),
                time = 0.25,
                stagger = 0.04,
            },
        }
    end,

    -- torn paper rather than a box, so it ignores the corner radius it is handed.
    -- Without a cache the tears reroll every frame
    background = function( style, x, y, w, h, color, _cornerRadius, fade, cache )
        local oldMultiplier = surface.GetAlphaMultiplier()
        surface.SetAlphaMultiplier( oldMultiplier * fade )

        terminator_Extras.glee_HudHelpers.DrawTornStrip( style.tornStrip, color, x, y, w, h, cache or {} )

        surface.SetAlphaMultiplier( oldMultiplier )

    end,
} )
