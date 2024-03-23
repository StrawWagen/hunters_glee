
AddCSLuaFile()

if SERVER then

    util.AddNetworkString( "coolprogressbar_start" )

    function generic_WaitForProgressBar( user, id, speed, rate, data )

        local progressKey = "progressBar_" .. id .. user:GetCreationID()
        local progressLastUpdateKey = "progressBarUpd_" .. id .. user:GetCreationID()

        local exitTheProgressBar = function()
            if not IsValid( user ) then return end

            if data and data.onEnd then
                data.onEnd( user[ progressKey ] )

            end

            user:SetNW2Bool( progressKey, false )
            user:SetNW2Int( progressKey, false )
            user:SetNW2Int( progressLastUpdateKey, 0 )
            timer.Remove( progressLastUpdateKey )

            user[ progressKey ] = nil
            user[ progressLastUpdateKey ] = nil

        end

        -- start
        if not user:GetNWBool( progressKey, nil ) then
            user:SetNW2Bool( progressKey, true )

            timer.Simple( 0, function()
                net.Start( "coolprogressbar_start" )
                    net.WriteString( progressKey )
                    net.WriteFloat( speed )
                    net.WriteFloat( rate )
                net.Send( user )

            end )

            timer.Create( progressLastUpdateKey, speed, 0, function()
                if not IsValid( user ) then exitTheProgressBar() return end
                local lastUpdate = user:GetNWInt( progressLastUpdateKey, nil )
                if not lastUpdate then exitTheProgressBar() return end
                if ( lastUpdate + 1 ) < CurTime() then exitTheProgressBar() return end

            end )
        end

        -- progressing
        user:SetNW2Int( progressLastUpdateKey, CurTime() )
        local progress = user[ progressKey ] or 0

        if ( user[progressLastUpdateKey] or 0 ) < CurTime() then
            user[progressLastUpdateKey] = CurTime() + speed

            progress = progress + rate
            user[ progressKey ] = progress

        end

        user:SetNW2Int( progressKey, progress )

        return progress

    end

end
if CLIENT then
    local barColor = Color( 255, 255, 255, 255 )
    local barBackground = Color( 50, 50, 50, 100 )

    local function PaintProgressBar( percent )
        local xOffs, yOffs = glee_sizeScaled( -200, 110 )
        local barWidth, barHeight = glee_sizeScaled( 400, 20 )
        barWidth = barWidth / 100

        local PosX = ScrW() / 2
        local PosY = ScrH() / 2

        local x = PosX + xOffs
        local y = PosY + yOffs

        surface.SetDrawColor( barBackground )
        surface.DrawRect( x, y, 100 * barWidth, barHeight )

        surface.SetDrawColor( barColor )
        surface.DrawRect( x, y, percent * barWidth, barHeight )

    end

    local isProgressBar = nil
    local progressBarId = nil
    local updateSpeed = 0
    local updateRate = 0
    local oldPercent = 0
    local progBarHookName = "termhunt_coolgenericprogressbar"

    local nextRecieve = 0

    local function cancelProgressBar()
        isProgressBar = nil
        progressBarId = nil
        updateSpeed = 0
        updateRate = 0
        oldPercent = 0
        hook.Remove( "PostDrawHUD", progBarHookName )

    end
    hook.Remove( "PostDrawHUD", progBarHookName )

    local function progBarDraw()
        if not isProgressBar then cancelProgressBar() return end
        if LocalPlayer():GetNW2Bool( progressBarId, false ) ~= true then cancelProgressBar() return end

        local percent = LocalPlayer():GetNW2Int( progressBarId, 0 )
        local absed = math.abs( updateSpeed - 1 ) / 65
        local lerped = Lerp( absed, oldPercent, percent + updateRate )
        oldPercent = lerped
        local percentFinal = math.Clamp( lerped, 0, 100 )

        PaintProgressBar( percentFinal )

    end

    net.Receive( "coolprogressbar_start", function()
        if nextRecieve > CurTime() then return end
        nextRecieve = CurTime() + 0.01
        local idWeCanFindStuffAt = net.ReadString()

        if not idWeCanFindStuffAt then return end

        local boolAtId = LocalPlayer():GetNW2Bool( idWeCanFindStuffAt, nil )
        if boolAtId ~= true then return end

        isProgressBar = true
        progressBarId = idWeCanFindStuffAt

        updateSpeed = net.ReadFloat()
        updateRate = net.ReadFloat()

        hook.Add( "PostDrawHUD", progBarHookName, progBarDraw )

    end )
end