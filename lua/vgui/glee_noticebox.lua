--[[
    glee_noticebox — extends glee_hudbox

    A hudbox with an optional description under its text, in a smaller font,
    and an optional icon on its right, with an optional badge at its top left.
    The notice feed's box, see cl_noticefeed.lua.

        local box = vgui.Create( "glee_noticebox", parent )
        box:SetMaxTextWidth( 600 )
        box:SetText( "A Prospective Account Holder has arrived..." )
        box:SetDescription( "Get them up to speed!" )
        box:SetIcon( terminator_Extras.glee_MaterialIcon( "entities/item_battery.png" ), 48, "2" )
        box:AutoSize()

    The description wraps at the same width as the text.
    An icon alone, with no text, is fine.
    The badge sits above the icon, like weapon selection's slot numbers. Icons fill their corners, it'd be lost on top.
]]

-- looked up when called, see glee_panel.lua for why not baseclass.Get
local function baseClass()
    return vgui.GetControlTable( "glee_hudbox" )

end


local BADGE_NUDGE = 0.5 -- the badge sits this many of its own heights left of the picture's corner

local PANEL = {}

PANEL.Init = function( self )
    self._descriptionFont = "noticeDescription"
    self._rawDescription  = nil
    self._description     = nil

    self._icon      = nil
    self._iconTall  = 0
    self._iconBadge = nil
    self._badgeFont = "noticeBadge"

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

-- An icon from glee_hud/cl_icons.lua, tall pixels high, as wide as its shape makes it. nil for none.
-- Drawn in the content colour, baking it is the caller's.
-- badge, optional, a few characters at its top left, like a weapon's slot
PANEL.SetIcon = function( self, icon, tall, badge )
    self._icon = icon
    self._iconTall = icon and tall or 0
    self._iconBadge = icon and badge or nil

end


-- Measuring -----------------------------------------------------------------

local function lineCount( text )
    local _, newlines = string.gsub( text, "\n", "" )
    return newlines + 1

end

local function hasText( self )
    return self._text ~= nil and #self._text > 0

end

local function textHeight( self )
    if not hasText( self ) then return 0 end

    return draw.GetFontHeight( self:GetResolvedFont() ) * lineCount( self._text )

end

local function descriptionHeight( self )
    if not self._description then return 0 end

    return draw.GetFontHeight( self:GetResolvedDescriptionFont() ) * lineCount( self._description )

end

-- the wider of the text and description
local function wordsWidth( self )
    local measure = terminator_Extras.glee_HudHelpers.MeasureText
    local width = 0

    if hasText( self ) then
        width = measure( self._text, self:GetResolvedFont() )

    end

    if self._description then
        local descriptionWidth = measure( self._description, self:GetResolvedDescriptionFont() )
        width = math.max( width, descriptionWidth )

    end

    return width

end

local function badgeFont( self )
    return self:Style():Font( self._badgeFont )

end

local function badgeHeight( self )
    if not self._iconBadge then return 0 end

    return draw.GetFontHeight( badgeFont( self ) )

end

local function iconWidth( self )
    if not self._icon then return 0 end

    return self._iconTall * self._icon:Aspect()

end

-- The badge sits above the picture, which often starts below the icon's top, this is what's left sticking out
local function badgeOverhang( self )
    local badgeTall = badgeHeight( self )
    if badgeTall <= 0 then return 0 end

    local _, inkV = self._icon:InkTopLeft()
    return math.max( 0, badgeTall - self._iconTall * inkV )

end

-- the icon, or the badge above it if that's wider
local function iconColumnWidth( self )
    local width = iconWidth( self )
    if not self._iconBadge then return width end

    return math.max( width, terminator_Extras.glee_HudHelpers.MeasureText( self._iconBadge, badgeFont( self ) ) )

end

-- between the words and the icon, when there's both
local function iconGap( self, wordsWide )
    if not self._icon or wordsWide <= 0 then return 0 end

    return self:GetTextPadding() * 2

end

-- Words, icon, the gap between, and pad * 2 either side
PANEL.GetContentWidth = function( self )
    self:SyncWrap()
    local wordsWide = wordsWidth( self )

    return wordsWide + iconGap( self, wordsWide ) + iconColumnWidth( self ) + self:GetTextPadding() * 4

end

-- The taller of the words and the icon with whatever of its badge sticks out, and pad above and below
PANEL.GetContentHeight = function( self )
    self:SyncWrap()
    local wordsTall = textHeight( self ) + descriptionHeight( self )

    return math.max( wordsTall, self._iconTall + badgeOverhang( self ) ) + self:GetTextPadding() * 2

end

-- glee_panel's skips a panel with no text, an icon alone still needs sizing
PANEL.AutoSize = function( self )
    self:SetSize( self:GetContentWidth(), self:GetContentHeight() )

end


-- Paint ---------------------------------------------------------------------

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

    local pad = self:GetTextPadding()
    local left = pad * 2
    local right = w - pad * 2

    local icon = self._icon
    if icon then
        local iconWide = iconWidth( self )
        local overhang = badgeOverhang( self )
        local iconTop = ( h - self._iconTall - overhang ) * 0.5 + overhang
        local iconLeft = right - iconWide

        icon:Draw( iconLeft, iconTop, iconWide, self._iconTall, contentColor )

        -- above the picture's corner, not the icon's, most have a see through margin
        if self._iconBadge then
            local inkU, inkV = icon:InkTopLeft()
            local badgeX = iconLeft + iconWide * inkU - badgeHeight( self ) * BADGE_NUDGE
            local badgeY = iconTop + self._iconTall * inkV - badgeHeight( self )
            draw.SimpleText( self._iconBadge, badgeFont( self ), badgeX, badgeY, contentColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

        end
        right = right - iconColumnWidth( self ) - iconGap( self, wordsWidth( self ) )

    end

    local align = self._textAlign
    local x = ( left + right ) * 0.5
    if align == TEXT_ALIGN_LEFT then
        x = left

    elseif align == TEXT_ALIGN_RIGHT then
        x = right

    end

    local y = h * 0.5 - ( textHeight( self ) + descriptionHeight( self ) ) * 0.5
    if hasText( self ) then
        y = drawLines( self._text, self:GetResolvedFont(), x, y, contentColor, align )

    end

    if self._description then
        drawLines( self._description, self:GetResolvedDescriptionFont(), x, y, contentColor, align )

    end
end

vgui.Register( "glee_noticebox", PANEL, "glee_hudbox" )
