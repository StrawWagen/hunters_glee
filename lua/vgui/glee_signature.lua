--[[
    glee_signature — extends glee_panel

    A line to sign on. Holding the mouse on it writes the signer's name across the line,
    in godlyDecree's ink; letting go early lets the ink run back. OnSigned fires once the
    name is written out, and the line stays signed.

        local line = vgui.Create( "glee_signature", parent )
        line:SetSigner( LocalPlayer():Nick() )
        line:SetMaxWidth( width )
        line:Dock( BOTTOM )
        function line:OnSigned() end

    A name too long for SetMaxWidth wraps, between words if it can, between letters if it
    can't, and the panel grows taller to fit. Without a max width it never wraps.

    While disabled it can't be held, and a hold in progress lets go.

    Hovers and holds past the line's end fall through, like glee_button.
]]

local HOLD_TIME  = 1.6 -- seconds of holding to write the whole name
local DRAIN_TIME = 0.4 -- seconds for a whole name's worth of ink to run back
local TICKS      = 12 -- pen scratches across one signing

local INK_FONT  = "signature" -- godlyDecree's
local INK_COLOR = "text"

local PROMPT = "HOLD TO SIGN"

local DISABLED_ALPHA = 0.3

local LINE_SPACING = 1.2 -- of the ink's font height, matching style:Draw's multi-line text

local PANEL = {}

PANEL.Init = function( self )
    self:SetPaintBackground( false )
    self:SetMouseInputEnabled( true )

    self._signer     = ""
    self._maxWidth   = nil
    self._inkLines   = { "" } -- the name as wrapped, one string a line
    self._inkWidths  = { 0 }
    self._fill       = 0 -- how much of the name is written, 0 to 1
    self._holding    = false
    self._signed     = false
    self._lastTick   = 0
    self._wasHovered = false

    self:Rewrap()

end

-- stub, called once
PANEL.OnSigned = function( _self )
end

-- The name the ink writes out
PANEL.SetSigner = function( self, name )
    self._signer = name
    self:Rewrap()

end

-- The widest the whole panel may be, X and line included. nil never wraps
PANEL.SetMaxWidth = function( self, width )
    self._maxWidth = width
    self:Rewrap()

end

-- the ink is godlyDecree's, at whatever scale this panel is drawn at
PANEL.InkStyle = function( self )
    return terminator_Extras.glee_Style( "godlyDecree", self:Style().scaleName )

end

-- where the line starts, past the X
local function lineStart( self )
    local pad = self:GetTextPadding()
    local markW = self:Style():Measure( "X", "medium" )

    return pad * 2 + markW + pad * 2

end

-- where the ink starts, a little in from the line's start
local function inkStart( self )
    return lineStart( self ) + self:GetTextPadding() * 2

end

-- Word wraps first, then breaks any word still too wide between its letters.
-- A single letter wider than maxWidth still gets a line of its own
local function wrapName( name, font, maxWidth )
    local wordWrapped = terminator_Extras.glee_HudHelpers.WrapText( name, font, maxWidth )

    surface.SetFont( font )
    local lines = {}

    for _, wordLine in ipairs( string.Explode( "\n", wordWrapped, false ) ) do
        local line = ""

        for letter in string.gmatch( wordLine, utf8.charpattern ) do
            local try = line .. letter
            if line ~= "" and surface.GetTextSize( try ) > maxWidth then
                lines[#lines + 1] = line
                line = letter

            else
                line = try

            end
        end

        lines[#lines + 1] = line

    end

    return lines

end

-- Rewraps the name and resizes to fit it. Anything the wrap depends on calls this
PANEL.Rewrap = function( self )
    local font = self:InkStyle():Font( INK_FONT )
    local pad = self:GetTextPadding()

    local lines = { self._signer }
    if self._maxWidth then
        -- the line runs pad * 2 past the ink's end
        local inkRoom = self._maxWidth - inkStart( self ) - pad * 2
        lines = wrapName( self._signer, font, math.max( inkRoom, 1 ) )

    end

    surface.SetFont( font )
    local widths = {}
    for index, line in ipairs( lines ) do
        widths[index] = ( surface.GetTextSize( line ) )

    end

    self._inkLines = lines
    self._inkWidths = widths

    local fontH = draw.GetFontHeight( font )
    self:SetTall( fontH + ( #lines - 1 ) * fontH * LINE_SPACING + pad * 2 )

end

PANEL.OnHudStyleChanged = PANEL.Rewrap

-- x of the line's start and end. The line runs under the widest line of the name, or
-- the prompt if that's wider
local function lineSpan( self )
    local pad = self:GetTextPadding()
    local promptW = self:Style():Measure( PROMPT, "medium" )
    local inkW = math.max( unpack( self._inkWidths ) )

    local start = lineStart( self )
    return start, start + math.max( inkW, promptW ) + pad * 4

end

PANEL.GetContentWidth = function( self )
    local _, lineEnd = lineSpan( self )
    return lineEnd

end

PANEL.TestHover = function( self, x, y )
    local localX, localY = self:ScreenToLocal( x, y )
    local _, lineEnd = lineSpan( self )

    return localX >= 0 and localX < math.min( lineEnd, self:GetWide() ) and localY >= 0 and localY < self:GetTall()

end


-- Holding -------------------------------------------------------------------

local function canHold( self )
    return not self._signed and not self:GetDisabled()

end

local function stopHolding( self )
    self._holding = false
    self:MouseCapture( false )

end

-- Takes the signature back, for an OnSigned that turned out not to want it. The ink runs
-- back off the line as if let go early
PANEL.Unsign = function( self )
    self._signed = false
    self._fill = math.min( self._fill, 0.999 )

end

PANEL.OnMousePressed = function( self, mouseCode )
    if mouseCode ~= MOUSE_LEFT then return end
    if not canHold( self ) then return end

    self._holding = true
    self:MouseCapture( true )

end

PANEL.OnMouseReleased = function( self, mouseCode )
    if mouseCode ~= MOUSE_LEFT then return end

    stopHolding( self )

end

local function scratch( self )
    local tick = math.floor( self._fill * TICKS )
    if tick <= self._lastTick then return end

    self._lastTick = tick
    self:Style():PlaySound( "switch", 70 + ( tick / TICKS ) * 60, nil, 0.3 )

end

local function sign( self )
    self._fill = 1
    self._signed = true
    stopHolding( self )

    self:Style():PlaySound( "press", 80, nil, 1 )
    self:OnSigned()

end

PANEL.Think = function( self )
    local hovered = self:IsHovered()
    if hovered ~= self._wasHovered then
        self._wasHovered = hovered
        if canHold( self ) then
            self:Style():PlaySound( "switch", hovered and 90 or 80, nil, 0.14, 60 )

        end
    end

    if self._signed then return end

    -- a release off the panel, or on another window, never reaches OnMouseReleased.
    -- Disabling mid-hold lets go too
    if self._holding and ( self:GetDisabled() or not input.IsMouseDown( MOUSE_LEFT ) ) then
        stopHolding( self )

    end

    if self._holding then
        self._fill = self._fill + FrameTime() / HOLD_TIME
        scratch( self )
        if self._fill >= 1 then sign( self ) end

    else
        self._fill = math.max( self._fill - FrameTime() / DRAIN_TIME, 0 )
        self._lastTick = math.floor( self._fill * TICKS )

    end
end


-- Paint ---------------------------------------------------------------------

-- The name, revealed left to right and line by line, as far as the ink has got
local function drawInk( self, h )
    local ink = self:InkStyle()
    local pad = self:GetTextPadding()
    local inkX = inkStart( self )
    local lineStep = draw.GetFontHeight( ink:Font( INK_FONT ) ) * LINE_SPACING

    local totalW = 0
    for _, lineW in ipairs( self._inkWidths ) do
        totalW = totalW + lineW

    end

    local inkLeft = totalW * self._fill

    for index, line in ipairs( self._inkLines ) do
        if inkLeft <= 0 then break end

        local lineW = self._inkWidths[index]
        local revealW = math.ceil( math.min( lineW, inkLeft ) )
        inkLeft = inkLeft - lineW

        local lineY = pad + ( index - 1 ) * lineStep
        local screenX, screenY = self:LocalToScreen( inkX, 0 )

        -- the full height, so a tall letter's shadow isn't clipped mid-line
        render.SetScissorRect( screenX, screenY, screenX + revealW, screenY + h, true )
        ink:Draw( line, INK_FONT, inkX, lineY, INK_COLOR, false )
        render.SetScissorRect( 0, 0, 0, 0, false )

    end
end

local function paintSignature( self, h )
    local style = self:Style()
    local pad = self:GetTextPadding()
    local lineX, lineEndX = lineSpan( self )

    local lineColor = "text"
    if self._holding or ( self:IsHovered() and canHold( self ) ) then
        lineColor = "happy"

    end

    local markH = draw.GetFontHeight( style:Font( "medium" ) )
    style:Draw( "X", "medium", pad * 2, h - pad - markH, lineColor, false )

    surface.SetDrawColor( style:Color( lineColor ) )
    surface.DrawRect( lineX, h - pad, lineEndX - lineX, math.max( 1, style:Scaled( 2 ) ) )

    if self._fill <= 0 then
        local promptH = draw.GetFontHeight( style:Font( "medium" ) )
        style:Draw( PROMPT, "medium", inkStart( self ), h - pad - promptH, lineColor, false )
        return

    end

    drawInk( self, h )

end

PANEL.PaintContent = function( self, _w, h, _contentColor )
    local oldMultiplier = surface.GetAlphaMultiplier()
    if self:GetDisabled() then
        surface.SetAlphaMultiplier( oldMultiplier * DISABLED_ALPHA )

    end

    paintSignature( self, h )
    surface.SetAlphaMultiplier( oldMultiplier )

end

vgui.Register( "glee_signature", PANEL, "glee_panel" )
