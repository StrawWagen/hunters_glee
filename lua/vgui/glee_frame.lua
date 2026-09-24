--[[
    glee_frame — extends DFrame

    A DFrame with derma's window furniture turned off and its style's backdrop in its
    place, so a menu built out of glee panels sits on a matching background.

    DFrame's Init leaves DockPadding( 5, 29, 5, 5 ) behind to clear a title bar this
    doesn't have, which pushes every docked child down by 29. This replaces it with the
    style's blockPadding, and again on every style change, since the scale sets how big
    that is. DFrame's PerformLayout never touches padding.

    easyClosePanel is left to the caller on purpose. It wraps the panel's Think at the
    moment it runs, so a caller that assigns frame.Think afterwards silently replaces the
    wrapper and loses click-off-to-close. Call it after your own Think, never before.

        local frame = vgui.Create( "glee_frame" )
        frame:SetSize( w, h )
        frame:Center()
        terminator_Extras.easyClosePanel( frame )
]]

local PANEL = {}

-- vgui runs every Init in the chain, base first. Calling DFrame's again from here builds
-- a second set of title bar furniture, and only the set the accessors point at is hidden.
PANEL.Init = function( self )
    self:SetTitle( "" )
    self:ShowCloseButton( false )
    self:SetDraggable( false )
    self:MakePopup()

    self._backdropColor = "bgDark"
    self._padContents   = true

    self:ApplyPadding()

end

-- see glee_hud/cl_stylecontext.lua
PANEL.Style = function( self )
    return terminator_Extras.glee_PanelStyle( self )

end

-- False for contents that bring their own padding
PANEL.SetPadContents = function( self, padContents )
    self._padContents = padContents
    self:ApplyPadding()

end

PANEL.ApplyPadding = function( self )
    local pad = 0
    if self._padContents then
        pad = self:Style():Metric( "blockPadding" )

    end

    self:DockPadding( pad, pad, pad, pad )

end

PANEL.OnHudStyleChanged = PANEL.ApplyPadding

PANEL.Paint = function( self, w, h )
    self:Style():Background( 0, 0, w, h, self._backdropColor, nil, 1, "idle", self )

end

vgui.Register( "glee_frame", PANEL, "DFrame" )
