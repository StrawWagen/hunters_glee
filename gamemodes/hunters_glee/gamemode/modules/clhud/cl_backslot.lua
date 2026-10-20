-- shows while something's carried on the back, see glee_carrying/sh_carrying.lua

local glee_Carrying = terminator_Extras.glee_Carrying
local hl2 = terminator_Extras.glee_Style( "hl2" )

local materialSize = math.Clamp( glee_sizeScaled( nil, 48 ), 0, hl2:Settings().iconMaxSize ) -- the battery's

local backTexture = Material( "vgui/hud/glee_backslot.png", "smooth" ) -- icon's not in yet

-- full when what's on the back changes, settling to dim like the resting heart
local restingAlpha = 110
local settleRate = 4 -- per second, of exponential easing

-- and a shake left and right, as glee_countbox's, shrinking as it runs out
local shakeMaxSize = glee_sizeScaled( nil, 2 ) -- per second of shake left
local shakeTime = 2

local iconColor = Color( 0, 0, 0, 0 )
local iconAlpha = restingAlpha
local lastOnBack = NULL
local shakeUntil = 0

local function createBackSlotBox()
    if IsValid( terminator_Extras.gleeHud_BackSlotBox ) then terminator_Extras.gleeHud_BackSlotBox:Remove() end

    local box = vgui.Create( "glee_hudbox", GetAutoHidingHUDPanel() )
    terminator_Extras.gleeHud_BackSlotBox = box

    box:SetIconSize( materialSize )
    box:SetMaterial( backTexture )
    box:SetFadeSpeed( 500 ) -- of 255 a second, so it's gone in about half a second

    function box:AdditionalThink()
        if LocalPlayer():Health() <= 0 then
            self:SetState( self.STATE_HIDDEN )
            return

        end
    end
end

hook.Add( "OnGamemodeLoaded", "glee_backslot_create", createBackSlotBox )
if terminator_Extras.gleeHud_BackSlotBox then createBackSlotBox() end

-- NULL when nothing is
local function getWeaponOnBack( ply )
    for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( ply ) ) do
        if wep:GetOnBack() then return wep end

    end

    return NULL

end

hook.Add( "glee_cl_aliveplyhud", "glee_drawbackslot", function( ply )
    local backBox = terminator_Extras.gleeHud_BackSlotBox
    if not IsValid( backBox ) then return end

    local onBack = getWeaponOnBack( ply )
    if onBack ~= lastOnBack then
        lastOnBack = onBack
        iconAlpha = 255
        shakeUntil = RealTime() + shakeTime
        backBox:SetState( backBox.STATE_FLASH )

    end

    local xOffset = 0
    if shakeUntil > RealTime() then
        local shakeScale = ( shakeUntil - RealTime() ) * shakeMaxSize
        xOffset = math.Rand( -shakeScale, shakeScale )

    end

    -- over the heart, which places itself
    local bpmBox = terminator_Extras.gleeHud_BpmBox
    if IsValid( bpmBox ) then
        local heartX, heartY = bpmBox:GetPos()
        local size = backBox:GetWide()
        local gap = backBox:Style():Metric( "laneSpacing" )
        backBox:SetPos( heartX + xOffset, heartY - gap - size )

    end

    iconAlpha = iconAlpha + ( restingAlpha - iconAlpha ) * ( 1 - math.exp( -settleRate * RealFrameTime() ) )

    local roleColor = backBox:Style():Color( "happy" )
    iconColor.r = roleColor.r
    iconColor.g = roleColor.g
    iconColor.b = roleColor.b
    iconColor.a = iconAlpha
    backBox:SetContentColor( iconColor )

    if IsValid( onBack ) then
        backBox:SetState( backBox.STATE_NORMAL )

    else
        backBox:SetState( backBox.STATE_FADING )

    end
end )
