--[[
    glee_heading — extends glee_panel

    A section title: a box only as wide as its own text, at the left of a full width
    transparent row, so it can be docked into a list without stretching across it.

    It takes its height from the box and not the row, because a heading font taller than
    the row would have its rounded bottom clipped off square by the row's bounds.

        local heading = vgui.Create( "glee_heading", parent )
        heading:SetFont( "mediumLarge" )
        heading:SetText( "GLEE" )
        heading:Dock( TOP )
]]

local PANEL = {}

PANEL.Init = function( self )
    self:SetPaintBackground( false )

    self._box = vgui.Create( "glee_panel", self )
    self._box:SetPos( 0, 0 )

end

-- Takes a font role, like "mediumLarge". SetFont and SetText work in either order, and
-- as often as you like: the box re-wraps its text when the font changes, and both of
-- them resize the row afterwards.
PANEL.SetFont = function( self, fontRole )
    self._box:SetFont( fontRole )
    self:SizeToBox()

end

PANEL.SetText = function( self, text )
    self._box:SetText( text )
    self:SizeToBox()

end

PANEL.SizeToBox = function( self )
    self._box:AutoSize()
    self:SetTall( self._box:GetTall() )

end

PANEL.OnHudStyleChanged = PANEL.SizeToBox

vgui.Register( "glee_heading", PANEL, "glee_panel" )
