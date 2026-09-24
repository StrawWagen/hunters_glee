--[[
    glee_row — extends glee_panel

    One pickable line of a menu: a label at the left, a value at the right, and room
    between them for a child like a glee_meter. Its style draws it hovered, pressed and
    disabled, and it plays its style's switch and press sounds.

        local row = vgui.Create( "glee_row", parent )
        row:SetLabel( "Music volume" )
        row:SetValue( "0.5" )
        row:Dock( TOP )
        function row:DoClick() end
        function row:DoRightClick() end

    Its height comes from its font, and is redone on every style change. Its width is
    whatever docks it, GetContentWidth is how wide it would like to be.

    To line rows up into columns, give them all the widest SetLabelWidth among them, and
    SetReservedValue the widest value any of them will print.
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_panel" )

end

local PANEL = {}

PANEL.Init = function( self )
    self._label         = ""
    self._value         = ""
    self._labelWidth    = nil -- the label's own width
    self._reservedValue = nil
    self._middle        = nil
    self._middleMinWidth = 0

    self._hoveredBackdropColor = "bgUrgent"
    self._disabledContentColor = "text"

    self._pressDuration = 0.12
    self._pressedUntil  = 0
    self._wasHovered    = false

    self:SetMouseInputEnabled( true )
    self:SizeToFont()

end


-- Content -------------------------------------------------------------------

PANEL.SetLabel = function( self, label )
    self._label = label

end

PANEL.SetValue = function( self, value )
    self._value = value

end

PANEL.SetFont = function( self, fontRole )
    self._font = fontRole
    self:SizeToFont()

end

local function textWidth( font, text )
    surface.SetFont( font )
    return ( surface.GetTextSize( text ) )

end

-- The label column's width. nil goes back to the label's own
PANEL.SetLabelWidth = function( self, width )
    self._labelWidth = width
    self:InvalidateLayout()

end

PANEL.GetNaturalLabelWidth = function( self )
    return textWidth( self:GetResolvedFont(), self._label )

end

-- The value column is kept at least as wide as this text, so a value changing length
-- doesn't slide the middle child around
PANEL.SetReservedValue = function( self, text )
    self._reservedValue = text
    self:InvalidateLayout()

end

local function labelWidth( self )
    return self._labelWidth or self:GetNaturalLabelWidth()

end

local function valueWidth( self )
    local font = self:GetResolvedFont()
    return math.max( textWidth( font, self._value ), textWidth( font, self._reservedValue or "" ) )

end

-- Puts a child between the label and value columns, sized to fill the gap
PANEL.SetMiddle = function( self, panel, minWidth )
    panel:SetParent( self )
    self._middle = panel
    self._middleMinWidth = minWidth or 0
    self:InvalidateLayout()

end

PANEL.SizeToFont = function( self )
    local font = self:GetResolvedFont()
    self:SetTall( draw.GetFontHeight( font ) + self:GetTextPadding() * 2 )

end

PANEL.OnHudStyleChanged = function( self )
    self:SizeToFont()
    self:InvalidateLayout()

end

PANEL.GetContentWidth = function( self )
    local style = self:Style()
    local pad   = self:GetTextPadding()

    local between = style:Metric( "laneSpacing" )
    if self._middle then
        between = self._middleMinWidth + pad * 2

    end

    return pad * 4 + labelWidth( self ) + between + valueWidth( self )

end

PANEL.PerformLayout = function( self, w, h )
    local middle = self._middle
    if not IsValid( middle ) then return end

    local pad   = self:GetTextPadding()
    local left  = pad * 3 + labelWidth( self )
    local right = w - pad * 3 - valueWidth( self )

    middle:SetPos( left, pad )
    middle:SetSize( math.max( right - left, 0 ), h - pad * 2 )

end


-- Interaction ---------------------------------------------------------------

-- A role or a Color, for the backdrop while hovered or pressed
PANEL.SetHoveredBackdropColor = function( self, color )
    self._hoveredBackdropColor = color

end

-- A role or a Color, for the text while disabled
PANEL.SetDisabledContentColor = function( self, color )
    self._disabledContentColor = color

end

-- stubs
PANEL.DoClick = function( _self )
end

PANEL.DoRightClick = function( _self )
end

-- The press flash and sound. For an override of OnMousePressed that still wants to feel pressed
PANEL.ShowPress = function( self, soundSet, pitch )
    self._pressedUntil = CurTime() + self._pressDuration
    self:Style():PlaySound( soundSet or "press", pitch or 100, nil, 1 )

end

PANEL.OnMousePressed = function( self, mouseCode )
    if self:GetDisabled() then return end

    if mouseCode == MOUSE_LEFT then
        self:ShowPress()
        self:DoClick()

    elseif mouseCode == MOUSE_RIGHT then
        self:DoRightClick()

    end
end

PANEL.Think = function( self )
    local hovered = self:IsHovered()
    if hovered == self._wasHovered then return end

    self._wasHovered = hovered
    if self:GetDisabled() then return end

    local pitch = 80
    if hovered then
        pitch = 90

    end
    self:Style():PlaySound( "switch", pitch, nil, 0.14, 60 )

end

local function isPressed( self )
    return self._pressedUntil > CurTime()

end

PANEL.GetVisualState = function( self )
    if self:GetDisabled() then return "disabled" end
    if isPressed( self ) then return "pressed" end
    if self:IsHovered() then return "hovered" end

    return "idle"

end

PANEL.GetBackdropColor = function( self )
    local state = self:GetVisualState()
    if state == "hovered" or state == "pressed" then return self._hoveredBackdropColor end

    return baseClass().GetBackdropColor( self )

end

PANEL.GetContentColor = function( self )
    if self:GetDisabled() then return self._disabledContentColor end

    return baseClass().GetContentColor( self )

end


-- Paint ---------------------------------------------------------------------

-- contentColor is already faded
PANEL.PaintContent = function( self, w, h, contentColor )
    local font     = self:GetResolvedFont()
    local innerPad = self:GetTextPadding() * 2
    local midY     = h * 0.5

    draw.SimpleText( self._label, font, innerPad,     midY, contentColor, TEXT_ALIGN_LEFT,  TEXT_ALIGN_CENTER )
    draw.SimpleText( self._value, font, w - innerPad, midY, contentColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

end

vgui.Register( "glee_row", PANEL, "glee_panel" )
