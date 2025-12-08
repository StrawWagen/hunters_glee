-- Tiny, clean taunt menu using the glee_radialselector VGUI element.
-- Opened by a console command (DesktopWindows just triggers the command).

local panelName = "Taunts!"

-- 1080p baseline sizes for easy tweaking (auto-scaled via glee_sizeScaled)
local TAUNTMENU_FRAME_W_1080P   = 700
local TAUNTMENU_FRAME_H_1080P   = 700
local TAUNTMENU_INNER_R_1080P   = 140
local TAUNTMENU_OUTER_R_1080P   = 300
local TAUNTMENU_MARGIN_Y_1080P  = 14

local danceActs = {
    { key = "dance",    label = "Dance" },
    { key = "muscle",   label = "Muscle" },
    { key = "laugh",    label = "Laugh" },
    { key = "robot",    label = "Robot" },
    { key = "pers",     label = "Surprised" },
    { key = "wave",     label = "Wave" },
    { key = "salute",   label = "Salute" },
    { key = "cheer",    label = "Cheer" },
    { key = "bow",      label = "Bow" },
    { key = "agree",    label = "Agree" },
    { key = "disagree", label = "Disagree" },
    { key = "forward",  label = "Forward" },
    { key = "halt",     label = "Halt" },
    { key = "becon",    label = "Beckon" },
    { key = "group",    label = "Regroup" },
    { key = "zombie",   label = "Zombie" },
}

local function createTauntMenu( container )
    local scale = GAMEMODE.shopStandards.shpScale
    local buttonMargin = glee_sizeScaled( nil, TAUNTMENU_MARGIN_Y_1080P * scale )
    local innerRadius = glee_sizeScaled( nil, TAUNTMENU_INNER_R_1080P * scale )
    local outerRadius = glee_sizeScaled( nil, TAUNTMENU_OUTER_R_1080P * scale )
    local hudPadding = terminator_Extras.defaultHudPaddingFromEdge

    -- Style the container frame
    container:DockPadding( 0, 0, 0, 0 )
    container:DockMargin( hudPadding, hudPadding, hudPadding, hudPadding )
    container:SetTitle( "" )
    container:ShowCloseButton( false )
    container:SetDraggable( false )
    container.Paint = function() end

    terminator_Extras.easyClosePanel( container )

    -- Create and configure the radial selector
    local wheel = vgui.Create( "glee_radialselector", container )
    wheel:Dock( FILL )
    wheel:DockMargin( 0, buttonMargin, 0, 0 )
    wheel:SetItems( danceActs )
    wheel:SetTitle( panelName )
    wheel:SetInnerRadius( innerRadius )
    wheel:SetOuterRadius( outerRadius )

    -- Handle selection
    function wheel:OnItemSelected( item )
        if not item then return end
        if not item.key then return end
        if #item.key == 0 then return end

        LocalPlayer():ConCommand( "act " .. item.key )

        local menuHolder = GAMEMODE.glee_TauntMenu_Holder
        if not IsValid( menuHolder ) then return end
        menuHolder:Remove()

    end
end

local function createTauntMenuSafely()
    local frame

    local success, err = xpcall( function()
        local scale = GAMEMODE.shopStandards.shpScale
        local frameW, frameH = glee_sizeScaled( TAUNTMENU_FRAME_W_1080P * scale, TAUNTMENU_FRAME_H_1080P * scale )

        frame = vgui.Create( "DFrame" )
        frame:SetSize( frameW, frameH )
        frame:Center()
        frame:MakePopup()
        frame:SetSizable( true )

        createTauntMenu( frame )

        LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    end, function( errorMsg )
        if IsValid( frame ) then
            frame:Remove()
        end
        return errorMsg

    end )

    if not success then
        return nil, err

    end

    return frame
end

concommand.Add( "glee_taunts_open", function()
    local newFrame, err = createTauntMenuSafely()

    if not IsValid( newFrame ) then
        if err then
            print( "[Hunters Glee] Failed to open taunt menu:", err )

        end
        return

    end

    -- Remove existing menu if present
    local existingMenu = GAMEMODE.glee_TauntMenu_Holder
    if IsValid( existingMenu ) then
        existingMenu:Remove()

    end

    -- Store reference and setup cleanup
    GAMEMODE.glee_TauntMenu_Holder = newFrame

    function newFrame:OnRemove()
        if GAMEMODE.glee_TauntMenu_Holder ~= self then return end
        GAMEMODE.glee_TauntMenu_Holder = nil

    end
end )

local width, height = glee_sizeScaled( TAUNTMENU_FRAME_W_1080P, TAUNTMENU_FRAME_H_1080P )

list.Set( "DesktopWindows", "HuntersGlee_TauntMenu", {
    title = "Taunt",
    icon = "icon32/tool.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        if IsValid( window ) then
            window:Remove()

        end
        if LocalPlayer():Health() <= 0 then
            LocalPlayer():PrintMessage( HUD_PRINTTALK, "Dead people can't taunt!" )
            return

        end
        RunConsoleCommand( "glee_taunts_open" )

    end
} )

