--[[
    glee_panel — extends DPanel

    The base class of every glee panel. Draws its style's backdrop, then a material or
    text over it, all by role, so a change of style or scale changes only the look. Its
    style and scale come from its parents, see glee_hud/cl_stylecontext.lua.

    It has no states. glee_hudbox adds the hud's fading and flashing, glee_row hover and
    press. They change how this draws by overriding the three getters Paint reads:
    GetFade, GetVisualState and GetContentColor.

    Mouse input starts off. SetPaintBackground( false ) drops the backdrop, for a panel
    that only exists to be docked into.

        local box = vgui.Create( "glee_panel", parent )
        box:SetFont( "mediumLarge" )
        box:SetText( "Hello" )
        box:AutoSize()
]]

-- Not baseclass.Get: a baseclass table fetched before its class registers only ever gets
-- that class's own fields, none it inherits. Subclasses use vgui.GetControlTable at call time
local panelMeta = FindMetaTable( "Panel" )

local function syncSize( self )
    local overSize = self._iconSize * self._paddingRatio
    self._overSize = overSize
    local bgSize   = self._iconSize + overSize
    self:SetSize( bgSize, bgSize )

end


local PANEL = {}

PANEL.Init = function( self )
    local style = self:Style()

    self._iconSize     = math.min( style:Scaled( 48 ), style:Settings().iconMaxSize )
    self._paddingRatio = 0.4
    self._mat          = nil
    self._text         = nil
    self._rawText      = nil
    self._maxTextWidth = nil
    self._font         = "medium"
    self._textAlign    = TEXT_ALIGN_CENTER
    self._textPadding  = nil -- the style's blockPadding
    self._cornerRadius = nil -- the style's boxCornerRadius

    self._backdrop     = "bg"
    self._contentColor = "happy"

    self._drawContent = Color( 0, 0, 0, 0 ) -- Paint's scratch, the content colour faded

    syncSize( self )
    self:SetMouseInputEnabled( false )

end

-- see glee_hud/cl_stylecontext.lua
PANEL.Style = function( self )
    return terminator_Extras.glee_PanelStyle( self )

end

-- whatever a panel measured before this was in its old parent's style
PANEL.SetParent = function( self, parent )
    panelMeta.SetParent( self, parent )
    terminator_Extras.glee_NotifyPanelStyle( self )

end

-- DPanel's dims the panel and turns its mouse off, which takes its tooltip with it.
-- Here disabled is only a look, subclasses decide what else it stops
PANEL.SetDisabled = function( self, disabled )
    self.m_bDisabled = disabled

end


-- Content -------------------------------------------------------------------

-- Sizes the panel square around a material of this size, see SetPaddingRatio
PANEL.SetIconSize = function( self, size )
    self._iconSize = size
    syncSize( self )

end

-- How much wider than the material the panel is, as a fraction of the material
PANEL.SetPaddingRatio = function( self, ratio )
    self._paddingRatio = ratio
    syncSize( self )

end

-- Sets a material to draw centered. Clears any active text.
PANEL.SetMaterial = function( self, mat )
    self._mat     = mat
    self._text    = nil
    self._rawText = nil -- or SyncWrap brings the text back

end

-- Clears any active material. Wrapped to SetMaxTextWidth if one is set, aligned by
-- SetTextAlign
PANEL.SetText = function( self, text )
    self._rawText = text
    self._mat     = nil
    self:WrapText()

end

PANEL.WrapText = function( self )
    local font = self:GetResolvedFont()
    self._wrappedInFont = font

    local text = self._rawText
    if text and self._maxTextWidth then
        text = terminator_Extras.glee_HudHelpers.WrapText( text, font, self._maxTextWidth )

    end
    self._text = text

end

-- A style change swaps the font without a SetText
PANEL.SyncWrap = function( self )
    if self._wrappedInFont == self:GetResolvedFont() then return end

    self:WrapText()

end

-- Wrap text at this pixel width. nil ( the default ) leaves text unwrapped.
PANEL.SetMaxTextWidth = function( self, width )
    self._maxTextWidth = width
    if not self._rawText then return end

    self:SetText( self._rawText )

end

-- A font role, like "medium". See the style's fonts for what it has
PANEL.SetFont = function( self, fontRole )
    self._font = fontRole
    self:WrapText()

end

-- TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER ( the default ) or TEXT_ALIGN_RIGHT. Left and right
-- sit in from the edge by the same pad * 2 AutoSize leaves either side
PANEL.SetTextAlign = function( self, align )
    self._textAlign = align

end

PANEL.GetResolvedFont = function( self )
    return self:Style():Font( self._font )

end

-- nil goes back to the style's blockPadding
PANEL.SetTextPadding = function( self, pad )
    self._textPadding = pad

end

PANEL.GetTextPadding = function( self )
    return self._textPadding or self:Style():Metric( "blockPadding" )

end

-- The panel is kept at least wide enough for this text, so text that changes length,
-- like a count, doesn't change the width of whatever sizes itself around it
PANEL.SetReservedText = function( self, text )
    self._reservedText = text

end

local function hasText( self )
    return self._text and #self._text > 0

end

local function widestLine( font, text )
    surface.SetFont( font )
    local widest = 0

    for line in ( text .. "\n" ):gmatch( "([^\n]*)\n" ) do
        widest = math.max( widest, ( surface.GetTextSize( line ) ) ) -- the brackets drop the height

    end

    return widest

end

-- Text plus its padding, pad * 2 each side. Anything else, its current width
PANEL.GetContentWidth = function( self )
    self:SyncWrap()
    if not hasText( self ) then return self:GetWide() end

    local font = self:GetResolvedFont()
    local textWidth = math.max( widestLine( font, self._text ), widestLine( font, self._reservedText or "" ) )

    return textWidth + self:GetTextPadding() * 4

end

-- Text plus its padding, pad each side. Anything else, its current height
PANEL.GetContentHeight = function( self )
    self:SyncWrap()
    if not hasText( self ) then return self:GetTall() end

    local _, lineCount = string.gsub( self._text, "\n", "" )
    local fontHeight = draw.GetFontHeight( self:GetResolvedFont() )

    return fontHeight * ( lineCount + 1 ) + self:GetTextPadding() * 2

end

-- Resizes the panel to fit the current text plus its text padding on all sides.
-- Call after SetText when the text content changes.
PANEL.AutoSize = function( self )
    if not hasText( self ) then return end

    self:SetSize( self:GetContentWidth(), self:GetContentHeight() )

end


-- Look ----------------------------------------------------------------------

-- nil goes back to the style's boxCornerRadius
PANEL.SetCornerRadius = function( self, radius )
    self._cornerRadius = radius

end

-- A backdrop family, "bg" or "bgDark", or a Color to draw whatever the state
PANEL.SetBackdrop = function( self, family )
    self._backdrop = family

end

-- A role or a Color, for the text or material. Its alpha is scaled by GetFade.
PANEL.SetContentColor = function( self, color )
    self._contentColor = color

end

-- 0 to 1, scaling the backdrop and the content. Nothing paints at 0
PANEL.GetFade = function( _self )
    return 1

end

-- The state handed to the style's background, see handle:Background
PANEL.GetVisualState = function( self )
    if self:GetDisabled() then return "disabled" end

    return "idle"

end

PANEL.GetContentColor = function( self )
    return self._contentColor

end


-- Paint ---------------------------------------------------------------------

PANEL.Paint = function( self, w, h )
    local fade = self:GetFade()
    if fade <= 0 then return end

    local style = self:Style()

    if self:GetPaintBackground() then
        style:Background( 0, 0, w, h, self._backdrop, self._cornerRadius, fade, self:GetVisualState(), self )

    end

    local contentColor = style:Color( self:GetContentColor() )
    local drawContent  = self._drawContent
    drawContent.r = contentColor.r
    drawContent.g = contentColor.g
    drawContent.b = contentColor.b
    drawContent.a = math.floor( contentColor.a * fade )

    self:PaintContent( w, h, drawContent )

end

-- contentColor is already faded
PANEL.PaintContent = function( self, w, h, contentColor )
    local padding = self._overSize * 0.5

    if self._mat then
        surface.SetDrawColor( contentColor )
        surface.SetMaterial( self._mat )
        surface.DrawTexturedRect( padding, padding, self._iconSize, self._iconSize )

    else
        self:SyncWrap()
        if not self._text or #self._text <= 0 then return end

        local font            = self:GetResolvedFont()
        local fontHeight      = draw.GetFontHeight( font )
        local lines           = string.Explode( "\n", self._text )
        local totalTextHeight = fontHeight * #lines
        local startY          = h * 0.5 - totalTextHeight * 0.5

        local align = self._textAlign
        local textX = w * 0.5
        if align == TEXT_ALIGN_LEFT then
            textX = self:GetTextPadding() * 2

        elseif align == TEXT_ALIGN_RIGHT then
            textX = w - self:GetTextPadding() * 2

        end

        for i, line in ipairs( lines ) do
            draw.SimpleText( line, font, textX, startY + ( i - 1 ) * fontHeight, contentColor, align, TEXT_ALIGN_TOP )

        end
    end
end

vgui.Register( "glee_panel", PANEL, "DPanel" )
