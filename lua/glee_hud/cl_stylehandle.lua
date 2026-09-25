--[[------------------------------------
    Style handles: the only way anything outside glee_hud uses a style.

        local decree = terminator_Extras.glee_Style( "godlyDecree" )
        decree:Draw( "Welcome.", "huge", x, y, "text" )

    A handle is NOT the style table. It has no colors and no fonts on it, so handle.colors
    is nil. handle:Color and handle:Font turn a role name into one.

    Everything is named by role, so swapping a panel's style changes its look and nothing
    else. Text arguments run in draw.SimpleText's order.
--]]-------------------------------------

local hudHelpers = terminator_Extras.glee_HudHelpers
local builtStyles = terminator_Extras.glee_BuiltStyles

local styleHandle = {}
styleHandle.__index = styleHandle

local handles = {}

--[[---------------------------------------------------------
    terminator_Extras.glee_Style
    Gets the handle for a style at a scale.
    @param styleName: The name a style was registered under, like "hl2".
    @param scaleName: The name a scale was registered under. Defaults to "fixed".
    @return: The handle. Shared, and it outlives rebuilds, so keep one in a local forever.
--]]---------------------------------------------------------
function terminator_Extras.glee_Style( styleName, scaleName )
    scaleName = scaleName or "fixed"

    handles[scaleName] = handles[scaleName] or {}
    local handle = handles[scaleName][styleName]
    if handle then return handle end

    handle = setmetatable( { styleName = styleName, scaleName = scaleName, drawData = {} }, styleHandle )
    handles[scaleName][styleName] = handle

    return handle

end

local warned = {}

local function warnOnce( message )
    if warned[message] then return end

    warned[message] = true
    ErrorNoHaltWithStack( "glee_hud: " .. message .. "\n" )

end

terminator_Extras.glee_HudStyleAliases = terminator_Extras.glee_HudStyleAliases or {}
local aliases = terminator_Extras.glee_HudStyleAliases

--[[---------------------------------------------------------
    terminator_Extras.glee_RegisterStyleAlias
    Adds a style name that stands for whichever real style fits right now, like generic.
    Handles by that name follow it as it changes; see cl_stylecontext.lua for how panels
    hear that it did.
    @param aliasName: The name handles and panels will ask for.
    @param resolve: Returns a registered style's name. Called on every draw, so keep it cheap.
    @return: None
--]]---------------------------------------------------------
function terminator_Extras.glee_RegisterStyleAlias( aliasName, resolve )
    aliases[aliasName] = resolve

end

-- The registered style this handle draws as right now. Its own name, unless that's an alias
function styleHandle:ResolvedName()
    local resolve = aliases[self.styleName]
    if resolve then return resolve() end

    return self.styleName

end

--[[---------------------------------------------------------
    handle:Settings
    Gets the built style, for look data that has no method here.
    @return: The built style, see cl_stylebuild.lua. Read tornStrip, blot, ghosts and
        fontSizes off it. Every rebuild replaces it, and an alias's changes with the
        player, so get it where you use it rather than keeping it.
--]]---------------------------------------------------------
function styleHandle:Settings()
    local styleName = self:ResolvedName()

    local byScale = builtStyles[styleName]
    if not byScale then
        warnOnce( "no style named \"" .. styleName .. "\", drawing as hl2" )
        byScale = builtStyles.hl2

    end

    local built = byScale[self.scaleName]
    if built then return built end

    warnOnce( "no scale named \"" .. self.scaleName .. "\", drawing at fixed" )

    return byScale.fixed

end

--[[---------------------------------------------------------
    handle:Font
    Turns a font role into a font name, for surface.SetFont and draw.SimpleText.
    @param fontRole: A key of the style's fonts, like "medium".
    @return: The font's name. An unknown role warns once and gives the medium role.
--]]---------------------------------------------------------
function styleHandle:Font( fontRole )
    local style = self:Settings()
    local font = style.fonts[fontRole]
    if font then return font end

    warnOnce( "style \"" .. style.styleName .. "\" has no font role \"" .. tostring( fontRole ) .. "\"" )

    return style.fonts.medium or builtStyles.hl2.fixed.fonts.medium

end

--[[---------------------------------------------------------
    handle:Color
    Turns a colour role into the Color this style draws it in.
    @param colorRole: A key of the style's colors, like "text". A Color passes through.
    @return: The Color. Shared by everything drawing that role, so copy it before
        writing to it. An unknown role warns once and gives the text role.
--]]---------------------------------------------------------
function styleHandle:Color( colorRole )
    if not isstring( colorRole ) then return colorRole end

    local colors = self:Settings().colors
    local color = colors[colorRole]
    if color then return color end

    warnOnce( "unknown colour role \"" .. colorRole .. "\"" )

    return colors.text

end

-- 1080p pixels in this scale's pixels, rounded. For sizes too local to be a metric
function styleHandle:Scaled( pixels1080 )
    return math.Round( glee_sizeScaledExact( nil, pixels1080 ) * self:Settings().scale )

end

-- A length off the style's metrics, like "blockPadding", in this scale's pixels
function styleHandle:Metric( metricName )
    local metric = self:Settings().metrics[metricName]
    if metric then return metric end

    warnOnce( "unknown metric \"" .. tostring( metricName ) .. "\"" )

    return 0

end

-- Width and height of text in this style, every line of it counted
function styleHandle:Measure( text, fontRole )
    return hudHelpers.MeasureText( text, self:Font( fontRole ) )

end

-- The same text with newlines added to fit maxWidth. A longer word overflows
function styleHandle:Wrap( text, fontRole, maxWidth )
    return hudHelpers.WrapText( text, self:Font( fontRole ), maxWidth )

end

--[[---------------------------------------------------------
    handle:Draw
    Draws text in this style, with its shadow. Allocates nothing.
    @param text: The string to draw, newlines and all.
    @param fontRole: Which font role to draw it in.
    @param x: The middle of the text, or its left if doCenter is false.
    @param y: The top of the first line.
    @param colorRole: A colour role, or a Color. Defaults to the text role.
    @param doCenter: False to draw rightwards from x. Defaults to true.
    @return: None
--]]---------------------------------------------------------
function styleHandle:Draw( text, fontRole, x, y, colorRole, doCenter )
    local metrics = self:Settings().metrics
    local data = self.drawData

    data.text = text
    data.font = self:Font( fontRole )
    data.textColor = self:Color( colorRole or "text" )
    data.shadowColor = self:Color( "shadow" )
    data.shadowOffsetX = metrics.shadowOffsetX
    data.shadowOffsetY = metrics.shadowOffsetY
    data.posX = x
    data.posY = y
    data.doCenter = doCenter

    surface.drawShadowedTextBetterData( data )

end

local stateSuffixes = {
    idle     = "",
    hovered  = "Hovered",
    pressed  = "Pressed",
    chosen   = "Chosen",
    disabled = "Disabled",
}

--[[---------------------------------------------------------
    handle:BackdropColor
    The colour a backdrop family draws in for a state, the family's role with the state
    on the end: bg idle is bg, bg hovered is bgHovered. See hl2's colors.
    @param family: "bg" or "bgDark". A Color passes through, whatever the state.
    @param state: "idle", "hovered", "pressed", "chosen" or "disabled". Defaults to idle.
    @return: The Color.
--]]---------------------------------------------------------
function styleHandle:BackdropColor( family, state )
    if not isstring( family ) then return family end

    return self:Color( family .. stateSuffixes[state or "idle"] )

end

--[[---------------------------------------------------------
    handle:Background
    Draws a panel's backdrop the way this style does. A box, a blot, a torn strip, all in
    the colour BackdropColor gives for the family and state.
    @param x, y, w, h: The panel's bounds.
    @param family: "bg" or "bgDark", or a Color. Unfaded, fade is applied here. Defaults to bg.
    @param cornerRadius: Defaults to the style's boxCornerRadius metric.
    @param fade: 0 to 1. Defaults to 1.
    @param state: "idle", "hovered", "pressed", "chosen" or "disabled". Defaults to idle.
    @param cache: A table that lives as long as the backdrop, the panel itself usually.
        A shape that has to hold still between frames, like a torn strip, is kept on it.
    @return: None
--]]---------------------------------------------------------
function styleHandle:Background( x, y, w, h, family, cornerRadius, fade, state, cache )
    local style = self:Settings()

    style.background(
        style, x, y, w, h,
        self:BackdropColor( family or "bg", state ),
        cornerRadius or style.metrics.boxCornerRadius,
        fade or 1,
        cache
    )

end

-- Writes jitterX and jitterY onto state, for a draw position to add. Safe every frame,
-- it rerolls on its own clock. Only for styles with a jitter
function styleHandle:Jitter( state )
    hudHelpers.DoJitter( state, self:Settings().jitter )

end

-- One sound at random from the style's sounds[setName]. volume defaults to 0.5, level 75.
-- A set the style doesn't have warns once and plays nothing
function styleHandle:PlaySound( setName, pitch, channel, volume, level )
    local sounds = self:Settings().sounds[setName]
    if not sounds then
        warnOnce( "style \"" .. self.styleName .. "\" has no sound set \"" .. tostring( setName ) .. "\"" )
        return

    end

    hudHelpers.PlaySound( sounds, pitch, channel, volume, level )

end


--[[------------------------------------
    Arriving text: a message that spirals in out of faint ghosts and settles.

        local line = decree:NewArrival( "huge" )
        line:SetText( "Welcome.\nTo the hunt!" )

        local appeared, justLanded = line:Update( elapsed )
        line:Draw( x, y )

    appeared and justLanded fire once, as sound cues. Whether it landed already is .landed.

    The caller owns the clock. elapsed is seconds since this text started arriving: wall
    time for text on a schedule, or your own accumulated delta for text that must not
    advance while the window is minimised.
--]]-------------------------------------

local arrivingText = {}
arrivingText.__index = arrivingText

--[[---------------------------------------------------------
    handle:NewArrival
    Builds one arriving message. Make it once and keep it, it holds the animation.
    @param fontRole: Which font role the text lands in.
    @param ghostRole: Which ghosts settings to spiral in with. Defaults to fontRole.
    @param doCenter: False to draw rightwards from x. Defaults to true.
    @return: The arrival, to call SetText, Update and Draw on.
--]]---------------------------------------------------------
function styleHandle:NewArrival( fontRole, ghostRole, doCenter )
    local style = self:Settings()

    -- a style with no ghosts under that role lands its text at once instead
    local ghostSettings = style.ghosts and style.ghosts[ghostRole or fontRole]

    local shadowColor = self:Color( "shadow" )
    local metrics = style.metrics

    -- DrawGhosts writes these alphas, so they can't be the style's own colours
    local ghostTextColor = Color( 255, 255, 255, 255 )
    local ghostShadowColor = ColorAlpha( shadowColor, 255 )

    return setmetatable( {
        style = self,
        fontRole = fontRole,
        ghostSettings = ghostSettings,

        materialised = 0,
        landed = false,

        ghostTextColor = ghostTextColor,
        ghostData = {
            textColor = ghostTextColor,
            shadowColor = ghostShadowColor,
            shadowOffsetX = metrics.shadowOffsetX,
            shadowOffsetY = metrics.shadowOffsetY,
            doCenter = doCenter,
        },
        solidData = {
            shadowColor = shadowColor,
            shadowOffsetX = metrics.shadowOffsetX,
            shadowOffsetY = metrics.shadowOffsetY,
            doCenter = doCenter,
        },
    }, arrivingText )

end

-- Keeps the text, replays the animation
function arrivingText:Restart()
    self.ghosts = self.ghostSettings and hudHelpers.BuildGhosts( self.ghostSettings )
    self.materialised = 0
    self.landed = false

end

-- Only new words arrive, so a panel may set this every layout pass
function arrivingText:SetText( text )
    if self.text == text then return end

    self.text = text
    self:Restart()

end

--[[---------------------------------------------------------
    arrival:Update
    Advances the animation. Call it every frame the text is on screen.
    @param elapsed: Seconds since this text started arriving.
    @return: How many ghosts appeared this call, and whether it landed this call.
--]]---------------------------------------------------------
function arrivingText:Update( elapsed )
    if not self.text then return 0, false end

    local ghostSettings = self.ghostSettings
    if ghostSettings then
        local appeared = hudHelpers.AdvanceGhosts( self.ghosts, elapsed, ghostSettings )
        self.materialised = hudHelpers.GhostsMaterialised( elapsed, ghostSettings )

        if self.materialised < 1 or self.landed then return appeared, false end

        self.landed = true
        return appeared, true

    end

    self.materialised = 1
    if self.landed then return 0, false end

    self.landed = true
    return 0, true

end

--[[---------------------------------------------------------
    arrival:Draw
    Draws the ghosts still on their way in, then the text behind them.
    @param x: The middle of the text, or its left if doCenter was false.
    @param y: The top of the first line.
    @param colorRole: A colour role, or a Color. Defaults to the text role.
    @return: None
--]]---------------------------------------------------------
function arrivingText:Draw( x, y, colorRole )
    if not self.text then return end

    local textColor = self.style:Color( colorRole or "text" )
    local font = self.style:Font( self.fontRole )

    local ghostTextColor = self.ghostTextColor
    ghostTextColor.r, ghostTextColor.g, ghostTextColor.b = textColor.r, textColor.g, textColor.b

    local ghostData = self.ghostData
    ghostData.text = self.text
    ghostData.font = font

    local solidData = self.solidData
    solidData.text = self.text
    solidData.font = font
    solidData.textColor = textColor

    hudHelpers.DrawArrivingText( self.ghosts, self.ghostSettings, ghostData, solidData, x, y, self.materialised )

end
