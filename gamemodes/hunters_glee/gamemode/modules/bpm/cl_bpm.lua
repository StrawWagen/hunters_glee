
local GAMEMODE = GAMEMODE or GM
local dontDrawDefaultHud

local math_Clamp = math.Clamp
local CurTime = CurTime

-- draw heart synced with beats
-- 

local paddingFromEdge = terminator_Extras.defaultHudPaddingFromEdge
local screenHeight = ScrH()

local paddingAboveHealth = glee_sizeScaled( 96, nil )

local materialSize = glee_sizeScaled( nil, 55 )
materialSize = math.Clamp( materialSize, 0, 128 )
local overSize = materialSize * 0.6 -- box edge offset from material
local backgroundSize = materialSize + overSize


local heartTexture = Material( "vgui/hud/heartbeat.png", "smooth" )

local colorHealthy = Color( 255, 235, 20, 250 )
local boxColor = Color( 0, 0, 0, 76 )
local colorDying = Color( 255, 50, 50, 200 )
local boxColorDying = Color( 150, 25, 25, 76 )

local boxFlashTime = 0
local colorBox = colorHealthy
local boxAlphaDefault = boxColor.a
local boxAlpha = 0

local notBeatingTime = 0
local colorImage = colorHealthy
local imageAlpha = 0

hook.Add( "glee_cl_aliveplyhud", "glee_drawbpmcooler", function( ply, cur )

    if not dontDrawDefaultHud then
        if GAMEMODE.DontDrawDefaultHud then
            dontDrawDefaultHud = GAMEMODE.DontDrawDefaultHud

        end
        return

    elseif dontDrawDefaultHud() then
        return

    end

    local noHeartBeats

    if notBeatingTime < cur then
        noHeartBeats = true
        colorImage = colorDying
        imageAlpha = math_Clamp( imageAlpha + 1, 0, 255 )
        colorImage.a = imageAlpha

    else
        local decrease = 4
        if imageAlpha < 100 then
            decrease = 0.5

        end

        colorImage = colorHealthy
        imageAlpha = math_Clamp( imageAlpha - decrease, 0, 255 )
        colorImage.a = imageAlpha

    end

    if boxFlashTime > cur then
        if noHeartBeats then
            colorBox = boxColorDying

        end
    else
        colorBox = boxColor
        if noHeartBeats and boxFlashTime < cur - 0.1 then
            boxFlashTime = cur + 0.1
            boxAlpha = 150

        else
            boxAlpha = boxAlphaDefault

        end
    end

    colorBox.a = boxAlpha

    local offsetX = paddingFromEdge
    local texture = heartTexture

    local boxPosX = offsetX + paddingFromEdge / 2
    local boxPosY = screenHeight + -paddingFromEdge + -backgroundSize + -paddingAboveHealth

    draw.RoundedBox( 10, boxPosX, boxPosY, backgroundSize, backgroundSize, colorBox )

    surface.SetDrawColor( colorImage )
    surface.SetMaterial( texture )

    surface.DrawTexturedRect( boxPosX + overSize / 2, boxPosY + overSize / 2, materialSize, materialSize )

end )

hook.Add( "glee_cl_heartbeat", "glee_updatebeatindicator", function( ply )
    if ply:GetNWInt( "termHuntPlyBPM" ) <= 0 then
        notBeatingTime = CurTime()
        return

    end

    imageAlpha = 255

    boxFlashTime = CurTime() + 0.08
    notBeatingTime = CurTime() + 1

end )
