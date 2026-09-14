local defaultDuration = CreateConVar( "hunterslglee_modevote_duration", 20, FCVAR_ARCHIVE, "Default duration of the mode vote" )
local defaultMaxOptions = CreateConVar( "hunterslglee_modevote_maxoptions", 6, FCVAR_ARCHIVE, "Amount of options that show up in the mode vote", 2, 9 )

local GM = GM or GAMEMODE

local spawnSetVote = GM.glee_SpawnSetVote or {}
GM.glee_SpawnSetVote = spawnSetVote

util.AddNetworkString( "glee_begin_spawnsetvote" )

function spawnSetVote:BeginVote( duration, maxOptions )

    duration = duration or defaultDuration:GetInt()
    duration = math.Round( duration )

    maxOptions = maxOptions or defaultMaxOptions:GetInt()
    maxOptions = math.Round( maxOptions )
    maxOptions = math.Clamp( maxOptions, 2, 9 )

    local currVote = {}
    spawnSetVote.currVote = currVote

    currVote.voteEnd = CurTime() + duration
    currVote.votes = {}

    local options = {}
    currVote.options = options
    local optionsSeq = {}
    currVote.optionsSeq = optionsSeq

    local spawnSets = GAMEMODE:GetSpawnSets()
    local toBrowse = table.Copy( spawnSets )

    local currentSpawnsetName, currentSpawnSet = GAMEMODE:GetSpawnSet()
    local wantsOtherEasyOnes = currentSpawnSet.easy
    local doneEasyEscape
    local easyAdded = 0

    local toAdd = {}

    toBrowse[currentSpawnsetName] = nil -- remove current mode from options

    while table.Count( toBrowse ) > 0 do
        if ( #toAdd + 1 ) > maxOptions then break end

        local option, key = table.Random( toBrowse )
        toBrowse[key] = nil

        local optionsMul = GAMEMODE:GetSpawnsetsEscapeMultiplier( key )

        local chance = option.chanceToBeVotable
        if option.chanceToBeVotableWhenHard and optionsMul >= 1 then -- make spawnsets fade into the background if they aren't challenging people
            chance = option.chanceToBeVotableWhenHard

        end

        local plsSkip

        -- if in easy realm, prefer easy ones
        -- but always allow 1 hard misery
        if wantsOtherEasyOnes then
            -- this counts mul < 1 as easy, but no other code does it
            -- intentional transition space, might change later
            local optionIsEasy = option.easy or optionsMul < 1
            local enoughEasy = easyAdded + 2 > maxOptions
            local freebie = ( not chance or chance == 100 ) and not doneEasyEscape
            -- add 1 hard mode with 100% pick chance ( one of the default hard modes )
            -- or just add any hard mode if we're about to run out of room
            if enoughEasy or freebie then
                if optionIsEasy then
                    plsSkip = true

                else
                    plsSkip = false
                    doneEasyEscape = true

                end
            -- and fill the rest with easy modes
            else
                if optionIsEasy then
                    plsSkip = false

                else
                    plsSkip = true

                end
            end
        else
            plsSkip = isnumber( chance ) and chance < math.Rand( 0, 100 )

        end

        local stillEnoughToOverfill = ( table.Count( toBrowse ) + #toAdd ) > maxOptions -- always meet maxOptions

        if stillEnoughToOverfill and plsSkip then continue end
        table.insert( toAdd, option )

    end

    for _, set in SortedPairsByMemberValue( toAdd, "prettyName" ) do -- sorted so its alphabetical
        local prettyName = set.prettyName
        if wantsOtherEasyOnes and not set.easy then
            prettyName = prettyName .. " (HARD)"

        elseif not wantsOtherEasyOnes and set.easy then
            prettyName = prettyName .. " (EASY)"

        end
        local data = {
            name = set.name,
            prettyName = prettyName,
            description = set.description,
        }
        table.insert( optionsSeq, data )
        options[set.name] = data

    end

    GAMEMODE:SyncEscapeMultipliersForSpawnsets( table.GetKeys( options ) )

    net.Start( "glee_begin_spawnsetvote" )
        net.WriteInt( currVote.voteEnd, 20 ) -- overflows with 6d uptime, servers are never up that long
        net.WriteInt( #optionsSeq, 16 )
        for _, data in pairs( optionsSeq ) do
            net.WriteString( data.name )
            net.WriteString( data.prettyName )
            net.WriteString( data.description )

        end
    net.Send( player.GetAll() )

    permaPrint( "GLEE: A mode vote has begun" )

    timer.Create( "glee_spawnsetvote_end", duration, 1, function() -- one timername
        spawnSetVote:OnVoteEnd()

    end )
end

local function validVote( currVote )
    if not currVote then return end -- vote was cancelled
    if currVote.voteEnd + 1 < CurTime() then return end --- vote has ended
    return true

end

function spawnSetVote:RecieveVote( ply, name )
    local currVote = spawnSetVote.currVote
    if not validVote( currVote ) then return end

    if not currVote.options[name] then return end -- invalid vote

    local votes = currVote.votes
    votes[ply:SteamID64()] = name

end

local function applyVotedSpawnSet( set )
    GAMEMODE.rtmWaitingForRoundEnd = nil
    game.ConsoleCommand( "huntersglee_spawnset " .. set .. "\n" )
    huntersGlee_Announce( player.GetAll(), 150, 3, "NEW MISERY..." )
    timer.Simple( 2, function()
        huntersGlee_AnnounceDramatic( player.GetAll(), 1001, 5, GAMEMODE:GetPrettyNameOfSpawnSet( set ) .. "\nis your new Misery..." )

    end )
end

-- a winner voted in mid round waits in rtmWaitingForRoundEnd until one of these
local function applyPendingSpawnSet()
    local pending = GAMEMODE.rtmWaitingForRoundEnd
    if not pending then return end

    applyVotedSpawnSet( pending )

end

hook.Add( "huntersglee_round_into_inactive", "glee_setvotedspawnset", applyPendingSpawnSet )
hook.Add( "ShutDown", "glee_setvotedspawnset", applyPendingSpawnSet )
hook.Add( "MapVote_VoteStarted", "glee_setvotedspawnset", applyPendingSpawnSet )

function spawnSetVote:OnVoteEnd()
    local currVote = spawnSetVote.currVote
    if not validVote( currVote ) then return end

    local voteCounts = {}
    for name, _ in pairs( currVote.options ) do
        voteCounts[name] = 0

    end
    for _, name in pairs( currVote.votes ) do
        local old = voteCounts[name]
        voteCounts[name] = old + 1

    end

    spawnSetVote.winner = spawnSetVote:GetWinningKey( voteCounts )

    if spawnSetVote.winner == GAMEMODE:GetSpawnSet() then
        huntersGlee_AnnounceDramatic( player.GetAll(), 1001, 5, "Your Misery will remain; " .. GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetVote.winner ) .. "..." )
        spawnSetVote.currVote = nil

        return

    end

    -- print in console!
    permaPrint( "GLEE: Misery vote is over, winner is, " .. spawnSetVote.winner )
    -- and in people's chat!
    GAMEMODE:SpeakAsHuntersGlee( "the Misery vote winner; " .. GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetVote.winner ) )

    if GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE and GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, CurTime() ) > 60 then -- if round has properly started
        huntersGlee_AnnounceDramatic( player.GetAll(), 1001, 10, "The next Misery; " .. GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetVote.winner ) .. "\nwill arrive upon round end..." )
        GAMEMODE.rtmWaitingForRoundEnd = spawnSetVote.winner

    else
        applyVotedSpawnSet( spawnSetVote.winner )

    end

    spawnSetVote.currVote = nil

end

-- the voters are gone, drop their vote, and any winner still waiting for round end
-- clearing currVote is enough to cancel a vote in progress, OnVoteEnd bails on it
hook.Add( "huntersglee_emptyserver", "glee_reset_pendingmisery", function()
    spawnSetVote.currVote = nil
    GAMEMODE.rtmWaitingForRoundEnd = nil

end )

-- from cfc mapvote cause the code's clean and it handles every case
-- GIVE LOVE TO HMM
function spawnSetVote:GetWinningKey( tab )
    local highest = -math.huge
    local count = 0

    for _, v in pairs( tab ) do
        if v > highest then
            highest = v
            count = 1
        elseif v == highest then
            count = count + 1
        end
    end

    local desired = math.random( 1, count )
    local i = 0
    for k, v in pairs( tab ) do
        if v == highest then
            i = i + 1
        end
        if i == desired then
            return k
        end
    end

    return nil
end

concommand.Add( "glee_spawnset_castvote", function( ply, _, args, _ )
    spawnSetVote:RecieveVote( ply, args[1] )

end )
concommand.Add( "glee_spawnset_startvote", function( ply, _, args, _ )
    if IsValid( ply ) and not ply:IsAdmin() then return end
    spawnSetVote:BeginVote( args[1] )

end )

include( "sv_rtm.lua" )
