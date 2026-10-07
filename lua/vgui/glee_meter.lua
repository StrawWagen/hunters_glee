--[[
    glee_meter — extends glee_hudbox

    A chunked suit-power style bar, drawn inside a hud box. Only the bar is new.

    Chunks only tell the truth when there is one per step of whatever they show.
    SetSmooth( true ) draws one unbroken bar instead, for finer values.

        local meter = vgui.Create( "glee_meter", parent )
        meter:SetBarSize( 260, 10 )          -- pixels
        meter:SetChunks( 20 )
        meter:SetFill( 0.5 )                 -- 0-1
        meter:SetRounding( meter.ROUND_UP )  -- how a fill between chunks lights, ROUND by default
        meter:SetLostFlash( "damaged", 0.4 )  -- optional, chunks a SetFill drops light up a moment
        meter:SetState( meter.STATE_NORMAL ) -- like any hudbox
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_hudbox" )

end

local CHUNK_GAP_1080P = 3

local ROUND      = 0
local ROUND_UP   = 1 -- any fill at all lights a chunk, for things that are alive until 0
local ROUND_DOWN = 2 -- a chunk lights only once it's full

local PANEL = {
    ROUND      = ROUND,
    ROUND_UP   = ROUND_UP,
    ROUND_DOWN = ROUND_DOWN,
}

PANEL.Init = function( self )
    local style = self:Style()

    self._rounding   = ROUND
    self._chunks     = 20
    self._smooth     = false
    self._fill       = 0
    self._fillColor  = "happy"
    self._emptyColor = "bg"

    self._lostColor    = nil
    self._lostDuration = 0
    self._lostFrom     = 0 -- lit chunks before the drop being shown
    self._lostUntil    = 0

    self:SetBarSize( style:Scaled( 260 ), style:Scaled( 12 ) )

end

-- float error would otherwise light or drop a chunk exactly on a boundary
local boundaryTolerance = 0.0001

local function litChunks( self, fraction )
    local exact = fraction * self._chunks

    if self._rounding == ROUND_UP then
        return math.ceil( exact - boundaryTolerance )

    elseif self._rounding == ROUND_DOWN then
        return math.floor( exact + boundaryTolerance )

    end

    return math.Round( exact )

end

-- meter.ROUND, meter.ROUND_UP or meter.ROUND_DOWN
PANEL.SetRounding = function( self, rounding )
    self._rounding = rounding

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

-- Chunks a SetFill drops show in this colour, a role or a Color, for duration seconds.
-- Chunked meters only
PANEL.SetLostFlash = function( self, color, duration )
    self._lostColor = color
    self._lostDuration = duration

end

-- For a drop that isn't a loss, like the meter switching to show something else
PANEL.ClearLost = function( self )
    self._lostUntil = 0

end

PANEL.SetFill = function( self, fraction )
    fraction = math.Clamp( fraction, 0, 1 )

    local oldLit, newLit = litChunks( self, self._fill ), litChunks( self, fraction )
    if self._lostColor and newLit < oldLit then
        local now = CurTime()
        -- a drop mid flash keeps flashing from the first drop's top
        if self._lostUntil <= now then self._lostFrom = oldLit end
        self._lostUntil = now + self._lostDuration

    end

    self._fill = fraction

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
    local lit    = litChunks( self, self._fill )
    local chunkW = barW / chunks
    local drawnW = math.max( 1, chunkW - style:Scaled( CHUNK_GAP_1080P ) )

    local lostTo = self._lostUntil > CurTime() and self._lostFrom or 0
    local lost   = lostTo > lit and style:Color( self._lostColor )

    for i = 1, chunks do
        local src = empty
        if i <= lit then
            src = fill

        elseif lost and i <= lostTo then
            src = lost

        end
        surface.SetDrawColor( src.r, src.g, src.b, src.a * stateAlpha / 255 )
        surface.DrawRect( pad + math.floor( ( i - 1 ) * chunkW ), pad, drawnW, barH )

    end
end

vgui.Register( "glee_meter", PANEL, "glee_hudbox" )
