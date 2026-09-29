--[[
    glee_meter — extends glee_hudbox

    A chunked suit-power style bar, drawn inside a hud box. Only the bar is new.

    Chunks only tell the truth when there is one per step of whatever they show.
    SetSmooth( true ) draws one unbroken bar instead, for finer values.

        local meter = vgui.Create( "glee_meter", parent )
        meter:SetBarSize( 260, 10 )          -- pixels
        meter:SetChunks( 20 )
        meter:SetFill( 0.5 )                 -- 0-1
        meter:SetState( meter.STATE_NORMAL ) -- like any hudbox
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_hudbox" )

end

local CHUNK_GAP_1080P = 3

local PANEL = {}

PANEL.Init = function( self )
    local style = self:Style()

    self._chunks     = 20
    self._smooth     = false
    self._fill       = 0
    self._fillColor  = "happy"
    self._emptyColor = "bg"

    self:SetBarSize( style:Scaled( 260 ), style:Scaled( 12 ) )

end

-- The bar's size in pixels, the box grows around it by blockPadding
PANEL.SetBarSize = function( self, barW, barH )
    local pad = self:Style():Metric( "blockPadding" )
    self:SetSize( barW + pad * 2, barH + pad * 2 )

end

-- Height only, leaving the width to whatever docks us. Paint derives the bar
-- from the panel's own width, so it doesn't need telling.
PANEL.SetBarHeight = function( self, barH )
    local pad = self:Style():Metric( "blockPadding" )
    self:SetTall( barH + pad * 2 )

end

PANEL.SetChunks = function( self, count )
    self._chunks = count

end

-- One unbroken bar, for values too fine for a chunk each
PANEL.SetSmooth = function( self, smooth )
    self._smooth = smooth

end

-- A colour role or a Color, for the lit part of the bar
PANEL.SetFillColor = function( self, color )
    self._fillColor = color

end

-- A backdrop family, like "bgDark", or a Color, for the unlit part of the bar
PANEL.SetEmptyColor = function( self, family )
    self._emptyColor = family

end

PANEL.SetFill = function( self, fraction )
    self._fill = math.Clamp( fraction, 0, 1 )

end

PANEL.Paint = function( self, w, h )
    baseClass().Paint( self, w, h ) -- the box; we set no mat/text so that is all it draws

    local stateAlpha = self:GetStateAlpha()
    if stateAlpha <= 0 then return end

    local style  = self:Style()
    local pad    = style:Metric( "blockPadding" )
    local barW   = w - pad * 2
    local barH   = h - pad * 2
    local fill   = style:Color( self._fillColor )
    local empty  = style:BackdropColor( self._emptyColor )

    if self._smooth then
        surface.SetDrawColor( empty.r, empty.g, empty.b, empty.a * stateAlpha / 255 )
        surface.DrawRect( pad, pad, barW, barH )

        surface.SetDrawColor( fill.r, fill.g, fill.b, fill.a * stateAlpha / 255 )
        surface.DrawRect( pad, pad, math.Round( barW * self._fill ), barH )

        return

    end

    local chunks = self._chunks
    local lit    = math.Round( self._fill * chunks )
    local chunkW = barW / chunks
    local drawnW = math.max( 1, chunkW - style:Scaled( CHUNK_GAP_1080P ) )

    for i = 1, chunks do
        local src = ( i <= lit ) and fill or empty
        surface.SetDrawColor( src.r, src.g, src.b, src.a * stateAlpha / 255 )
        surface.DrawRect( pad + math.floor( ( i - 1 ) * chunkW ), pad, drawnW, barH )

    end
end

vgui.Register( "glee_meter", PANEL, "glee_hudbox" )
