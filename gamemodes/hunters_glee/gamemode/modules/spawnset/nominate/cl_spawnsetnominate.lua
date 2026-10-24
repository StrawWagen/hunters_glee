
-- mirrors sv_spawnsetnominate's SyncMiseryNominations
net.Receive( "glee_misery_nominations", function()
    local nominations = {}

    local count = net.ReadUInt( 8 )
    for _ = 1, count do
        local steamID64 = net.ReadString()
        local setName = net.ReadString()
        local cost = net.ReadUInt( 32 )
        nominations[steamID64] = { setName = setName, cost = cost }

    end

    GAMEMODE.glee_MiseryNominations = nominations

    local suspended = {}
    if net.ReadBool() then
        local setName = net.ReadString()
        local cost = net.ReadUInt( 32 )
        suspended[LocalPlayer():SteamID64()] = { setName = setName, cost = cost }

    end

    GAMEMODE.glee_SuspendedMiseryNominations = suspended

end )

-- any misery can be nominated by name, autocomplete only offers the ones you've seen
local function autoComplete( cmd, argStr )
    local typed = string.Trim( string.lower( argStr ) )

    local completions = {}
    for setName, _ in SortedPairs( GAMEMODE:GetSpawnSets() ) do
        if not GAMEMODE:HasSeenMisery( setName ) then continue end
        if not string.find( string.lower( setName ), typed, 1, true ) then continue end
        table.insert( completions, cmd .. " " .. setName )

    end
    return completions

end

concommand.Add( "huntersglee_misery_nominate", function( _, _, args, _ )
    net.Start( "glee_misery_nominate" )
        net.WriteString( args[1] or "" )
    net.SendToServer()

end, autoComplete, "Nominate a Misery for the next Misery vote" )

concommand.Add( "huntersglee_misery_withdraw", function()
    net.Start( "glee_misery_withdraw" )
    net.SendToServer()

end, nil, "Withdraw your Misery nomination, suspended or not, forfeiting what it cost" )
