
-- TODO: impliment guilt effects

local developerVar = GetConVar( "developer" )
-- guilt effects are a dedicated server only mechanic
-- developer 1 enables them for testing
if not game.IsDedicated() and not developerVar:GetBool() then return end


-- only the width is ours to pick. the height is whatever the checker's contents
-- come to at that width, which moves with the fonts and the player's ui scale
local FRAME_W_1080P = 460


local function openGuiltChecker()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local scale  = GAMEMODE.shopStandards.shpScale or 1
    local frameW = glee_sizeScaled( FRAME_W_1080P * scale )

    local frame = vgui.Create( "DFrame" )
    frame:MakePopup()
    frame:SetTitle( "" )
    frame:ShowCloseButton( false )
    frame:SetDraggable( false )

    -- the checker's own box is the background, as it is a glee_hl2hudbox itself
    function frame:Paint() end

    local checker = vgui.Create( "glee_guiltchecker", frame )

    -- DFrame re-applies its own DockPadding ( 5, 29, 5, 5 ) as it lays out, so a
    -- docked child gets pushed down under the title bar and hangs off the bottom.
    -- We have no title bar, so the checker is placed by hand instead, and DFrame's
    -- layout is left unrun.
    function frame:PerformLayout( w, h )
        checker:SetPos( 0, 0 )
        checker:SetSize( w, h )

    end

    local function fitToChecker()
        frame:SetSize( frameW, checker:LayoutForWidth( frameW ) )
        frame:Center()

    end

    -- the description grows a line and the frame has to grow with it
    checker.OnLayoutChanged = fitToChecker
    fitToChecker()

    terminator_Extras.easyClosePanel( frame )

    -- open sound pitched lower the guiltier you are
    local days = GAMEMODE:GetPersistentGuilt( ply )
    local pitch = math.Clamp( 200 - math.floor( days * 4 ), 80, 200 )
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, pitch, 0.45 )

    return frame

end

concommand.Add( "glee_guiltchecker_open", function()
    local newFrame = openGuiltChecker()
    if not IsValid( newFrame ) then return end

    if IsValid( GAMEMODE.glee_GuiltChecker_Holder ) then
        GAMEMODE.glee_GuiltChecker_Holder:Remove()

    end

    GAMEMODE.glee_GuiltChecker_Holder = newFrame

    function newFrame:OnRemove()
        if GAMEMODE.glee_GuiltChecker_Holder ~= self then return end
        GAMEMODE.glee_GuiltChecker_Holder = nil

    end
end )

-- the spawnmenu icon's own window, which init throws away for the real one
local width, height = glee_sizeScaled( FRAME_W_1080P, FRAME_W_1080P * 0.5 )
list.Set( "DesktopWindows", "HuntersGlee_GuiltChecker", {
    title = "Guilt",
    icon = "icon16/heart_delete.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        if IsValid( window ) then window:Remove() end
        RunConsoleCommand( "glee_guiltchecker_open" )

    end
} )
