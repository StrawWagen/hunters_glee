-- mapvote module
if not MapVote then return end

hook.Add( "MapVote_VoteStarted", "glee_mapvote_detectandtransmit", function( voteState )
    GAMEMODE:SyncEscapeMultipliersForMaps( voteState.currentMaps )

end )

-- play when vote is started
hook.Add( "MapVote_VoteStarted", "glee_stopmusic_mapvote", function()
    GAMEMODE:SendMusic( "tracks/mapvoteMusic" )

end )

local mapVoteQueued = nil

-- a round that starts mid vote just gets cut off by the map change
-- so any vote holds it, not just the forced one
hook.Add( "glee_sv_canroundstart", "glee_mapvote_holdround", function()
    if not mapVoteQueued and not MapVote.state.isInProgress then return end

    local voteLeft = 0
    if MapVote.state.endTime then
        voteLeft = math.max( math.ceil( MapVote.state.endTime - CurTime() ), 0 )

    end
    return false, "VOTING...", voteLeft

end )

if not game.IsDedicated() then return end

local mavoteDefaultTime = 30
local mapvoteVar = CreateConVar( "huntersglee_activetimeneededfor_mapvote", -1, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "minutes. added length of all ROUND_ACTIVE needed to force map vote (-1 for default, " .. mavoteDefaultTime .. ")", 0, math.huge )
-- added length of all ROUND_ACTIVE needed to force map vote, if gamemode was waiting for players to join, this stops the first round from kicking them to a new map.
-- also accounts for multiple short rounds
-- or one round that goes on way way too long

local mapVoteIncrement = 0
local countdownKey = "glee_mapvote_countdown"

local function notifyQueued()
    huntersGlee_NotifyLivingAndDead( player.GetAll(), {
        text = "FORCED LOCALE VOTE QUEUED",
        description = "LIKELY safe for now.\nPREPARE for the vote.",
        kind = "alert",
        time = 30,
    }, {
        text = "FORCED MAP VOTE QUEUED",
        description = "This hunt will be somewhere new soon...",
        kind = "alert",
        time = 30,
    } )
end

-- the whole preparation, escaped players come back to a payout and need the time to bank it
local countdownAlerted = nil
local function notifyCountdown()
    local untilShift = math.ceil( GAMEMODE.termHunt_roundStartTime - CurTime() )
    if untilShift <= 0 then return end

    huntersGlee_Notify( player.GetAll(), {
        text = "FORCED LOCALE SHIFT IN " .. untilShift,
        description = "SUGGESTED ACTION: DEPOSIT EVERYTHING.",
        kind = countdownAlerted and "bad" or "alert", -- only the first one makes a sound
        time = 1.5,
        replaceKey = countdownKey,
    } )
    countdownAlerted = true

end

local function startTheMapVoteTimer()
    timer.Create( "glee_mapvote_think", 1, 0, function()
        local state = GAMEMODE:RoundState()
        if mapVoteQueued then
            if state == GAMEMODE.ROUND_INACTIVE then
                notifyCountdown()

            end
            return

        end

        if state ~= GAMEMODE.ROUND_ACTIVE then return end

        -- new players get kicked to a new map mid tutorial otherwise
        if GAMEMODE:GetSpawnSet() == GAMEMODE.TheTutorialMisery then return end

        local varTranslated = mapvoteVar:GetInt()
        if varTranslated < 0 then
            varTranslated = mavoteDefaultTime

        end

        varTranslated = varTranslated * 60

        mapVoteIncrement = mapVoteIncrement + 1
        local lessThanVar = mapVoteIncrement <= varTranslated
        if lessThanVar then return end

        mapVoteQueued = true
        countdownAlerted = nil
        notifyQueued()

    end )
end

hook.Add( "huntersglee_round_firstsetup", "glee_mapvote_setup", startTheMapVoteTimer )

local function unqueue()
    mapVoteQueued = nil
    mapVoteIncrement = 0
    huntersGlee_CancelNotify( player.GetAll(), countdownKey, { noFade = true } )

end

-- MapVote.Start doesn't check for a running vote, it wipes it
-- so a vote players start themselves counts as the forced one
hook.Add( "MapVote_VoteStarted", "glee_mapvote_fillsforced", function()
    if not mapVoteQueued then return end
    unqueue()

end )

-- the preparation countdown ran out into glee_mapvote_holdround
-- a vote that fails to start holds nothing, so the round just carries on
hook.Add( "glee_sv_roundstartheld", "glee_mapvote_startforced", function()
    if not mapVoteQueued then return end
    unqueue()

    GAMEMODE:SpeakAsHuntersGlee( "Starting forced mapvote..." )
    MapVote.Start()

    hook.Run( "glee_mapvote_start" )

end )

hook.Add( "huntersglee_emptyserver", "glee_mapvote_reset", unqueue )
