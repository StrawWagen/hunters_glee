--[[
    glee_noticebox — extends glee_hudbox

    A hudbox with an optional description under its text, in a smaller font.
    The notice feed's box, see cl_noticefeed.lua.

        local box = vgui.Create( "glee_noticebox", parent )
        box:SetMaxTextWidth( 600 )
        box:SetText( "A Prospective Account Holder has arrived..." )
        box:SetDescription( "Get them up to speed!" )
        box:AutoSize()

    The description wraps at the same width as the text.
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_hudbox" )

end


local PANEL = {}

PANEL.Init = function( self )
    self._descriptionFont = "noticeDescription"
    self._rawDescription  = nil
    self._description     = nil

end

-- nil or "" for none
PANEL.SetDescription = function( self, description )
    if description == "" then description = nil end

    self._rawDescription = description
    self:WrapDescription()

end

-- A font role, like "small"
PANEL.SetDescriptionFont = function( self, fontRole )
    self._descriptionFont = fontRole
    self:WrapDescription()

end

PANEL.GetResolvedDescriptionFont = function( self )
    return self:Style():Font( self._descriptionFont )

end

PANEL.WrapDescription = function( self )
    local font = self:GetResolvedDescriptionFont()
    self._descriptionWrappedInFont = font

    local description = self._rawDescription
    if description and self._maxTextWidth then
        description = terminator_Extras.glee_HudHelpers.WrapText( description, font, self._maxTextWidth )

    end
    self._description = description

end

-- the text's SyncWrap, for the description. A style change swaps the font without a SetDescription
PANEL.SyncWrap = function( self )
    baseClass().SyncWrap( self )

    if self._descriptionWrappedInFont == self:GetResolvedDescriptionFont() then return end
    self:WrapDescription()

end

PANEL.SetMaxTextWidth = function( self, width )
    baseClass().SetMaxTextWidth( self, width )
    self:WrapDescription()

end

local function lineCount( text )
    local _, newlines = string.gsub( text, "\n", "" )
    return newlines + 1

end

local function descriptionHeight( self )
    if not self._description then return 0 end

    return draw.GetFontHeight( self:GetResolvedDescriptionFont() ) * lineCount( self._description )

end

PANEL.GetContentWidth = function( self )
    local width = baseClass().GetContentWidth( self )
    if not self._description then return width end

    local descriptionWidth = terminator_Extras.glee_HudHelpers.MeasureText( self._description, self:GetResolvedDescriptionFont() )

    return math.max( width, descriptionWidth + self:GetTextPadding() * 4 )

end

PANEL.GetContentHeight = function( self )
    return baseClass().GetContentHeight( self ) + descriptionHeight( self )

end

-- glee_panel's text drawing, line by line, from the top of y
local function drawLines( text, font, x, y, color, align )
    local fontHeight = draw.GetFontHeight( font )

    for i, line in ipairs( string.Explode( "\n", text ) ) do
        draw.SimpleText( line, font, x, y + ( i - 1 ) * fontHeight, color, align, TEXT_ALIGN_TOP )

    end

    return y + fontHeight * lineCount( text )

end

PANEL.PaintContent = function( self, w, h, contentColor )
    self:SyncWrap()
    if not self._description then
        baseClass().PaintContent( self, w, h, contentColor )
        return

    end

    local font = self:GetResolvedFont()
    local text = self._text or ""
    local textHeight = #text > 0 and draw.GetFontHeight( font ) * lineCount( text ) or 0

    local align = self._textAlign
    local x = w * 0.5
    if align == TEXT_ALIGN_LEFT then
        x = self:GetTextPadding() * 2

    elseif align == TEXT_ALIGN_RIGHT then
        x = w - self:GetTextPadding() * 2

    end

    local y = h * 0.5 - ( textHeight + descriptionHeight( self ) ) * 0.5
    if textHeight > 0 then
        y = drawLines( text, font, x, y, contentColor, align )

    end

    drawLines( self._description, self:GetResolvedDescriptionFont(), x, y, contentColor, align )

end

vgui.Register( "glee_noticebox", PANEL, "glee_hudbox" )
