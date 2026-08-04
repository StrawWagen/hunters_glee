--[[
    glee_hl2hudheading — extends glee_hl2layoutpanel

    A section title: a box only as wide as its own text, at the left of a full width
    transparent row, so it can be docked into a list without stretching across it.

    It takes its height from the box and not the row, because a heading font taller than
    the row would have its rounded bottom clipped off square by the row's bounds.

        local heading = vgui.Create( "glee_hl2hudheading", parent )
        heading:SetFont( "glee_mediumLargeHL2Font" )
        heading:SetText( "GLEE" )
        heading:Dock( TOP )
]]

local PANEL = {}

PANEL.Init = function( self )
    self._box = vgui.Create( "glee_hl2hudbox", self )
    self._box:SetDoFadeDelays( false )
    self._box:SetPos( 0, 0 )
    self._box:SetState( self._box.STATE_NORMAL ) -- nothing ever changes it, so this holds

end

-- SetFont and SetText work in either order, and as often as you like: the box re-wraps
-- its text when the font changes, and both of them resize the row afterwards.
PANEL.SetFont = function( self, font )
    self._box:SetIconFont( font )
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

vgui.Register( "glee_hl2hudheading", PANEL, "glee_hl2layoutpanel" )
