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
local styles = terminator_Extras.glee_HudStyles
local styleBase = terminator_Extras.glee_StyleBase

local styleHandle = {}
styleHandle.__index = styleHandle

local handles = {}

--[[---------------------------------------------------------
    terminator_Extras.glee_Style
    Gets the handle for a style.
    @param styleName: The name a style was registered under, like "hl2".
    @return: The handle. Shared, so keep one in a local forever.
--]]---------------------------------------------------------
function terminator_Extras.glee_Style( styleName )
    local handle = handles[styleName]
    if handle then return handle end

    handle = setmetatable( { styleName = styleName, drawData = {} }, styleHandle )
    handles[styleName] = handle

    return handle

end

local warned = {}

local function warnOnce( message )
    if warned[message] then return end

    warned[message] = true
    ErrorNoHaltWithStack( "glee_hud: " .. message .. "\n" )

end

--[[---------------------------------------------------------
    handle:Settings
    Gets the style's own table, for look data that has no method here.
    @return: The style table. Read tornStrip, blot, ghosts and the paddings off it.
--]]---------------------------------------------------------
function styleHandle:Settings()
    local style = styles[self.styleName]
    if style then return style end

    warnOnce( "no style named \"" .. self.styleName .. "\", drawing as hl2" )

    return styles.hl2

end

--[[---------------------------------------------------------
    handle:Font
    Turns a font role into a font name, for surface.SetFont and draw.SimpleText.
    @param fontRole: A key of the style's fontSizes or borrowedFonts, like "medium".
    @return: The font's name. An unknown role warns once and gives the medium role.
--]]---------------------------------------------------------
function styleHandle:Font( fontRole )
    local style = self:Settings()
    local font = style.fonts[fontRole]
    if font then return font end

    warnOnce( "style \"" .. style.styleName .. "\" has no font role \"" .. tostring( fontRole ) .. "\"" )

    return style.fonts.medium or styles.hl2.fonts.medium

end

--[[---------------------------------------------------------
    handle:Color
    Turns a colour role into the Color this style draws it in.
    @param colorRole: A key of the style's colors, like "text". A Color passes through.
    @return: The Color. An unknown role warns once and gives the text role.
--]]---------------------------------------------------------
function styleHandle:Color( colorRole )
    if not isstring( colorRole ) then return colorRole end

    local style = self:Settings()
    local color = style.colors[colorRole] or styleBase.colors[colorRole]
    if color then return color end

    warnOnce( "unknown colour role \"" .. colorRole .. "\"" )

    return style.colors.text or styleBase.colors.text

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
    local style = self:Settings()
    local data = self.drawData

    data.text = text
    data.font = self:Font( fontRole )
    data.textColor = self:Color( colorRole or "text" )
    data.shadowColor = self:Color( "shadow" )
    data.shadowOffsetX = style.shadowOffsetX
    data.shadowOffsetY = style.shadowOffsetY
    data.posX = x
    data.posY = y
    data.doCenter = doCenter

    surface.drawShadowedTextBetterData( data )

end

--[[---------------------------------------------------------
    handle:Background
    Draws a panel's backdrop the way this style does. A blot, a box, whatever it is.
    @param x, y, w, h: The panel's bounds.
    @param color: A Color, not a role. Unfaded, fade is applied to it here.
    @param cornerRadius: Defaults to the style's boxCornerRadius.
    @param fade: 0 to 1. Defaults to 1.
    @param highlighted: True while flashing or picked. Defaults to false.
    @return: None
--]]---------------------------------------------------------
function styleHandle:Background( x, y, w, h, color, cornerRadius, fade, highlighted )
    local style = self:Settings()

    style.background( x, y, w, h, color, cornerRadius or style.boxCornerRadius, fade or 1, highlighted or false )

end

-- Writes jitterX and jitterY onto state, for a draw position to add. Safe every frame,
-- it rerolls on its own clock. Only for styles with a jitter
function styleHandle:Jitter( state )
    hudHelpers.DoJitter( state, self:Settings().jitter )

end

-- One sound at random from the style's sounds[setName]. volume defaults to 0.5, level 75
function styleHandle:PlaySound( setName, pitch, channel, volume, level )
    hudHelpers.PlaySound( self:Settings().sounds[setName], pitch, channel, volume, level )

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
            shadowOffsetX = style.shadowOffsetX,
            shadowOffsetY = style.shadowOffsetY,
            doCenter = doCenter,
        },
        solidData = {
            shadowColor = shadowColor,
            shadowOffsetX = style.shadowOffsetX,
            shadowOffsetY = style.shadowOffsetY,
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
