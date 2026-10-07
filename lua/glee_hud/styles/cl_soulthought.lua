--[[------------------------------------
    soulthought: how the world reads to the dead.

    Swaps in for hl2 on the same panels the moment you die, so it keeps hl2's font roles
    and changes only the face, or every box would change shape.
--]]-------------------------------------

local function scrollViewportAbove( pnl )
    local parent = pnl:GetParent()
    while IsValid( parent ) do
        if isfunction( parent.GetCanvas ) then return parent end
        parent = parent:GetParent()

    end
end

-- RNDX draws shadows with vgui's clipping off, so a smudge in a scrolling list would show
-- over the list's edge even when scrolled out of view. 0 to 1, how much of the panel the
-- list shows, to fade its smudge by. Scissoring to the list instead cuts every smudge
-- inside it square at the list's edges
local function shownByScroll( pnl )
    if not ispanel( pnl ) then return 1 end

    local viewport = scrollViewportAbove( pnl )
    if not viewport then return 1 end

    local px, py = pnl:LocalToScreen( 0, 0 )
    local pw, ph = pnl:GetSize()
    local vx, vy = viewport:LocalToScreen( 0, 0 )
    local vw, vh = viewport:GetSize()

    local overlapW = math.max( 0, math.min( px + pw, vx + vw ) - math.max( px, vx ) )
    local overlapH = math.max( 0, math.min( py + ph, vy + vh ) - math.max( py, vy ) )

    return ( overlapW * overlapH ) / math.max( pw * ph, 1 )

end

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

    metrics = {
        -- for cl_plynames
        -- shrinks the panel itself, so that the fading away 'shadow' becomes the background of the nameplate
        nameTagBackdropInset = 15,
    },

    -- what the smudge comes to at its centre, it fades out from there
    backdrops = {
        bg         = Color( 4, 6, 1, 160 ),
        bgDisabled = Color( 4, 6, 1, 160 ),
        bgHovered  = Color( 20, 24, 8, 190 ),
        bgPressed  = Color( 34, 40, 14, 210 ),
        bgChosen   = Color( 44, 60, 10, 210 ),

        bgDark         = Color( 4, 6, 1, 235 ),
        bgDarkHovered  = Color( 20, 24, 8, 240 ),
        bgDarkPressed  = Color( 34, 40, 14, 245 ),
        bgDarkChosen   = Color( 44, 60, 10, 245 ),
        bgDarkDisabled = Color( 4, 6, 1, 235 ),
    },

    -- see styleHandle:PlaySound. Pitches are the caller's, these are just what plays
    sounds = {
        switch = { "physics/cardboard/cardboard_box_impact_hard7.wav" }, -- hovering onto and off of something pickable
        press  = { "physics/cardboard/cardboard_box_impact_bullet5.wav" },
        alert  = { "ambient/machines/thumper_top.wav" }, -- pay attention!
    },

    scaled = function( px )
        return {
            smudge = {
                softness = px( 24 ), -- how wide the fade from solid to nothing is
                spill = px( 10 ), -- how far past the panel the fade is half way
                -- capped by half the height, so a row is a soft pill and a whole frame is a
                -- rounded box rather than an oval
                cornerRadius = px( 20 ),
            },
        }
    end,

    -- A soft shadow, solid in the middle, fading out past the panel's edge. Fainter the
    -- further it's scrolled out of a list. Ignores the corner radius it is handed
    background = function( style, x, y, w, h, color, _cornerRadius, fade, cache, blur )
        local smudge = style.smudge

        fade = fade * shownByScroll( cache )
        if fade <= 0 then return end

        -- RNDX cuts its shadows hollow where the shape casting them is, so the shape sits off
        -- to the left and the shadow is offset back. Clear of the shadow's far edge, its
        -- spill plus a 3 sigma pad, 1.5 softness, the hole can't reach it
        local holeOffset = w + smudge.spill + smudge.softness * 2

        local rect = terminator_Extras.glee_RNDX.Rect( x - holeOffset, y, w, h )
            :Rad( smudge.cornerRadius )
            :Color( color.r, color.g, color.b, color.a * fade )
            :Shadow( smudge.softness, smudge.spill, holeOffset, 0 )

        if blur then rect:Blur( blur * fade ) end

        rect:Draw()

    end,
} )
