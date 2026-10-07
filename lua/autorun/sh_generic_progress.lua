
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

    -- chunked like the suit power meter, see glee_meter. One chunk per server step, until
    -- the steps are too fine to chunk and it becomes a plain bar
    local BAR_W_1080P = 300
    local BAR_H_1080P = 8
    local MAX_CHUNKS = 25
    local CHUNK_GAP_1080P = 3
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

        local pad = style:Metric( "blockPadding" )
        local barH = style:Scaled( BAR_H_1080P )
        local chunks = math.max( math.Round( 100 / bar.step ), 1 )
        local smooth = chunks > MAX_CHUNKS

        -- whole pixels for every chunk and gap, or rounding makes the gaps differ by a pixel.
        -- The bar shrinks a little to whatever whole chunks fit
        local gap = smooth and 0 or style:Scaled( CHUNK_GAP_1080P )
        local chunkW = math.max( 1, math.floor( ( style:Scaled( BAR_W_1080P ) + gap ) / chunks ) - gap )
        local barW = smooth and style:Scaled( BAR_W_1080P ) or chunks * ( chunkW + gap ) - gap

        local centreX = ScrW() * 0.5
        local top = math.Round( ScrH() * 0.5 + style:Scaled( DROP_1080P ) )

        local oldMultiplier = surface.GetAlphaMultiplier()
        surface.SetAlphaMultiplier( oldMultiplier * bar.alpha )

        -- the info gets a box of its own above the bar's
        if bar.info ~= "" then
            local textPad = math.Round( pad * 0.5 )
            local textW, textH = style:Measure( bar.info, INFO_FONT )
            local infoW, infoH = textW + textPad * 4, textH + textPad * 2
            local infoX = math.Round( centreX - infoW * 0.5 )

            style:Background( infoX, top, infoW, infoH, "bg", nil, 1, "idle", bar.infoCache )
            -- not style:Draw, which always shadows
            draw.DrawText( bar.info, style:Font( INFO_FONT ), centreX, top + textPad, style:Color( "text" ), TEXT_ALIGN_CENTER )

            top = top + infoH + style:Metric( "laneSpacing" )

        end

        local boxW, boxH = barW + pad * 2, barH + pad * 2
        local boxX = math.Round( centreX - boxW * 0.5 )
        local barX, barY = boxX + pad, top + pad

        style:Background( boxX, top, boxW, boxH, "bg", nil, 1, "idle", bar )

        local fill = style:Color( "happy" )
        local empty = style:BackdropColor( "bgDark" )
        local fraction = math.Clamp( bar.shown / 100, 0, 1 )

        if smooth then
            surface.SetDrawColor( empty )
            surface.DrawRect( barX, barY, barW, barH )
            surface.SetDrawColor( fill )
            surface.DrawRect( barX, barY, math.Round( barW * fraction ), barH )

        else
            -- floored, so the last chunk only lights once it's really done
            local lit = math.floor( fraction * chunks + 0.001 )

            for index = 1, chunks do
                surface.SetDrawColor( index <= lit and fill or empty )
                surface.DrawRect( barX + ( index - 1 ) * ( chunkW + gap ), barY, chunkW, barH )

            end
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
            bar = { id = id, shown = progress, alpha = bar and bar.alpha or 0, infoCache = {} }
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