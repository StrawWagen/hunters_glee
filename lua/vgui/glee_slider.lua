--[[
    glee_slider — extends glee_row

    A row with a bar in the middle, dragged along to pick a number anywhere in its range.
    The label and value text are the caller's, like any row.

        local slider = vgui.Create( "glee_slider", parent )
        slider:SetLabel( "FM" )
        slider:SetRange( 0, 51 )
        slider:SetPosition( 12 )
        function slider:OnDragged( position ) end -- every move while held, unrounded
        function slider:OnReleased( position ) end
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_row" )

end

local BAR_MIN_W_1080P = 200

local PANEL = {}

PANEL.Init = function( self )
    self._min      = 0
    self._max      = 1
    self._position = 0
    self._dragging = false

    -- the row is the box, so the meter contributes the bar only
    local meter = vgui.Create( "glee_meter", self )
    meter:SetPaintBackground( false )
    meter:SetEmptyColor( "bgDark" )
    meter:SetFillColor( "happy" )
    meter:SetSmooth( true )
    meter:SetState( meter.STATE_NORMAL )
    self._meter = meter

    self:SetMiddle( meter, BAR_MIN_W_1080P )

end

-- stubs
PANEL.OnDragged = function( _self, _position )
end

PANEL.OnReleased = function( _self, _position )
end

PANEL.SetRange = function( self, min, max )
    self._min = min
    self._max = max
    self:SetPosition( self._position )

end

-- Clamped to the range. Doesn't call OnDragged
PANEL.SetPosition = function( self, position )
    self._position = math.Clamp( position, self._min, self._max )

    local span = self._max - self._min
    self._meter:SetFill( span > 0 and ( self._position - self._min ) / span or 0 )

end

PANEL.GetPosition = function( self )
    return self._position

end

PANEL.IsDragging = function( self )
    return self._dragging

end

-- For chunks, or another fill colour
PANEL.GetMeter = function( self )
    return self._meter

end

-- the meter insets its bar by blockPadding, so the ends of the range are the bar's ends
local function positionFromCursor( self )
    local meter = self._meter
    local pad   = meter:Style():Metric( "blockPadding" )
    local barW  = meter:GetWide() - pad * 2
    if barW <= 0 then return self._min end

    local cursorX  = meter:CursorPos()
    local fraction = math.Clamp( ( cursorX - pad ) / barW, 0, 1 )

    return self._min + fraction * ( self._max - self._min )

end

local function dragTo( self, position )
    if position == self._position then return end

    self:SetPosition( position )
    self:OnDragged( self._position )

end

-- a press starts a drag rather than being a click
PANEL.OnMousePressed = function( self, mouseCode )
    if mouseCode ~= MOUSE_LEFT then
        baseClass().OnMousePressed( self, mouseCode )
        return

    end

    if self:GetDisabled() then return end

    self:ShowPress()
    self._dragging = true
    self:MouseCapture( true ) -- so a drag that leaves the row still ends here
    dragTo( self, positionFromCursor( self ) )

end

PANEL.OnCursorMoved = function( self )
    if not self._dragging then return end

    dragTo( self, positionFromCursor( self ) )

end

PANEL.OnMouseReleased = function( self, mouseCode )
    if mouseCode ~= MOUSE_LEFT then return end
    if not self._dragging then return end

    self._dragging = false
    self:MouseCapture( false )
    self:OnReleased( self._position )

end

vgui.Register( "glee_slider", PANEL, "glee_row" )
