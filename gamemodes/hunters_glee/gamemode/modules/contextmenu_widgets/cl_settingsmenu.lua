-- AI SLOP FILE
-- Minimalist, table-driven settings menu. Clientside only.
-- Architecture mirrors cl_tauntmenu/cl_banktop: command-owned window, single-instance holder, DesktopWindows just triggers the command.

local GAMEMODE = GAMEMODE or GM

local settingsMenu = {}

-- 1080p baseline sizes (auto-scaled via glee_sizeScaled)
local FRAME_W_1080P          = 720
local FRAME_H_1080P          = 700
-- Shared border padding comes from GAMEMODE.shopStandards.borderPadding (unscaled value).
-- Name it as UNSCALED to avoid implying it's a hardcoded 1080p constant.
local SHOP_BORDER_PAD_UNSCALED = GAMEMODE.shopStandards.borderPadding
local ROW_H_1080P              = 48
local GAP_Y_1080P              = 6

-- Static reset icon config (edit here to tweak look/placement)
local RESET_ICON_PATH   = "icon16/arrow_rotate_anticlockwise.png"
local RESET_ICON_SIZE   = 16   -- static pixels
local RESET_ICON_PADTOP = 4    -- distance from top edge of a row
local RESET_ICON_PADR   = 4    -- distance from right edge of a row
local RESET_ICON_COLOR  = Color(255, 255, 255, 255)
local RESET_ICON_COLOR_HOVER = Color(255, 255, 255, 255)
local resetIconMat = Material( RESET_ICON_PATH, "smooth" )

-- Helper to close and reopen the settings menu (useful after scale changes)
local function reopenSettingsMenu()
    if IsValid( GAMEMODE.glee_SettingsMenu_Holder ) then
        GAMEMODE.glee_SettingsMenu_Holder:Remove()
    end
    timer.Simple( 0, function()
        RunConsoleCommand( "glee_settings_open" )
    end )
end

local settingsCategories = {
    {
        name = "GLEE",
        items = {
            {
                cvar = "huntersglee_cl_showhud",
                type = "check",
                prettyName = "Show top left info",
                desc = "Show score, round type, and skull count?",
            },
            {
                cvar = "cl_huntersglee_guiscale",
                type = "slider",
                min = 0.2,
                max = 1,
                decimals = 2,
                prettyName = "GUI scale",
                desc = "Scale all GUIs, shop, bank leaderboard, etc. Default is -1, which translates to 0.9",
                changeWhenDone = true,
                postChangedFunc = reopenSettingsMenu,
            },
            {
                cvar = "huntersglee_cl_heartbeat_volume",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 1,
                prettyName = "Heartbeat volume",
                desc = "Turn down the beat.",
            },
        }
    },
    {
        name = "Souls",
        items = {
            {
                cvar = "huntersglee_cl_dosoulragdolls",
                type = "check",
                prettyName = "Enable 'Souls'",
                desc = "Enable funny client ragdolls on dead players",
            },
            {
                cvar = "huntersglee_cl_seeownsoul",
                type = "check",
                prettyName = "Draw your own soul?",
                desc = "Let your own soul be visible to you",
            },
            {
                cvar = "huntersglee_cl_ownsoul_nearfade",
                type = "slider",
                min = 0,
                max = 1,
                decimals = 2,
                prettyName = "Own soul transparency",
                desc = "How transparent should your own soul be when it's near you",
            },
        }
    },
}

local function emitUISound( pitch )
    local snd = GAMEMODE and GAMEMODE.shopStandards and GAMEMODE.shopStandards.switchSound
    if not snd then return end
    LocalPlayer():EmitSound( snd, 60, pitch or 85, 0.14 )
end

function settingsMenu:Create( container )
    local scale = GAMEMODE.shopStandards.shpScale or 1

    -- Unify all shop GUI paddings via shopStandards.borderPadding (shared across menus)
    local padding = glee_sizeScaled( nil, SHOP_BORDER_PAD_UNSCALED * scale )
    local rowH      = glee_sizeScaled( nil, ROW_H_1080P * scale )
    local gapY      = glee_sizeScaled( nil, GAP_Y_1080P * scale )

    container:DockPadding( 0, 0, 0, 0 )
    container:DockMargin( padding, padding, padding, padding )
    container:SetTitle( "" )
    container:ShowCloseButton( false )
    container:SetDraggable( false )
    function container:Paint() end

    local root = vgui.Create( "DPanel", container )
    root:Dock( FILL )
    root:DockMargin( 0, padding, 0, padding )
    function root:Paint( w, h )
        surface.SetDrawColor( GAMEMODE.shopStandards.backgroundColor )
        surface.DrawRect( 0, 0, w, h )
    end

    local scroll = vgui.Create( "DScrollPanel", root )
    scroll:Dock( FILL )
    scroll:DockMargin( padding, padding, padding, padding )

    local settingsList = vgui.Create( "DListLayout", scroll )
    settingsList:Dock( FILL )

    local function addGap( h )
        -- Spacer panel: used because DListLayout lacks SetSpacing; keep empty.
        local spacer = vgui.Create( "DPanel", settingsList )
        spacer:SetTall( h )
        function spacer:Paint() end
        settingsList:Add( spacer )
    end

    local function addRow( def )
        local row = vgui.Create( "DPanel", settingsList )
        row:SetTall( rowH )
        row:Dock( TOP )
        row:DockMargin( 0, 0, 0, 0 )
        row:SetTooltip( def.desc or "" )
        function row:Paint( w, h )
            -- Subtle row background separation
            surface.SetDrawColor( GAMEMODE.shopStandards.itemBackground or Color( 0, 0, 0, 100 ) )
            surface.DrawRect( 0, 0, w, h )
        end

        -- Label on the left
        local nameLbl = vgui.Create( "DLabel", row )
        nameLbl:SetFont( "termhuntShopItemFont" )
        nameLbl:SetText( def.prettyName or def.cvar or "Setting" )
        nameLbl:SetTextColor( GAMEMODE.shopStandards.white )
        nameLbl:Dock( LEFT )
        nameLbl:DockMargin( padding, 0, padding, 0 )
        nameLbl:SizeToContentsX()

        -- Control on the right
        if def.type == "check" then
            local cvarRef = GetConVar( def.cvar )

            local chk = vgui.Create( "DCheckBox", row )
            chk:Dock( RIGHT )
            chk:DockMargin( padding, 0, padding, 0 )
            chk:SetWide( rowH )
            chk:SetChecked( cvarRef and cvarRef:GetBool() or false )
            function chk:OnChange( val )
                if def.cvar then RunConsoleCommand( def.cvar, val and "1" or "0" ) end
                emitUISound( val and 95 or 80 )
                if isfunction( def.postChangedFunc ) then def.postChangedFunc() end
            end
            -- Clicking the label toggles too
            function nameLbl:OnMousePressed()
                chk:Toggle()
            end

            -- Row-level reset handler for overlay button
            row._glee_doReset = function()
                if not cvarRef then return end
                local defaultStr = cvarRef:GetDefault() or "0"
                local numDefault = tonumber( defaultStr )
                local defaultBool = ( numDefault and numDefault ~= 0 ) or ( not numDefault and defaultStr ~= "0" and string.lower( defaultStr ) ~= "false" )
                chk:SetChecked( defaultBool )
                if def.cvar then RunConsoleCommand( def.cvar, defaultStr ) end
                emitUISound( 100 )
                if isfunction( def.postChangedFunc ) then def.postChangedFunc() end
            end

        elseif def.type == "slider" then
            local cvarRef = GetConVar( def.cvar )
            local min, max = def.min or 0, def.max or 1
            local decimals = def.decimals or 0

            local slider = vgui.Create( "DNumSlider", row )
            slider:Dock( FILL )
            slider:DockMargin( padding, 0, padding, 0 )
            slider:SetText( "" )
            slider:SetMin( min )
            slider:SetMax( max )
            slider:SetDecimals( decimals )
            slider:SetValue( cvarRef and cvarRef:GetFloat() or min )
            function slider:OnValueChanged( val )
                if def.changeWhenDone then
                    self._pendingVal = val
                    self._dirty = true
                    return
                end
                if def.cvar then
                    RunConsoleCommand( def.cvar, tostring( val ) )
                end
            end

            -- Row-level reset handler for overlay button
            row._glee_doReset = function()
                if not cvarRef then return end
                local defaultStr = cvarRef:GetDefault()
                local defaultNum = tonumber( defaultStr ) or min
                if defaultNum ~= -1 then -- auto-defaulting
                    defaultNum = math.Clamp( defaultNum, min, max )
                end
                slider:SetValue( defaultNum )
                -- Apply immediately regardless of changeWhenDone (explicit reset intent)
                if def.cvar then RunConsoleCommand( def.cvar, tostring( defaultNum ) ) end
                slider._dirty = nil
                emitUISound( 100 )
                if isfunction( def.postChangedFunc ) then def.postChangedFunc() end
            end
            if def.changeWhenDone then
                -- We can't rely on DNumSlider:OnMouseReleased; instead, buffer changes
                -- and commit when the left mouse is released (via Think), or when the
                -- TextArea confirms input (OnEnter/OnLoseFocus). This avoids mid-drag
                -- GUI scale reflows and matches how cl_banktop avoids mid-interaction churn.
                local function commitSlider()
                    if not def.cvar then return end
                    if not slider._dirty then return end
                    slider._dirty = nil
                    local v = slider._pendingVal or slider:GetValue()
                    RunConsoleCommand( def.cvar, tostring( v ) )
                    if isfunction( def.postChangedFunc ) then
                        def.postChangedFunc()
                    end
                    emitUISound( 90 )
                end
                function slider:Think()
                    self._wasDown = self._wasDown or false
                    local isDown = input.IsMouseDown( MOUSE_LEFT )
                    if self._wasDown and not isDown then
                        commitSlider()
                    end
                    self._wasDown = isDown
                end
                if IsValid( slider.TextArea ) then
                    function slider.TextArea:OnEnter()
                        local parent = self:GetParent()
                        parent._pendingVal = tonumber( self:GetValue() ) or parent:GetValue()
                        parent._dirty = true
                        commitSlider()
                    end
                    function slider.TextArea:OnLoseFocus()
                        local parent = self:GetParent()
                        parent._pendingVal = tonumber( self:GetValue() ) or parent:GetValue()
                        parent._dirty = true
                        commitSlider()
                    end
                end
            end

        else
            -- Unknown type: show a placeholder
            local warn = vgui.Create( "DLabel", row )
            warn:SetFont( "termhuntShopItemFont" )
            warn:SetText( string.format( "Unsupported setting type: %s", tostring( def.type ) ) )
            warn:SetTextColor( Color( 255, 80, 80 ) )
            warn:Dock( RIGHT )
            warn:SizeToContentsX()
        end

        -- reset icon defs
        local padR = RESET_ICON_PADR * scale
        local size = RESET_ICON_SIZE * scale
        local padT = RESET_ICON_PADTOP * scale

        -- Add reset overlay: draw the icon above children and capture clicks in a tiny hitbox.
        function row:PaintOver( w )
            -- icon rect (top-right of the row)
            local ix = w - padR - size
            local iy = padT
            surface.SetMaterial( resetIconMat )
            -- simple hover effect
            local mx, my = self:CursorPos()
            local hover = mx >= ix and mx <= ix + size and my >= iy and my <= iy + size
            local col = hover and RESET_ICON_COLOR_HOVER or RESET_ICON_COLOR
            surface.SetDrawColor( col )
            surface.DrawTexturedRect( ix, iy, size, size )
        end

        -- small invisible button to capture clicks reliably over children
        if not IsValid( row._glee_resetHitbox ) then
            local hit = vgui.Create( "DButton", row )
            hit:SetText( "" )
            hit:SetCursor( "hand" )
            function hit:Paint() end
            hit:SetZPos( 10000 )
            hit:SetTooltip( "Reset to default." )
            row._glee_resetHitbox = hit
        end
        function row:PerformLayout()
            -- position hitbox to match icon rect
            local w = self:GetWide()
            local ix = w - padR - size
            local iy = padT
            local hit = self._glee_resetHitbox
            if IsValid( hit ) then
                hit:SetPos( ix, iy )
                hit:SetSize( size, size )
            end
        end
        if IsValid( row._glee_resetHitbox ) then
            function row._glee_resetHitbox:DoClick()
                if isfunction( row._glee_doReset ) then row._glee_doReset() end
            end
            row:InvalidateLayout( true )
        end

        -- Add row to list and follow with a spacer gap
        settingsList:Add( row )
        addGap( gapY )
        return row
    end

    -- Category header helper
    local function addCategoryHeader( name )
        local headerRow = vgui.Create( "DPanel", settingsList )
        headerRow:SetTall( math.floor( rowH * 0.9 ) )
        headerRow:Dock( TOP )
        headerRow:DockMargin( 0, math.floor( gapY * 1.5 ), 0, math.floor( gapY * 0.5 ) )
        function headerRow:Paint( _, h )
            -- Match left indent of row labels by using the same padding value.
            surface.SetFont( "termhuntShopItemFontShadowed" )
            local _, textH = surface.GetTextSize( name )
            local textY = math.floor( ( h - textH ) * 0.5 )
            draw.SimpleText( name, "termhuntShopItemFontShadowed", padding, textY, GAMEMODE.shopStandards.white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
        end
        settingsList:Add( headerRow )
        addGap( math.floor( gapY * 0.5 ) )
    end

    -- Build categories and rows
    for _, cat in ipairs( settingsCategories ) do
        if istable( cat ) and isstring( cat.name ) then
            addCategoryHeader( cat.name )
        end
        if istable( cat ) and istable( cat.items ) then
            for _, def in ipairs( cat.items ) do
                if istable( def ) and def.cvar and def.type then
                    addRow( def )
                end
            end
        end
    end
end

-- Command-owned window creation (mirrors cl_banktop simplified flow)
local function createSettingsMenuSafely()
    local frame = vgui.Create( "DFrame" )
    terminator_Extras.easyClosePanel( frame )
    local w, h = glee_sizeScaled( FRAME_W_1080P * ( GAMEMODE.shopStandards.shpScale or 1 ), FRAME_H_1080P * ( GAMEMODE.shopStandards.shpScale or 1 ) )
    frame:SetSize( w, h )
    frame:Center()
    frame:MakePopup()
    frame:SetSizable( true )
    settingsMenu:Create( frame )
    LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )
    return frame
end

concommand.Add( "glee_settings_open", function()
    local newFrame = createSettingsMenuSafely()
    if not IsValid( newFrame ) then return end

    if IsValid( GAMEMODE.glee_SettingsMenu_Holder ) then
        GAMEMODE.glee_SettingsMenu_Holder:Remove()
    end

    GAMEMODE.glee_SettingsMenu_Holder = newFrame
    function newFrame:OnRemove()
        if GAMEMODE.glee_SettingsMenu_Holder == self then
            GAMEMODE.glee_SettingsMenu_Holder = nil
        end
    end
end )

local width, height = glee_sizeScaled( FRAME_W_1080P, FRAME_H_1080P )
list.Set( "DesktopWindows", "HuntersGlee_Settings", {
    title = "Glee Settings",
    icon = "icon16/wrench.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        if IsValid( window ) then window:Remove() end
        RunConsoleCommand( "glee_settings_open" )
    end
} )

