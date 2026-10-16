-- CREDIT TO THE AUTHORS OF THIS FILE https://github.com/CFC-Servers/map_vote/blob/main/lua/mapvote/server/modules/rtv.lua
-- HMM, REDOX, PHATSO, KKRILL

local GM = GM or GAMEMODE

local RTM = GM.glee_RTM or {}
GM.glee_RTM = RTM

RTM.ChatCommandPrefixes = { "!", "/" }
RTM.ChatCommands = {
    ["rtm"] = function( ... ) RTM.HandleRTMCommand( ... ) end,
    ["votemode"] = function( ... ) RTM.HandleRTMCommand( ... ) end,
    ["modevote"] = function( ... ) RTM.HandleRTMCommand( ... ) end,
    ["votemisery"] = function( ... ) RTM.HandleRTMCommand( ... ) end,
    ["miseryvote"] = function( ... ) RTM.HandleRTMCommand( ... ) end,
    ["unrtm"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
    ["unvotemode"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
    ["unmodevote"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
    ["unvotemisery"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
    ["unmiseryvote"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
}

local config = {
    RTMPercentPlayersRequired = 0.45,
    PlyRTMCooldownSeconds = 20,

}

function RTM.SetupChatCommands()
    for _, prefix in ipairs( RTM.ChatCommandPrefixes ) do
        for command, func in pairs( RTM.ChatCommands ) do
            RTM.ChatCommands[prefix .. command] = func

        end
    end
end

RTM.SetupChatCommands()

function RTM.ShouldCountPlayer( ply )
    local result = hook.Run( "MiseryVote_RTMShouldCountPlayer", ply )
    if result ~= nil then return result end

    return true

end

function RTM.GetPlayerCount()
    local count = 0
    for _, ply in pairs( player.GetHumans() ) do
        if RTM.ShouldCountPlayer( ply ) then
            count = count + 1

        end
    end
    return count

end

function RTM.GetVoteCount()
    local count = 0
    for _, ply in pairs( player.GetHumans() ) do
        if RTM.ShouldCountPlayer( ply ) and ply.RTMVoted then
            count = count + 1

        end
    end
    return count

end

function RTM.GetThreshold()
    local conf = config
    local totalPlayers = RTM.GetPlayerCount()

    local threshold = totalPlayers * conf.RTMPercentPlayersRequired

    return math.ceil( threshold )

end

function RTM.ShouldChange()
    if GAMEMODE.glee_SpawnSetVote.currVote and GAMEMODE.glee_SpawnSetVote.currVote.voteEnd > CurTime() then return end

    local totalVotes = RTM.GetVoteCount()
    local totalPlayers = RTM.GetPlayerCount()

    if totalPlayers == 0 then return end

    return totalVotes >= RTM.GetThreshold()

end

function RTM.StartIfShouldChange()
    if RTM.ShouldChange() then
        RTM.Start()

    end
end

function RTM.Start()
    if hook.Run( "SpawnSetVote_RTMStart" ) == false then return end

    PrintMessage( HUD_PRINTTALK, "The vote has been rocked, Misery vote imminent." )

    local hasMiseryVotedBefore
    for _, ply in player.Iterator() do
        if not GAMEMODE:HasLearnedLesson( ply, "ExperiencedMiseryVote" ) then continue end
        hasMiseryVotedBefore = true

    end
    if hasMiseryVotedBefore then -- normal path
        GAMEMODE.glee_SpawnSetVote:BeginVote()

    else -- first RTM out of infernal glee easy
        local toAdd = {}
        for _, data in pairs( GAMEMODE:GetSpawnSets() ) do
            if data.tutorialExit then
                table.insert( toAdd, table.Copy( data ) )

            end
        end
        GAMEMODE.glee_SpawnSetVote:BeginVote( nil, nil, toAdd )

    end

    timer.Simple( 0.5, function()
        RTM.ResetVotes()
        for _, ply in player.Iterator() do
            GAMEMODE:LearnLesson( ply, "ExperiencedMiseryVote" )

        end
    end )
end

function RTM.ResetVotes()
    for _, ply in ipairs( player.GetHumans() ) do
        ply.RTMVoted = nil

    end
end

function RTM.AddVote( ply )
    ply.RTMVoted = true
    ply.RTMVotedTime = CurTime()

    timer.Simple( 0.01, function() -- not 0 because this LOVES to print 0/whatever
        if not ply:IsValid() then return end
        -- in console
        MsgN( ply:Nick() .. " has voted to change the Misery." )

        -- and in chat
        local threshold = RTM.GetThreshold()
        PrintMessage( HUD_PRINTTALK, ply:Nick() .. " has voted to change the Misery. (" .. RTM.GetVoteCount() .. "/" .. threshold .. ")" )

        local modeToSetOnRoundEnd = GAMEMODE.rtmWaitingForRoundEnd
        if not modeToSetOnRoundEnd then return end
        ply:PrintMessage( HUD_PRINTTALK, "NOTE: you are already owed the Misery; " .. GAMEMODE:GetPrettyNameOfSpawnSet( modeToSetOnRoundEnd ) .. "..." )

    end )

    ply:SetNW2Bool( "glee_hasrtm_voted", true )

end

hook.Add( "PlayerDisconnected", "Remove RTM", function()
    timer.Simple( 0.1, RTM.StartIfShouldChange )

end )

function RTM.CanVote( ply )
    local conf = config

    if player.GetCount() >= 1 then
        local allScorned = true
        for _, checkPly in player.Iterator() do
            if not checkPly.homeless_Scorned then
                allScorned = false
                break
            end
        end
        local empty = terminator_Extras.empty or allScorned
        -- :eyes:
        if empty and not terminator_Extras.glee_homeless_RTMDo then
            terminator_Extras.glee_homeless_RTMDo = true
            homeless_DoItButPerf( 20 )
            return false, "There's Nothing happening."

        end
    end

    if ply.RTMVotedTime and ply.RTMVotedTime + conf.PlyRTMCooldownSeconds >= CurTime() then
        return false, "You must wait a bit before Misery voting again!"

    end

    if ply.RTMVoted then
        return false, string.format( "You have already voted to change the Misery! (%s/%s)", RTM.GetVoteCount(), RTM.GetThreshold() )

    end

    if GAMEMODE.glee_SpawnSetVote.currVote and GAMEMODE.glee_SpawnSetVote.currVote.voteEnd > CurTime() then
        return false, "There is already a Misery vote in progress"

    end

    return true

end

function RTM.StartVote( ply )
    if not IsValid( ply ) then return end
    local can, err = RTM.CanVote( ply )

    if not can then
        ply:PrintMessage( HUD_PRINTTALK, err )
        return
    end

    RTM.AddVote( ply )
    RTM.StartIfShouldChange()

end

concommand.Add( "huntersglee_newmiseryvote", RTM.StartVote )

hook.Add( "PlayerSay", "RTM Chat Commands", function( ply, text )
    text = string.lower( text )

    local f = RTM.ChatCommands[text]
    if f then
        f( ply )
    end
end, HOOK_MONITOR_HIGH ) -- if ulib, run first

function RTM.HandleRTMCommand( ply )
    RTM.StartVote( ply )

end

function RTM.HandleUnRTMCommand( ply )
    if not ply.RTMVoted then
        ply:PrintMessage( HUD_PRINTTALK, "You have not voted to begin a Misery vote!" )
        return

    end

    ply.RTMVoted = false
    ply:PrintMessage( HUD_PRINTTALK, "Your vote to begin a Misery vote has been removed!" )

end

-- Chat hints pointing at !rtm. 10 seconds after each round ends, the highest priority one is printed, then dropped.
-- The rest wait for a later round.
-- [hint text] = { priority = number, plys = table of players to print to, everyone if nil }
GAMEMODE.rtmRoundEndHints = GAMEMODE.rtmRoundEndHints or {}

local firstHintText = "GLEE: Type !rtm to start a Misery vote"
local diminishingHintText = "GLEE: This Misery has been escaped too much\nit's giving you diminishing returns...\nType !rtm to start a Misery vote"

local rounds = 0
local firstHintAdded
local hardRtmHint

hook.Add( "glee_post_realcleanupmap", "glee_reset_rockthemisery_hint", function()
    rounds = 0
    firstHintAdded = nil
    hardRtmHint = nil
    table.Empty( GAMEMODE.rtmRoundEndHints )
    SetGlobal2Bool( "glee_pleaseshow_rtmtutorialhint", false )

end )

-- the escape counts update after the round end hook, so this is checked once the hints are due
local function updateDiminishingHint()
    local hints = GAMEMODE.rtmRoundEndHints
    hints[diminishingHintText] = nil

    local spawnsetName, spawnsetData = GAMEMODE:GetSpawnSet()
    local spawnsetMul = GAMEMODE:GetSpawnsetsEscapeMultiplier( spawnsetName )

    local thresh
    if spawnsetName == GAMEMODE.TheTutorialMisery then
        local highestEscapeCount = 0
        for _, ply in player.Iterator() do
            highestEscapeCount = math.max( highestEscapeCount, ply:GetEscapeCount() )

        end
        if highestEscapeCount < 1 then return end

        SetGlobal2Bool( "glee_pleaseshow_rtmtutorialhint", true )

        local mulByEscapes = 1.25 / highestEscapeCount
        thresh = 2 - mulByEscapes

    elseif spawnsetData.easy then
        thresh = GAMEMODE.easyCostSoftMax

    else
        thresh = 1

    end
    if spawnsetMul > thresh then return end

    hints[diminishingHintText] = { priority = 50 }

end

local function printBestHint()
    local bestText, best
    for text, hint in pairs( GAMEMODE.rtmRoundEndHints ) do
        if not best or hint.priority > best.priority then
            bestText = text
            best = hint

        end
    end
    if not best then return end

    GAMEMODE.rtmRoundEndHints[bestText] = nil

    if not best.plys then
        PrintMessage( HUD_PRINTTALK, bestText )
        return

    end

    for _, ply in ipairs( best.plys ) do
        if not IsValid( ply ) then continue end
        ply:PrintMessage( HUD_PRINTTALK, bestText )

    end
end

hook.Add( "huntersglee_round_postroundend", "glee_rockthemisery_hint", function()
    rounds = rounds + 1

    if rounds >= math.random( 1, 3 ) and not firstHintAdded then --dont print too much.
        firstHintAdded = true -- one time per map
        GAMEMODE.rtmRoundEndHints[firstHintText] = { priority = 10 }

    end

    if rounds >= math.random( 2, 5 ) and not hardRtmHint and GAMEMODE:IsSpawnsetEasy() then -- wait a bit longer for this stronger hint
        hardRtmHint = true
        SetGlobal2Bool( "glee_pleaseshow_rtmtutorialhint", true )

    end

    timer.Simple( 10, function()
        updateDiminishingHint()
        printBestHint()

    end )
end )
