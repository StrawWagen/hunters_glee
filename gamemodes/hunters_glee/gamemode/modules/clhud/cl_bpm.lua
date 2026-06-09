local GAMEMODE = GAMEMODE or GM

local math_Clamp = math.Clamp
local CurTime    = CurTime

-- draw heart synced with beats

local paddingFromEdge    = terminator_Extras.defaultHudPaddingFromEdge
local screenHeight       = ScrH()
local paddingAboveHealth = glee_sizeScaled( 96, nil )

local materialSize = math.Clamp( glee_sizeScaled( nil, 55 ), 0, terminator_Extras.hl2hud.iconMaxSize )

local heartTexture = Material( "vgui/hud/heartbeat.png", "smooth" )

local colorHealthy = terminator_Extras.hl2hud.colorHappyYellow:Copy()
local colorDying   = terminator_Extras.hl2hud.colorRedUrgent:Copy()

local notBeatingTime = 0
local imageAlpha     = 0

local function createBpmBox()
    if IsValid( terminator_Extras.gleeHud_BpmBox ) then terminator_Extras.gleeHud_BpmBox:Remove() end

    local box = vgui.Create( "glee_hl2hudbox", GetAutoHidingHUDPanel() )
    terminator_Extras.gleeHud_BpmBox = box

    box:SetIconSize( materialSize )
    box:SetPaddingRatio( 0.6 )
    box:SetMaterial( heartTexture )
    box:SetNormalBoxColor( terminator_Extras.hl2hud.colorBackground:Copy() )
    box:SetUrgentBoxColor( terminator_Extras.hl2hud.colorBackgroundUrgent:Copy() )
    box:SetFlashDuration( 0.08 )

    local bgSize       = box:GetWide()
    local innerPadding = paddingFromEdge / 2
    local boxPosX      = paddingFromEdge + innerPadding
    local boxPosY      = screenHeight - paddingFromEdge - bgSize - paddingAboveHealth
    box:SetPos( boxPosX, boxPosY )

    function box:AdditionalThink()
        if LocalPlayer():Health() <= 0 then
            self:SetState( self.STATE_HIDDEN )
            return

        end
    end

end

hook.Add( "OnGamemodeLoaded", "glee_bpm_create", createBpmBox )
if terminator_Extras.gleeHud_BpmBox then createBpmBox() end


hook.Add( "glee_cl_aliveplyhud", "glee_drawbpmcooler", function( ply, cur )
    local bpmBox = terminator_Extras.gleeHud_BpmBox
    if not IsValid( bpmBox ) then return end

    local noHeartBeats = notBeatingTime < cur

    -- Icon alpha is beat-driven and managed here; state alpha scales it further.
    if noHeartBeats then -- HEART ATTACK: icon fades in to full red
        imageAlpha   = math_Clamp( imageAlpha + 1, 0, 255 )
        colorDying.a = imageAlpha
        bpmBox:SetIconColor( colorDying )
        bpmBox:SetState( bpmBox.STATE_URGENT )

    else -- healthy: icon fades out between beats
        local decrease = imageAlpha < 100 and 0.5 or 4
        imageAlpha      = math_Clamp( imageAlpha - decrease, 0, 255 )
        colorHealthy.a  = imageAlpha
        bpmBox:SetIconColor( colorHealthy )
        bpmBox:SetState( bpmBox.STATE_NORMAL )

    end
end )


-- beat just happened, pulse the heart
hook.Add( "glee_cl_heartbeat", "glee_updatebeatindicator", function( ply )
    if ply:GetNWInt( "termHuntPlyBPM" ) <= 0 then
        notBeatingTime = CurTime()
        return

    end

    imageAlpha     = 255
    notBeatingTime = CurTime() + 1

    local bpmBox = terminator_Extras.gleeHud_BpmBox
    if IsValid( bpmBox ) then
        bpmBox:SetState( bpmBox.STATE_FLASH )

    end
end )
