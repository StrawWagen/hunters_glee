-- draw battery indicator

local paddingFromEdge = terminator_Extras.defaultHudPaddingFromEdge
local paddingFromBottom  = terminator_Extras.defaultHudPaddingFromBottom
local screenHeight    = ScrH()

local materialSize = math.Clamp( glee_sizeScaled( nil, 48 ), 0, terminator_Extras.hl2hud.iconMaxSize )

local noBatteryTexture = Material( "vgui/hud/nobattery.png", "smooth" )
local drainingTexture  = Material( "vgui/hud/losingcharge.png", "smooth" )

local colorDraining = terminator_Extras.hl2hud.colorHappyYellow:Copy()
local colorDead     = terminator_Extras.hl2hud.colorRedUrgent:Copy()

local paddingJustHealth = glee_sizeScaled( nil, 260 )
local paddingHpAndArmor = glee_sizeScaled( nil, 550 )

local paintExpireTime = 0 -- CurTime() value until which the indicator should stay visible

local GAMEMODE = GAMEMODE or GM

local function createBatteryBox()
    if IsValid( terminator_Extras.gleeHud_BatteryBox ) then terminator_Extras.gleeHud_BatteryBox:Remove() end

    local box = vgui.Create( "glee_hl2hudbox", GetAutoHidingHUDPanel() )
    terminator_Extras.gleeHud_BatteryBox = box

    box:SetIconSize( materialSize )
    box:SetPaddingRatio( 0.4 )
    box:SetNormalBoxColor( terminator_Extras.hl2hud.colorBackground:Copy() )
    box:SetFlashBoxColor( terminator_Extras.hl2hud.colorBackgroundUrgent:Copy() )
    box:SetFlashDuration( 0.15 )

    function box:AdditionalThink()
        if LocalPlayer():Health() <= 0 then
            self:SetState( self.STATE_HIDDEN )
            return

        end
    end

end

hook.Add( "OnGamemodeLoaded", "glee_battery_create", createBatteryBox )
if terminator_Extras.gleeHud_BatteryBox then createBatteryBox() end

hook.Add( "glee_cl_aliveplyhud", "glee_drawbatterynotifs", function( ply, cur )
    local batteryBox = terminator_Extras.gleeHud_BatteryBox
    if not IsValid( batteryBox ) then return end

    -- texture and icon color follow armor state
    local hasBattery = ply:Armor() > 0
    local texture    = hasBattery and drainingTexture or noBatteryTexture
    local iconColor  = hasBattery and colorDraining or colorDead

    batteryBox:SetMaterial( texture )
    batteryBox:SetIconColor( iconColor )

    -- position shifts right when the armor bar is also visible
    local outOfWaySize = hasBattery and paddingHpAndArmor or paddingJustHealth
    local outOfWayAndExtraPadding   = paddingFromEdge + outOfWaySize
    local bgSize         = batteryBox:GetWide()
    local boxPosX        = outOfWayAndExtraPadding + paddingFromEdge -- double padding, one to get away from edge of screen, one to get away from other elements
    local boxPosY        = screenHeight - paddingFromBottom - bgSize
    batteryBox:SetPos( boxPosX, boxPosY )

    if paintExpireTime > cur then
        batteryBox:SetState( batteryBox.STATE_NORMAL )

    else
        batteryBox:SetState( batteryBox.STATE_FADING )

    end
end )


-- battery charge just changed, wake up the indicator
net.Receive( "glee_batterychangedcharge", function()
    paintExpireTime = net.ReadFloat()

    local batteryBox = terminator_Extras.gleeHud_BatteryBox
    if IsValid( batteryBox ) then
        batteryBox:SetState( batteryBox.STATE_FLASH )

    end
end )