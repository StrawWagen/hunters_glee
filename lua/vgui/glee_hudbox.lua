--[[
    glee_hudbox — extends glee_panel

    A glee_panel with the hud's display state machine. Callers set colours and state, the
    box does all its own fading.

    States:
        HIDDEN (0) - invisible, at once
        FADING (1) - holds for SetFadeStartDelay, then fades out and becomes HIDDEN
        NORMAL (2) - fully visible at once, never fades in
        FLASH  (3) - draws chosen for flashDuration seconds, then goes back to the last
                     other state asked for. SetState can't cut it short
        URGENT (4) - blinks between idle and chosen

    Chosen is the backdrop state, see handle:BackdropColor. While flashing the content
    is the flash role.

    Setup:
        local box = vgui.Create( "glee_hudbox", parent )
        box:SetIconSize( 48 )
        box:SetMaterial( mat )

        box:SetState( box.STATE_NORMAL )
        box:SetContentColor( "happy" )

        box:SetState( box.STATE_FLASH )   -- a one-off flash, then back to NORMAL
]]

local HIDDEN = 0
local FADING = 1
local NORMAL = 2
local FLASH  = 3
local URGENT = 4

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_panel" )

end


local PANEL = {
    STATE_HIDDEN = HIDDEN,
    STATE_FADING = FADING,
    STATE_NORMAL = NORMAL,
    STATE_FLASH  = FLASH,
    STATE_URGENT = URGENT,
}

PANEL.Init = function( self )
    self._state        = HIDDEN
    self._pendingState = HIDDEN
    self._stateAlpha   = 0

    self._flashDuration = 0.15
    self._flashExpiry   = 0

    self._urgentInterval  = 0.1
    self._urgentNextBlink = 0
    self._urgentBlink     = false

    self._doFadeDelays   = true
    self._fadeSpeed      = 120
    self._fadeStartDelay = 0
    self._fadeStartTime  = 0

    self._flashContentColor = "flash"

end

-- One of the STATE_ constants, see the top of this file
PANEL.SetState = function( self, state )
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
end

PANEL.GetState = function( self )
    return self._state

end

PANEL.GetPendingState = function( self )
    return self._pendingState

end

PANEL.GetStateAlpha = function( self )
    return self._stateAlpha

end

-- Content colour while in FLASH state. A role or a Color
PANEL.SetFlashContentColor = function( self, color )
    self._flashContentColor = color

end

-- Duration of a FLASH before returning to NORMAL.
PANEL.SetFlashDuration = function( self, dur )
    self._flashDuration = dur

end

-- False skips SetFadeStartDelay's hold, so FADING starts fading at once
PANEL.SetDoFadeDelays = function( self, doDelays )
    self._doFadeDelays = doDelays

end

-- Alpha lost per second while in FADING state, out of 255.
PANEL.SetFadeSpeed = function( self, speed )
    self._fadeSpeed = speed

end

-- Seconds FADING holds at full alpha before it starts to fade, counted from the last
-- frame the box was asked to stay
PANEL.SetFadeStartDelay = function( self, delay )
    self._fadeStartDelay = delay

end

-- Seconds between blink toggles while in URGENT state.
PANEL.SetUrgentInterval = function( self, interval )
    self._urgentInterval = interval

end

PANEL.Think = function( self )
    local state = self._state
    local cur   = CurTime()

    if state == FLASH and cur >= self._flashExpiry then
        self._state = self._pendingState
        state       = self._pendingState

    end

    -- a flash can't be cut short by the state asked for
    if state ~= FLASH then
        self._state = self._pendingState
        state       = self._state

    end

    if state == URGENT and cur >= self._urgentNextBlink then
        self._urgentNextBlink = cur + self._urgentInterval
        self._urgentBlink     = not self._urgentBlink

    end

    local goinAway

    if state == HIDDEN then
        goinAway = true
        self._stateAlpha = 0

    elseif state == FADING then
        goinAway = true
        -- _fadeStartDelay is never nil, it defaults to 0, so this check of it and the one
        -- below always pass
        if self._doFadeDelays and self._fadeStartDelay and self._fadeStartTime > cur then
            self._stateAlpha = 255

        else
            self._stateAlpha = math.max( 0, self._stateAlpha - self._fadeSpeed * FrameTime() )

            if self._stateAlpha <= 0 then
                self._state        = HIDDEN
                self._pendingState = HIDDEN

            end
        end
    else -- NORMAL, FLASH or URGENT
        self._stateAlpha = 255

    end

    if not goinAway and self._fadeStartDelay then
        self._fadeStartTime = cur + self._fadeStartDelay

    end

    self:AdditionalThink()

end

-- stub, called at the end of every Think for a caller's own per frame logic
PANEL.AdditionalThink = function( _self )
end

local function isBlinking( self )
    return self._state == URGENT and self._urgentBlink

end

PANEL.GetFade = function( self )
    return self._stateAlpha / 255

end

PANEL.GetVisualState = function( self )
    if self._state == FLASH or isBlinking( self ) then return "chosen" end

    return baseClass().GetVisualState( self )

end

PANEL.GetContentColor = function( self )
    if self._state == FLASH then return self._flashContentColor end

    return baseClass().GetContentColor( self )

end

vgui.Register( "glee_hudbox", PANEL, "glee_panel" )
