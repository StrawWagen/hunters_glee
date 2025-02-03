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
    ["unrtm"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
    ["unvotemode"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
    ["unmodevote"] = function( ... ) RTM.HandleUnRTMCommand( ... ) end,
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
    local result = hook.Run( "ModeVote_RTMShouldCountPlayer", ply )
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
    if GAMEMODE.glee_SpawnSetVote.currVote then return end

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

    PrintMessage( HUD_PRINTTALK, "The vote has been rocked, glee mode vote imminent" )
    GAMEMODE.glee_SpawnSetVote:BeginVote()
    timer.Simple( 0.5, function()
        RTM.ResetVotes()

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
        MsgN( ply:Nick() .. " has voted to change the glee mode." )
        local threshold = RTM.GetThreshold()
        PrintMessage( HUD_PRINTTALK,
            ply:Nick() .. " has voted to change the glee mode. (" .. RTM.GetVoteCount() .. "/" .. threshold .. ")" )
    end )
end

hook.Add( "PlayerDisconnected", "Remove RTM", function()
    timer.Simple( 0.1, RTM.StartIfShouldChange )
end )

function RTM.CanVote( ply )
    local conf = config

    if ply.RTMVotedTime and ply.RTMVotedTime + conf.PlyRTMCooldownSeconds >= CurTime() then
        return false, "You must wait a bit before mode voting again!"
    end

    if ply.RTMVoted then
        return false,
            string.format( "You have already voted to change the glee mode! (%s/%s)", RTM.GetVoteCount(),
                RTM.GetThreshold() )
    end

    if GAMEMODE.glee_SpawnSetVote.currVote then
        return false,
            "There is already a glee mode vote in progress"
    end

    return true
end

function RTM.StarTMote( ply )
    if not IsValid( ply ) then return end
    local can, err = RTM.CanVote( ply )

    if not can then
        ply:PrintMessage( HUD_PRINTTALK, err )
        return
    end

    RTM.AddVote( ply )
    RTM.StartIfShouldChange()
end

concommand.Add( "rtm_start", RTM.StarTMote )

hook.Add( "PlayerSay", "RTM Chat Commands", function( ply, text )
    text = string.lower( text )

    local f = RTM.ChatCommands[text]
    if f then
        f( ply )
    end
end )

function RTM.HandleRTMCommand( ply )
    RTM.StarTMote( ply )
end

function RTM.HandleUnRTMCommand( ply )
    if not ply.RTMVoted then
        ply:PrintMessage( HUD_PRINTTALK, "You have not rocked the glee mode vote!" )
        return
    end

    ply.RTMVoted = false
    ply:PrintMessage( HUD_PRINTTALK, "Your glee mode vote has been removed!" )
end

local rounds = 0
local printed
hook.Add( "huntersglee_round_into_inactive", "glee_rockthemode_hint", function()
    rounds = rounds + 1
    if rounds < math.random( 2, 4 ) then return end --dont print too much.

    if printed then return end
    printed = true -- one time per map

    PrintMessage( HUD_PRINTTALK, "GLEE: Type !rtm to start a mode vote" )

end )
