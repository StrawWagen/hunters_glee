include( "shared.lua" )
include( "cl_shopstandards.lua" ) -- has to load almost first
include( "cl_shoppinggui.lua" )
include( "modules/cl_winscreen.lua" )
include( "modules/cl_scoreboard.lua" )
include( "modules/cl_modelscale.lua" )
include( "modules/cl_obfuscation.lua" )
include( "modules/cl_fallingwind.lua" )
include( "modules/cl_killfeedoverride.lua" )
include( "modules/cl_spectateflashlight.lua" )
include( "modules/spawnset/cl_spawnsetvote.lua" )
include( "modules/shopitems/cl_shopgobbler.lua" )
include( "modules/music/cl_music.lua" )
include( "modules/statuseffects/cl_statuseffects.lua" )
include( "modules/signalstrength/cl_signalstrength.lua" )
include( "modules/thirdpersonflashlight/cl_flashlight.lua" )
include( "modules/firsttimeplayers/cl_firsttimeplayers.lua" )

include( "modules/escaping/cl_escaping.lua" )
include( "modules/escaping/cl_escapecounts.lua" )

include( "modules/deadplayerfx/cl_souls.lua" )
include( "modules/deadplayerfx/cl_deaddesaturation.lua" )

include( "modules/contextmenu_widgets/cl_banktop.lua" )
include( "modules/contextmenu_widgets/cl_tauntmenu.lua" )
include( "modules/contextmenu_widgets/cl_settingsmenu.lua" )
include( "modules/contextmenu_widgets/cl_guiltchecker.lua" )

local GAMEMODE = GAMEMODE or GM

GAMEMODE.GLEE_FONT = "Arial"


if IsValid( terminator_Extras.glee_AutoHidingPanel ) then terminator_Extras.glee_AutoHidingPanel:Remove() end
terminator_Extras.glee_AutoHidingPanel = vgui.Create( "Panel", GetHUDPanel() )
local autoHidingPanel = terminator_Extras.glee_AutoHidingPanel
autoHidingPanel:Dock( FILL )

cvars.AddChangeCallback( "cl_drawhud", function( cvarName, oldValue, newValue )
    local shouldDraw = tobool( newValue )
    if shouldDraw then
        autoHidingPanel:SetVisible( true )

    else
        autoHidingPanel:SetVisible( false )

    end
end, "glee_cl_drawhud_hideplayernames" )

hook.Add()

function GetAutoHidingHUDPanel()
    return autoHidingPanel

end

include( "modules/clhud/cl_topleftinfo.lua" )
include( "modules/clhud/cl_bpm.lua" )
include( "modules/clhud/cl_battery.lua" )
include( "modules/clhud/cl_plynames.lua" )


-- from https://github.com/Facepunch/garrysmod/blob/e189f14c088298ca800136fcfcfaf5d8535b6648/garrysmod/lua/includes/modules/killicon.lua#L202
local killIconColor = Color( 255, 80, 0, 255 )
killicon.Add( "glee_skullpickup", "vgui/hud/glee_skullpickup", killIconColor )

local heartbeatVol = CreateClientConVar( "huntersglee_cl_heartbeat_volume", 1, true, false, "Heartbeat sound volume.", 0, 1 )
local baseDoHud = GetConVar( "cl_drawhud" )

local closestSpectateDistance = 15
local defaultSpectateDistance = 100
local maxSpectateZoomOut = 1500
local spectateZoomRate = 10

fontData = {
    font = GAMEMODE.GLEE_FONT,
    extended = false,
    size = glee_sizeScaled( nil, 40 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "huntersglee_finestpreyhint", fontData )

-- the RATE YOUR HJEAT BEATS OH GOD HE'S HERE
fontData = {
    font = GAMEMODE.GLEE_FONT,
    extended = false,
    size = glee_sizeScaled( nil, 80 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntBPMFont", fontData )

-- triumphant font
fontData = {
    font = GAMEMODE.GLEE_FONT,
    extended = false,
    size = glee_sizeScaled( nil, 50 ),
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntTriumphantFont", fontData )

GAMEMODE.currRoundState = GAMEMODE.currRoundState or GAMEMODE.ROUND_SETUP

function GAMEMODE:RoundState()
    return GAMEMODE.currRoundState

end

net.Receive( "glee_roundstate", function()
    local currState = GAMEMODE.currRoundState
    local newState = net.ReadInt( 8 )
    GAMEMODE.currRoundState = newState
    hook.Run( "glee_roundstatechanged", currState, newState )

end )

function GAMEMODE:TranslatedBind( bind )
    local lookedUp = input.LookupBinding( bind )
    if not lookedUp then return end

    local keyCode = input.GetKeyCode( lookedUp )
    -- unbound
    if not keyCode then return end

    local keyName = input.GetKeyName( keyCode )
    local phrase = language.GetPhrase( keyName )

    return true, phrase

end

local nextBeat = 0

local function beatThink( ply, cur )
    if nextBeat > cur then return end
    local BPM = ply:GetNWInt( "termHuntPlyBPM" )
    local beatTime = math.Clamp( 60 / BPM, 0, 2 )
    local pitch = BPM
    local volume = ( BPM / 200 ) + -0.1
    -- Apply user volume scaling (0..1)
    local volScale = math.Clamp( heartbeatVol:GetFloat(), 0, 1 )
    volume = math.Clamp( volume * volScale, 0, 1 )
    nextBeat = cur + beatTime

    if ply:Health() > 0 then
        ply:EmitSound( "hunters_glee/418788_name_heartbeat_single.wav", 100, pitch, volume )

    end

    return true, beatTime

end


-- THE BIG ONE!
-- Calls everything else above

local lastDisplayWinners = false

function doGleeHud()
    local ply = LocalPlayer()
    local cur = UnPredictedCurTime()
    local displayWinners = GetGlobalBool( "glee_DisplayWinners", false )

    if displayWinners then
        hook.Run( "glee_cl_paintplayers_stop", ply, cur )
        hook.Run( "glee_paintWinScreen", ply, cur )

    else
        if lastDisplayWinners then
            hook.Run( "glee_winScreenEnded" )
        end
        if not baseDoHud:GetBool() then
            lastDisplayWinners = displayWinners
            return
        end
        hook.Run( "glee_cl_topleftinfo", ply, cur )

        local spectating = ply:Health() <= 0

        if spectating == true then
            hook.Run( "glee_cl_paintplayers", ply, cur )

        else
            hook.Run( "glee_cl_paintplayers_whilealive", ply, cur )
            hook.Run( "glee_cl_aliveplyhud", ply, cur )

        end
    end
    lastDisplayWinners = displayWinners

end

-- override HudPaint to remove HUDDrawTargetID hook run
function GM:HUDPaint()
    doGleeHud()
    hook.Run( "HUDDrawPickupHistory" )
    hook.Run( "DrawDeathNotice", 0.85, 0.04 )

end

-- return in it for any addons that check it
hook.Add( "HUDDrawTargetID", "glee_no_targetid", function()
    return true

end )


-- manage heartbeat sounds
local function ClThink()
    local ply = LocalPlayer()
    local cur = UnPredictedCurTime()
    local spectating = ply:Health() <= 0

    if spectating then return end

    local didBeat, interval = beatThink( ply, cur )
    if didBeat then
        hook.Run( "glee_cl_heartbeat", ply, interval )

    end
end
hook.Add( "Think", "termhunt_clthink", ClThink )


-- weird bug where vms show up sometimes i think
hook.Add( "PreDrawViewModel", "glee_dontdrawviewmodelsWHENDEAD", function( _vm, ply )
    if ply:Health() > 0 then return end -- they are alive
    if ( ply:GetObserverMode() == OBS_MODE_IN_EYE ) and IsValid( ply:GetObserverTarget() ) then return end -- spectating another player

    return true -- dont draw vm

end )


-- flash the gmod window!
-- only flash when round ends, and when it goes into active
local oldState = nil
local toFlash = {
    [GAMEMODE.ROUND_ACTIVE]     = true,
    [GAMEMODE.ROUND_LIMBO]      = true,
}

hook.Add( "Think", "termhunt_alertroundchange", function()
    local currState = GAMEMODE:RoundState()
    if oldState == currState then return end
    oldState = currState

    if not toFlash[currState] then return end
    if system.HasFocus() then return end
    system.FlashWindow()

end )

function GAMEMODE:CanShowDefaultHud()
    local ply = LocalPlayer()

    if not ply.MAINSSHOPPANEL then return true end
    if not IsValid( ply.MAINSSHOPPANEL ) then return true end
    if ply.MAINSSHOPPANEL:IsMouseInputEnabled() then return nil end

    return true

end

local function IsSpectatingTerminator()
    local spectateTarget = LocalPlayer():GetObserverTarget()
    if not spectateTarget:IsNextBot() then return nil, spectateTarget end

    return true, spectateTarget

end

hook.Add( "CalcView", "glee_override_spectating_angles", function( ply, _, ang, fov )

    local isTerm, spectateTarget = IsSpectatingTerminator()
    local mode = ply:GetObserverMode()

    if ply:IsDrivingEntity() then -- yield to driving system
        return

    end

    if mode == OBS_MODE_CHASE and IsValid( spectateTarget ) then
        local pivot
        if spectateTarget.GetShootPos then
            pivot = spectateTarget:GetShootPos()

        else
            pivot = spectateTarget:WorldSpaceCenter()

        end

        local orbitDist = ply.glee_SpectateOrbitDistance
        if not orbitDist then
            local actualDistance = spectateTarget:BoundingRadius()
            local differenceToDefault = math.abs( defaultSpectateDistance - closestSpectateDistance )
            if differenceToDefault <= 50 then
                orbitDist = defaultSpectateDistance

            else
                orbitDist = math.Clamp( actualDistance + defaultSpectateDistance / 2, closestSpectateDistance, maxSpectateZoomOut )

            end
            ply.glee_SpectateOrbitDistance = orbitDist

        end

        local dir = -ang:Forward()
        local fallbackDrawPos = pivot + dir * closestSpectateDistance
        local desiredDrawPos = pivot + dir * orbitDist
        local filter = { spectateTarget }
        if spectateTarget.InVehicle and spectateTarget:InVehicle() then
            local vehicle = spectateTarget:GetVehicle()
            filter[#filter + 1] = vehicle
            if IsValid( vehicle:GetParent() ) then
                filter[#filter + 1] = vehicle:GetParent()

            end
        end

        ang.r = 0 -- no roll please

        local checkTr = {
            start = fallbackDrawPos,
            endpos = desiredDrawPos,
            filter = filter

        }

        local spectateTr = util.TraceLine( checkTr )
        -- just use the endpos if something fucked is going on ( evac heli )
        local cameraOrigin = ( spectateTr.Entity == spectateTarget ) and desiredDrawPos or spectateTr.HitPos

        local view = {
            origin = cameraOrigin,
            angles = ang,
            fov = fov,
            drawviewer = false,

        }
        return view

    end

    if mode == OBS_MODE_IN_EYE then
        if spectateTarget.InVehicle and spectateTarget:InVehicle() then
            local vehicle = spectateTarget:GetVehicle()
            local eyeAng = spectateTarget:EyeAngles()
            eyeAng = vehicle:WorldToLocalAngles( eyeAng )
            local view = {
                origin = spectateTarget:GetShootPos(),
                angles = eyeAng,
                fov = fov,
                znear = 8,
                drawviewer = false

            }
            return view

        elseif isTerm then
            local termAng
            if spectateTarget.GetEyeAngles then
                termAng = spectateTarget:GetEyeAngles()

            else
                termAng = spectateTarget:GetAngles()

            end

            local forward = termAng:Forward()

            local origin
            if spectateTarget.GetShootPos then
                origin = spectateTarget:GetShootPos()

            else
                origin = spectateTarget:WorldSpaceCenter()

            end

            local view = {
                origin = origin + forward * 15,
                angles = termAng,
                fov = fov,
                znear = 8,
                drawviewer = false

            }
            return view

        end
    end
end )


function GM:OnSpawnMenuOpen() -- when +menu is pressed
    local shouldShop
    local shouldSpawnMenu
    local localPly = LocalPlayer()

    if not localPly:IsAdmin() then
        shouldShop = true

    else
        local canSpawnMenu = hook.Call( "SpawnMenuOpen", self )
        -- q+shift+ctrl to open spawnmenu
        if canSpawnMenu and localPly:KeyDown( IN_DUCK ) and localPly:KeyDown( IN_SPEED ) then
            shouldShop = false
            shouldSpawnMenu = true

        else
            shouldShop = true

        end
    end
    if shouldShop then
        self:ShowShop()

    end
    if shouldSpawnMenu then
        if ( IsValid( g_SpawnMenu ) ) then
            g_SpawnMenu:Open()
            menubar.ParentTo( g_SpawnMenu )
        end

        hook.Call( "SpawnMenuOpened", self )

    end
end

-- misc binds
-- yoinked from darkrp so we do it right
local FKeyBinds = {
    ["noclip"] = "DropCurrentWeapon",
    ["invnext"] = "HandleZoomOut",
    ["invprev"] = "HandleZoomIn",
    ["toggle_zoom"] = "SendFakeInZoom",

}

function GM:PlayerBindPress( _, bind, _, code )
    if FKeyBinds[bind] then
        hook.Call( FKeyBinds[bind], GAMEMODE, code )

    end
end

function GM:DropCurrentWeapon( keyCode )
    if not keyCode then return end
    local name = "glee_dropweaponhold"
    timer.Create( name, 0.05, 0, function()
        if not input.IsButtonDown( keyCode ) then timer.Remove( name ) return end
        net.Start( "glee_dropcurrentweapon" )
        net.SendToServer()

    end )
end

function GM:HandleZoomIn()
    local ply = LocalPlayer()
    local following = ply:GetObserverTarget()
    if not IsValid( following ) then return end

    local oldDist = ply.glee_SpectateOrbitDistance
    if not oldDist then return end

    local rate = spectateZoomRate
    if ply:KeyDown( IN_SPEED ) then
        rate = rate * 5

    end
    ply.glee_SpectateOrbitDistance = math.Clamp( oldDist - rate, closestSpectateDistance, maxSpectateZoomOut )

end

function GM:HandleZoomOut()
    local ply = LocalPlayer()
    local following = ply:GetObserverTarget()
    if not IsValid( following ) then return end

    local oldDist = ply.glee_SpectateOrbitDistance
    if not oldDist then return end

    local rate = spectateZoomRate
    if ply:KeyDown( IN_SPEED ) then
        rate = rate * 5

    end
    ply.glee_SpectateOrbitDistance = math.Clamp( oldDist + rate, closestSpectateDistance, maxSpectateZoomOut )

end

function GM:SendFakeInZoom()
    local ply = LocalPlayer()
    local following = ply:GetObserverTarget()
    if not IsValid( following ) then return end

    net.Start( "glee_fakeinzoom" )
    net.SendToServer()

end
