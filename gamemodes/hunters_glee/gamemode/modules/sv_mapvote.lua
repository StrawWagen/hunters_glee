-- mapvote module
if not MapVote then return end
if not game.IsDedicated() then return end

local mavoteDefaultTime = 20
local mapvoteVar = CreateConVar( "huntersglee_activetimeneededfor_mapvote", -1, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "minutes. added length of all ROUND_ACTIVE needed to force map vote (-1 for default, " .. mavoteDefaultTime .. ")", 0, math.huge )
-- added length of all ROUND_ACTIVE needed to force map vote, if gamemode was waiting for players to join, this stops the first round from kicking them to a new map.
-- also accounts for multiple short rounds
-- or one round that goes on way way too long

local mapVoteIncrement = 0
local doingMapVote = nil

local function startTheMapVoteTimer()
    timer.Create( "glee_mapvote_think", 1, 0, function()
        if not doingMapVote then
            if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

            local varTranslated = mapvoteVar:GetInt()
            if varTranslated < 0 then
                varTranslated = mavoteDefaultTime

            end

            varTranslated = varTranslated * 60

            mapVoteIncrement = mapVoteIncrement + 1
            local lessThanVar = mapVoteIncrement <= varTranslated
            if lessThanVar then return end

            doingMapVote = true

            GAMEMODE:SpeakAsHuntersGlee( "A forced mapvote has been queued..." )

        else
            -- wait until round and podium is over
            if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_INACTIVE then return end

            if not MapVote.state then return end
            if MapVote.state.isInProgress then return end

            GAMEMODE:SpeakAsHuntersGlee( "Starting forced mapvote..." )
            MapVote.Start()

            mapVoteIncrement = 0
            doingMapVote = nil

        end
    end )
end

hook.Add( "huntersglee_round_firstsetup", "glee_mapvote_setup", startTheMapVoteTimer )

hook.Add( "huntersglee_emptyserver", "glee_mapvote_reset", function()
    if mapVoteIncrement ~= 0 then return end
    mapVoteIncrement = 0

end )

hook.Add( "MapVote_RTVStart", "glee_stopsolidsounds_mapvote", function()
    GAMEMODE:SendSolidSound( "tracks/mapvoteMusic" )

end )
