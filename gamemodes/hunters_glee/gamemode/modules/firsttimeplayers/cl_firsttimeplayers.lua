
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

local imNewMyself = nil
local hasSeenMessage = CreateClientConVar( "cl_huntersglee_firsttimetutorial", 0, true, true, "Has the player seen the one-time tutorial series of messages?" )

local stagesSingleplayer = {
    [1] = "Welcome.\nTo the hunt!",
    [2] = "YOU ARE NOT ALONE.",
    [3] = "Listen, see, flee...",
    [4] = "Listen, to your heart.",
    [5] = "See them, if they don't see you first.",
    [6] = "Flee, but to where?",
    [7] = "Just, above all else.",
    [8] = "GIVE THEM GLEE!",
}

local stagesMultiplayer = { -- way less tense in multiplayer
    [1] = "Welcome.\nTo the hunt!",
    [2] = "You're here to survive.",
    [3] = "You're here to... DIE?",
    [4] = "Death will not be the end.",
    [5] = "Until, then...",
    [6] = "SURVIVE."
}

local function doMessageIfWeCan()
    if not IsValid( LocalPlayer() ) then return end -- erm
    -- double check!
    if hasSeenMessage:GetBool() then return true end

    imNewMyself = true

    termHuntCloseTheShop()
    -- errored alot...
    if LocalPlayer().SetDSP then
        LocalPlayer():SetDSP( 15, true )

    end

    local popup, width, height = GAMEMODE:CreateScreenFillingPopup()

    popup:SetDraggable( false )

    LocalPlayer().MAINSCROLLPANEL = popup
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

    local stages
    if player.GetCount() >= 4 then
        stages = stagesMultiplayer

    else
        stages = stagesSingleplayer

    end

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

        local rampUp = math.Clamp( button.charCount / 600, 0, 0.10 )
        local added = 0.15 + rampUp
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

local gleetingsAsk = CreateClientConVar( "huntersglee_cl_gleetingsask", 1, true, true, "Get a chat print when someone who's never played glee joins?" )

if not game.IsDedicated() then return end

local andThenYaps = {
    "And then push them off a cliff...",
    "Before you beartrap them...",
    "And then show them the ropes!",
    "And then help them learn the gamemode!",
    "And then gaslight them into thinking RDM is banned!",
    "And then temporally invert them!",
    "And then warn them about the terminators!",
    "Then tell them the terminators are friendly!",
    "Before they get too comfortable...",
    "Before they get overstimulated!",
    "And then gaslight them into thinking someone's a traitor!",
    "And then gaslight them they can somehow survive...",
    "And then... Uhh, i forgot.",
    "And then tell them the TRUTH about hunter's glee!",
    "And don't forget to help them place stuff while dead!",
    "It's their first glee!",
    "They haven't found glee yet!",
    "Make sure they don't leave without a little bit of glee...",
    "Just keep them gleeful!",
    "Kill them, show them what it means to be gleeful.",
    "Treat them to a gleeful first impression!",
    "First impressions matter, so push them off a cliff for good measure!",
    "First impressions matter, so make sure nobody kills them...",
    "But it's not like first impressions actually matter!",
    "Warn them about the crates, god the crates!",
    "Make sure they don't go into debt!",
    "And then push them into a beartrap!",
    "And then feed them to a barnacle!",
    "And then gaslight them into going Legally Bind!",
    "And warn them not to go Legally Blind!",
    "And tell them how to respawn, unless they somehow live forever!",
    "And revive them like your life depends on it!",
    "But silently curse their soul under your breath...",
    "And gain their trust, only to feed them to a barnacle...",
    "And gaslight them into thinking supercop's friendly!",
    "And help them learn the ropes!",
    "And tell them it's okay to be overwhelmed!",
    "And tell them it's okay to die!",
    "And gaslight them into debt!",
    "Before they get crushed in an elevator!",
    "Before they get stuck between a supercop and a hard place!",
    "Before you RTV to gm_skyblock!",
    "Before supercop gets them!",
    "Before the terminators get them!",
    "And bless them like their life depends on it, cause it does!",
    "And then temporally invert them into a pit of despair!",
    "And then temporally invert them to saftey!",
    "And then resupply them with everything nice!",
    "And then resupply a dozen manhacks into their face!",

}

local white = Color( 255, 255, 255 )

net.Receive( "glee_askforgleetings", function()
    if imNewMyself then return end -- we're new, we can't help anyone!
    if not gleetingsAsk:GetBool() then return end -- shut UP

    local firstTimePlayer = net.ReadEntity()
    if not IsValid( firstTimePlayer ) then return end -- might happen

    LocalPlayer():EmitSound( "garrysmod/save_load2.wav", 75, math.random( 110, 140 ), 0.65 )

    local gleetings = "GLEE: Please wish Gleetings! To " .. firstTimePlayer:GetName() .. "!\n" .. andThenYaps[math.random( 1, #andThenYaps )]
    chat.AddText( white, gleetings )
    -- EG;
    -- Please wish Gleetings! To StrawWagen!
    -- And then push them off a cliff...

end )