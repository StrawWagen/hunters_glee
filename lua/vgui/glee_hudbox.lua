--[[
    glee_hudbox — extends glee_panel

    A glee_panel with the hud's display state machine. All alpha management is internal,
    callers only set colours and instruct state.

    States:
        HIDDEN (0) - invisible; applied immediately
        FADING (1) - alpha decreasing toward zero, then transitions to HIDDEN
        NORMAL (2) - immediately visible at the color's own alpha; never fades in
        FLASH  (3) - edge-triggered; box shows flashBoxColor at full brightness,
                     auto-returns to NORMAL after flashDuration seconds; cannot be
                     interrupted by SetState until the flash completes
        URGENT (4) - level-triggered; box alternates between normalBoxColor and
                     urgentBoxColor at full brightness

    Every colour is a role, and defaults to one, so a caller only names what it wants
    different. The flash content colour defaults to the flash role.

    The state alpha scales both the box and the content multiplicatively, so:
      - in NORMAL/FADING: effective alpha  = color.a * stateAlpha / 255
      - in FLASH/URGENT:  effective alpha  = color.a  (stateAlpha == 255)
    Semi-transparency in NORMAL state comes from the colors' own .a values.

    Setup:
        local box = vgui.Create( "glee_hudbox", parent )
        box:SetIconSize( 48 )
        box:SetMaterial( mat )
        box:SetNormalBoxColor( "bg" )

    Per-frame (in a hook):
        box:SetState( box.STATE_NORMAL )  -- instruct desired state each frame
        box:SetContentColor( "happy" )    -- update tint as needed

    Event-driven (called once):
        box:SetState( box.STATE_FLASH )   -- trigger a flash
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
    self._fadeSpeed      = 2
    self._fadeStartDelay = 0
    self._fadeStartTime  = 0

    self._flashBoxColor     = "bgUrgent"
    self._urgentBoxColor    = "bgUrgent"
    self._flashContentColor = "flash"

end

-- Sets the desired display state.
-- FLASH is edge-triggered: starts a timed flash that cannot be interrupted until
--   it expires, then the panel returns to NORMAL.
-- HIDDEN is applied immediately.
-- All other states are level-triggered: call every frame to hold the state.
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

-- Box colour while in NORMAL or FADING state, and non-blink frames of URGENT. A role or a Color
PANEL.SetNormalBoxColor = function( self, color )
    self:SetBackdropColor( color )

end

-- Box colour while in FLASH state. A role or a Color
PANEL.SetFlashBoxColor = function( self, color )
    self._flashBoxColor = color

end

-- Box colour on blink frames while in URGENT state. A role or a Color
PANEL.SetUrgentBoxColor = function( self, color )
    self._urgentBoxColor = color

end

-- Content colour while in FLASH state. A role or a Color
PANEL.SetFlashContentColor = function( self, color )
    self._flashContentColor = color

end

-- Duration of a FLASH before returning to NORMAL.
PANEL.SetFlashDuration = function( self, dur )
    self._flashDuration = dur

end

PANEL.SetDoFadeDelays = function( self, doDelays )
    self._doFadeDelays = doDelays

end

-- Alpha units lost per frame while in FADING state.
PANEL.SetFadeSpeed = function( self, speed )
    self._fadeSpeed = speed

end

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
    else -- NORMAL, FLASH or URGENT
        self._stateAlpha = 255

    end

    if not goinAway and self._fadeStartDelay then
        self._fadeStartTime = cur + self._fadeStartDelay

    end

    self:AdditionalThink()

end

-- stub
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

PANEL.GetBackdropColor = function( self )
    if self._state == FLASH then return self._flashBoxColor end
    if isBlinking( self ) then return self._urgentBoxColor end

    return baseClass().GetBackdropColor( self )

end

PANEL.GetContentColor = function( self )
    if self._state == FLASH then return self._flashContentColor end

    return baseClass().GetContentColor( self )

end

vgui.Register( "glee_hudbox", PANEL, "glee_panel" )
