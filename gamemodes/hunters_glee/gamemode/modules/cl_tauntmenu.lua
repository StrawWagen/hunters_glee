-- AI SLOP FILE
-- Tiny, clean taunt menu styled like the spawnset voter. Clientside only.
-- Opened by a console command (DesktopWindows just triggers the command).

local panelName = "Taunts!"
local tauntMenu = {}

-- 1080p baseline sizes for easy tweaking (auto-scaled via glee_sizeScaled)
local TAUNTMENU_FRAME_W_1080P   = 700
local TAUNTMENU_FRAME_H_1080P   = 700
local TAUNTMENU_INNER_R_1080P   = 140
local TAUNTMENU_OUTER_R_1080P   = 300
local TAUNTMENU_WEDGE_SEGS      = 28
local TAUNTMENU_MARGIN_Y_1080P  = 14

local danceActs = {
    { key = "dance",   pretty = "Dance" },
    { key = "muscle",  pretty = "Muscle" },
    { key = "laugh",   pretty = "Laugh" },
    { key = "robot",   pretty = "Robot" },
    { key = "pers",    pretty = "Surprised" },
    { key = "wave",    pretty = "Wave" },
    { key = "salute",  pretty = "Salute" },
    { key = "cheer",   pretty = "Cheer" },
    { key = "bow",     pretty = "Bow" },
    { key = "agree",   pretty = "Agree" },
    { key = "disagree",pretty = "Disagree" },
    { key = "forward", pretty = "Forward" },
    { key = "halt",    pretty = "Halt" },
    { key = "becon",   pretty = "Beckon" },
    { key = "group",   pretty = "Regroup" },
    { key = "zombie",  pretty = "Zombie" },

}

-- no button paint helper needed for radial menu

function tauntMenu:Create( container )
    local scale = GAMEMODE.shopStandards.shpScale -- match shop scale cvar

    -- Scale and style to match cl_spawnsetvote, using glee_sizeScaled directly
    local buttonMargin = glee_sizeScaled( nil, TAUNTMENU_MARGIN_Y_1080P * scale )

    -- no pressableThink needed for radial menu
    local hudPadding = terminator_Extras.defaultHudPaddingFromEdge

    -- Container is a DFrame provided by DesktopWindows; style it simply
    container:DockPadding( 0, 0, 0, 0 )
    container:DockMargin( hudPadding, hudPadding, hudPadding, hudPadding )
    container:SetTitle( "" )
    container:ShowCloseButton( false )
    container:SetDraggable( false )

    terminator_Extras.easyClosePanel( container )

    function container:Paint() end

    -- Radial menu panel
    local wheel = vgui.Create( "DPanel", container )
    wheel:Dock( FILL )
    wheel:DockMargin( 0, buttonMargin, 0, 0 )
    wheel:SetMouseInputEnabled( true )

    local innerR = glee_sizeScaled( nil, TAUNTMENU_INNER_R_1080P * scale )
    local outerR = glee_sizeScaled( nil, TAUNTMENU_OUTER_R_1080P * scale )
    local segsPerWedge = TAUNTMENU_WEDGE_SEGS
    local startAngle = -90 -- start at top
    local switchSound = GAMEMODE.shopStandards.switchSound
    wheel.lastHoveredIdx = nil
    wheel.wasInRing = false

    local function angleToIndex( ang )
        local count = #danceActs
        local step = 360 / math.max( count, 1 )
        local a = ( ang - startAngle ) % 360
        return math.floor( a / step ) + 1
    end

    local function cursorPolar()
        local w, h = wheel:GetSize()
        local cx, cy = w * 0.5, h * 0.5
        local mx, my = wheel:CursorPos()
        local dx, dy = mx - cx, my - cy
        local r = math.sqrt( dx * dx + dy * dy )
        local ang = math.deg( math.atan2( dy, dx ) )
        return r, ang, cx, cy
    end

    function wheel:OnMousePressed( keyCode )
        if keyCode ~= MOUSE_LEFT then return end
        self.pressed = true
    end

    function wheel:OnMouseReleased( keyCode )
        if keyCode ~= MOUSE_LEFT then return end
        self.pressed = nil

        local r, ang = cursorPolar()
        if r < innerR or r > outerR then return end

        local idx = angleToIndex( ang )
        local act = danceActs[idx]
        if not act or not act.key or #act.key == 0 then return end

        LocalPlayer():ConCommand( "act " .. act.key )
        LocalPlayer():EmitSound( GAMEMODE.shopStandards.switchSound, 60, 50, 0.24 )
        if IsValid( GAMEMODE.glee_TauntMenu_Holder ) then
            GAMEMODE.glee_TauntMenu_Holder:Remove()
        end
    end

    function wheel:Think()
        local r, ang = cursorPolar()
        local inRing = ( r >= innerR and r <= outerR )
        if not inRing then
            if self.wasInRing then
                LocalPlayer():EmitSound( switchSound, 60, 80, 0.12 )
            end
            self.wasInRing = false
            self.lastHoveredIdx = nil
            return
        end

        local idx = angleToIndex( ang )
        if idx ~= self.lastHoveredIdx then
            LocalPlayer():EmitSound( switchSound, 60, 90, 0.12 )
            self.lastHoveredIdx = idx
        end
        self.wasInRing = true
    end

    local function drawSegment( cx, cy, rInner, rOuter, a0, a1, col )
        draw.NoTexture()
        surface.SetDrawColor( col )
        local poly = {}
        local arc = math.max( a1 - a0, 0.001 )
        local step = arc / segsPerWedge
        -- outer edge (a0 -> a1)
        for i = 0, segsPerWedge do
            local a = math.rad( a0 + step * i )
            poly[#poly + 1] = { x = cx + math.cos( a ) * rOuter, y = cy + math.sin( a ) * rOuter }
        end
        -- inner edge (a1 -> a0)
        for i = segsPerWedge, 0, -1 do
            local a = math.rad( a0 + step * i )
            poly[#poly + 1] = { x = cx + math.cos( a ) * rInner, y = cy + math.sin( a ) * rInner }
        end
        surface.DrawPoly( poly )
    end

    function wheel:Paint( w, h )
        local cx, cy = w * 0.5, h * 0.5
        local count = #danceActs
        if count <= 0 then return end

    local step = 360 / count
    local hoveredIdx = self.wasInRing and self.lastHoveredIdx or nil

    -- Wedges and labels
        for i = 1, count do
            local a0 = startAngle + ( i - 1 ) * step
            local a1 = a0 + step

            -- per-wedge base fill (prevents 360° poly artifacts)
            drawSegment( cx, cy, innerR, outerR, a0, a1, GAMEMODE.shopStandards.backgroundColor )

            if hoveredIdx == i then
                drawSegment( cx, cy, innerR, outerR, a0, a1, GAMEMODE.shopStandards.notHoveredOverlay )
                if self.pressed then
                    drawSegment( cx, cy, innerR, outerR, a0, a1, GAMEMODE.shopStandards.pressedItemOverlay )
                end
            end

            local mid = math.rad( ( a0 + a1 ) * 0.5 )
            local tx = cx + math.cos( mid ) * ( ( innerR + outerR ) * 0.5 )
            local ty = cy + math.sin( mid ) * ( ( innerR + outerR ) * 0.5 )

            local act = danceActs[i]
            if act and act.pretty and #act.pretty > 0 then
                draw.SimpleText( act.pretty, "termhuntShopItemFont", tx, ty, GAMEMODE.shopStandards.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            end
        end

        -- Force-draw title centered over the wheel
        draw.SimpleText( panelName, "termhuntShopItemFontShadowed", cx, cy, GAMEMODE.shopStandards.white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end
end

-- Optional programmatic open ( can be handy for binds/testing )
local function createTauntMenuSafely()
    local frame
    local ok, err = xpcall( function()
    frame = vgui.Create( "DFrame" )
    local w, h = glee_sizeScaled( TAUNTMENU_FRAME_W_1080P * GAMEMODE.shopStandards.shpScale, TAUNTMENU_FRAME_H_1080P * GAMEMODE.shopStandards.shpScale )
    frame:SetSize( w, h )
        frame:Center()
        frame:MakePopup()
        frame:SetSizable( true )
    tauntMenu:Create( frame )
    LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )
    end, function( e )
        if IsValid( frame ) then frame:Remove() end
        return e
    end )

    if not ok then return nil, err end
    return frame
end

concommand.Add( "glee_taunts_open", function()
    local newFrame, err = createTauntMenuSafely()
    if not IsValid( newFrame ) then
        -- Keep the old one if creation failed
        if err then print( "[Hunters Glee] Failed to open taunt menu:", err ) end
        return
    end

    -- Remove old in one place only after we have a new valid frame
    if IsValid( GAMEMODE.glee_TauntMenu_Holder ) then
        GAMEMODE.glee_TauntMenu_Holder:Remove()
    end

    GAMEMODE.glee_TauntMenu_Holder = newFrame
    function newFrame:OnRemove()
        if GAMEMODE.glee_TauntMenu_Holder == self then
            GAMEMODE.glee_TauntMenu_Holder = nil
        end
    end
end )

local width, height = glee_sizeScaled( TAUNTMENU_FRAME_W_1080P, TAUNTMENU_FRAME_H_1080P )

list.Set( "DesktopWindows", "HuntersGlee_TauntMenu", {
    title = "Taunt",
    icon = "icon32/tool.png", -- placeholder; author will replace
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        -- Follow sandbox pattern: clicking the icon runs a command.
        -- The command is responsible for creating the menu window.
        if IsValid( window ) then window:Remove() end
        if LocalPlayer():Health() <= 0 then LocalPlayer():PrintMessage( HUD_PRINTTALK, "Dead people can't taunt!" ) return end -- dead!
        RunConsoleCommand( "glee_taunts_open" )
    end
} )

