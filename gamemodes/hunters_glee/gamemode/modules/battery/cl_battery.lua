-- draw battery indicator
-- 

local math_Clamp = math.Clamp

local paddingFromEdge = glee_sizeScaled( nil, 26 )
local screenHeight = ScrH()

local materialSize = glee_sizeScaled( nil, 48 )
materialSize = math.Clamp( materialSize, 0, 128 )
local overSize = materialSize * 0.4 -- box edge offset from material
local backgroundSize = materialSize + overSize


local noBatteryTexture = Material( "vgui/hud/nobattery.png", "smooth" )
local drainingTexture = Material( "vgui/hud/losingcharge.png", "smooth" )


local colorDraining = Color( 255, 235, 20, 250 )
local colorDead = Color( 255, 50, 50, 200 )
local boxColor = Color( 0, 0, 0, 76 )
local boxColorJustAppeared = Color( 100, 100, 50, 76 )

local colorGUI = colorDraining
local paintGUIFullAlpha = 0
local guiAlphaDefault = colorGUI.a
local guiAlpha = 0
local oldTexture

local nextDontDrawCheck = 0
local guiDead = 0
local dontDraw

hook.Add( "glee_aliveplyhud", "glee_drawbatterynotifs", function( ply, cur )

    if nextDontDrawCheck < cur then
        dontDraw = nil
        nextDontDrawCheck = cur + 1
        if hook.Run( "HUDShouldDraw", "CHudHealth" ) == false then dontDraw = true return end
        if hook.Run( "HUDShouldDraw", "CHudBattery" ) == false then dontDraw = true return end

    end
    if dontDraw then return end

    -- flash when first showing up
    if guiAlpha <= 0 then guiDead = 17 return end
    local boxColorInt = boxColor
    if guiDead > 0 then
        guiDead = guiDead + -1
        boxColorInt = boxColorJustAppeared

    end

    if paintGUIFullAlpha > cur then
        guiAlpha = guiAlphaDefault
        colorGUI.a = guiAlpha

    else
        guiAlpha = math_Clamp( guiAlpha + -2, 0, guiAlphaDefault )
        colorGUI.a = guiAlpha

    end

    local offsetX = paddingFromEdge + 260
    local texture = noBatteryTexture
    local hasBattery = ply:Armor() > 0
    if hasBattery then
        offsetX = paddingFromEdge + 550
        texture = drainingTexture

    end

    if texture ~= oldTexture then
        if hasBattery then
            colorGUI = colorDraining

        else
            colorGUI = colorDead

        end
    end

    oldTexture = texture

    local boxPosX = offsetX + paddingFromEdge
    local boxPosY = screenHeight + -paddingFromEdge + -backgroundSize

    draw.RoundedBox( 10, boxPosX, boxPosY, backgroundSize, backgroundSize, boxColorInt )

    surface.SetDrawColor( colorGUI )
    surface.SetMaterial( texture )

    surface.DrawTexturedRect( boxPosX + overSize / 2, boxPosY + overSize / 2, materialSize, materialSize )

end )

net.Receive( "glee_batterychangedcharge", function()
    local expireTime = net.ReadFloat()
    paintGUIFullAlpha = expireTime
    guiAlpha = guiAlphaDefault

end )