
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

    local frame = vgui.Create( "glee_hl2frame" )

    -- the checker brings its own padding, and its height is measured including it
    frame:DockPadding( 0, 0, 0, 0 )

    local checker = vgui.Create( "glee_guiltchecker", frame )
    checker:Dock( FILL )

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
