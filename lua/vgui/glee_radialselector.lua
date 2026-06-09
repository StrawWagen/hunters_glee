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

local INNER_RADIUS_RATIO = 0.35 -- ratio of width/2
local OUTER_RADIUS_RATIO = 0.75 -- ratio of width/2
local SEGS_PER_WEDGE = 28
local START_ANGLE = -90 -- start at top

-- Fonts: detected once on first panel creation (gamemode fonts may not exist at file load)
local ITEM_FONT
local TITLE_FONT


local PANEL = {
    Init = function( self )
        -- Detect and cache fonts on first panel creation
        if not ITEM_FONT then
            ITEM_FONT = "termhuntShopItemFont"
            surface.SetFont( ITEM_FONT )
            local testW = surface.GetTextSize( "test" )
            if not testW or testW == 0 then ITEM_FONT = "DermaDefaultBold" end

            TITLE_FONT = "termhuntShopItemFontShadowed"
            surface.SetFont( TITLE_FONT )
            testW = surface.GetTextSize( "test" )
            if not testW or testW == 0 then TITLE_FONT = "DermaLarge" end

        end

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

        self.itemFont = ITEM_FONT
        self.titleFont = TITLE_FONT

        self:SetMouseInputEnabled( true )

    end,

    SetItems = function( self, items )
        self.items = items or {}

    end,

    GetItems = function( self )
        return self.items

    end,

    SetTitle = function( self, title )
        self.title = title or ""

    end,

    GetTitle = function( self )
        return self.title

    end,

    SetInnerRadius = function( self, r )
        self.innerRadiusOverride = r

    end,

    SetOuterRadius = function( self, r )
        self.outerRadiusOverride = r

    end,

    SetBackgroundColor = function( self, col )
        self.backgroundColor = col

    end,

    SetHoverColor = function( self, col )
        self.hoverColor = col

    end,

    SetPressedColor = function( self, col )
        self.pressedColor = col

    end,

    SetTextColor = function( self, col )
        self.textColor = col

    end,

    SetItemFont = function( self, font )
        self.itemFont = font

    end,

    SetTitleFont = function( self, font )
        self.titleFont = font

    end,

    SetSwitchSound = function( self, snd )
        self.switchSound = snd

    end,

    SetSelectSound = function( self, snd )
        self.selectSound = snd

    end,

    GetInnerRadius = function( self )
        if self.innerRadiusOverride then return self.innerRadiusOverride end
        local w = self:GetWide()
        return ( w * 0.5 ) * INNER_RADIUS_RATIO

    end,

    GetOuterRadius = function( self )
        if self.outerRadiusOverride then return self.outerRadiusOverride end
        local w = self:GetWide()
        return ( w * 0.5 ) * OUTER_RADIUS_RATIO

    end,

    GetCursorPolar = function( self )
        local w, h = self:GetSize()
        local centerX, centerY = w * 0.5, h * 0.5
        local cursorX, cursorY = self:CursorPos()

        local deltaX = cursorX - centerX
        local deltaY = cursorY - centerY

        local radius = math.sqrt( deltaX * deltaX + deltaY * deltaY )
        local angle = math.deg( math.atan2( deltaY, deltaX ) )

        return radius, angle

    end,

    AngleToIndex = function( self, angle )
        local itemCount = #self.items
        if itemCount <= 0 then return nil end

        local degreesPerItem = 360 / itemCount
        local normalizedAngle = ( angle - START_ANGLE ) % 360

        return math.floor( normalizedAngle / degreesPerItem ) + 1

    end,

    GetHoveredItem = function( self )
        local radius, angle = self:GetCursorPolar()
        local innerRadius = self:GetInnerRadius()
        local outerRadius = self:GetOuterRadius()

        if radius < innerRadius then return nil, nil end
        if radius > outerRadius then return nil, nil end

        local index = self:AngleToIndex( angle )
        if not index then return nil, nil end

        return self.items[index], index

    end,

    OnMousePressed = function( self, keyCode )
        if keyCode ~= MOUSE_LEFT then return end
        self.pressed = true

    end,

    OnMouseReleased = function( self, keyCode )
        if keyCode ~= MOUSE_LEFT then return end
        self.pressed = false

        local item, index = self:GetHoveredItem()
        if not item then return end

        if self.selectSound then
            LocalPlayer():EmitSound( self.selectSound, 60, 50, 0.24 )

        end

        self:OnItemSelected( item, index )

    end,

    Think = function( self )
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

    end,

    DrawSegment = function( self, centerX, centerY, innerRadius, outerRadius, startAngle, endAngle, color )
        draw.NoTexture()
        surface.SetDrawColor( color )

        local polygon = {}
        local arcLength = math.max( endAngle - startAngle, 0.001 )
        local angleStep = arcLength / SEGS_PER_WEDGE

        -- Outer edge (startAngle -> endAngle)
        for i = 0, SEGS_PER_WEDGE do
            local angle = math.rad( startAngle + angleStep * i )
            polygon[#polygon + 1] = {
                x = centerX + math.cos( angle ) * outerRadius,
                y = centerY + math.sin( angle ) * outerRadius,
            }

        end

        -- Inner edge (endAngle -> startAngle)
        for i = SEGS_PER_WEDGE, 0, -1 do
            local angle = math.rad( startAngle + angleStep * i )
            polygon[#polygon + 1] = {
                x = centerX + math.cos( angle ) * innerRadius,
                y = centerY + math.sin( angle ) * innerRadius,
            }

        end

        surface.DrawPoly( polygon )

    end,

    Paint = function( self, w, h )
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
            local wedgeStart = START_ANGLE + ( i - 1 ) * degreesPerItem
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
    end,

    -- Callback stub - override this.
    -- item: table from items array; index: 1-based position.
    OnItemSelected = function( self, item, index )

    end,
}

vgui.Register( "glee_radialselector", PANEL, "DPanel" )
