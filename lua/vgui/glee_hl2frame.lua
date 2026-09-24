--[[
    glee_hl2frame — extends DFrame

    A DFrame with derma's window furniture turned off and an hl2 hud backdrop in its
    place, so a menu built out of glee_hl2hudboxes sits on a matching background.

    DFrame's Init leaves DockPadding( 5, 29, 5, 5 ) behind to clear a title bar this
    doesn't have, which pushes every docked child down by 29. This replaces it once, and
    is not fought over: DFrame's PerformLayout never touches padding again.

    easyClosePanel is left to the caller on purpose. It wraps the panel's Think at the
    moment it runs, so a caller that assigns frame.Think afterwards silently replaces the
    wrapper and loses click-off-to-close. Call it after your own Think, never before.

        local frame = vgui.Create( "glee_hl2frame" )
        frame:SetSize( w, h )
        frame:Center()
        terminator_Extras.easyClosePanel( frame )
]]

local PANEL = {}

-- vgui runs every Init in the chain, base first. Calling DFrame's again from here builds
-- a second set of title bar furniture, and only the set the accessors point at is hidden.
PANEL.Init = function( self )
    local hl2 = terminator_Extras.glee_Style( "hl2" )
    local pad = hl2:Metric( "blockPadding" )

    self:SetTitle( "" )
    self:ShowCloseButton( false )
    self:SetDraggable( false )
    self:MakePopup()
    self:DockPadding( pad, pad, pad, pad )

    self._backdrop     = hl2:Color( "bgDark" )
    self._cornerRadius = hl2:Metric( "boxCornerRadius" )

end

-- see glee_hud/cl_stylecontext.lua
PANEL.Style = function( self )
    return terminator_Extras.glee_PanelStyle( self )

end

PANEL.Paint = function( self, w, h )
    self:Style():Background( 0, 0, w, h, self._backdrop, self._cornerRadius )

end

vgui.Register( "glee_hl2frame", PANEL, "DFrame" )
