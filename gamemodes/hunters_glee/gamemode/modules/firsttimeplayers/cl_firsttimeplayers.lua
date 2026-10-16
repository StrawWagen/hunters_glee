
-- the clientside half of the first time player system. sv_firsttimeplayers.lua decides who
-- is new and nets glee_dothefirsttimemessage, everything here is what they then see

local GAMEMODE = GAMEMODE or GM

local imNewMyself = nil
local hasSeenMessage = CreateClientConVar( "cl_huntersglee_firsttimetutorial", 0, true, true, "Has the player seen the one-time tutorial series of messages?" )

-- rare error where this convar is nil?!?!?!?
-- can probably happen with all convars but this one is especially important, so a proper fallback is a good idea here
local function currentSpawnset()
    local spawnsetCvar = GetConVar( "huntersglee_spawnset" )
    if not spawnsetCvar then return GAMEMODE.TheTutorialMisery end

    return spawnsetCvar:GetString()

end

local stagesTutorialMiseryChooser = {
    "Welcome.\nTo the hunt!",
    "This is your first hunt,\nis it not?",
    "We have.. a choice of,\nMISERY.\nFor you...",
    "The Infernal Horde?",
    "Extremely weak enemies,\nfor YOU to HUNT.",
    "Or, if you are a brave SOUL?",
    "CRUEL, intelligent,\nUNSTOPPABLE enemies.",
    "You will have to outwit,\nhave to carefully survive?",
    "It does not matter,\nto both options, you will...",
    "DIE.",
    "Oh,\nyou will die.",
    "But don't worry.\nDeath is not the end.",
    "It's time now.",
    "Time to choose...",
}

-- CHOOSE your misery
local tutorialMiseryChoices = {
    { "The Infernal Horde\nWeaklings.\nTo prepare you..." },
    { "Hunter's Glee\nA TRUE MISERY.\nTO OVERCOME.", function()
        net.Start( "glee_tutorial_jumpin" )
        net.SendToServer()

    end },
}

local stagesTutorialMiseryAdditional = {
    "Welcome.\nTo the hunt!",
    "This is your first hunt,\nis it not?",
    "We have chosen, this MISERY for you.",
    "You must hunt the Infernal Horde...",
    "Extremely weak enemies, for YOU to HUNT.",
    "You will still, DIE.",
    "But don't worry, that's the best part.",
    "Because then,\nthe HAUNTING will begin",
    "Let the Hunt....\nBEGIN!",
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
}

-- Builds the whole tutorial, or decides this player doesn't need one.
-- Returns true for both, because the only caller is a retry timer and both mean stop retrying.
-- Returns nil when LocalPlayer wasn't ready, which is the only case worth trying again.
-- offerChoice ends it in the choice to skip the tutorial misery, if that's still the misery.
local function doMessageIfWeCan( tutorialType, offerChoice )
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

    local onTutorialMisery = currentSpawnset() == GAMEMODE.TheTutorialMisery
    local lines
    local choices

    if tutorialType == "ghostly" then
        lines = stagesGhostly
        LocalPlayer().glee_SpawnedInDeadTutorialPlease = true

    elseif onTutorialMisery and offerChoice then
        lines = stagesTutorialMiseryChooser
        choices = tutorialMiseryChoices

    elseif onTutorialMisery then
        lines = stagesTutorialMiseryAdditional

    elseif player.GetCount() >= 2 then
        lines = stagesMultiplayer

    else
        lines = stagesSingleplayer

    end

    local tutorial = table.Copy( lines )
    tutorial.choices = choices
    tutorial.muffle = true
    tutorial.onClose = function()
        if currentSpawnset() == GAMEMODE.TheTutorialMisery then
            LocalPlayer():EmitSound( "ambient/levels/streetwar/gunship_distant2.wav", 120, 140, 0.5, CHAN_STATIC, SND_NOFLAGS, 0 )

        end

        RunConsoleCommand( "cl_huntersglee_firsttimetutorial", tostring( target ) )

    end

    GAMEMODE:ShowDecree( tutorial )
    return true

end

local timerName = "glee_dofirsttimemessage_ensured"

net.Receive( "glee_dothefirsttimemessage", function()
    local tutorialType = net.ReadString()
    local offerChoice = net.ReadBool()
    timer.Create( timerName, 1, 0, function()
        -- repeat this until LocalPlayer() is valid and the tutorial is started
        if doMessageIfWeCan( tutorialType, offerChoice ) == true then timer.Remove( timerName ) end

    end )
end )

-- decrees the server shows by name, with glee_tutorial_decree
local namedDecrees = {}

-- their first real hunt after skipping the tutorial misery went nowhere
namedDecrees.regret = function()
    GAMEMODE:ShowDecree( {
        "Did you expect to survive?",
        "We warned you,\nthis was a...",
        "TRUE MISERY",
        "I will give you one,\nfinal choice.",
        "Choose WISELY...",
        choices = {
            { "The Infernal Horde\nWeaklings,\na graceful start.", function()
                net.Start( "glee_tutorial_goback" )
                net.SendToServer()

            end },
            { "Hunter's Glee\nCONTINUE,\nTRUE MISERY.", function()
                net.Start( "glee_tutorial_continue" )
                net.SendToServer()

            end },
        },
    } )
end

-- their first death, with others still alive to haunt
namedDecrees.ghostshop = function()
    local bound, shopKey = GAMEMODE:TranslatedBind( "+menu" )
    local openShopLine = "The GHOST SHOP awaits..."
    if bound then
        openShopLine = "PRESS \" " .. string.upper( shopKey ) .. " \"\nto OPEN the GHOST SHOP."

    end

    local divineInterventionAwaitsLine = "Happy HAUNTING..."
    if GAMEMODE:canShowInShop( LocalPlayer(), "resurrection" ) then
        divineInterventionAwaitsLine = "DIVINE INTERVENTION AWAITS."

    end

    GAMEMODE:ShowDecree( {
        "What a shame...",
        "You've DIED.",
        "This,\nthis is an OPPORTUNITY!",
        "That body was.\nHolding you back.",
        "The HUNT...\nIt hasn't ended.",
        "It's time to HAUNT,\nthe living...",
        "Haunt, for a PROFIT?",
        openShopLine,
        divineInterventionAwaitsLine,
    } )
end

-- their first escape from the tutorial misery.
namedDecrees.escapedeasy = function()
    GAMEMODE:ShowDecree( {
        "You ESCAPED.",
        "You've passed the first...\nTEST.",
        "That Misery was made to prepare you..",
        "For the TRUE, hard MISERIES.\nThat await you...",
        "Type \" !rtm \"\nTo begin a Misery vote...",
    } )
end

net.Receive( "glee_tutorial_decree", function()
    local name = net.ReadString()
    local show = namedDecrees[name]
    if not show then ErrorNoHaltWithStack( "GLEE: no tutorial decree named " .. name ) return end

    show()

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