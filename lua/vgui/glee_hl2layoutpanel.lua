--[[
    glee_hl2layoutpanel — extends DPanel

    A panel that paints nothing and takes no mouse input. It exists to be docked into, so
    a dock pass has something full width to work with while the visible boxes inside it
    are only as big as their own contents.
]]

local PANEL = {}

PANEL.Init = function( self )
    -- DPanel's Init turns background painting on, and vgui runs it before this one
    self:SetPaintBackground( false )
    self:SetMouseInputEnabled( false )

end

vgui.Register( "glee_hl2layoutpanel", PANEL, "DPanel" )
