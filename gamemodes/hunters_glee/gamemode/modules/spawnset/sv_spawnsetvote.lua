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

    local toAdd = { ["hunters_glee"] = toBrowse["hunters_glee"] } -- always include default
    toBrowse["hunters_glee"] = nil

    while table.Count( toBrowse ) > 0 do
        if ( #toAdd + 1 ) >= maxOptions then break end

        local option, key = table.Random( toBrowse )
        toBrowse[key] = nil

        local notVotableRand = isnumber( option.chanceToBeVotable ) and option.chanceToBeVotable < math.random( 0, 100 )
        local wouldBeOverfilled = ( table.Count( toBrowse ) + #toAdd ) > maxOptions -- always meet maxOptions

        if wouldBeOverfilled and notVotableRand then continue end
        table.insert( toAdd, option )

    end

    for _, set in SortedPairsByMemberValue( toAdd, "prettyName" ) do -- sorted so its alphabetical
        local data = {
            name = set.name,
            prettyName = set.prettyName,
            description = set.description,
        }
        table.insert( optionsSeq, data )
        options[set.name] = data

    end

    net.Start( "glee_begin_spawnsetvote" )
        net.WriteInt( currVote.voteEnd, 20 )
        net.WriteInt( #optionsSeq, 16 )
        for _, data in pairs( optionsSeq ) do
            net.WriteString( data.name )
            net.WriteString( data.prettyName )
            net.WriteString( data.description )

        end
    net.Send( player.GetAll() )

    print( "GLEE: A mode vote has begun" )

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
        huntersGlee_Announce( player.GetAll(), 1001, 5, "Mode will remain " .. GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetVote.winner ) .. "..." )
        spawnSetVote.currVote = nil

        return

    end

    local function setSpawnSet( set )
        hook.Remove( "huntersglee_round_into_inactive", "glee_setvotedspawnset" )
        hook.Remove( "MapVote_VoteStarted", "glee_setvotedspawnset" )
        hook.Remove( "ShutDown", "glee_setvotedspawnset" )
        game.ConsoleCommand( "huntersglee_spawnset " .. set .. "\n" )
        huntersGlee_Announce( player.GetAll(), 150, 3, "Setting mode..." )
        timer.Simple( 2, function()
            huntersGlee_Announce( player.GetAll(), 1001, 5, "Mode changed to " .. GAMEMODE:GetPrettyNameOfSpawnSet( set ) )

        end )
    end

    print( "GLEE: Mode vote is over, winner is, " .. spawnSetVote.winner )
    GAMEMODE:speakAsHuntersGlee( "Mode vote over! Winner is " .. GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetVote.winner ) )

    if GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE and GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, CurTime() ) > 60 then -- if round has properly started
        huntersGlee_Announce( player.GetAll(), 1001, 10, "Mode will be changed to " .. GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetVote.winner ) .. "\n on round end." )
        hook.Add( "huntersglee_round_into_inactive", "glee_setvotedspawnset", function()
            setSpawnSet( spawnSetVote.winner )

        end )
        hook.Add( "ShutDown", "glee_setvotedspawnset", function()
            setSpawnSet( spawnSetVote.winner )

        end )
        hook.Add( "MapVote_VoteStarted", "glee_setvotedspawnset", function()
            setSpawnSet( spawnSetVote.winner )

        end )
    else
        setSpawnSet( spawnSetVote.winner )

    end

    spawnSetVote.currVote = nil

end

-- from cfc mapvote cause the code's clean and it handles every case
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
