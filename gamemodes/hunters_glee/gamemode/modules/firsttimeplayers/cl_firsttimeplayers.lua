
-- the clientside half of the first time player system. sv_firsttimeplayers.lua decides who
-- is new and nets glee_dothefirsttimemessage, everything here is what they then see

local GAMEMODE = GAMEMODE or GM

local decree = terminator_Extras.glee_Style( "godlyDecree" )

local clickImpatience = 0.30 -- seconds of animation a click skips

local imNewMyself = nil
local hasSeenMessage = CreateClientConVar( "cl_huntersglee_firsttimetutorial", 0, true, true, "Has the player seen the one-time tutorial series of messages?" )

local spawnsetCvar = GetConVar( "huntersglee_spawnset" )

local stagesTutorialMisery = {
    [1] = "Welcome.\nTo the hunt!",
    [2] = "You're here to...\nDIE?",
    [3] = "You're here to bring, to FEEL,\noverwhelming glee?",
    [4] = "It's kill or be killed in the HUNT",
    [5] = "Don't worry though,\ndeath is not the end...",
    [6] = "Give THEM a gleeful hunt,\nand be careful!",
    [7] = "They're already on your tail...",
}

local stagesTutorialMiseryMulti = {
    [1] = "Welcome.\nTo the hunt!",
    [2] = "You're here to...\nDIE?",
    [3] = "You are here to HAUNT.",
    [4] = "You're here to bring, to FEEL,\noverwhelming glee?",
    [5] = "It's kill or be killed in the HUNT",
    [6] = "Don't worry though,\ndeath is not the end...",
    [7] = "Your SOUL will live on.",
    [8] = "Give THEM a gleeful hunt,\nand be careful!",
    [9] = "They're already on your tail...",
}

local stagesSingleplayer = {
    [1] = "Welcome.\nTo the hunt!",
    [2] = "You're here to survive?",
    [3] = "You will treasure SKULLS.\nTo ESCAPE?",
    [4] = "You will...\nDIE?",
    [5] = "Oh, you will die...",
    [6] = "Just, don't forget WHERE you die...",
    [7] = "Have a gleeful hunt,\nand be careful!",
    [8] = "Because they're already on your tail...",
}

local stagesMultiplayer = {
    [1] = "Welcome.\nTo the hunt!",
    [2] = "You're here to survive?",
    [3] = "You will treasure skulls, to escape?",
    [4] = "You will...\nDIE?",
    [5] = "But don't let death worry you.",
    [6] = "You're here...\nTo HAUNT those left alive.",
    [7] = "Here, to BUY yourself back alive?",
    [8] = "After all...",
    [9] = "The hunt MUST GO ON.",
}

local stagesGhostly = {
    [1] = "Welcome.\nTo the hunt!",
    [2] = "You are...",
    [3] = "Temporarily...",
    [4] = "Separate from your body.",
    [5] = "...",
    [6] = "You are DEAD.",
    [7] = "But don't worry.",
    [8] = "Your SOUL persists...",
    [9] = "Death is only temporary.",
    [10] = "DIVINE INTERVENTION AWAITS YOU",
    [11] = "Just, be ready to pay the price...",
    [12] = "Happy haunting!",
}

-- Builds the whole tutorial, or decides this player doesn't need one.
-- Returns true for both, because the only caller is a retry timer and both mean stop retrying.
-- Returns nil when LocalPlayer wasn't ready, which is the only case worth trying again.
local function doMessageIfWeCan( tutorialType )
    if not IsValid( LocalPlayer() ) then return end -- erm
    -- double check!

    -- 1 is the singleplayer tutorial, 2 is the multiplayer one, and doing the multiplayer one
    -- counts as having done both
    local target = 1
    if game.IsDedicated() then
        target = 2

    end

    if hasSeenMessage:GetInt() >= target then return true end

    imNewMyself = true

    termHuntCloseTheShop()
    -- errored alot...
    if LocalPlayer().SetDSP then
        LocalPlayer():SetDSP( 15, true )

    end

    local stages

    if tutorialType == "default" then
        local plyCount = player.GetCount()
        if spawnsetCvar:GetString() == GAMEMODE.TheTutorialMisery then
            if plyCount >= 2 then
                stages = stagesTutorialMiseryMulti

            else
                stages = stagesTutorialMisery

            end

        elseif plyCount >= 2 then
            stages = stagesMultiplayer

        else
            stages = stagesSingleplayer

        end
    elseif tutorialType == "ghostly" then
        stages = stagesGhostly
        LocalPlayer().glee_SpawnedInDeadTutorialPlease = true

    end

    if not stages then return end -- saftey check for indev work

    local popup, width, height = GAMEMODE:CreateScreenFillingPopup()

    popup:SetDraggable( false )

    popup.Paint = function() end

    -- the panel as the identifier means gmod drops this hook itself once the panel is gone
    hook.Add( "HUDShouldDraw", popup, function() return false end )

    popup.oldRemove = popup.Remove
    popup.Remove = function( self )
        if LocalPlayer().SetDSP then
            LocalPlayer():SetDSP( 1, true )

        end
        self:oldRemove()

        local status = "1"
        if game.IsDedicated() then
            status = "2"

        end

        RunConsoleCommand( "cl_huntersglee_firsttimetutorial", status )

    end

    local button = vgui.Create( "DButton", popup, "glee_nexttorialtextbutton" )
    button:Dock( FILL )
    button:SetText( "" )

    button.stage = 1
    button.nextPress = 0
    button.nextFlash = 0
    button.lastThink = CurTime()
    button.elapsed = 0
    button.clickPlsGoFaster = 0
    button.jitterX = 0 -- Jitter fills these in, Paint just needs them to exist on frame one
    button.jitterY = 0
    button.line = decree:NewArrival( "huge" )

    local function showStage()
        local fullMsg = stages[button.stage]
        if not fullMsg then return end

        button.line:SetText( fullMsg )
        button.elapsed = 0
        button.clickPlsGoFaster = 0
        button.nextAutomatic = nil

    end

    local function nextStage()
        button.stage = button.stage + 1
        local fullMsg = stages[button.stage]

        if not fullMsg then
            local us = LocalPlayer()

            if spawnsetCvar:GetString() == GAMEMODE.TheTutorialMisery then
                us:EmitSound( "ambient/levels/streetwar/gunship_distant2.wav", 120, 140, 0.5, CHAN_STATIC, SND_NOFLAGS, 0 )

            end
            decree:PlaySound( "arrival", math.random( 90, 110 ), CHAN_STATIC )
            decree:PlaySound( "arrival", math.random( 70, 80 ), CHAN_STATIC )
            decree:PlaySound( "arrival", math.random( 50, 60 ), CHAN_STATIC )

            popup:Remove()
            return

        end

        showStage()

    end

    showStage()

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

        decree:Jitter( button )

        -- a minimised window stops thinking, don't let it come back already materialised
        local delta = math.Clamp( CurTime() - button.lastThink, 0, 0.1 )
        button.lastThink = CurTime()

        button.elapsed = button.elapsed + delta + button.clickPlsGoFaster
        button.clickPlsGoFaster = 0

        local appeared, justLanded = button.line:Update( button.elapsed )
        for _ = 1, appeared do
            decree:PlaySound( "arrival", math.random( 90, 110 ), CHAN_STATIC )

        end

        if justLanded then
            button.nextAutomatic = CurTime() + 5
            decree:PlaySound( "landing", math.random( 50, 60 ), CHAN_BODY )

        end
    end

    button.Paint = function()
        local centreX = ( width / 2 ) + button.jitterX
        local topY = ( height / 2 ) + -256 + button.jitterY

        button.line:Draw( centreX, topY )

    end

    button.DoClick = function()
        if not button.line.landed then button.clickPlsGoFaster = button.clickPlsGoFaster + clickImpatience return end
        if button.nextPress > CurTime() then return end
        nextStage()

    end
    return true

end

local timerName = "glee_dofirsttimemessage_ensured"

net.Receive( "glee_dothefirsttimemessage", function()
    local tutorialType = net.ReadString()
    timer.Create( timerName, 1, 0, function()
        -- repeat this until LocalPlayer() is valid and the tutorial is started
        if doMessageIfWeCan( tutorialType ) == true then timer.Remove( timerName ) end

    end )
end )

GAMEMODE:RegisterStatusEffect( "spawn_protection",
    function( self, _owner )
        local preDrawing = {}
        self:HookOnce( "PrePlayerDraw", function( ply )
            if not ply:HasStatusEffect( "spawn_protection" ) then return end
            preDrawing[ply] = true

            local pulse = math.abs( math.sin( CurTime() * 2 ) ) * 0.25 + 0.2
            render.SetBlend( pulse )
            render.SetColorModulation( 0.6, 0.8, 1 )

        end )
        self:HookOnce( "PostPlayerDraw", function( ply )
            if not preDrawing[ply] then return end
            preDrawing[ply] = nil

            render.SetBlend( 1 )
            render.SetColorModulation( 1, 1, 1 )

        end )
    end
)


local gleetingsAsk = CreateClientConVar( "cl_huntersglee_gleetingsask", 1, true, true, "Get a chat print when someone who's never played glee joins?" )

if not game.IsDedicated() then return end

local andThenYaps = {
    "And then push them off a cliff...",
    "Before you beartrap them...",
    "And then show them the ropes!",
    "And then help them learn the gamemode!",
    "And then gaslight them into thinking RDM is banned!",
    "And then temporally invert them!",
    "Then tell them the terminators are friendly!",
    "And then gaslight them into thinking someone's a traitor!",
    "And then... Uhh, i forgot.",
    "And then tell them the TRUTH about hunter's glee!",
    "And don't forget to help them place stuff while dead!",
    "Make sure they don't leave without a little bit of glee...",
    "Treat them to a gleeful first impression!",
    "First impressions matter, so push them off a cliff for good measure!",
    "Warn them about the crates, god the crates!",
    "Make sure they don't go into debt!",
    "And then push them into a beartrap!",
    "And then feed them to a barnacle!",
    "And then gaslight them into going Legally Bind!",
    "And warn them not to go Legally Blind!",
    "And revive them like your life depends on it!",
    "But silently curse their soul under your breath...",
    "And gain their trust, only to feed them to a barnacle...",
    "And gaslight them into thinking supercop's friendly!",
    "And gaslight them into debt!",
    "Before they get crushed in an elevator!",
    "Before they get stuck between a supercop and a hard place!",
    "Before you RTV to gm_skyblock!",
    "And bless them like their life depends on it, cause it does!",
    "And then temporally invert them into a pit of despair!",
    "And then temporally invert them to saftey!",

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