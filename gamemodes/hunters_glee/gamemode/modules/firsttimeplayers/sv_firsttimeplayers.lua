local GAMEMODE = GAMEMODE or GM

local asked = {}
local spawned = {}
local alreadyDone = {}

-- One new player per map is offered the choice to skip the tutorial misery. Each SteamID is
-- cleared once it's been acted on, so every answer only counts once
local tutorialChoiceOffered
local chooserSteamID -- until they answer
local jumpedInSteamID -- skipped it, until their first real hunt ends
local regretPendingSteamID -- that hunt ended with nobody out, until the win screen's done
local regretAskedSteamID -- asked if they'd rather go back, until they answer

-- First time status, the os.time() it runs out, by SteamID
-- saved in PData so it outlasts rejoins and map changes. Wall clock, not playtime
local firstTimeStatusDuration = 60 * 60
local firstTimeStatusPDataName = "glee_firsttimeplayer"
GAMEMODE.firstTimeStatusExpiries = GAMEMODE.firstTimeStatusExpiries or {}

local function hasFirstTimeStatus( ply )
    if ply:IsBot() then return ply.glee_firstTimeBot == true end

    local expiry = GAMEMODE.firstTimeStatusExpiries[ply:SteamID()]
    return expiry ~= nil and expiry > os.time()

end

-- never extends a live status, re-taking the tutorial doesn't buy more time
local function giveFirstTimeStatus( ply )
    if hasFirstTimeStatus( ply ) then return end

    local expiry = os.time() + firstTimeStatusDuration
    GAMEMODE.firstTimeStatusExpiries[ply:SteamID()] = expiry
    ply:SetPData( firstTimeStatusPDataName, expiry )

end

hook.Add( "PlayerInitialSpawn", "glee_firsttimeply_loadstatus", function( ply )
    -- half of them come in new. a flag on the bot, they all share one SteamID
    if ply:IsBot() then
        ply.glee_firstTimeBot = math.random( 2 ) == 1
        return

    end

    local expiry = tonumber( ply:GetPData( firstTimeStatusPDataName ) )
    if not expiry or expiry <= os.time() then return end

    GAMEMODE.firstTimeStatusExpiries[ply:SteamID()] = expiry

end )

hook.Add( "huntersglee_round_firstsetup", "glee_wipe_expired_firsttimestatus", function()
    GAMEMODE:WipeExpiredPData( firstTimeStatusPDataName )

end )

util.AddNetworkString( "glee_askforgleetings" )
util.AddNetworkString( "glee_tutorial_jumpin" )
util.AddNetworkString( "glee_tutorial_decree" )
util.AddNetworkString( "glee_tutorial_goback" )
util.AddNetworkString( "glee_tutorial_continue" )

-- shows one of cl_firsttimeplayers.lua's namedDecrees
local function sendTutorialDecree( ply, name )
    net.Start( "glee_tutorial_decree" )
        net.WriteString( name )
    net.Send( ply )

end

local function gleetings( ply )
    if not game.IsDedicated() then return end

    local filterNotPly = RecipientFilter()
    filterNotPly:AddAllPlayers()
    filterNotPly:RemovePlayer( ply )
    net.Start( "glee_askforgleetings" )
        net.WriteEntity( ply )
    net.Send( filterNotPly )

end

GAMEMODE:RegisterStatusEffect( "spawn_protection",
    function( self, owner )
        self:SetPlyRemoveOnDeath( true ) -- in case it gets stuck, will make it remove on owner killbind

        owner.glee_sheltering_normalCollisionGroup = owner.glee_sheltering_normalCollisionGroup or owner:GetCollisionGroup()
        owner:SetNoTarget( true )
        owner:GodEnable()
        owner:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
        owner:Fire( "alpha", 0, 0 )

        self:HookOnce( "glee_ply_blockhuntability", function( ply )
            if ply:HasStatusEffect( "spawn_protection" ) then return true end

        end )

    end,
    function( _self, owner )
        owner:SetNoTarget( false )
        owner:GodDisable()
        owner:SetCollisionGroup( owner.glee_sheltering_normalCollisionGroup or COLLISION_GROUP_PLAYER )
        owner:Fire( "alpha", 255, 0 )
        owner.glee_importantSpawnProtection = nil

    end
)

local function shelterPly( ply )
    if ply:IsBot() then return end

    if ply:Health() > 0 then
        ply:GiveStatusEffect( "spawn_protection" )
        ply.glee_importantSpawnProtection = true

    end

    local wait = 2
    wait = wait + ply:Ping() / 50

    timer.Simple( wait, function() -- wait until the gui gets em
        if not IsValid( ply ) then return end

        local startingAng = ply:GetAngles()

        local timerName = "glee_tutorialshelter_" .. ply:GetCreationID()
        timer.Create( timerName, 0.1, 0, function()
            if not IsValid( ply ) then timer.Remove( timerName ) return end
            local currAng = ply:GetAngles()

            -- remove godmode when tutorial lets go and allows them to aim again
            if math.abs( math.AngleDifference( currAng.p, startingAng.p ) ) < 5 and
               math.abs( math.AngleDifference( currAng.y, startingAng.y ) ) < 5 and
               math.abs( math.AngleDifference( currAng.r, startingAng.r ) ) < 5 then return end

            if ply:Health() > 0 then
                ply:RemoveStatusEffect( "spawn_protection" )

            end

            timer.Remove( timerName )
            gleetings( ply )

        end )
    end )
end

-- so their first Preparing has something to spend, score only builds up during the hunt
local freeScore = 100

-- FREE SCORE!!!
local function giveFreeScore( ply )
    if hasFirstTimeStatus( ply ) then return end
    if ply:BankHasAccount() then return end -- nuh uh

    ply:GivePlayerScore( freeScore )

end

-- decreeName is one of cl_firsttimeplayers.lua's tutorial_ decrees
local function tutorialize( ply, decreeName )
    permaPrint( "GLEE: Tutorializing ", ply )
    if ply:Glee_FlashlightIsOn() then
        ply:Glee_Flashlight( false )

    end
    asked[ply] = true
    -- even on a rejoin, the decree tells them they're dead
    if decreeName == "tutorial_ghostly" then
        GAMEMODE:LearnLesson( ply, "SpawnedInDead" ) -- their first real death gets diedafterspawningindead, not ghostshop
        if ply:Health() > 0 then
            ply:KillSilent()

        end
    end
    if not alreadyDone[ply:SteamID()] then -- NEVER give god/notarg more than once per session
        alreadyDone[ply:SteamID()] = true
        shelterPly( ply )
        giveFreeScore( ply ) -- wait, FREE score? FREE???
        ply:SetNW2Bool( "glee_firsttime_divinediscount", true )

    end
    sendTutorialDecree( ply, decreeName )

    giveFirstTimeStatus( ply )

end

-- two different tutorials for singleplayer/multiplayer, the multiplayer one counts as both
local function requiredKnowledgeLevel()
    if game.IsDedicated() then return 2 end
    return 1

end

-- The convar, then the lesson cl_firsttimeplayers.lua learns alongside it. Some players' convars don't save
local function isEducated( ply )
    if ply:IsBot() then return true end

    local level = requiredKnowledgeLevel()
    if ply:GetInfoNum( "cl_huntersglee_firsttimetutorial", 0 ) >= level then return true end

    for seenLevel = level, 2 do
        if GAMEMODE:HasLearnedLesson( ply, "SawTheTutorial" .. seenLevel ) then return true end

    end

    return false

end

local function needsToAsk( ply )
    if not spawned[ply] then return end -- wait until ply has full loaded
    if asked[ply] then return end

    if ply:IsBot() then return end

    return not isEducated( ply )

end

-- Is this player new to this experience, do they qualify for extra protections?
-- needs extra checks because the convar can be faked
function GAMEMODE:IsFirstTimePlayer( ply )
    return hasFirstTimeStatus( ply ) and ply:BankFundsFast() < 2000 and self:GetPersistentGuilt( ply ) < 4 -- dont let guilty players exploit this by resetting the convar

end

-- Half or more of the session is still being tutorialised, so the round can't be won and
-- hunters shouldn't spawn.
-- Only counts players we've actually sent the tutorial to, isEducated alone is false for
-- anyone still connecting and they'd freeze the round just by loading in.
-- Not IsFirstTimePlayer, its wealth and guilt checks would let the round end mid tutorial
function GAMEMODE:TutorialIsHoldingTheRound( players )
    if #players <= 0 then return end

    local inTutorial = 0

    for _, ply in ipairs( players ) do
        if not hasFirstTimeStatus( ply ) then continue end
        if not ply.glee_importantSpawnProtection and isEducated( ply ) then continue end

        inTutorial = inTutorial + 1

    end

    return inTutorial >= #players / 2

end

-- separate from the question above, this one acts
function GAMEMODE:TutorializeNewPlayers( players )
    if #players <= 0 then return end

    local nonKnowers = {}

    for _, ply in ipairs( players ) do
        if needsToAsk( ply ) then nonKnowers[#nonKnowers + 1] = ply end

    end
    if #nonKnowers <= 0 then return end

    -- enough of the session is new that the whole server should be on the gentle misery
    local threshold = #players / 2
    local switchingToTutorialMisery = #nonKnowers > threshold
    if switchingToTutorialMisery then
        RunConsoleCommand( "huntersglee_misery", self.TheTutorialMisery )

    end
    local hunting = self:RoundState() == self.ROUND_ACTIVE
    -- spawn in dead if the hunt's been going a while
    local ghostly = hunting and self:getRemaining( self.termHunt_roundBegunTime, CurTime() ) > 5

    -- the cvar change applies after this, so the current misery can still be the old one
    local onTutorialMisery = switchingToTutorialMisery or self:GetSpawnSet() == self.TheTutorialMisery
    local chooser
    if onTutorialMisery and not hunting and not tutorialChoiceOffered then
        for _, ply in ipairs( nonKnowers ) do
            if not chooser or ply:TimeConnected() > chooser:TimeConnected() then
                chooser = ply

            end
        end
        tutorialChoiceOffered = true
        chooserSteamID = chooser:SteamID()

    end

    for _, ply in ipairs( nonKnowers ) do
        local decreeName
        if ghostly then
            decreeName = "tutorial_ghostly"

        elseif ply == chooser then
            decreeName = "tutorial_chooser"

        elseif onTutorialMisery then
            decreeName = "tutorial_infernal"

        else
            decreeName = "tutorial_multiplayer"

        end

        tutorialize( ply, decreeName )

    end
end

-- they want to jump STRAIGHT INTO THE REAL HUNT
net.Receive( "glee_tutorial_jumpin", function( _, ply )
    if ply:SteamID() ~= chooserSteamID then return end
    chooserSteamID = nil
    if GAMEMODE:GetSpawnSet() ~= GAMEMODE.TheTutorialMisery then return end

    permaPrint( "GLEE: ", ply, "CHOSE A REAL MISERY" )

    jumpedInSteamID = ply:SteamID()
    RunConsoleCommand( "huntersglee_misery", "hunters_glee" )
    GAMEMODE:BumpSessionDifficulty( 40, "tutorial_jumpin" ) -- give em a truly miserable first impression
    GAMEMODE:LearnLesson( ply, "ExperiencedMiseryVote" ) -- skip the .tutorialExit options

    hook.Add( "terminator_enemythink", "glee_playTutorialHardOptionTrack", function( bot, spotted )
        if not spotted:IsPlayer() then return end

        if not bot:GetNW2Bool( "glee_IsHunter" ) then return end -- interloper
        if bot.DistToEnemy > 1250 then return end -- too far, ply doesn't see it

        hook.Remove( "terminator_enemythink", "glee_playTutorialHardOptionTrack" )
        GAMEMODE:SendMusic( "tracks/tutorialPickedHardOption" )

    end )
end )

-- their first real hunt went nowhere, ask once if they'd rather go back
hook.Add( "huntersglee_no_one_escaped", "glee_tutorialmisery_regret", function()
    if not jumpedInSteamID then return end
    if GAMEMODE:GetSpawnSet() ~= "hunters_glee" then jumpedInSteamID = nil return end

    regretPendingSteamID = jumpedInSteamID
    jumpedInSteamID = nil

end )

-- after the win screen, not over it
hook.Add( "huntersglee_round_postroundend", "glee_tutorialmisery_regret", function()
    if not regretPendingSteamID then return end
    local chooser = player.GetBySteamID( regretPendingSteamID )
    regretPendingSteamID = nil

    if not IsValid( chooser ) then return end
    if GAMEMODE:GetSpawnSet() ~= "hunters_glee" then return end

    regretAskedSteamID = chooser:SteamID()
    sendTutorialDecree( chooser, "regret" )

end )

net.Receive( "glee_tutorial_goback", function( _, ply )
    if ply:SteamID() ~= regretAskedSteamID then return end
    regretAskedSteamID = nil
    if GAMEMODE:GetSpawnSet() ~= "hunters_glee" then return end

    permaPrint( "GLEE: ", ply, "WENT BACK TO THE INFERNAL HORDE" )
    RunConsoleCommand( "huntersglee_misery", GAMEMODE.TheTutorialMisery )

end )

net.Receive( "glee_tutorial_continue", function( _, ply )
    if ply:SteamID() ~= regretAskedSteamID then return end
    regretAskedSteamID = nil

    GAMEMODE.rtmRoundEndHints["GLEE: You can still choose another Misery\nType !rtm to start a Misery vote"] = { priority = 100, plys = { ply } }

end )

local ghostShopHintDelay = 5

-- a new player's first death with others still alive, tell them dying's where the haunting starts.
-- KillSilent doesn't run PlayerDeath, so for those who spawned in dead, this is their first death since coming back
hook.Add( "PlayerDeath", "glee_tutorial_ghostshophint", function( ply )
    if ply:IsBot() then return end
    if not hasFirstTimeStatus( ply ) then return end
    if player.GetCount() < 2 then return end
    if GAMEMODE:HasLearnedLesson( ply, "DiedTimeToContinueShoppingHint" ) then return end

    timer.Create( "glee_tutorial_ghostshophint_" .. ply:GetCreationID(), ghostShopHintDelay, 1, function()
        if not IsValid( ply ) then return end
        if ply:Alive() then return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        if GAMEMODE:HasLearnedLesson( ply, "DiedTimeToContinueShoppingHint" ) then return end -- the client learns it once they've seen it all

        -- the ghostly tutorial already told them about haunting
        if GAMEMODE:HasLearnedLesson( ply, "SpawnedInDead" ) then
            sendTutorialDecree( ply, "diedafterspawningindead" )

        else
            sendTutorialDecree( ply, "ghostshop" )

        end
    end )
end )

local divineInterventionHintDelay = ghostShopHintDelay + 1 -- the ghost shop hint can mention it first

-- an earlier decree couldn't mention Divine Intervention, it wasn't on sale. The client checks if it is now
hook.Add( "PlayerDeath", "glee_tutorial_divineinterventionhint", function( ply )
    if not GAMEMODE:HasLearnedLesson( ply, "MissedDivineIntervention" ) then return end
    if GAMEMODE:HasLearnedLesson( ply, "KnowsDivineIntervention" ) then return end

    timer.Create( "glee_tutorial_divineinterventionhint_" .. ply:GetCreationID(), divineInterventionHintDelay, 1, function()
        if not IsValid( ply ) then return end
        if ply:Alive() then return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

        sendTutorialDecree( ply, "divineintervention" )

    end )
end )

local escapedEasyHintDelay = 15 -- after the round's over, so it isn't buried under the escape rewards

-- the first time someone escapes the tutorial misery, show them there's more, once the round's over
hook.Add( "glee_ply_escaped", "glee_tutorial_escapedeasyhint", function( ply )
    if GAMEMODE:GetSpawnSet() ~= GAMEMODE.TheTutorialMisery then return end
    if GAMEMODE:HasLearnedLesson( ply, "EscapedTheEasyMisery" ) then return end

    local timerName = "glee_tutorial_escapedeasyhint_" .. ply:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( ply ) then timer.Remove( timerName ) return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_INACTIVE then return end

        timer.Remove( timerName )

        timer.Simple( escapedEasyHintDelay, function()
            if not IsValid( ply ) then return end
            if not GAMEMODE:LearnLesson( ply, "EscapedTheEasyMisery" ) then return end

            sendTutorialDecree( ply, "escapedeasy" )

        end )
    end )
end )

-- shelter until they are done loading
hook.Add( "PlayerInitialSpawn", "glee_firsttimeply_shelterwhenloading", function( ply )
    ply:GiveStatusEffect( "spawn_protection" )

end )

local forceResetOnSpawn

-- make this player mimic exact conditions of someone who just spawned into the server
local function forceResetTutorial( ply )
    asked[ply] = nil
    alreadyDone[ply:SteamID()] = nil

    ply:ConCommand( "cl_huntersglee_firsttimetutorial 0" )
    spawned[ply] = true

end

local loadedIn = {}
local lessonsArrived = {}

local function markReadyForTutorial( ply )
    if not loadedIn[ply] or not lessonsArrived[ply] then return end
    spawned[ply] = true

end

-- they're done loading
hook.Add( "glee_full_load", "glee_firsttimeplayercheck", function( ply )
    -- wait a couple seconds
    timer.Simple( 2, function()
        if not IsValid( ply ) then return end
        -- then remove their spawn protection
        ply:RemoveStatusEffect( "spawn_protection" )

        if forceResetOnSpawn then
            forceResetTutorial( ply )

        end

        loadedIn[ply] = true
        markReadyForTutorial( ply )

    end )
end )

-- isEducated falls back on their lessons, the client sends them on its own schedule
hook.Add( "glee_clientset_synced", "glee_firsttimeplayercheck", function( ply, setName )
    if setName ~= "lessons" then return end

    lessonsArrived[ply] = true
    markReadyForTutorial( ply )

end )

hook.Add( "glee_test_tutorial", "firsttimeplayers", function()
    tutorialChoiceOffered = nil
    chooserSteamID = nil
    jumpedInSteamID = nil
    regretPendingSteamID = nil
    regretAskedSteamID = nil

    -- reset tutorial for all plys in session
    for _, ply in player.Iterator() do
        if not ply.glee_FullLoaded then continue end
        forceResetTutorial( ply )

    end
    -- and all plys who join into the session
    forceResetOnSpawn = true

end )