--[[
    glee_hl2hudscrollpanel — extends DScrollPanel

    A DScrollPanel whose bar is painted in the hl2 hud palette instead of derma's grey, so
    a scrolling list can sit inside a glee_hl2frame without the bar giving it away.

    Nothing else changes: dock it and add to it exactly like a DScrollPanel.

        local scroll = vgui.Create( "glee_hl2hudscrollpanel", frame )
        scroll:Dock( FILL )
]]

local PANEL = {}

-- vgui runs every Init in the chain, base first, so the canvas and the bar already exist.
-- Calling DScrollPanel's again from here builds a second pair, and rows added afterwards
-- land in whichever canvas the accessors stopped pointing at.
PANEL.Init = function( self )
    local hud = terminator_Extras.glee_HL2Hud
    local bar = self:GetVBar()

    -- hiding the buttons zeroes the track they reserved as well, so the grip becomes the
    -- whole bar and neither button needs a paint of its own
    bar:SetHideButtons( true )
    bar:SetWide( hud.blockPadding * 2 )

    -- DVScrollBar is built on a raw Panel and never disables the engine's own background
    -- drawing, so its Paint returns true to suppress it. A replacement has to as well.
    bar.Paint = function( _bar, w, h )
        draw.RoundedBox( hud.boxCornerRadius, 0, 0, w, h, hud.colorBackground )
        return true

    end

    -- the grip is a DPanel underneath, which turns engine drawing off in its own Init
    bar.btnGrip.Paint = function( _grip, w, h )
        draw.RoundedBox( hud.boxCornerRadius, 0, 0, w, h, hud.colorHappyYellow )

    end
end

vgui.Register( "glee_hl2hudscrollpanel", PANEL, "DScrollPanel" )
