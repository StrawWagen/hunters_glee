--[[
    glee_textentry — extends glee_panel

    A box to type into, drawn like a glee_row: hovered while the cursor is over it or
    it's being typed in, its text inset as far as a row's label. A DTextEntry inside it
    does the typing, caret and selection, in the style's colours.

        local search = vgui.Create( "glee_textentry", parent )
        search:SetPlaceholder( "Search..." )
        search:Dock( RIGHT )
        function search:OnChange( text ) end

    It sets its own height from its font, as a glee_row does. Its width is whatever docks
    or sizes it.
]]

-- vgui's TextEntry draws its text this far in from its own edge, and has no setter for it
local ENTRY_INSET_X = 3
local SELECTION_ALPHA = 60

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_panel" )

end

local PANEL = {}

PANEL.Init = function( self )
    self._placeholder    = ""
    self._selectionColor = Color( 0, 0, 0, 0 ) -- PaintEntry's scratch

    self:SetMouseInputEnabled( true )

    local entry = vgui.Create( "DTextEntry", self )
    entry:Dock( FILL )
    entry:SetUpdateOnType( true )
    self._entry = entry

    entry.OnValueChange = function( _, text )
        self:OnChange( text )

    end

    entry.Paint = function( _entry )
        self:PaintEntry( _entry )

    end

    self:SyncToStyle()

end

PANEL.SyncToStyle = function( self )
    local pad = self:GetTextPadding()
    local inset = math.max( pad * 2 - ENTRY_INSET_X, 0 )
    self:DockPadding( inset, 0, inset, 0 )

    local font = self:GetResolvedFont()
    self._entry:SetFont( font )
    self:SetTall( draw.GetFontHeight( font ) + pad * 2 )

end

PANEL.OnHudStyleChanged = PANEL.SyncToStyle

PANEL.SetFont = function( self, fontRole )
    baseClass().SetFont( self, fontRole )
    self:SyncToStyle()

end

-- Shown, in the disabled colour, while it's empty and not being typed in
PANEL.SetPlaceholder = function( self, text )
    self._placeholder = text

end

PANEL.GetText = function( self )
    return self._entry:GetText()

end

-- stub, called on every keystroke
PANEL.OnChange = function( _self, _text )
end

PANEL.GetVisualState = function( self )
    local entry = self._entry
    if entry:HasFocus() or entry:IsHovered() then return "hovered" end

    return baseClass().GetVisualState( self )

end

-- the entry draws the text, see PaintEntry
PANEL.PaintContent = function( _self )
end

PANEL.PaintEntry = function( self, entry )
    local style = self:Style()
    local textColor = style:Color( self:GetContentColor() )

    local selection = self._selectionColor
    selection.r = textColor.r
    selection.g = textColor.g
    selection.b = textColor.b
    selection.a = SELECTION_ALPHA

    local text = entry:GetText()
    if text == "" and not entry:HasFocus() then
        -- drawn as the entry's own text, the way derma's skin does, so it sits exactly where typing will
        entry:SetText( self._placeholder )
        entry:DrawTextEntryText( style:Color( "disabled" ), selection, textColor )
        entry:SetText( text )
        return

    end

    entry:DrawTextEntryText( textColor, selection, textColor )

end

vgui.Register( "glee_textentry", PANEL, "glee_panel" )
