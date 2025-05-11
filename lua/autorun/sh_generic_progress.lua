
AddCSLuaFile()

if SERVER then

    util.AddNetworkString( "coolprogressbar_maintain" )

    function generic_KillProgressBar( user, id )
        if not IsValid( user ) then return end

        local progressKey = "progressBar_" .. id .. user:GetCreationID()
        local progressLastUpdateKey = "progressBarUpd_" .. id .. user:GetCreationID()

        user:SetNW2Bool( progressKey, false )
        user:SetNW2Float( progressLastUpdateKey, 0 )
        timer.Remove( progressLastUpdateKey )

        user[progressKey] = nil
        user[progressLastUpdateKey] = nil

    end

    -- speed is how often it networks
    -- chunkSize is how much percent is gained every "speed" seconds
    function generic_WaitForProgressBar( user, id, speed, chunkSize, data )

        data = data or {}
        local progInfo = data.progInfo or ""

        local progressKey = "progressBar_" .. id .. user:GetCreationID()
        local progressLastUpdateKey = "progressBarUpd_" .. id .. user:GetCreationID()

        local exitTheProgressBar = function()
            generic_KillProgressBar( user, id )

        end

        -- start
        if not user:GetNW2Bool( progressKey, nil ) then
            user:SetNW2Bool( progressKey, true )

            -- tear it down when updates stop
            timer.Create( progressLastUpdateKey, speed + 0.25, 0, function()
                if not IsValid( user ) then exitTheProgressBar() return end
                if user:GetNW2Bool( progressKey, false ) ~= true then exitTheProgressBar() return end
                local lastUpdate = user:GetNW2Float( progressLastUpdateKey, nil )
                if not lastUpdate then exitTheProgressBar() return end
                if ( lastUpdate + 0.5 ) < CurTime() then exitTheProgressBar() return end

            end )
        end

        -- progressing
        local progress = user[progressKey] or 0
        local oldProgress = progress

        user:SetNW2Float( progressLastUpdateKey, CurTime() )

        if ( user[progressLastUpdateKey] or 0 ) < CurTime() then
            net.Start( "coolprogressbar_maintain" )
                net.WriteString( progressKey )
                net.WriteString( progInfo )
                net.WriteFloat( progress )
                net.WriteFloat( speed )
                net.WriteFloat( chunkSize )
            net.Send( user )

            user[progressLastUpdateKey] = CurTime() + speed

            progress = progress + chunkSize
            user[progressKey] = progress

        end

        return progress, oldProgress

    end

end
if CLIENT then

    include( "autorun/client/cl_gleescalingfunc.lua" )

    local fontData = {
        font = "Arial",
        extended = false,
        size = glee_sizeScaled( nil, 30 ),
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
    surface.CreateFont( "huntersglee_barinfo", fontData )

    local barColor = Color( 255, 255, 255, 255 )
    local barBackground = Color( 50, 50, 50, 100 )

    local function PaintProgressBar( percent, info )
        local xOffs, yOffs = glee_sizeScaled( -200, 110 )
        local barWidth, barHeight = glee_sizeScaled( 400, 20 )
        barWidth = barWidth / 100

        local posX = ScrW() / 2
        local posY = ScrH() / 2

        local x = posX + xOffs
        local y = posY + yOffs

        if info and info ~= "" then
            surface.drawShadowedTextBetter( info, "huntersglee_barinfo", barColor, posX, y + 20, true )

        end

        surface.SetDrawColor( barBackground )
        surface.DrawRect( x, y, 100 * barWidth, barHeight )

        surface.SetDrawColor( barColor )
        surface.DrawRect( x, y, percent * barWidth, barHeight )

    end

    local isProgressBar
    local progressBarId
    local progressInfo
    local progressLastRecieved = 0
    local updateSpeed = 0
    local updateChunkSize = 0
    local progBarHookName = "termhunt_coolgenericprogressbar"

    local nextRecieve = 0

    local function cancelProgressBar()
        isProgressBar = nil
        progressBarId = nil
        progressInfo = nil
        progressLastRecieved = 0
        updateSpeed = 0
        updateChunkSize = 0
        hook.Remove( "PostDrawHUD", progBarHookName )

    end
    hook.Remove( "PostDrawHUD", progBarHookName )

    local function progBarDraw()
        if not isProgressBar then cancelProgressBar() return end
        local localPly = LocalPlayer()

        if localPly:GetNW2Bool( progressBarId, false ) ~= true then cancelProgressBar() return end

        local tillNextPredicted = ( nextUpdatePredictedTime - CurTime() ) / updateSpeed
        tillNextPredicted = math.Clamp( tillNextPredicted, 0, 1 )

        local predictedDest = progressLastRecieved + updateChunkSize

        local percentPredicting = Lerp( 1 - tillNextPredicted, progressLastRecieved, predictedDest )

        local clamped = math.Clamp( percentPredicting, 0, 100 )
        PaintProgressBar( clamped, progressInfo )

    end

    net.Receive( "coolprogressbar_maintain", function()
        if nextRecieve > CurTime() then return end
        nextRecieve = CurTime() + 0.01
        local idWeCanFindStuffAt = net.ReadString()

        if not idWeCanFindStuffAt then return end

        local boolAtId = LocalPlayer():GetNW2Bool( idWeCanFindStuffAt, nil )
        if boolAtId ~= true then return end

        isProgressBar = true
        progressBarId = idWeCanFindStuffAt

        progressInfo = net.ReadString()

        progressLastRecieved = net.ReadFloat()

        updateSpeed = net.ReadFloat()
        nextUpdatePredictedTime = CurTime() + updateSpeed

        updateChunkSize = net.ReadFloat()

        hook.Add( "PostDrawHUD", progBarHookName, progBarDraw )

    end )
end