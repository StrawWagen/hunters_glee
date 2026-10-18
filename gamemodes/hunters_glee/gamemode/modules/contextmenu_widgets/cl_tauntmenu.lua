--[[
    The taunt wheel. Pick a wedge to play that act.

    Opened by the glee_taunts_open concommand, which its DesktopWindows icon runs, or held
    open with +glee_taunts, flicked toward a taunt and let go.
]]

local GAMEMODE = GAMEMODE or GM

local OUTER_RADIUS_1080P = 300

local danceActs = {
    { key = "dance",    label = "Dance", icon = Material( "vgui/hud/taunts/dance.png", "smooth" ) },
    { key = "muscle",   label = "Muscle", icon = Material( "vgui/hud/taunts/muscle.png", "smooth" ) },
    { key = "laugh",    label = "Laugh", icon = Material( "vgui/hud/taunts/laugh.png", "smooth" ) },
    { key = "robot",    label = "Robot", icon = Material( "vgui/hud/taunts/robot.png", "smooth" ) },
    { key = "pers",     label = "Surprised", icon = Material( "vgui/hud/taunts/surprised.png", "smooth" ) },
    { key = "wave",     label = "Wave", icon = Material( "vgui/hud/taunts/wave.png", "smooth" ) },
    { key = "salute",   label = "Salute", icon = Material( "vgui/hud/taunts/salute.png", "smooth" ) },
    { key = "cheer",    label = "Cheer", icon = Material( "vgui/hud/taunts/cheer.png", "smooth" ) },
    { key = "bow",      label = "Bow", icon = Material( "vgui/hud/taunts/bow.png", "smooth" ) },
    { key = "agree",    label = "Agree", icon = Material( "vgui/hud/taunts/agree.png", "smooth" ) },
    { key = "disagree", label = "Disagree", icon = Material( "vgui/hud/taunts/disagree.png", "smooth" ) },
    { key = "forward",  label = "Forward", icon = Material( "vgui/hud/taunts/forward.png", "smooth" ) },
    { key = "halt",     label = "Halt", icon = Material( "vgui/hud/taunts/halt.png", "smooth" ) },
    { key = "becon",    label = "Beckon", icon = Material( "vgui/hud/taunts/beckon.png", "smooth" ) },
    { key = "group",    label = "Regroup", icon = Material( "vgui/hud/taunts/regroup.png", "smooth" ) },
    { key = "zombie",   label = "Zombie", icon = Material( "vgui/hud/taunts/zombie.png", "smooth" ) },
}

local function buildTauntWheel( held )
    local wheel = vgui.Create( "glee_wheel" )

    local outer = wheel:Style():Scaled( OUTER_RADIUS_1080P )

    wheel:SetSize( outer * 2, outer * 2 )
    wheel:SetItems( danceActs )
    wheel:Center()

    function wheel:OnItemSelected( item )
        LocalPlayer():ConCommand( "act " .. item.key )
        self:Close()

    end

    if held then
        wheel:HoldAim()

    else
        wheel:MakePopup()
        terminator_Extras.easyClosePanel( wheel )

    end

    LocalPlayer():EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    return wheel

end

local function openTauntWheel( held )
    if LocalPlayer():Health() <= 0 then
        LocalPlayer():PrintMessage( HUD_PRINTTALK, "Dead people can't taunt!" )
        return

    end

    -- the old wheel's OnRemove clears the holder, so it has to go before the new one is stored
    if IsValid( GAMEMODE.glee_TauntMenu_Holder ) then
        GAMEMODE.glee_TauntMenu_Holder:Remove()

    end

    local newWheel = buildTauntWheel( held )
    GAMEMODE.glee_TauntMenu_Holder = newWheel

    function newWheel:OnRemove()
        if GAMEMODE.glee_TauntMenu_Holder ~= self then return end

        GAMEMODE.glee_TauntMenu_Holder = nil

    end
end

concommand.Add( "glee_taunts_open", function()
    openTauntWheel( false )

end )

concommand.Add( "+glee_taunts", function()
    openTauntWheel( true )

end )

concommand.Add( "-glee_taunts", function()
    local wheel = GAMEMODE.glee_TauntMenu_Holder
    if not IsValid( wheel ) then return end

    wheel:Release()

end )

local width, height = glee_sizeScaled( OUTER_RADIUS_1080P * 2, OUTER_RADIUS_1080P * 2 )
list.Set( "DesktopWindows", "HuntersGlee_TauntMenu", {
    title = "Taunt",
    icon = "hunters_glee/materials/vgui/hud/taunts/dance.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        -- the list gives us a window we don't want, the concommand builds the real one
        if IsValid( window ) then window:Remove() end

        RunConsoleCommand( "glee_taunts_open" )

    end
} )
