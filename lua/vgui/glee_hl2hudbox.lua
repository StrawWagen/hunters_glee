--[[
    glee_hl2hudbox - A small HUD icon box with a built-in display state machine.

    Draws a background with a centered material or text, in the glee_HudHelpers.styles look named by
    ._myStyle. Colors and the font take a role ( "happy", "medium" ) to follow the style.
    All alpha management is internal. Callers only set colors and instruct state.

    States (HUDBOX_STATE_* globals):
        HIDDEN (0) - invisible; applied immediately
        FADING (1) - alpha decreasing toward zero, then transitions to HIDDEN
        NORMAL (2) - immediately visible at the color's own alpha; never fades in
        FLASH  (3) - edge-triggered; box shows flashBoxColor at full brightness,
                     auto-returns to NORMAL after flashDuration seconds; cannot be
                     interrupted by SetState until the flash completes
        URGENT (4) - level-triggered; box alternates between normalBoxColor and
                     urgentBoxColor at full brightness

    Every colour, the font, and the text padding default to the hl2 hud palette, so a
    caller only names what it wants different. The flash icon colour defaults to red, which
    the menus override to yellow.

    Icon color (SetIconColor) is set by the caller and may be updated every frame.
    The state alpha scales both the box and icon multiplicatively, so:
      - in NORMAL/FADING: effective alpha  = color.a * stateAlpha / 255
      - in FLASH/URGENT:  effective alpha  = color.a  (stateAlpha == 255)
    Semi-transparency in NORMAL state comes from the colors' own .a values.

    Setup:
        local box = vgui.Create( "glee_hl2hudbox" )
        box:SetPos( x, y )
        box:SetIconSize( 48 )
        box:SetPaddingRatio( 0.4 )
        box:SetMaterial( mat )
        box:SetNormalBoxColor( color )
        box:SetFlashBoxColor( color )
        box:SetUrgentBoxColor( color )

    Per-frame (in a hook):
        box:SetState( HUDBOX_STATE_NORMAL )  -- instruct desired state each frame
        box:SetIconColor( color )            -- update icon tint/alpha as needed

    Event-driven (called once):
        box:SetState( HUDBOX_STATE_FLASH )   -- trigger a flash
]]


-- State constants, accessible on every instance as box.STATE_HIDDEN etc.
local HIDDEN = 0
local FADING = 1
local NORMAL = 2
local FLASH  = 3
local URGENT = 4


local function syncSize( self )
    local overSize = self._iconSize * self._paddingRatio
    self._overSize = overSize
    local bgSize   = self._iconSize + overSize
    self:SetSize( bgSize, bgSize )

end


local PANEL = {
    STATE_HIDDEN = 0,
    STATE_FADING = 1,
    STATE_NORMAL = 2,
    STATE_FLASH  = 3,
    STATE_URGENT = 4,
    Init = function( self )
        local scaledIconSize = glee_sizeScaled( nil, 48 )
        self._iconSize       = math.min( scaledIconSize, terminator_Extras.glee_HL2Hud.iconMaxSize )
        self._paddingRatio = 0.4
        self._mat          = nil
        self._text         = nil
        self._rawText      = nil
        self._maxTextWidth = nil
        self._font         = "medium"
        self._textPadding  = glee_sizeScaled( nil, 8 )
        self._cornerRadius = terminator_Extras.glee_HL2Hud.boxCornerRadius
        self._myStyle      = "hl2"

        -- State machine
        self._state        = HIDDEN
        self._pendingState = HIDDEN
        self._stateAlpha   = 0

        -- Flash
        self._flashDuration = 0.15
        self._flashExpiry   = 0

        -- Urgent
        self._urgentInterval  = 0.1
        self._urgentNextBlink = 0
        self._urgentBlink     = false

        -- Fade
        self._doFadeDelays = true
        self._fadeSpeed = 2
        self._fadeStartDelay = 0
        self._fadeStartTime = 0

        -- Colors
        local hud            = terminator_Extras.glee_HL2Hud
        self._normalBoxColor = hud.colorBackground:Copy()
        self._flashBoxColor  = hud.colorBackgroundUrgent:Copy()
        self._urgentBoxColor = hud.colorBackgroundUrgent:Copy()
        self._iconColor      = "happy"
        self._flashIconColor = "flash"

        -- Cached draw color (less memory churn)
        self._drawIcon = Color( 0, 0, 0, 0 )

        syncSize( self )
        self:SetMouseInputEnabled( false )

    end,

    -- Sets the desired display state.
    -- FLASH is edge-triggered: starts a timed flash that cannot be interrupted until
    --   it expires, then the panel returns to NORMAL.
    -- HIDDEN is applied immediately.
    -- All other states are level-triggered: call every frame to hold the state.
    SetState = function( self, state )
        if state == FLASH then
            if self._state ~= FLASH then
                self._state       = FLASH
                self._flashExpiry = CurTime() + self._flashDuration

            end

        elseif state == HIDDEN then
            self._state        = HIDDEN
            self._pendingState = HIDDEN
            self._stateAlpha   = 0

        else
            self._pendingState = state

        end
    end,

    SetIconSize = function( self, size )
        self._iconSize = size
        syncSize( self )

    end,

    SetPaddingRatio = function( self, ratio )
        self._paddingRatio = ratio
        syncSize( self )

    end,

    -- Sets a material to draw centered. Clears any active text.
    SetMaterial = function( self, mat )
        self._mat     = mat
        self._text    = nil
        self._rawText = nil -- or SyncWrap brings the text back

    end,

    -- Sets text to draw centered. Clears any active material.
    -- Wrapped to SetMaxTextWidth if one is set.
    SetText = function( self, text )
        self._rawText = text
        self._mat     = nil
        self:WrapText()

    end,

    WrapText = function( self )
        local font = self:GetResolvedFont()
        self._wrappedInFont = font

        local text = self._rawText
        if text and self._maxTextWidth then
            text = terminator_Extras.glee_HudHelpers.WrapText( text, font, self._maxTextWidth )

        end
        self._text = text

    end,

    GetResolvedFont = function( self )
        return terminator_Extras.glee_HudHelpers.ResolveFont( self._myStyle, self._font )

    end,

    -- A style change swaps the font without a SetText
    SyncWrap = function( self )
        if self._wrappedInFont == self:GetResolvedFont() then return end

        self:WrapText()

    end,

    -- Wrap text at this pixel width. nil ( the default ) leaves text unwrapped.
    SetMaxTextWidth = function( self, width )
        self._maxTextWidth = width
        if not self._rawText then return end

        self:SetText( self._rawText )

    end,

    -- A role or a font name
    SetIconFont = function( self, font )
        self._font = font
        self:WrapText()

    end,

    SetTextPadding = function( self, pad )
        self._textPadding = pad

    end,

    -- Resizes the panel to fit the current text string plus _textPadding on all sides.
    -- Call after SetText when the text content changes.
    AutoSize = function( self )
        self:SyncWrap()
        if not self._text or #self._text == 0 then return end

        local font = self:GetResolvedFont()
        surface.SetFont( font )
        local fontHeight = draw.GetFontHeight( font )
        local maxWidth   = 0
        local lineCount  = 0

        for line in ( self._text .. "\n" ):gmatch( "([^\n]*)\n" ) do
            lineCount    = lineCount + 1
            local lineWidth = surface.GetTextSize( line )
            if lineWidth > maxWidth then maxWidth = lineWidth end

        end

        local pad = self._textPadding
        self:SetSize( maxWidth + pad * 4, fontHeight * lineCount + pad * 2 )

    end,

    -- Box color while in NORMAL or FADING state, and non-blink frames of URGENT.
    SetNormalBoxColor = function( self, col )
        self._normalBoxColor = col

    end,

    -- Box color while in FLASH state.
    SetFlashBoxColor = function( self, col )
        self._flashBoxColor = col

    end,

    -- A role or a Color
    SetFlashIconColor = function( self, col )
        self._flashIconColor = col

    end,

    -- Box color on blink frames while in URGENT state.
    SetUrgentBoxColor = function( self, col )
        self._urgentBoxColor = col

    end,

    -- A role or a Color. Its alpha is scaled by the state alpha.
    SetIconColor = function( self, col )
        self._iconColor = col

    end,

    SetCornerRadius = function( self, r )
        self._cornerRadius = r

    end,

    -- Duration of a FLASH before returning to NORMAL.
    SetFlashDuration = function( self, dur )
        self._flashDuration = dur

    end,

    SetDoFadeDelays = function( self, doDelays )
        self._doFadeDelays = doDelays

    end,

    -- Alpha units lost per frame while in FADING state.
    SetFadeSpeed = function( self, speed )
        self._fadeSpeed = speed

    end,

    SetFadeStartDelay = function( self, delay )
        self._fadeStartDelay = delay

    end,

    GetState = function( self )
        return self._state

    end,

    GetPendingState = function( self )
        return self._pendingState

    end,

    GetStateAlpha = function( self )
        return self._stateAlpha

    end,

    -- Seconds between blink toggles while in URGENT state.
    SetUrgentInterval = function( self, interval )
        self._urgentInterval = interval

    end,

    Think = function( self )
        local state = self._state
        local cur   = CurTime()

        -- Flash: check expiry, return to pending state
        if state == FLASH and cur >= self._flashExpiry then
            self._state = self._pendingState
            state       = self._pendingState

        end

        -- Honor pending state (cannot interrupt an active flash).
        -- Also fires when flash just expired above; harmlessly re-applies pendingState.
        if state ~= FLASH then
            self._state = self._pendingState
            state       = self._state

        end

        -- Urgent blink tick
        if state == URGENT and cur >= self._urgentNextBlink then
            self._urgentNextBlink = cur + self._urgentInterval
            self._urgentBlink     = not self._urgentBlink

        end

        local goinAway

        -- Advance state alpha
        if state == HIDDEN then
            goinAway = true
            self._stateAlpha = 0

        elseif state == FADING then
            goinAway = true
            -- Hold at full alpha until the configured fade-start delay elapses
            if self._doFadeDelays and self._fadeStartDelay and self._fadeStartTime > cur then
                self._stateAlpha = 255

            else
                self._stateAlpha = math.max( 0, self._stateAlpha - self._fadeSpeed )

                if self._stateAlpha <= 0 then
                    self._state        = HIDDEN
                    self._pendingState = HIDDEN

                end
            end
        elseif state == NORMAL then
            self._stateAlpha = 255

        else -- FLASH or URGENT
            self._stateAlpha = 255

        end

        if not goinAway and self._fadeStartDelay then
            self._fadeStartTime = cur + self._fadeStartDelay

        end

        self:AdditionalThink()

    end,

    -- stub
    AdditionalThink = function( _self )
    end,

    Paint = function( self, w, h )
        local stateAlpha = self._stateAlpha
        if stateAlpha <= 0 then return end

        local state = self._state

        -- Determine box color source for this frame
        local boxSrc
        local highlighted = true
        if state == FLASH then
            boxSrc = self._flashBoxColor

        elseif state == URGENT and self._urgentBlink then
            boxSrc = self._urgentBoxColor

        else
            boxSrc = self._normalBoxColor
            highlighted = false

        end

        self:PaintBackground( w, h, boxSrc, stateAlpha / 255, highlighted )

        local iconSrc = self._iconColor
        if state == FLASH then
            iconSrc = self._flashIconColor

        end
        iconSrc = terminator_Extras.glee_HudHelpers.ResolveColor( self._myStyle, iconSrc )

        -- cl_settingsmenu and the bank atm wrap Paint and draw their text in this
        local dIcon   = self._drawIcon
        dIcon.r = iconSrc.r
        dIcon.g = iconSrc.g
        dIcon.b = iconSrc.b
        dIcon.a = math.floor( iconSrc.a * stateAlpha / 255 )

        self:PaintContent( w, h, dIcon )

    end,

    -- color is unfaded. highlighted is true while flashing, or on an urgent blink
    PaintBackground = function( self, w, h, color, fade, highlighted )
        terminator_Extras.glee_HudHelpers.DrawBackground( self._myStyle, 0, 0, w, h, color, self._cornerRadius, fade, highlighted )

    end,

    -- iconColor is already faded
    PaintContent = function( self, w, h, iconColor )
        local padding = self._overSize * 0.5

        if self._mat then
            surface.SetDrawColor( iconColor )
            surface.SetMaterial( self._mat )
            surface.DrawTexturedRect( padding, padding, self._iconSize, self._iconSize )

        else
            self:SyncWrap()
            if not self._text or #self._text <= 0 then return end

            -- Center the text block vertically; each line steps down by fontHeight
            local font            = self:GetResolvedFont()
            local fontHeight      = draw.GetFontHeight( font )
            local lines           = string.Explode( "\n", self._text )
            local totalTextHeight = fontHeight * #lines
            local startY          = h * 0.5 - totalTextHeight * 0.5
            for i, line in ipairs( lines ) do
                draw.SimpleText( line, font, w * 0.5, startY + ( i - 1 ) * fontHeight, iconColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

            end
        end
    end,
}

vgui.Register( "glee_hl2hudbox", PANEL, "DPanel" )
