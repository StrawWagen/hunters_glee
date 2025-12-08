--[[
    glee_radialselector - A reusable radial/wheel menu VGUI element

    Usage:
        local wheel = vgui.Create( "glee_radialselector" )
        wheel:SetSize( 400, 400 )
        wheel:Center()

        wheel:SetItems( {
            { key = "option1", label = "First Option" },
            { key = "option2", label = "Second Option" },
            { key = "option3", label = "Third Option" },
        } )

        wheel:SetInnerRadius( 80 )  -- optional, default scales with size
        wheel:SetOuterRadius( 180 ) -- optional, default scales with size
        wheel:SetTitle( "Pick One" ) -- optional center text

        wheel.OnItemSelected = function( self, item )
            print( "Selected:", item.key, item.label )
        end
]]

local PANEL = {}

-- Default settings
PANEL.innerRadiusRatio = 0.35 -- ratio of width/2
PANEL.outerRadiusRatio = 0.75 -- ratio of width/2
PANEL.segsPerWedge = 28
PANEL.startAngle = -90 -- start at top

function PANEL:Init()
    self.items = {}
    self.title = ""
    self.lastHoveredIdx = nil
    self.wasInRing = false
    self.pressed = false

    -- Colors - use shop standards if available, otherwise defaults
    local shopStandards = GAMEMODE and GAMEMODE.shopStandards

    if shopStandards then
        self.backgroundColor = shopStandards.backgroundColor
        self.hoverColor = shopStandards.notHoveredOverlay
        self.pressedColor = shopStandards.pressedItemOverlay
        self.textColor = shopStandards.white
        self.switchSound = shopStandards.switchSound
        self.selectSound = shopStandards.switchSound

    else
        self.backgroundColor = Color( 40, 40, 40, 200 )
        self.hoverColor = Color( 80, 80, 80, 100 )
        self.pressedColor = Color( 100, 100, 100, 100 )
        self.textColor = color_white
        self.switchSound = "ui/buttonrollover.wav"
        self.selectSound = "ui/buttonclick.wav"

    end

    -- Font - try shop fonts first, fallback to defaults
    self.itemFont = "termhuntShopItemFont"
    self.titleFont = "termhuntShopItemFontShadowed"

    surface.SetFont( self.itemFont )
    local testW = surface.GetTextSize( "test" )
    if not testW or testW == 0 then
        self.itemFont = "DermaDefaultBold"

    end

    surface.SetFont( self.titleFont )
    testW = surface.GetTextSize( "test" )
    if not testW or testW == 0 then
        self.titleFont = "DermaLarge"

    end

    self:SetMouseInputEnabled( true )

end

function PANEL:SetItems( items )
    self.items = items or {}
end

function PANEL:GetItems()
    return self.items
end

function PANEL:SetTitle( title )
    self.title = title or ""
end

function PANEL:GetTitle()
    return self.title
end

function PANEL:SetInnerRadius( r )
    self.innerRadiusOverride = r
end

function PANEL:SetOuterRadius( r )
    self.outerRadiusOverride = r
end

function PANEL:SetBackgroundColor( col )
    self.backgroundColor = col
end

function PANEL:SetHoverColor( col )
    self.hoverColor = col
end

function PANEL:SetPressedColor( col )
    self.pressedColor = col
end

function PANEL:SetTextColor( col )
    self.textColor = col
end

function PANEL:SetItemFont( font )
    self.itemFont = font
end

function PANEL:SetTitleFont( font )
    self.titleFont = font
end

function PANEL:SetSwitchSound( snd )
    self.switchSound = snd
end

function PANEL:SetSelectSound( snd )
    self.selectSound = snd
end

function PANEL:GetInnerRadius()
    if self.innerRadiusOverride then return self.innerRadiusOverride end
    local w = self:GetWide()
    return ( w * 0.5 ) * self.innerRadiusRatio
end

function PANEL:GetOuterRadius()
    if self.outerRadiusOverride then return self.outerRadiusOverride end
    local w = self:GetWide()
    return ( w * 0.5 ) * self.outerRadiusRatio
end

function PANEL:GetCursorPolar()
    local w, h = self:GetSize()
    local centerX, centerY = w * 0.5, h * 0.5
    local cursorX, cursorY = self:CursorPos()

    local deltaX = cursorX - centerX
    local deltaY = cursorY - centerY

    local radius = math.sqrt( deltaX * deltaX + deltaY * deltaY )
    local angle = math.deg( math.atan2( deltaY, deltaX ) )

    return radius, angle, centerX, centerY

end

function PANEL:AngleToIndex( angle )
    local itemCount = #self.items
    if itemCount <= 0 then return nil end

    local degreesPerItem = 360 / itemCount
    local normalizedAngle = ( angle - self.startAngle ) % 360

    return math.floor( normalizedAngle / degreesPerItem ) + 1

end

function PANEL:GetHoveredItem()
    local radius, angle = self:GetCursorPolar()
    local innerRadius = self:GetInnerRadius()
    local outerRadius = self:GetOuterRadius()

    if radius < innerRadius then return nil, nil end
    if radius > outerRadius then return nil, nil end

    local index = self:AngleToIndex( angle )
    if not index then return nil, nil end

    return self.items[index], index

end

function PANEL:OnMousePressed( keyCode )
    if keyCode ~= MOUSE_LEFT then return end
    self.pressed = true

end

function PANEL:OnMouseReleased( keyCode )
    if keyCode ~= MOUSE_LEFT then return end
    self.pressed = false

    local item, index = self:GetHoveredItem()
    if not item then return end

    -- Play select sound
    if self.selectSound then
        LocalPlayer():EmitSound( self.selectSound, 60, 50, 0.24 )

    end

    -- Call the callback
    if not self.OnItemSelected then return end
    self:OnItemSelected( item, index )

end

function PANEL:Think()
    local radius, angle = self:GetCursorPolar()
    local innerRadius = self:GetInnerRadius()
    local outerRadius = self:GetOuterRadius()

    local cursorInRing = radius >= innerRadius and radius <= outerRadius

    -- Cursor left the ring
    if not cursorInRing then
        if self.wasInRing and self.switchSound then
            LocalPlayer():EmitSound( self.switchSound, 60, 80, 0.12 )

        end
        self.wasInRing = false
        self.lastHoveredIdx = nil
        return

    end

    -- Cursor moved to a different wedge
    local hoveredIndex = self:AngleToIndex( angle )
    if hoveredIndex ~= self.lastHoveredIdx then
        if self.switchSound then
            LocalPlayer():EmitSound( self.switchSound, 60, 90, 0.12 )

        end
        self.lastHoveredIdx = hoveredIndex

    end

    self.wasInRing = true

end

function PANEL:DrawSegment( centerX, centerY, innerRadius, outerRadius, startAngle, endAngle, color )
    draw.NoTexture()
    surface.SetDrawColor( color )

    local polygon = {}
    local arcLength = math.max( endAngle - startAngle, 0.001 )
    local angleStep = arcLength / self.segsPerWedge

    -- Outer edge (startAngle -> endAngle)
    for i = 0, self.segsPerWedge do
        local angle = math.rad( startAngle + angleStep * i )
        polygon[#polygon + 1] = {
            x = centerX + math.cos( angle ) * outerRadius,
            y = centerY + math.sin( angle ) * outerRadius
        }
    end

    -- Inner edge (endAngle -> startAngle)
    for i = self.segsPerWedge, 0, -1 do
        local angle = math.rad( startAngle + angleStep * i )
        polygon[#polygon + 1] = {
            x = centerX + math.cos( angle ) * innerRadius,
            y = centerY + math.sin( angle ) * innerRadius
        }

    end

    surface.DrawPoly( polygon )

end

function PANEL:Paint( w, h )
    local centerX, centerY = w * 0.5, h * 0.5
    local itemCount = #self.items
    local innerRadius = self:GetInnerRadius()
    local outerRadius = self:GetOuterRadius()

    -- No items - just draw title
    if itemCount <= 0 then
        if self.title and #self.title > 0 then
            draw.SimpleText( self.title, self.titleFont, centerX, centerY, self.textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

        end
        return

    end

    local degreesPerItem = 360 / itemCount
    local hoveredIndex = self.wasInRing and self.lastHoveredIdx or nil
    local labelRadius = ( innerRadius + outerRadius ) * 0.5

    -- Draw wedges and labels
    for i = 1, itemCount do
        local wedgeStart = self.startAngle + ( i - 1 ) * degreesPerItem
        local wedgeEnd = wedgeStart + degreesPerItem

        -- Base fill
        self:DrawSegment( centerX, centerY, innerRadius, outerRadius, wedgeStart, wedgeEnd, self.backgroundColor )

        -- Hover and pressed highlights
        if hoveredIndex == i then
            self:DrawSegment( centerX, centerY, innerRadius, outerRadius, wedgeStart, wedgeEnd, self.hoverColor )

            if self.pressed then
                self:DrawSegment( centerX, centerY, innerRadius, outerRadius, wedgeStart, wedgeEnd, self.pressedColor )

            end
        end

        -- Label
        local labelAngle = math.rad( ( wedgeStart + wedgeEnd ) * 0.5 )
        local labelX = centerX + math.cos( labelAngle ) * labelRadius
        local labelY = centerY + math.sin( labelAngle ) * labelRadius

        local item = self.items[i]
        local label = item.label or item.pretty or item.name or item.key or ""

        if label and #label > 0 then
            draw.SimpleText( label, self.itemFont, labelX, labelY, self.textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

        end
    end

    -- Draw center title
    if self.title and #self.title > 0 then
        draw.SimpleText( self.title, self.titleFont, centerX, centerY, self.textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

    end
end

-- Callback stub - override this
function PANEL:OnItemSelected( item, index )
    -- Override this function to handle selection
    -- item is the table from items array
    -- index is the 1-based index
end

vgui.Register( "glee_radialselector", PANEL, "DPanel" )
