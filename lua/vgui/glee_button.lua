--[[
    glee_button — extends glee_row

    A glee_row only as wide as its own text, at the left of whatever width docks it, so it
    can be docked into a list without stretching across it. Hover, press, disabled and
    sounds are all glee_row's.

        local button = vgui.Create( "glee_button", parent )
        button:SetLabel( "I AGREE" )
        button:Dock( BOTTOM )
        function button:DoClick() end

    Clicks and hovers past the text's width fall through to whatever is behind it.
]]

local PANEL = {}

local function drawnWidth( self )
    return math.min( self:GetContentWidth(), self:GetWide() )

end

PANEL.TestHover = function( self, x, y )
    local localX, localY = self:ScreenToLocal( x, y )
    return localX >= 0 and localX < drawnWidth( self ) and localY >= 0 and localY < self:GetTall()

end

-- glee_panel's Paint, not glee_row's, which is only inherited. See glee_panel.lua for why
-- control tables are fetched at call time
PANEL.Paint = function( self, _w, h )
    vgui.GetControlTable( "glee_panel" ).Paint( self, drawnWidth( self ), h )

end

vgui.Register( "glee_button", PANEL, "glee_row" )
