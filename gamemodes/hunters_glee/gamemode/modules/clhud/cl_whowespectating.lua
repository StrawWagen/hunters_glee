--[[------------------------------------
    Who you are watching, or what you have taken over, in a box across the top of the
    screen while you are dead.

    A glee_hl2hudbox like the top left lane's, so it reads as the same hud. It never
    fades: it is either showing who you are watching or it is gone.
--]]-------------------------------------

local GAMEMODE = GAMEMODE or GM

local FONT = "mediumLarge"

local topPadding = terminator_Extras.defaultHudPaddingFromBottom * 2 -- level with the top left lane
local gapBelowHud = terminator_Extras.glee_HL2Hud.laneSpacing

local box

local function createBox()
    if IsValid( box ) then box:Remove() end

    box = vgui.Create( "glee_hl2hudbox", GetAutoHidingHUDPanel() )
    box:SetIconFont( FONT )
    box._myStyle = "soulthought" -- only ever drawn while dead

end

hook.Add( "OnGamemodeLoaded", "glee_whowespectating_create", createBox )
if GAMEMODE then createBox() end

-- Players carry their own name. Nextbots and NPCs don't have one the client can read, so
-- the server sends what GM:GetNameOfBot made of whoever is being watched
local function watchedName()
    local sent = LocalPlayer():GetNW2String( "glee_currentlySpectatingName", "" )
    if sent ~= "" then return sent end

    return "Something"

end

-- What the box says, or nil when there is nothing to watch
local function watchingLine( ply )
    local driving = ply:GetDrivingEntity()
    if IsValid( driving ) then
        return "Posessing\n" .. watchedName()

    end

    if IsValid( ply:GetObserverTarget() ) then
        return "Spectating\n" .. watchedName()

    end
end

local function hideBox()
    if not IsValid( box ) then return end

    box:SetState( box.STATE_HIDDEN )

end

hook.Add( "glee_cl_deadplyhud", "glee_whowespectating_draw", function( ply, _cur )
    if not IsValid( box ) then return end

    local line = watchingLine( ply )
    if not line or not GAMEMODE:CanShowDefaultHud() then
        hideBox()
        return

    end

    box:SetText( line )
    box:AutoSize()
    box:SetState( box.STATE_NORMAL )

    local x = ScrW() * 0.5 - box:GetWide() * 0.5
    local y = topPadding

    -- a long Misery name stretches the top left lane out to here, and the lane shrinks
    -- back smoothly as it fades, so this slides rather than snaps
    local inTheWay = GAMEMODE:HudSpaceInMyWay( x, y, box:GetWide(), box:GetTall() )
    if inTheWay then
        y = inTheWay + gapBelowHud

    end

    box:SetPos( x, y )

end )

-- The panel keeps painting whether or not glee_cl_deadplyhud runs, and it stops running
-- on a respawn and on the win screen, so both have to put it away
hook.Add( "glee_cl_aliveplyhud", "glee_whowespectating_hide", hideBox )
hook.Add( "glee_paintWinScreen", "glee_whowespectating_hide", hideBox )
