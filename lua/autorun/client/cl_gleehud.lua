
local math_Round = math.Round

local uiScaleVert = ScrH() / 1080
local uiScaleHoris = ScrW() / 1920

--[[------------------------------------
    glee_sizeScaled
    Desc: scales sizes based on screen resolution
    Pass 1080p pixel values; they are scaled to the current resolution.

    Examples:
    - glee_sizeScaled( 400 )           -> 400 * uiScaleHoris (same visual width as 400px at 1080p)
    - glee_sizeScaled( nil, 26 )       -> 26  * uiScaleVert  (same visual height as 26px at 1080p)
    - glee_sizeScaled( 64, 32 )        -> returns both scaled width and height

    Use nil for the axis you don’t need.
--]]-------------------------------------
function glee_sizeScaled( sizeX, sizeY )
    if sizeX and sizeY then
        return math_Round( sizeX * uiScaleHoris ), math_Round( sizeY * uiScaleVert )

    elseif sizeX then
        return math_Round( sizeX * uiScaleHoris )

    elseif sizeY then
        return math_Round( sizeY * uiScaleVert )

    end
end

terminator_Extras = terminator_Extras or {}

-- USED FOR ADDING TO DEFAULT HUD, eg, beating heart element. NOT GUIS
terminator_Extras.defaultHudPaddingFromEdge = glee_sizeScaled( nil, 24.5 ) -- how far to start the faded background
terminator_Extras.defaultHudPaddingFromBottom = glee_sizeScaled( nil, 26 ) -- how far to start the faded background
terminator_Extras.defaultHudTextPaddingFromEdge = glee_sizeScaled( nil, 54 ) -- dead on match for the "health" text


function terminator_Extras.glee_PlayerNameColor( ply, visible )
    local color = nil
    local a = nil
    if ply:Health() <= 0 then
        if ply.HasEscaped and ply:HasEscaped() then
            color = terminator_Extras.glee_EscapedPlyColor
            a = 255

        elseif visible then
            color = terminator_Extras.glee_DeadPlyColor
            a = 255

        end
    elseif ply:Health() > 0 then
        if visible then
            color = GAMEMODE:GetTeamColor( ply )
            a = 160

        end
    end

    if ply.glee_PlayerNameColorOverride then
        color = ply.glee_PlayerNameColorOverride
        a = 255

    end

    if not color then return terminator_Extras.glee_DeadPlyColor end
    color.a = a

    return color
end


-- Text and drawing helpers any hud table can use, and the styles hud panels can be drawn in
terminator_Extras.glee_HudHelpers = {}
local hudHelpers = terminator_Extras.glee_HudHelpers


terminator_Extras.glee_DeadPlyColor = Color( 87, 117, 117 )
terminator_Extras.glee_EscapedPlyColor = Color( 0, 190, 255 )

terminator_Extras.glee_HL2Hud = {
    iconMaxSize     = 128,
    boxCornerRadius = 10,
    blockPadding    = glee_sizeScaled( nil, 8 ),  -- y-padding between box edge and text
    laneSpacing     = glee_sizeScaled( nil, 6 ),  -- gap between stacked hud boxes
    fontName        = "Trebuchet MS",

    colorHappyYellow            = Color( 255, 230, 0, 220 ),
    colorUnHappyYellow          = Color( 225, 200, 0, 220 ),
    colorRedUrgent              = Color( 255, 50, 50, 200 ),
    colorBackground             = Color( 0, 0, 0, 76 ), -- for hud elements that should fade into the background
    colorBackgroundUrgent       = Color( 100, 100, 50, 76 ),
    colorBackgroundDark         = Color( 0, 0, 0, 175 ), -- for gui elements that need visibility
    colorBackgroundDarkUrgent   = Color( 100, 100, 50, 175 ),

    colorInnocent               = Color( 200, 255, 140, 220 ),
}

local hl2Hud = terminator_Extras.glee_HL2Hud

-- Soulthoughts: a soul thinking, how the world reads to the dead
terminator_Extras.ghostHud = {
    fontName = "Acidic",

    sizeMul = 0.85, -- Acidic is bigger than Trebuchet
    textColor = Color( 193, 199, 159 ),
    textHoveredColor = Color( 233, 240, 188 ),
    textChosenColor = Color( 211, 228, 121 ),
    textUrgentColor = Color( 206, 108, 90 ),
    shadowColor = Color( 0, 0, 0, 230 ),

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
            -- the soulthought style only draws idle and chosen, bring these back for something pickable
            -- hovered = Color( 20, 24, 8, 34 ),
            -- pressed = Color( 34, 40, 14, 38 ),
            chosen = Color( 44, 60, 10, 38 ),
        },
    },
}

local ghostHud = terminator_Extras.ghostHud

-- Each pair shares its data, so a box keeps its size when its style changes
local function defineHUDFontPair()
    local mediumLargeData = {
        size      = glee_sizeScaled( nil, 34 ),
        weight    = 2000,
        blursize  = 0,
        scanlines = 1,
        antialias = true,
    }
    local mediumData = {
        size      = glee_sizeScaled( nil, 28 ),
        weight    = 1000,
        blursize  = 0,
        scanlines = 0,
        antialias = true,
    }
    local smallData = {
        size      = glee_sizeScaled( nil, 22 ),
        weight    = 1000,
        antialias = true,
    }

    mediumLargeData.font = hl2Hud.fontName
    surface.CreateFont( "glee_mediumLargeHL2Font", mediumLargeData )
    mediumLargeData.font = ghostHud.fontName
    mediumLargeData.size = mediumLargeData.size * ghostHud.sizeMul
    surface.CreateFont( "glee_mediumLargeSoulthoughtFont", mediumLargeData )

    mediumData.font = hl2Hud.fontName
    surface.CreateFont( "glee_mediumHL2Font", mediumData )
    mediumData.font = ghostHud.fontName
    mediumData.size = mediumData.size * ghostHud.sizeMul
    surface.CreateFont( "glee_mediumSoulthoughtFont", mediumData )

    smallData.font = hl2Hud.fontName
    surface.CreateFont( "glee_smallHL2Font", smallData )
    smallData.font = ghostHud.fontName
    smallData.size = smallData.size * ghostHud.sizeMul
    surface.CreateFont( "glee_smallSoulthoughtFont", smallData )

    -- TargetID is the engine's, its size picked by resolution band in ClientScheme.res,
    -- so copy its height rather than guess the band
    surface.CreateFont( "glee_targetIDSoulthoughtFont", {
        font      = ghostHud.fontName,
        size      = draw.GetFontHeight( "TargetID" ),
        weight    = 700,
        shadow    = true, -- TargetID has dropshadow
        antialias = true,
    } )

end

local function getStyle( styleName )
    return hudHelpers.styles[styleName] or hudHelpers.styles.hl2

end

local warnedColorRoles = {}

-- Colors pass through. An unknown role warns once, then draws as the text role
function hudHelpers.ResolveColor( styleName, colorOrRole )
    if not isstring( colorOrRole ) then return colorOrRole end

    local style = getStyle( styleName )
    local color = style.colors[colorOrRole] or hudHelpers.styles.hl2.colors[colorOrRole]
    if color then return color end

    if not warnedColorRoles[colorOrRole] then
        warnedColorRoles[colorOrRole] = true
        ErrorNoHaltWithStack( "glee_HL2Hud: unknown color role \"" .. colorOrRole .. "\"\n" )

    end

    return style.colors.text or hudHelpers.styles.hl2.colors.text

end

-- Anything that isn't a role is taken as a font name, and passes through
function hudHelpers.ResolveFont( styleName, fontOrRole )
    return getStyle( styleName ).fonts[fontOrRole] or hudHelpers.styles.hl2.fonts[fontOrRole] or fontOrRole

end

-- cornerRadius defaults to boxCornerRadius, fade to 1
function hudHelpers.DrawBackground( styleName, x, y, w, h, color, cornerRadius, fade, highlighted )
    getStyle( styleName ).background( x, y, w, h, color, cornerRadius or hl2Hud.boxCornerRadius, fade or 1, highlighted or false )

end

-- Decrees: what the gods have decided, or are deciding
terminator_Extras.godHud = {
    fontName = "Sparkplucked",
    shadowOffsetX = 2.5,
    shadowOffsetY = 2,
    -- played as text comes into view
    textArrivalSounds = {
        "physics/nearmiss/whoosh_huge2.wav",
        "physics/nearmiss/whoosh_large1.wav",
    },
    -- played when it stops moving
    textLandingSounds = {
        "physics/cardboard/cardboard_box_impact_bullet1.wav",
        "physics/cardboard/cardboard_box_impact_bullet3.wav",
        "physics/cardboard/cardboard_box_impact_bullet5.wav",
    },
    -- god's hand isn't steady, See glee_HudHelpers.DoJitter
    jitter = {
        pixels = 1,
        interval = { 1 / 25, 1 / 18 },
    },

    textColor = Color( 235, 110, 20 ),
    textHoveredColor = Color( 255, 150, 50 ),
    textChosenColor = Color( 255, 200, 90 ),
    textUrgentColor = Color( 200, 25, 5 ),
    shadowColor = Color( 0, 0, 0, 255 ),

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

    -- made in defineGodFonts
    fonts = {
        large = "huntersglee_decrees_large",
        medium = "huntersglee_decrees_medium",
        small = "huntersglee_decrees_small",
    },

    -- the text arrival animation, faint copies converging onto the text. Keyed by the font they land on
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
}

local godHud = terminator_Extras.godHud

-- The first time tutorial's and round end screen's decrees. Shares godHud's sounds and jitter
terminator_Extras.godlyDecreeHud = {
    fontName = "Protest Revolution",
    shadowOffsetX = 2.5,
    shadowOffsetY = 2,

    textColor = Color( 200, 0, 0 ),
    textEndscreenColor = Color( 200, 25, 25 ),
    textDoomColor = Color( 100, 0, 0 ), -- bad news, like nobody escaping
    textBoonColor = Color( 200, 200, 0 ), -- good news, like everybody escaping
    shadowColor = Color( 0, 0, 0, 255 ),

    -- made in defineGodFonts
    fonts = {
        huge = "huntersglee_tutorial_huge",
        triumphant = "huntersglee_tutorial_triumphant",
        playerName = "huntersglee_winscreen_name", -- player names need characters the decree font lacks
    },

    -- the text arrival animation, faint copies converging onto the text. Keyed by the font they land on
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
}

local godlyDecreeHud = terminator_Extras.godlyDecreeHud

local function defineGodFonts()
    surface.CreateFont( "huntersglee_tutorial_huge", {
        font      = godlyDecreeHud.fontName,
        size      = glee_sizeScaled( nil, 150 ),
        weight    = 600,
        antialias = false,
    } )

    -- the round end verdict
    surface.CreateFont( "huntersglee_tutorial_triumphant", {
        font      = godlyDecreeHud.fontName,
        size      = glee_sizeScaled( nil, 90 ),
        weight    = 600,
        antialias = true,
    } )
    -- sized to sit with huntersglee_tutorial_triumphant
    surface.CreateFont( "huntersglee_winscreen_name", {
        font      = "Arial", -- GAMEMODE.GLEE_FONT, which isn't set yet when this file loads
        size      = glee_sizeScaled( nil, 65 ),
        weight    = 500,
        antialias = true,
    } )

    -- brush strokes chew up without antialias at these sizes
    surface.CreateFont( "huntersglee_decrees_large", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 70 ),
        weight    = 200,
        antialias = true,
    } )
    surface.CreateFont( "huntersglee_decrees_medium", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 35 ),
        weight    = 200,
        antialias = true,
    } )
    surface.CreateFont( "huntersglee_decrees_small", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 30 ),
        weight    = 200,
        antialias = true,
    } )
end


-- Looks for hl2 hud panels, picked by their ._myStyle. soulthought is ghostHud's look, for the dead.
-- A role a style lacks falls back to hl2's.
-- background: color is unfaded, fade is 0 to 1, highlighted means flashing
local fadedBackground = Color( 0, 0, 0, 0 )

hudHelpers.styles = {
    hl2 = {
        fonts = {
            small = "glee_smallHL2Font",
            medium = "glee_mediumHL2Font",
            mediumLarge = "glee_mediumLargeHL2Font",
            targetID = "TargetID",
        },

        colors = {
            text = hl2Hud.colorUnHappyYellow,
            happy = hl2Hud.colorHappyYellow,
            alert = Color( 255, 50, 50 ),
            flash = hl2Hud.colorRedUrgent,
            jackpot = Color( 255, 255, 0 ),
        },

        background = function( x, y, w, h, color, cornerRadius, fade, _highlighted )
            fadedBackground.r = color.r
            fadedBackground.g = color.g
            fadedBackground.b = color.b
            fadedBackground.a = math.floor( color.a * fade )

            draw.RoundedBox( cornerRadius, x, y, w, h, fadedBackground )

        end,
    },

    soulthought = {
        fonts = {
            small = "glee_smallSoulthoughtFont",
            medium = "glee_mediumSoulthoughtFont",
            mediumLarge = "glee_mediumLargeSoulthoughtFont",
            targetID = "glee_targetIDSoulthoughtFont",
        },

        colors = {
            text = ghostHud.textColor,
            happy = ghostHud.textHoveredColor,
            alert = ghostHud.textUrgentColor,
            flash = ghostHud.textUrgentColor,
            jackpot = ghostHud.textChosenColor,
        },

        background = function( x, y, w, h, _color, _cornerRadius, fade, highlighted )
            local oldMultiplier = surface.GetAlphaMultiplier()
            surface.SetAlphaMultiplier( oldMultiplier * fade )

            local blotState = "idle"
            if highlighted then
                blotState = "chosen"

            end

            hudHelpers.DrawBlot( ghostHud.blot, x, y, w, h, blotState )

            surface.SetAlphaMultiplier( oldMultiplier )

        end,
    },
}

-- Measures whole lines, not words, so kerning can't push a line past maxWidth.
-- A word wider than maxWidth overflows on its own line
function hudHelpers.WrapText( text, font, maxWidth )
    surface.SetFont( font )
    local lines = {}

    for _, paragraph in ipairs( string.Explode( "\n", text, false ) ) do
        local line = ""

        for _, word in ipairs( string.Explode( " ", paragraph, false ) ) do
            local try = ( line == "" ) and word or ( line .. " " .. word )

            if line ~= "" and surface.GetTextSize( try ) > maxWidth then
                lines[#lines + 1] = line
                line = word

            else
                line = try

            end
        end

        lines[#lines + 1] = line

    end

    return table.concat( lines, "\n" )

end

-- surface.PlaySound has no pitch arg. volume defaults to 0.5
function hudHelpers.PlaySound( sounds, pitch, channel, volume )
    LocalPlayer():EmitSound( sounds[math.random( 1, #sounds )], 75, pitch, volume or 0.5, channel )

end


-- The 1.2 has to match drawShadowedTextBetterData's line spacing
function hudHelpers.MeasureText( text, font )
    surface.SetFont( font )
    local lines = string.Explode( "\n", text, false )
    local widest = 0
    local height = 0

    for ind, line in ipairs( lines ) do
        local lineWidth, lineHeight = surface.GetTextSize( line )
        widest = math.max( widest, lineWidth )

        if ind < #lines then
            height = height + ( lineHeight * 1.2 )

        else
            height = height + lineHeight

        end
    end

    return widest, height

end

-- Ghosts are faint copies of a message that spiral onto it as it arrives
function hudHelpers.BuildGhosts( ghostSettings )
    local ghosts = {}

    for ind = 1, ghostSettings.count do
        local orbit = math.rad( math.Rand( ghostSettings.orbitMin, ghostSettings.orbitMax ) )
        if math.random( 2 ) == 1 then -- half of them sweep the other way round
            orbit = -orbit

        end

        ghosts[ind] = {
            angle = math.rad( math.Rand( 0, 360 ) ),
            spread = math.Rand( ghostSettings.spreadMin, ghostSettings.spreadMax ),
            orbit = orbit,
            startAt = math.Rand( 0, ghostSettings.startSpread ),
            progress = 0,
            eased = 0,
        }
    end

    return ghosts

end

-- Returns how many ghosts appeared this call
function hudHelpers.AdvanceGhosts( ghosts, elapsed, ghostSettings )
    local appeared = 0

    for _, ghost in ipairs( ghosts ) do
        local progress = math.Clamp( ( elapsed - ghost.startAt ) / ghostSettings.mergeTime, 0, 1 )
        ghost.progress = progress
        ghost.eased = 1 - ( ( 1 - progress ) ^ 3 )

        if progress > 0 and not ghost.appeared then
            ghost.appeared = true
            appeared = appeared + 1

        end
    end

    return appeared

end

-- 0 to 1, reaching 1 as the last ghost lands
function hudHelpers.GhostsMaterialised( elapsed, ghostSettings )
    return math.Clamp( elapsed / ( ghostSettings.startSpread + ghostSettings.mergeTime ), 0, 1 )

end

-- Writes the alpha of data's colors, so pass copies, never a hud table's
function hudHelpers.DrawGhosts( ghosts, ghostSettings, data, landingX, landingY )
    local textColor = data.textColor
    local shadowColor = data.shadowColor

    for _, ghost in ipairs( ghosts ) do
        if ghost.progress <= 0 then continue end

        local eased = ghost.eased

        -- peaks halfway in, gone once it lands
        local fade = math.sin( eased * math.pi )
        textColor.a = ghostSettings.peakAlpha * fade
        shadowColor.a = ghostSettings.peakAlpha * fade

        local angle = ghost.angle + ( ghost.orbit * eased )
        local dist = ghost.spread * ( 1 - eased )

        data.posX = landingX + ( math.cos( angle ) * dist )
        data.posY = landingY + ( math.sin( angle ) * dist )
        surface.drawShadowedTextBetterData( data )

    end
end

-- A soft dark smudge behind text. Spills past x, y, w, h, and past the panel's bounds.
-- blot is settings like ghostHud.blot, state a key of its colors
function hudHelpers.DrawBlot( blot, x, y, w, h, state )
    local color = blot.colors[state]

    local blotX = x - blot.spillX
    local blotY = y - blot.spillY
    local blotW = w + ( blot.spillX * 2 )
    local blotH = h + ( blot.spillY * 2 )

    local wasClipping = DisableClipping( true )

    for layer = 0, blot.layers - 1 do
        local insetX = layer * blot.insetX
        local insetY = layer * blot.insetY
        local layerW = blotW - ( insetX * 2 )
        local layerH = blotH - ( insetY * 2 )

        if layerW <= 0 or layerH <= 0 then break end

        local cornerRad = math.floor( layerH / 2.5 )
        draw.RoundedBox( cornerRad, blotX + insetX, blotY + insetY, layerW, layerH, color )

    end

    DisableClipping( wasClipping )

end

-- surface.DrawPoly wants convex shapes, wound clockwise
local tornQuad = { { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 }, { x = 0, y = 0 } }

local function drawQuad( x1, y1, x2, y2, x3, y3, x4, y4 )
    tornQuad[1].x, tornQuad[1].y = x1, y1
    tornQuad[2].x, tornQuad[2].y = x2, y2
    tornQuad[3].x, tornQuad[3].y = x3, y3
    tornQuad[4].x, tornQuad[4].y = x4, y4
    surface.DrawPoly( tornQuad )

end

local function makeRipReaches( settings, rows )
    local topReach = math.Rand( 0, settings.ripReachMax )
    local bottomReach = math.Rand( 0, settings.ripReachMax )

    local reaches = {}
    for ind = 1, rows + 1 do
        local slant = Lerp( ( ind - 1 ) / rows, topReach, bottomReach )
        reaches[ind] = math.max( slant + math.Rand( -settings.ripNoise, settings.ripNoise ), 0 )

    end
    return reaches

end

-- Rerolled only when the strip's size changes, so the tears hold still between frames
local function getTornShape( settings, cache, segments, rows )
    local shape = cache.tornShape
    if shape and shape.segments == segments and shape.rows == rows then return shape end

    shape = { segments = segments, rows = rows, top = {}, bottom = {} }
    for ind = 1, segments + 1 do
        shape.top[ind] = math.Rand( 0, settings.tearDepth )
        shape.bottom[ind] = math.Rand( 0, settings.tearDepth )

    end
    shape.left = makeRipReaches( settings, rows )
    shape.right = makeRipReaches( settings, rows )

    cache.tornShape = shape
    return shape

end

-- A dark strip ripped out of a page, jagged along the top and bottom, its ends torn off at a slant.
-- The ends spill past x and x + w, and past the panel's bounds.
-- settings is like godHud.tornStrip, state a key of its colors.
-- cache is any table that lives as long as the strip, the torn shape is kept on it.
function hudHelpers.DrawTornStrip( settings, x, y, w, h, state, cache )
    local segments = math.max( math.ceil( w / settings.tearSegment ), 1 )
    local rows = math.max( math.ceil( h / settings.ripRowStep ), 1 )
    local shape = getTornShape( settings, cache, segments, rows )

    local wasClipping = DisableClipping( true )
    draw.NoTexture()
    surface.SetDrawColor( settings.colors[state] )

    local segmentW = w / segments
    for ind = 1, segments do
        local leftX = x + ( ind - 1 ) * segmentW
        local rightX = leftX + segmentW
        drawQuad(
            leftX, y + shape.top[ind],
            rightX, y + shape.top[ind + 1],
            rightX, y + h - shape.bottom[ind + 1],
            leftX, y + h - shape.bottom[ind]
        )
    end

    -- each end spans the height of the strip's outermost column
    local last = segments + 1
    local rightX = x + w
    local leftTop = y + shape.top[1]
    local leftRowH = ( y + h - shape.bottom[1] - leftTop ) / rows
    local rightTop = y + shape.top[last]
    local rightRowH = ( y + h - shape.bottom[last] - rightTop ) / rows

    for row = 1, rows do
        local leftY1 = leftTop + ( row - 1 ) * leftRowH
        drawQuad(
            x - shape.left[row], leftY1,
            x, leftY1,
            x, leftY1 + leftRowH,
            x - shape.left[row + 1], leftY1 + leftRowH
        )

        local rightY1 = rightTop + ( row - 1 ) * rightRowH
        drawQuad(
            rightX, rightY1,
            rightX + shape.right[row], rightY1,
            rightX + shape.right[row + 1], rightY1 + rightRowH,
            rightX, rightY1 + rightRowH
        )
    end

    DisableClipping( wasClipping )

end

-- 0 to 1, eased. Each order starts arrivalSettings.stagger later
function hudHelpers.ArrivalProgress( openedAt, order, arrivalSettings )
    local startAt = openedAt + ( order * arrivalSettings.stagger )
    local progress = math.Clamp( ( CurTime() - startAt ) / arrivalSettings.time, 0, 1 )

    return 1 - ( ( 1 - progress ) ^ 3 )

end

-- Keeps jitterX and jitterY on whatever table you hand it, ready for a draw position to add.
-- Owns its own clock, a per frame reroll is a buzz nobody can see and it would shake harder
-- the better your hardware is. Safe to call every frame, it only rerolls when it's due.
-- jitterSettings is like godHud.jitter
function hudHelpers.DoJitter( state, jitterSettings )
    if state.nextJitter and state.nextJitter > CurTime() then return end

    local interval = jitterSettings.interval
    state.nextJitter = CurTime() + math.Rand( interval[1], interval[2] )

    local pixels = jitterSettings.pixels
    state.jitterX = math.random( -pixels, pixels )
    state.jitterY = math.random( -pixels, pixels )

end

defineGodFonts()
defineHUDFontPair()
hook.Add( "glee_rebuildfonts", "glee_rebuild_defaultfonts", function()
    defineGodFonts()
    defineHUDFontPair()

end )