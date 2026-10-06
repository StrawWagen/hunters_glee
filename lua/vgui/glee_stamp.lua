--[[
    glee_stamp — extends glee_panel

    A rubber stamp's impression. Slam drops it from above at a tilt, it lands in ink with
    a faint second impression beside it, then stays put. Draws past its own bounds while
    it falls, so it can sit anywhere over a form.

        local stamp = vgui.Create( "glee_stamp", form )
        stamp:SetInk( Material( "vgui/hud/deadshopicon_transparent.png", "smooth mips" ) )
        stamp:Slam( centerX, centerY ) -- in the parent's coordinates
        function stamp:OnImpact() end

    Takes no mouse input, so whatever is under it stays clickable.
]]

local SIZE_1080P   = 150 -- the landed stamp, square
local FALL_TIME    = 0.12 -- seconds from first sight to impact
local FALL_SCALE   = 3 -- how much bigger it is when it first shows, falling towards the page
local TILT_MIN     = 6 -- degrees either way, picked at random each Slam
local TILT_MAX     = 16

local INK_COLOR    = Color( 170, 20, 20, 225 ) -- a touch see-through, so the page shows under it

-- the second, fainter impression real stamps leave when they rock on landing
local SMUDGE_OFFSET_1080P = 3
local SMUDGE_ALPHA        = 0.3 -- of the ink's
local SMUDGE_TILT         = 2 -- degrees off the main impression

local PANEL = {}

PANEL.Init = function( self )
    self:SetPaintBackground( false )
    self:SetMouseInputEnabled( false )

    self._ink      = nil
    self._slamAt   = nil
    self._tilt     = 0
    self._impacted = false

    local size = self:Style():Scaled( SIZE_1080P )
    self:SetSize( size, size )

end

-- stub, called once, the frame it lands
PANEL.OnImpact = function( _self )
end

-- The material it prints, tinted INK_COLOR. White on transparent prints cleanest
PANEL.SetInk = function( self, material )
    self._ink = material

end

PANEL.OnHudStyleChanged = function( self )
    local centerX, centerY = self:GetX() + self:GetWide() * 0.5, self:GetY() + self:GetTall() * 0.5
    local size = self:Style():Scaled( SIZE_1080P )

    self:SetSize( size, size )
    self:SetPos( centerX - size * 0.5, centerY - size * 0.5 )

end

-- Centres on x, y in the parent's coordinates and starts falling. Slamming again restarts it
PANEL.Slam = function( self, x, y )
    self:SetPos( x - self:GetWide() * 0.5, y - self:GetTall() * 0.5 )
    self:MoveToFront()

    local tiltSide = math.random( 2 ) == 1 and 1 or -1
    self._tilt = math.Rand( TILT_MIN, TILT_MAX ) * tiltSide
    self._slamAt = RealTime()
    self._impacted = false

end

-- 0 at the first frame of the fall, 1 on impact and after
local function fallProgress( self )
    if not self._slamAt then return 0 end

    return math.Clamp( ( RealTime() - self._slamAt ) / FALL_TIME, 0, 1 )

end

PANEL.Think = function( self )
    if self._impacted or not self._slamAt then return end
    if fallProgress( self ) < 1 then return end

    self._impacted = true
    self:OnImpact()

end

-- One impression of the ink, centred on the panel, at this scale, tilt and alpha
local inkMatrix = Matrix()
local scaleVector = Vector( 1, 1, 1 )

local function drawImpression( self, w, h, scale, tilt, alpha, offsetX, offsetY )
    local centerX, centerY = self:LocalToScreen( w * 0.5 + offsetX, h * 0.5 + offsetY )
    local centre = Vector( centerX, centerY, 0 )

    scaleVector.x, scaleVector.y = scale, scale

    inkMatrix:Identity()
    inkMatrix:Translate( centre )
    inkMatrix:Rotate( Angle( 0, tilt, 0 ) )
    inkMatrix:Scale( scaleVector )
    inkMatrix:Translate( -centre )

    cam.PushModelMatrix( inkMatrix, true )
        surface.SetMaterial( self._ink )
        surface.SetDrawColor( INK_COLOR.r, INK_COLOR.g, INK_COLOR.b, INK_COLOR.a * alpha )
        surface.DrawTexturedRect( offsetX, offsetY, w, h )
    cam.PopModelMatrix()

end

PANEL.PaintContent = function( self, w, h, _contentColor )
    if not self._ink or not self._slamAt then return end

    local progress = fallProgress( self )
    local eased = progress ^ 2 -- falling, so it speeds up into the page
    local scale = Lerp( eased, FALL_SCALE, 1 )

    -- the falling stamp spills well past the panel
    local wasClipping = DisableClipping( true )
    render.PushFilterMag( TEXFILTER.ANISOTROPIC )
    render.PushFilterMin( TEXFILTER.ANISOTROPIC )

    if self._impacted then
        local smudgeOffset = self:Style():Scaled( SMUDGE_OFFSET_1080P )
        drawImpression( self, w, h, 1, self._tilt + SMUDGE_TILT, SMUDGE_ALPHA, smudgeOffset, smudgeOffset )

    end

    drawImpression( self, w, h, scale, self._tilt, eased, 0, 0 )

    render.PopFilterMin()
    render.PopFilterMag()
    DisableClipping( wasClipping )

end

vgui.Register( "glee_stamp", PANEL, "glee_panel" )
