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

    It sets its own height from its font, again on every style change. Its width is
    whatever docks it; GetContentWidth is what it would like.

    To line rows up into columns, give them all the same table of those rows through
    SetLabelColumn, and SetReservedValue the widest value any of them will print.
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_panel" )

end

local PANEL = {}

PANEL.Init = function( self )
    self._label         = ""
    self._value         = ""
    self._labelColumn   = nil
    self._reservedValue = nil
    self._middle        = nil
    self._middleMinWidth = 0

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

-- rows, this one included, share the widest label's width. Measured every layout, so a
-- style change can't leave it stale
PANEL.SetLabelColumn = function( self, rows )
    self._labelColumn = rows
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
    local column = self._labelColumn
    if not column then return self:GetNaturalLabelWidth() end

    local widest = 0
    for _, row in ipairs( column ) do
        if IsValid( row ) then
            widest = math.max( widest, row:GetNaturalLabelWidth() )

        end
    end

    return widest

end

local function valueWidth( self )
    local font = self:GetResolvedFont()
    return math.max( textWidth( font, self._value ), textWidth( font, self._reservedValue or "" ) )

end

-- Puts a child between the label and value columns, sized to fill the gap.
-- minWidth1080 is how narrow the gap may get, in 1080p pixels
PANEL.SetMiddle = function( self, panel, minWidth1080 )
    panel:SetParent( self )
    self._middle = panel
    self._middleMinWidth = minWidth1080 or 0
    panel.TestHover = function( _self, _x, _y ) -- let clicks passthru the middle
        return false

    end
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
        between = style:Scaled( self._middleMinWidth ) + pad * 2

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

-- A role or a Color, for the text while disabled
PANEL.SetDisabledContentColor = function( self, color )
    self._disabledContentColor = color

end

-- stubs. A disabled row doesn't call the clicks
PANEL.DoClick = function( _self )
end

PANEL.DoRightClick = function( _self )
end

-- called at the end of every Think
PANEL.AdditionalThink = function( _self )
end

-- The press flash and sound. For an override of OnMousePressed that still wants to feel
-- pressed. soundSet defaults to press, pitch to 100, volume to 1
PANEL.ShowPress = function( self, soundSet, pitch, volume )
    self._pressedUntil = CurTime() + self._pressDuration
    self:Style():PlaySound( soundSet or "press", pitch or 100, nil, volume or 1 )

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

local function playHoverSound( self, hovered )
    if self:GetDisabled() then return end

    local pitch = 80
    if hovered then
        pitch = 90

    end
    self:Style():PlaySound( "switch", pitch, nil, 0.14, 60 )

end

PANEL.Think = function( self )
    local hovered = self:IsHovered()
    if hovered ~= self._wasHovered then
        self._wasHovered = hovered
        playHoverSound( self, hovered )

    end

    self:AdditionalThink()

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
