
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

-- Messages from god, in two tiers, see decrees and scripture below
terminator_Extras.godHud = {
    fontName = "Protest Revolution",
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
    -- god's hand isn't steady, godly text never sits perfectly still
    jitterPixels = 1,
    jitterInterval = { 1 / 25, 1 / 18 },
}

local godHud = terminator_Extras.godHud

-- Decrees: what the gods have decided, or are deciding.
godHud.decrees = {
    textColor = Color( 235, 110, 20 ),
    textHoveredColor = Color( 255, 150, 50 ),
    textChosenColor = Color( 255, 200, 90 ),
    textUrgentColor = Color( 255, 240, 210 ),
    shadowColor = Color( 0, 0, 0, 255 ),

    boxPaddingX = glee_sizeScaled( nil, 8 ),
    boxPaddingY = glee_sizeScaled( nil, 1 ),
    boxGap = glee_sizeScaled( nil, 4 ),

    -- see godHud.DrawBlot
    blot = {
        layers = 8,
        spillX = glee_sizeScaled( nil, 10 ), -- bigger than boxGap, so stacked blots merge
        spillY = glee_sizeScaled( nil, 6 ),
        insetX = glee_sizeScaled( nil, 2 ), -- per side, per layer
        insetY = glee_sizeScaled( nil, 1 ),
        -- per layer, so the centre stacks darker
        colors = {
            idle = Color( 8, 4, 0, 27 ),
            hovered = Color( 28, 14, 4, 34 ),
            pressed = Color( 44, 22, 6, 38 ),
            chosen = Color( 64, 32, 8, 38 ),
        },
    },

    -- made in defineGodFonts
    fonts = {
        huge = "huntersglee_decrees_huge",
        large = "huntersglee_decrees_large",
        medium = "huntersglee_decrees_medium",
        small = "huntersglee_decrees_small",
    },

    -- by the font size they drift onto
    ghosts = {
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

    -- see godHud.ArrivalProgress
    arrival = {
        slideDistance = glee_sizeScaled( nil, 40 ),
        time = 0.25,
        stagger = 0.04,
    },
}

-- Scripture: ghostly text, how the world reads to the dead
godHud.scripture = {
    textColor = Color( 193, 199, 159 ),
    textHoveredColor = Color( 233, 240, 188 ),
    textChosenColor = Color( 211, 228, 121 ),
    textUrgentColor = Color( 206, 108, 90 ),
    shadowColor = Color( 0, 0, 0, 230 ),

    -- see godHud.DrawBlot
    blot = {
        layers = 8,
        spillX = glee_sizeScaled( nil, 10 ),
        spillY = glee_sizeScaled( nil, 6 ),
        insetX = glee_sizeScaled( nil, 2 ), -- per side, per layer
        insetY = glee_sizeScaled( nil, 1 ),
        -- per layer, so the centre stacks darker
        colors = {
            idle = Color( 6, 8, 2, 27 ),
            hovered = Color( 20, 24, 8, 34 ),
            pressed = Color( 34, 40, 14, 38 ),
            chosen = Color( 44, 60, 10, 38 ),
        },
    },
}

local function defineGodFonts()
    surface.CreateFont( "huntersglee_decrees_huge", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 150 ),
        weight    = 600,
        antialias = false,
    } )

    -- brush strokes chew up without antialias at these sizes
    surface.CreateFont( "huntersglee_decrees_large", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 70 ),
        weight    = 600,
        antialias = true,
    } )
    surface.CreateFont( "huntersglee_decrees_medium", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 35 ),
        weight    = 600,
        antialias = true,
    } )
    surface.CreateFont( "huntersglee_decrees_small", {
        font      = godHud.fontName,
        size      = glee_sizeScaled( nil, 30 ),
        weight    = 600,
        antialias = true,
    } )
end

-- Looks for hl2 hud panels, picked by their ._myStyle. A role a style lacks falls back to hl2's.
-- background: color is unfaded, fade is 0 to 1, highlighted means flashing
local fadedBackground = Color( 0, 0, 0, 0 )

hl2Hud.styles = {
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

    scripture = {
        fonts = {
            small = "glee_smallScriptureFont",
            medium = "glee_mediumScriptureFont",
            mediumLarge = "glee_mediumLargeScriptureFont",
            targetID = "glee_targetIDScriptureFont",
        },

        colors = {
            text = godHud.scripture.textColor,
            happy = godHud.scripture.textHoveredColor,
            alert = godHud.scripture.textUrgentColor,
            flash = godHud.scripture.textUrgentColor,
            jackpot = godHud.scripture.textChosenColor,
        },

        background = function( x, y, w, h, _color, _cornerRadius, fade, highlighted )
            local oldMultiplier = surface.GetAlphaMultiplier()
            surface.SetAlphaMultiplier( oldMultiplier * fade )

            local blotState = "idle"
            if highlighted then
                blotState = "chosen"

            end

            godHud.DrawBlot( godHud.scripture.blot, x, y, w, h, blotState )

            surface.SetAlphaMultiplier( oldMultiplier )

        end,
    },
}

-- Each pair shares its data, so a box keeps its size when its style changes
local function defineHL2Fonts()
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
    mediumLargeData.font = godHud.fontName
    surface.CreateFont( "glee_mediumLargeScriptureFont", mediumLargeData )

    mediumData.font = hl2Hud.fontName
    surface.CreateFont( "glee_mediumHL2Font", mediumData )
    mediumData.font = godHud.fontName
    surface.CreateFont( "glee_mediumScriptureFont", mediumData )

    smallData.font = hl2Hud.fontName
    surface.CreateFont( "glee_smallHL2Font", smallData )
    smallData.font = godHud.fontName
    surface.CreateFont( "glee_smallScriptureFont", smallData )

    -- TargetID is the engine's, its size picked by resolution band in ClientScheme.res,
    -- so copy its height rather than guess the band
    surface.CreateFont( "glee_targetIDScriptureFont", {
        font      = godHud.fontName,
        size      = draw.GetFontHeight( "TargetID" ),
        weight    = 700,
        shadow    = true, -- TargetID has dropshadow
        antialias = true,
    } )

end

local function getStyle( styleName )
    return hl2Hud.styles[styleName] or hl2Hud.styles.hl2

end

local warnedColorRoles = {}

-- Colors pass through. An unknown role warns once, then draws as the text role
function hl2Hud.ResolveColor( styleName, colorOrRole )
    if not isstring( colorOrRole ) then return colorOrRole end

    local style = getStyle( styleName )
    local color = style.colors[colorOrRole] or hl2Hud.styles.hl2.colors[colorOrRole]
    if color then return color end

    if not warnedColorRoles[colorOrRole] then
        warnedColorRoles[colorOrRole] = true
        ErrorNoHaltWithStack( "glee_HL2Hud: unknown color role \"" .. colorOrRole .. "\"\n" )

    end

    return style.colors.text or hl2Hud.styles.hl2.colors.text

end

-- Anything that isn't a role is taken as a font name, and passes through
function hl2Hud.ResolveFont( styleName, fontOrRole )
    return getStyle( styleName ).fonts[fontOrRole] or hl2Hud.styles.hl2.fonts[fontOrRole] or fontOrRole

end

-- Measures whole lines, not words, so kerning can't push a line past maxWidth.
-- A word wider than maxWidth overflows on its own line
function hl2Hud.WrapText( text, font, maxWidth )
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

-- cornerRadius defaults to boxCornerRadius, fade to 1
function hl2Hud.DrawBackground( styleName, x, y, w, h, color, cornerRadius, fade, highlighted )
    getStyle( styleName ).background( x, y, w, h, color, cornerRadius or hl2Hud.boxCornerRadius, fade or 1, highlighted or false )

end

-- surface.PlaySound has no pitch arg. volume defaults to 0.5
function godHud.PlaySound( sounds, pitch, channel, volume )
    LocalPlayer():EmitSound( sounds[math.random( 1, #sounds )], 75, pitch, volume or 0.5, channel )

end


-- The 1.2 has to match drawShadowedTextBetterData's line spacing
function godHud.MeasureText( text, font )
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
function godHud.BuildGhosts( ghostSettings )
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
function godHud.AdvanceGhosts( ghosts, elapsed, ghostSettings )
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
function godHud.GhostsMaterialised( elapsed, ghostSettings )
    return math.Clamp( elapsed / ( ghostSettings.startSpread + ghostSettings.mergeTime ), 0, 1 )

end

-- Writes the alpha of data's colors, so pass copies, never a tier's
function godHud.DrawGhosts( ghosts, ghostSettings, data, landingX, landingY )
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
-- blot is a tier's blot settings, state a key of its colors
function godHud.DrawBlot( blot, x, y, w, h, state )
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

-- 0 to 1, eased. Each order starts arrivalSettings.stagger later
function godHud.ArrivalProgress( openedAt, order, arrivalSettings )
    local startAt = openedAt + ( order * arrivalSettings.stagger )
    local progress = math.Clamp( ( CurTime() - startAt ) / arrivalSettings.time, 0, 1 )

    return 1 - ( ( 1 - progress ) ^ 3 )

end

-- Keeps jitterX and jitterY on whatever table you hand it, ready for a draw position to add.
-- Owns its own clock, a per frame reroll is a buzz nobody can see and it would shake harder
-- the better your hardware is. Safe to call every frame, it only rerolls when it's due.
function godHud.DoJitter( state )
    if state.nextJitter and state.nextJitter > CurTime() then return end

    local interval = godHud.jitterInterval
    state.nextJitter = CurTime() + math.Rand( interval[1], interval[2] )

    local pixels = godHud.jitterPixels
    state.jitterX = math.random( -pixels, pixels )
    state.jitterY = math.random( -pixels, pixels )

end

defineGodFonts()
defineHL2Fonts()
hook.Add( "glee_rebuildfonts", "glee_rebuild_defaultfonts", function()
    defineGodFonts()
    defineHL2Fonts()

end )