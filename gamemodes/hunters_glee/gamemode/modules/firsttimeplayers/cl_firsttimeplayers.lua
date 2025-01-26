
local fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 60 ),
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
surface.CreateFont( "huntersglee_welcometext", fontData )

local hasSeenMessage = CreateClientConVar( "cl_huntersglee_firsttimetutorial", 0, true, true, "Has the player seen the one-time tutorial series of messages?" )

local stages = {
    [ 1 ] = "Welcome.\nTo the hunt!",
    [ 2 ] = "YOU ARE NOT ALONE.",
    [ 3 ] = "Listen, see, flee...",
    [ 4 ] = "Listen, to your heart.",
    [ 5 ] = "See them, if they don't see you first.",
    [ 6 ] = "Flee, but to where?",
    [ 7 ] = "Just, above all else.",
    [ 8 ] = "GIVE THEM GLEE!",
}

local function doMessageIfWeCan()
    if not IsValid( LocalPlayer() ) then return end -- erm
    -- double check!
    if hasSeenMessage:GetBool() then return true end

    GAMEMODE:termHuntCloseShopHolder()
    -- errored alot...
    if LocalPlayer().SetDSP then
        LocalPlayer():SetDSP( 15, true )

    end

    local popup, width, height = GAMEMODE:CreateScreenFillingPopup()

    popup:SetDraggable( false )

    LocalPlayer().HOLDERSCROLLPANEL = popup
    popup.Paint = function() end

    popup.oldRemove = popup.Remove
    popup.Remove = function( self )
        if LocalPlayer().SetDSP then
            LocalPlayer():SetDSP( 1, true )

        end
        self:oldRemove()
        RunConsoleCommand( "cl_huntersglee_firsttimetutorial", "1" )

    end

    local button = vgui.Create( "DButton", popup, "glee_nexttorialtextbutton" )
    button:Dock( FILL )
    button:SetText( "" )

    button.paintText = ""
    button.stage = 1
    button.charCount = -5
    button.nextPress = 0
    button.nextFlash = 0

    local function nextStage()
        button.stage = button.stage + 1
        local fullMsg = stages[button.stage]

        if not fullMsg then
            popup:Remove()
            LocalPlayer():EmitSound( "doors/heavy_metal_stop1.wav", 100, 100 )

        end

        button.charCount = -5
        button.wasDone = nil
        button.nextAutomatic = nil
        button.halfDone = nil

    end

    button.Think = function()
        if not system.HasFocus() then
            button.nextAutomatic = CurTime() + 5
            button.nextPress = CurTime() + 0.2
            if button.nextFlash < CurTime() then
                button.nextFlash = CurTime() + 1
                system.FlashWindow()

            end

        elseif button.nextAutomatic and button.nextAutomatic < CurTime() then
            nextStage()

        end

        local fullMsg = stages[button.stage]
        if not fullMsg then return end
        local done

        local toShow = string.sub( fullMsg, 0, math.floor( button.charCount ) )

        local rampUp = math.Clamp( button.charCount / 800, 0, 0.10 )
        local added = 0.10 + rampUp
        button.charCount = button.charCount + added

        if button.charCount <= 1 then
            toShow = ""
            for _ = 1, math.abs( button.charCount ) do
                toShow = toShow .. "."

            end
        else
            if #toShow ~= button.oldCountSound then
                button.oldCountSound = #toShow

                local pit = math.random( 90, 110 ) - ( button.oldCountSound * 0.1 )

                -- surface.playsound doesnt have pitch....
                LocalPlayer():EmitSound( "physics/concrete/rock_impact_soft" .. math.random( 1, 3 ) .. ".wav", 75, pit, 0.35, CHAN_BODY )

            end
            done = button.charCount > #fullMsg
            if done and not button.wasDone then
                button.nextAutomatic = CurTime() + 5
                button.wasDone = true

            end
        end

        button.paintText = toShow

    end
    button.Paint = function()
        surface.drawShadowedTextBetter( button.paintText, "huntersglee_welcometext", color_white, width / 2, ( height / 2 ) + -256 )

    end

    button.DoClick = function()
        if not button.wasDone then return end
        if button.nextPress > CurTime() then return end
        nextStage()

    end
    return true

end

local timerName = "glee_dofirsttimemessage_ensured"

net.Receive( "glee_dothefirsttimemessage", function()
    timer.Create( timerName, 1, 0, function()
        -- repeat this until LocalPlayer() is valid and the tutorial is started
        if doMessageIfWeCan() == true then timer.Remove( timerName ) end

    end )
end )
