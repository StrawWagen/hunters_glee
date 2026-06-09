--[[
    glee_hl2hudbox - A small HUD icon box with a built-in display state machine.

    Draws a rounded background with a centered material or text.
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
        self._iconSize     = math.Clamp( glee_sizeScaled( nil, 48 ), 0, terminator_Extras.hl2hud.iconMaxSize )
        self._paddingRatio = 0.4
        self._mat          = nil
        self._text         = nil
        self._font         = "DermaDefault"
        self._textPadding  = glee_sizeScaled( nil, 8 )
        self._cornerRadius = terminator_Extras.hl2hud.boxCornerRadius

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
        local hud            = terminator_Extras.hl2hud
        self._normalBoxColor = hud.colorBackground:Copy()
        self._flashBoxColor  = hud.colorBackgroundUrgent:Copy()
        self._urgentBoxColor = hud.colorBackgroundUrgent:Copy()
        self._iconColor      = hud.colorHappyYellow:Copy()
        self._flashIconColor = hud.colorRedUrgent:Copy()

        -- Cached draw colors (less memory churn)
        self._drawBox  = Color( 0, 0, 0, 0 )
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
        self._mat  = mat
        self._text = nil

    end,

    -- Sets text to draw centered. Clears any active material.
    SetText = function( self, text )
        self._text = text
        self._mat  = nil

    end,

    SetIconFont = function( self, font )
        self._font = font

    end,

    SetTextPadding = function( self, pad )
        self._textPadding = pad

    end,

    -- Resizes the panel to fit the current text string plus _textPadding on all sides.
    -- Call after SetText when the text content changes.
    AutoSize = function( self )
        if not self._text or #self._text == 0 then return end

        surface.SetFont( self._font )
        local fontHeight = draw.GetFontHeight( self._font )
        local maxWidth   = 0
        local lineCount  = 0

        for line in ( self._text .. "\n" ):gmatch( "([^\n]*)\n" ) do
            lineCount    = lineCount + 1
            local lw     = surface.GetTextSize( line )
            if lw > maxWidth then maxWidth = lw end

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

    SetFlashIconColor = function( self, col )
        self._flashIconColor = col

    end,

    -- Box color on blink frames while in URGENT state.
    SetUrgentBoxColor = function( self, col )
        self._urgentBoxColor = col

    end,

    -- Icon/text tint including alpha. Alpha is scaled by the current state alpha.
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

        -- Honor pending state (cannot interrupt an active flash)
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
        if state == FLASH then
            boxSrc = self._flashBoxColor

        elseif state == URGENT and self._urgentBlink then
            boxSrc = self._urgentBoxColor

        else
            boxSrc = self._normalBoxColor

        end

        local dBox = self._drawBox
        dBox.r = boxSrc.r
        dBox.g = boxSrc.g
        dBox.b = boxSrc.b
        dBox.a = math.floor( boxSrc.a * stateAlpha / 255 )

        draw.RoundedBox( self._cornerRadius, 0, 0, w, h, dBox )

        local iconSrc = self._iconColor
        if state == FLASH then
            iconSrc = self._flashIconColor
        end

        local dIcon   = self._drawIcon
        dIcon.r = iconSrc.r
        dIcon.g = iconSrc.g
        dIcon.b = iconSrc.b
        dIcon.a = math.floor( iconSrc.a * stateAlpha / 255 )

        local padding = self._overSize * 0.5

        if self._mat then
            surface.SetDrawColor( dIcon )
            surface.SetMaterial( self._mat )
            surface.DrawTexturedRect( padding, padding, self._iconSize, self._iconSize )

        elseif self._text and #self._text > 0 then
            local fontHeight = draw.GetFontHeight( self._font )
            local lines      = string.Explode( "\n", self._text )
            local totalH     = fontHeight * #lines
            local startY     = h * 0.5 - totalH * 0.5
            for i, line in ipairs( lines ) do
                draw.SimpleText( line, self._font, w * 0.5, startY + ( i - 1 ) * fontHeight, dIcon, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

            end
        end
    end,
}

vgui.Register( "glee_hl2hudbox", PANEL, "DPanel" )
