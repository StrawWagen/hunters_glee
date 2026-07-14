--[[
    glee_hl2meter — extends glee_hl2hudbox

    A chunked suit-power style bar, drawn inside the standard hud box.
    Inherits the box, colors, and state machine; only the chunks are new.

    Setup:
        local meter = vgui.Create( "glee_hl2meter", parent )
        meter:SetBarSize( 260, 10 )
        meter:SetChunks( 20 )
        meter:SetFillColor( color )
        meter:SetFill( 0.5 )                 -- 0-1
        meter:SetState( meter.STATE_NORMAL ) -- like any hudbox
]]

local PANEL = {}

PANEL.Init = function( self )
    self.BaseClass.Init( self )

    local hud = terminator_Extras.glee_HL2Hud

    self._chunks     = 20
    self._fill       = 0
    self._chunkGap   = glee_sizeScaled( nil, 3 )
    self._fillColor  = hud.colorHappyYellow
    self._emptyColor = hud.colorBackground

    self:SetBarSize( glee_sizeScaled( nil, 260 ), glee_sizeScaled( nil, 12 ) )

end

-- Sizes the bar; the box grows around it by the standard block padding.
PANEL.SetBarSize = function( self, barW, barH )
    local pad = terminator_Extras.glee_HL2Hud.blockPadding
    self:SetSize( barW + pad * 2, barH + pad * 2 )

end

-- Height only, leaving the width to whatever docks us. Paint derives the bar
-- from the panel's own width, so it doesn't need telling.
PANEL.SetBarHeight = function( self, barH )
    local pad = terminator_Extras.glee_HL2Hud.blockPadding
    self:SetTall( barH + pad * 2 )

end

PANEL.SetChunks = function( self, count )
    self._chunks = count

end

PANEL.SetFillColor = function( self, col )
    self._fillColor = col

end

PANEL.SetEmptyColor = function( self, col )
    self._emptyColor = col

end

PANEL.SetFill = function( self, fraction )
    self._fill = math.Clamp( fraction, 0, 1 )

end

PANEL.Paint = function( self, w, h )
    self.BaseClass.Paint( self, w, h ) -- the box; we set no mat/text so that is all it draws

    local stateAlpha = self:GetStateAlpha()
    if stateAlpha <= 0 then return end

    local pad    = terminator_Extras.glee_HL2Hud.blockPadding
    local barW   = w - pad * 2
    local barH   = h - pad * 2

    local chunks = self._chunks
    local lit    = math.Round( self._fill * chunks )
    local chunkW = barW / chunks
    local drawnW = math.max( 1, chunkW - self._chunkGap )

    for i = 1, chunks do
        local src = ( i <= lit ) and self._fillColor or self._emptyColor
        surface.SetDrawColor( src.r, src.g, src.b, src.a * stateAlpha / 255 )
        surface.DrawRect( pad + math.floor( ( i - 1 ) * chunkW ), pad, drawnW, barH )

    end
end

vgui.Register( "glee_hl2meter", PANEL, "glee_hl2hudbox" )
