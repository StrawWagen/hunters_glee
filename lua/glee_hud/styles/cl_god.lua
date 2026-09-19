--[[------------------------------------
    god: decrees, what the gods have decided or are deciding. Text torn out of a page.

    Not a panel style. Its backdrop is the torn strip, which the caller draws itself
    through handle:Settings(), because a strip needs a cache to hold its tears still and
    background takes none. A panel set to this would paint styleBase's rounded box.
--]]-------------------------------------

terminator_Extras.godHud = terminator_Extras.glee_RegisterStyle( "god", {
    fontName = "Sparkplucked",
    fontWeight = 200, -- brush strokes chew up any heavier

    fontSizes = {
        large  = { size = 70 },
        medium = { size = 35 },
        small  = { size = 30 },
    },

    colors = {
        text    = Color( 235, 110, 20 ),
        hovered = Color( 255, 150, 50 ),
        chosen  = Color( 255, 200, 90 ),
        urgent  = Color( 200, 25, 5 ),
        shadow  = Color( 0, 0, 0, 255 ),
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

    textPaddingX = glee_sizeScaled( nil, 8 ),
    textPaddingY = glee_sizeScaled( nil, 1 ),
    lineGap = glee_sizeScaled( nil, 4 ), -- between stacked lines, like the Misery vote's options

    -- see glee_HudHelpers.DrawTornStrip
    tornStrip = {
        colors = {
            idle = Color( 10, 5, 0, 170 ),
            hovered = Color( 30, 15, 4, 200 ),
            pressed = Color( 48, 24, 6, 220 ),
            chosen = Color( 70, 34, 6, 220 ),
        },
        tearSegment = glee_sizeScaled( nil, 6 ), -- width of each jag along the top and bottom
        tearDepth = glee_sizeScaled( nil, 3 ),
        ripRowStep = glee_sizeScaled( nil, 3 ), -- height of each jag down the ripped ends
        ripReachMax = glee_sizeScaled( nil, 14 ), -- how far past the strip an end can be torn
        ripNoise = glee_sizeScaled( nil, 2 ),
    },

    -- the text arrival animation, faint copies converging onto the text. Keyed by the
    -- font role they land on, see styleHandle:NewArrival
    ghosts = {
        medium = {
            count = 2,
            spreadMin = glee_sizeScaled( nil, 6 ),
            spreadMax = glee_sizeScaled( nil, 18 ),
            orbitMin = 0,
            orbitMax = 0,
            startSpread = 0.1,
            mergeTime = 0.3,
            peakAlpha = 70,
        },
    },

    -- see glee_HudHelpers.ArrivalProgress
    arrival = {
        slideDistance = glee_sizeScaled( nil, 40 ),
        time = 0.25,
        stagger = 0.04,
    },
} )
