--[[
    glee_scrollpanel — extends DScrollPanel

    A DScrollPanel whose bar is painted in its style instead of derma's grey, so a
    scrolling list can sit inside a glee_frame without the bar giving it away.

    Nothing else changes: dock it and add to it exactly like a DScrollPanel.

        local scroll = vgui.Create( "glee_scrollpanel", frame )
        scroll:Dock( FILL )
]]

local PANEL = {}

-- vgui runs every Init in the chain, base first, so the canvas and the bar already exist.
-- Calling DScrollPanel's again from here builds a second pair, and rows added afterwards
-- land in whichever canvas the accessors stopped pointing at.
PANEL.Init = function( self )
    local bar = self:GetVBar()

    -- hiding the buttons zeroes the track they reserved as well, so the grip becomes the
    -- whole bar and neither button needs a paint of its own
    bar:SetHideButtons( true )

    -- DVScrollBar is built on a raw Panel and never disables the engine's own background
    -- drawing, so its Paint returns true to suppress it. A replacement has to as well.
    bar.Paint = function( _bar, w, h )
        self:Style():Background( 0, 0, w, h, "bg", nil, 1, "idle", _bar )
        return true

    end

    -- the grip is a DPanel underneath, which turns engine drawing off in its own Init
    bar.btnGrip.Paint = function( _grip, w, h )
        local style = self:Style()
        draw.RoundedBox( style:Metric( "boxCornerRadius" ), 0, 0, w, h, style:Color( "happy" ) )

    end

    self:SizeBar()

end

-- see glee_hud/cl_stylecontext.lua
PANEL.Style = function( self )
    return terminator_Extras.glee_PanelStyle( self )

end

PANEL.SizeBar = function( self )
    self:GetVBar():SetWide( self:Style():Metric( "blockPadding" ) * 2 )

end

PANEL.OnHudStyleChanged = PANEL.SizeBar

vgui.Register( "glee_scrollpanel", PANEL, "DScrollPanel" )
