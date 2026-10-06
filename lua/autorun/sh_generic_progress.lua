
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

    --[[------------------------------------
        The bar under the crosshair. Each message is the server's progress, plus how big
        and how far apart its steps are. Between messages the bar runs at that rate on its
        own, never past the step the server's on, so ping only ever makes it wait, never
        jump or go back.
    --]]-------------------------------------

    local BAR_W_1080P = 400
    local BAR_H_1080P = 12
    local DROP_1080P = 110 -- below the crosshair
    local INFO_FONT = "small"

    local lingerMin = 0.4 -- before the server's NW2Bool arrives, see stillActive
    local fadeSpeed = 6 -- of alpha, 0 to 1, per second

    local hookName = "glee_genericprogressbar"

    -- the one on screen, nil when there isn't one
    local bar

    -- The server's NW2Bool, under the bar's id, is true for as long as it holds the bar's
    -- progress. It can land after the first message, so until it does, recent messages count
    local function stillActive()
        if LocalPlayer():GetNW2Bool( bar.id, false ) then
            bar.seenActive = true
            return true

        end

        if bar.seenActive then return false end

        return RealTime() - bar.lastHeard < math.max( bar.interval * 2, lingerMin )

    end

    local function drawBar()
        local active = stillActive()

        bar.alpha = math.Approach( bar.alpha, active and 1 or 0, fadeSpeed * RealFrameTime() )
        if not active and bar.alpha <= 0 then
            bar = nil
            hook.Remove( "PostDrawHUD", hookName )
            return

        end

        -- the server's own rate, sped up by how many steps behind a late message left it
        local behind = bar.ahead - bar.shown
        if behind > 0 then
            local catchUp = math.max( 1, behind / bar.step )
            bar.shown = math.Approach( bar.shown, bar.ahead, bar.rate * catchUp * RealFrameTime() )

        end

        local style = terminator_Extras.glee_Style( "generic" )
        local RNDX = terminator_Extras.glee_RNDX

        local pad = style:Metric( "blockPadding" )
        local barW, barH = style:Scaled( BAR_W_1080P ), style:Scaled( BAR_H_1080P )

        local hasInfo = bar.info ~= ""
        local infoH = 0
        if hasInfo then
            local _, textH = style:Measure( bar.info, INFO_FONT )
            infoH = textH + pad

        end

        local w, h = barW + pad * 2, infoH + barH + pad * 2
        local x, y = ScrW() * 0.5 - w * 0.5, ScrH() * 0.5 + style:Scaled( DROP_1080P )

        local oldMultiplier = surface.GetAlphaMultiplier()
        surface.SetAlphaMultiplier( oldMultiplier * bar.alpha )

        style:Background( x, y, w, h, "bg", nil, 1, "idle", bar )

        if hasInfo then
            style:Draw( bar.info, INFO_FONT, ScrW() * 0.5, y + pad )

        end

        local barX, barY = x + pad, y + pad + infoH
        local radius = style:Metric( "boxCornerRadius" )
        RNDX.Rect( barX, barY, barW, barH ):Rad( radius ):Color( style:BackdropColor( "bgDark" ) ):Draw()

        local fraction = math.Clamp( bar.shown / 100, 0, 1 )
        if fraction > 0 then
            RNDX.Rect( barX, barY, barW * fraction, barH ):Rad( radius ):Color( style:Color( "happy" ) ):Draw()

        end

        surface.SetAlphaMultiplier( oldMultiplier )

    end

    net.Receive( "coolprogressbar_maintain", function()
        local id = net.ReadString()
        local info = net.ReadString()
        local progress = net.ReadFloat()
        local interval = net.ReadFloat()
        local step = net.ReadFloat()

        -- a new bar, or this one started over, which the server does under the same id
        if not bar or bar.id ~= id or progress < bar.confirmed then
            bar = { id = id, shown = progress, alpha = bar and bar.alpha or 0 }
            hook.Add( "PostDrawHUD", hookName, drawBar )

        end

        bar.info = info
        bar.confirmed = progress
        bar.ahead = progress + step -- the server counts this step the moment it sends it
        bar.step = math.max( step, 0.001 )
        bar.interval = interval
        bar.rate = bar.step / math.max( interval, 0.001 )
        bar.lastHeard = RealTime()

    end )
end