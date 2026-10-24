
-- The first time player decrees. sv_firsttimeplayers.lua picks which, and sends its name with glee_tutorial_decree

local GAMEMODE = GAMEMODE or GM

local hasSeenTutorialVar = CreateClientConVar( "cl_huntersglee_firsttimetutorial", 0, true, true, "Has the player seen the one-time tutorial series of messages?" )

-- 1 is the singleplayer tutorial, 2 is the multiplayer one, and the multiplayer one counts as both
local function tutorialLevel()
    if game.IsDedicated() then return 2 end
    return 1

end

local function tutorialLessonName( level )
    return "SawTheTutorial" .. level

end

-- The convar, then a lesson. Some players' convars don't save, and they'd get the tutorial every time
function GAMEMODE:HasSeenTutorial()
    local level = tutorialLevel()
    if hasSeenTutorialVar:GetInt() >= level then return true end

    for seenLevel = level, 2 do
        if self:HasLearnedLesson( tutorialLessonName( seenLevel ) ) then return true end

    end

    return false

end

local function markTutorialSeen()
    local level = tutorialLevel()
    -- never lower it, seeing the singleplayer tutorial doesn't undo having seen the multiplayer one
    if hasSeenTutorialVar:GetInt() < level then
        RunConsoleCommand( "cl_huntersglee_firsttimetutorial", tostring( level ) )

    end
    GAMEMODE:LearnLesson( tutorialLessonName( level ) )

end

-- not canShowInShop, its dead check can still see them alive, the server only just killed some of them
local function divineInterventionOnSale()
    local reviveItem = GAMEMODE:GetShopItemData( "resurrection" )
    return reviveItem and hook.Run( "glee_shop_canshow", LocalPlayer(), reviveItem ) ~= false

end

-- a tutorial's lines, shown unless they've already seen it
local function showTutorial( decree )
    if GAMEMODE:HasSeenTutorial() then return end

    decree.muffle = true
    decree.onClose = markTutorialSeen

    GAMEMODE:ShowDecree( decree )

end

local function playInfernalHordeSound()
    LocalPlayer():EmitSound( "ambient/levels/streetwar/gunship_distant2.wav", 120, 140, 0.5, CHAN_STATIC, SND_NOFLAGS, 0 )

end

local namedDecrees = {}

-- the longest connected new player, on the tutorial misery. They choose whether to stay on it
namedDecrees.tutorial_chooser = function()
    showTutorial( {
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
        choices = {
            { "The Infernal Horde\nWeaklings.\nTo prepare you...", playInfernalHordeSound },
            { "Hunter's Glee\nA TRUE MISERY.\nTO OVERCOME.", function()
                net.Start( "glee_tutorial_jumpin" )
                net.SendToServer()

            end },
        },
    } )
end

-- every other new player on the tutorial misery
namedDecrees.tutorial_infernal = function()
    showTutorial( {
        "Welcome.\nTo the hunt!",
        "This is your first hunt,\nis it not?",
        "We have chosen, this MISERY for you.",
        "You must hunt the Infernal Horde...",
        "Extremely weak enemies, for YOU to HUNT.",
        "You will still, DIE.",
        "But don't worry, that's the best part.",
        "Because then,\nthe HAUNTING will begin",
        "Let the Hunt....\nBEGIN!",
    } )
end

namedDecrees.tutorial_multiplayer = function()
    showTutorial( {
        "Welcome.\nTo the hunt!",
        "You're here to survive?",
        "You will treasure skulls, to escape?",
        "You will...\nDIE?",
        "But don't let death worry you.",
        "You're here...\nTo HAUNT those left alive.",
        "Here, to BUY yourself back alive?",
        "After all...",
        "The hunt MUST GO ON.",
    } )
end

-- A decree that would've told them about Divine Intervention, but it wasn't on sale.
-- sv_firsttimeplayers.lua sends divineintervention when they die somewhere it is
local function tellOfDivineIntervention( decree, toldLines, notToldLines )
    if divineInterventionOnSale() then
        GAMEMODE:LearnLesson( "KnowsDivineIntervention" )
        table.Add( decree, toldLines )

    else
        GAMEMODE:LearnLesson( "MissedDivineIntervention" )
        table.Add( decree, notToldLines )

    end
end

-- joined mid round, so they spawn dead
namedDecrees.tutorial_ghostly = function()
    if GAMEMODE:HasSeenTutorial() then return end
    LocalPlayer().glee_SpawnedInDeadTutorialPlease = true

    local decree = {
        "Welcome.\nTo the hunt!",
        "You are...",
        "Temporarily...",
        "Separate from your body.",
        "...",
        "You are DEAD.",
        "But don't worry.",
        "Your SOUL persists...",
        "Death is only temporary.",
    }

    tellOfDivineIntervention( decree,
        { "DIVINE INTERVENTION AWAITS YOU", "Just, be ready to pay the price..." },
        { "The GLEE of HAUNTING,\nawaits you...", "HAUNT THEM." }
    )

    showTutorial( decree )

end

-- their first real hunt after skipping the tutorial misery went nowhere
namedDecrees.regret = function()
    GAMEMODE:ShowDecree( {
        "Did you expect to survive?",
        "We warned you,\nthis was a...",
        "TRUE MISERY",
        "I will give another choice...",
        "Choose WISELY...",
        choices = {
            { "The Infernal Horde\nWeaklings,\na graceful start.", function()
                playInfernalHordeSound()
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

    local decree = {
        "What a shame...",
        "You've DIED.",
        "This,\nthis is an OPPORTUNITY!",
        "That body was...\nHolding you back.",
        "The HUNT...\nIt hasn't ended.",
        "It's time to HAUNT,\nthe living...",
        "Haunt, for a PROFIT?",
        openShopLine,
    }
    tellOfDivineIntervention( decree, { "DIVINE INTERVENTION AWAITS." }, { "Happy HAUNTING..." } )

    GAMEMODE:ShowDecree( decree )

end

-- dead, somewhere Divine Intervention's on sale, after an earlier decree couldn't mention it.
namedDecrees.divineintervention = function()
    if not divineInterventionOnSale() then return end -- the next death might be somewhere it is
    if not GAMEMODE:LearnLesson( "KnowsDivineIntervention" ) then return end

    GAMEMODE:ShowDecree( {
        "You are DEAD.",
        "You should know...\n",
        "This Misery isn't as cruel....",
        "DIVINE INTERVENTION\nawaits you.",
    } )
end

-- their first escape from the tutorial misery
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

    -- can arrive before LocalPlayer's valid
    local timerName = "glee_tutorial_decree_" .. name
    timer.Create( timerName, 0, 0, function()
        if not IsValid( LocalPlayer() ) then return end

        timer.Remove( timerName )
        show()

    end )
end )
