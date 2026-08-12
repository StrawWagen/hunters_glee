
-- the clientside half of the first time player system. sv_firsttimeplayers.lua decides who
-- is new and nets glee_dothefirsttimemessage, everything here is what they then see

local GAMEMODE = GAMEMODE or GM

local function defineFont()
    surface.CreateFont( "huntersglee_welcometext", {
        font = "Protest Revolution",
        extended = false,
        size = glee_sizeScaled( nil, 150 ),
        weight = 600,
        blursize = 0,
        scanlines = 0,
        antialias = false,
        underline = false,
        italic = false,
        strikeout = false,
        symbol = false,
        rotary = false,
        shadow = false,
        additive = false,
        outline = false,
    } )
end
defineFont()
hook.Add( "glee_rebuildfonts", "glee_rebuild_welcometext_font", function()
    defineFont()

end )

local godHud = terminator_Extras.godHud
local textArrivalSounds = godHud.textArrivalSounds
local textLandingSounds = godHud.textLandingSounds

-- surface.playsound doesnt have pitch....
local function playGodSound( sounds, pitch, channel )
    LocalPlayer():EmitSound( sounds[math.random( 1, #sounds )], 75, pitch, 0.5, channel )

end

local tutorialFont = "huntersglee_welcometext"

-- the message is drawn this many times over, scattered and faint, all sliding onto the same
-- spot. where they overlap the transparency stacks, so it thickens into one solid message
local ghostCount = 5
local ghostSpreadMin = glee_sizeScaled( nil, 15 )
local ghostSpreadMax = glee_sizeScaled( nil, 70 )
local ghostOrbitMin = 40 -- degrees each ghost sweeps around the centre on its way in
local ghostOrbitMax = 120
local ghostMergeTime = 0.45
local ghostStartSpread = 0.35 -- how long until the last ghost shows up
local ghostPeakAlpha = 90
local materialiseTime = ghostStartSpread + ghostMergeTime

local clickImpatience = 0.30 -- seconds of animation a click skips

-- these fade against each other, so they can't share the godHud colors
local ghostTextColor = Color( godHud.textColor.r, godHud.textColor.g, godHud.textColor.b )
local ghostShadowColor = Color( godHud.shadowColor.r, godHud.shadowColor.g, godHud.shadowColor.b )
local solidTextColor = Color( godHud.textColor.r, godHud.textColor.g, godHud.textColor.b )
local solidShadowColor = Color( godHud.shadowColor.r, godHud.shadowColor.g, godHud.shadowColor.b )

local ghostData = {
    font = tutorialFont,
    textColor = ghostTextColor,
    shadowColor = ghostShadowColor,
    shadowOffsetX = godHud.shadowOffsetX,
    shadowOffsetY = godHud.shadowOffsetY,
}

local solidData = {
    font = tutorialFont,
    textColor = solidTextColor,
    shadowColor = solidShadowColor,
    shadowOffsetX = godHud.shadowOffsetX,
    shadowOffsetY = godHud.shadowOffsetY,
}

-- where each copy starts out. Think advances progress and eased, Paint reads them
local function buildGhosts()
    local ghosts = {}

    for ind = 1, ghostCount do
        local orbit = math.rad( math.Rand( ghostOrbitMin, ghostOrbitMax ) )
        if math.random( 2 ) == 1 then -- half of them sweep the other way round
            orbit = -orbit

        end

        ghosts[ind] = {
            angle = math.rad( math.Rand( 0, 360 ) ),
            spread = math.Rand( ghostSpreadMin, ghostSpreadMax ),
            orbit = orbit,
            startAt = math.Rand( 0, ghostStartSpread ),
            progress = 0,
            eased = 0,
        }
    end

    return ghosts

end

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

-- Builds the whole tutorial, or decides this player doesn't need one.
-- Returns true for both, because the only caller is a retry timer and both mean stop retrying.
-- Returns nil when LocalPlayer wasn't ready, which is the only case worth trying again.
local function doMessageIfWeCan()
    if not IsValid( LocalPlayer() ) then return end -- erm
    -- double check!

    -- 1 is the singleplayer tutorial, 2 is the multiplayer one, and doing the multiplayer one
    -- counts as having done both. sv_firsttimeplayers' requiredKnowledgeLevel picks the same two
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
    button.jitterX = 0 -- DoJitter fills these in, Paint just needs them to exist on frame one
    button.jitterY = 0

    local stages
    if spawnsetCvar:GetString() == GAMEMODE.TheTutorialMisery then
        stages = stagesTutorialMisery

    elseif player.GetCount() >= 2 then
        stages = stagesMultiplayer

    else
        stages = stagesSingleplayer

    end

    local function showStage()
        local fullMsg = stages[button.stage]
        if not fullMsg then return end

        button.msg = fullMsg
        button.ghosts = buildGhosts()
        button.elapsed = 0
        button.clickPlsGoFaster = 0
        button.solidAlpha = 0
        button.wasDone = nil
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
            playGodSound( textArrivalSounds, math.random( 90, 110 ), CHAN_STATIC )
            playGodSound( textArrivalSounds, math.random( 70, 80 ), CHAN_STATIC )
            playGodSound( textArrivalSounds, math.random( 50, 60 ), CHAN_STATIC )

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

        godHud.DoJitter( button )

        local ghosts = button.ghosts
        if not ghosts then return end

        -- a minimised window stops thinking, don't let it come back already materialised
        local delta = math.Clamp( CurTime() - button.lastThink, 0, 0.1 )
        button.lastThink = CurTime()

        button.elapsed = button.elapsed + delta + button.clickPlsGoFaster
        button.clickPlsGoFaster = 0

        for _, ghost in ipairs( ghosts ) do
            local progress = math.Clamp( ( button.elapsed - ghost.startAt ) / ghostMergeTime, 0, 1 )
            ghost.progress = progress
            ghost.eased = 1 - ( ( 1 - progress ) ^ 3 )

            if progress <= 0 then continue end

            if not ghost.fizzled then
                ghost.fizzled = true
                playGodSound( textArrivalSounds, math.random( 90, 110 ), CHAN_STATIC )

            end
        end

        -- squared, so the solid copy stays out of the way while the ghosts are still spread out
        local materialised = math.Clamp( button.elapsed / materialiseTime, 0, 1 )
        button.solidAlpha = 255 * ( materialised ^ 2 )

        if materialised >= 1 and not button.wasDone then
            button.nextAutomatic = CurTime() + 5
            button.wasDone = true
            playGodSound( textLandingSounds, math.random( 50, 60 ), CHAN_BODY )

        end
    end

    button.Paint = function()
        local ghosts = button.ghosts
        if not ghosts then return end

        local centreX = ( width / 2 ) + button.jitterX
        local topY = ( height / 2 ) + -256 + button.jitterY

        ghostData.text = button.msg

        for _, ghost in ipairs( ghosts ) do
            if ghost.progress <= 0 then continue end

            local eased = ghost.eased

            -- brightest halfway in, so each copy swells out of nothing and is gone once it lands
            local fade = math.sin( eased * math.pi )
            ghostTextColor.a = ghostPeakAlpha * fade
            ghostShadowColor.a = ghostPeakAlpha * fade

            -- swings round the centre as it closes in, so it spirals rather than sliding straight
            local angle = ghost.angle + ( ghost.orbit * eased )
            local dist = ghost.spread * ( 1 - eased )

            ghostData.posX = centreX + ( math.cos( angle ) * dist )
            ghostData.posY = topY + ( math.sin( angle ) * dist )
            surface.drawShadowedTextBetterData( ghostData )

        end

        solidTextColor.a = button.solidAlpha
        solidShadowColor.a = button.solidAlpha

        solidData.text = button.msg
        solidData.posX = centreX
        solidData.posY = topY
        surface.drawShadowedTextBetterData( solidData )

    end

    button.DoClick = function()
        if not button.wasDone then button.clickPlsGoFaster = button.clickPlsGoFaster + clickImpatience return end
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