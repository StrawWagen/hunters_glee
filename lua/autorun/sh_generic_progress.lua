
AddCSLuaFile()

if SERVER then

    util.AddNetworkString( "coolprogressbar_start" )

    function generic_WaitForProgressBar( user, id, speed, rate )

        local progressKey = "progressBar_" .. id
        local progressLastUpdateKey = "progressBarUpd_" .. id

        local exitTheProgressBar = function()
            if not IsValid( user ) then return end
            user:SetNW2Bool( progressKey, nil )
            user:SetNW2Int( progressKey, nil )
            user:SetNW2Int( progressLastUpdateKey, nil )
            timer.Remove( progressLastUpdateKey )

            user[ progressKey ] = nil
            user[ progressLastUpdateKey ] = nil

        end

        if not user:GetNWBool( progressKey, nil ) then
            user:SetNW2Bool( progressKey, true )

            timer.Simple( 0, function()
                net.Start( "coolprogressbar_start" )
                    net.WriteString( progressKey )
                net.Send( user )

            end )

            timer.Create( progressLastUpdateKey, speed, 0, function()
                if not IsValid( user ) then exitTheProgressBar() return end
                local lastUpdate = user:GetNWInt( progressLastUpdateKey, nil )
                if not lastUpdate then exitTheProgressBar() return end
                if ( lastUpdate + 1 ) < CurTime() then exitTheProgressBar() return end

            end )
        end

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
    local resurrectBar = Color( 255, 255, 255, 200 )

    local function PaintProgressBar( percent )
        local PosX = ScrW() / 2
        local PosY = ScrH() / 2

        local x = PosX + -200
        local y = PosY + 110

        surface.SetDrawColor( resurrectBar )
        surface.DrawRect( x, y, percent * 4, 50 )

    end

    local isProgressBar = nil
    local progressBarId = nil

    local nextRecieve = 0

    net.Receive( "coolprogressbar_start", function()
        if nextRecieve > CurTime() then return end
        nextRecieve = CurTime() + 0.01
        local idWeCanFindStuffAt = net.ReadString()

        if not idWeCanFindStuffAt then return end

        local boolAtId = LocalPlayer():GetNW2Bool( idWeCanFindStuffAt, nil )
        if boolAtId ~= true then return end

        isProgressBar = true
        progressBarId = idWeCanFindStuffAt

    end )

    local function cancelProgressBar()
        isProgressBar = nil
        progressBarId = nil

    end

    hook.Add( "PostDrawHUD", "termhunt_coolgenericprogressbar", function()
        if not isProgressBar then cancelProgressBar() return end
        if LocalPlayer():GetNW2Bool( progressBarId, nil ) ~= true then cancelProgressBar() return end

        local percent = LocalPlayer():GetNW2Int( progressBarId, 0 )
        percent = math.Clamp( percent, 0, 100 )

        PaintProgressBar( percent )

    end )
end