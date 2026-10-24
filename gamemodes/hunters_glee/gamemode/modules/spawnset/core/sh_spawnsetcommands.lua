
-- huntersglee_misery is a convar, and convars can't autocomplete, so huntersglee_misery_setto sets it.
-- It's clientside only, the server takes it over net. A server command of the same name takes its
-- place in a listen server's shared console, autocomplete and all. The server console has the convar

if SERVER then
    util.AddNetworkString( "glee_misery_setto" )

    net.Receive( "glee_misery_setto", function( _, ply )
        if not ply:IsSuperAdmin() then return end

        local setName = net.ReadString()
        if not GAMEMODE:GetRegisteredSpawnSet( setName ) then
            ply:PrintMessage( HUD_PRINTCONSOLE, "GLEE: " .. setName .. " is not a registered Misery" )
            ply:PrintMessage( HUD_PRINTCONSOLE, "Valid spawnsets are..." )
            for _, set in SortedPairsByMemberValue( GAMEMODE:GetSpawnSets(), "name" ) do
                ply:PrintMessage( HUD_PRINTCONSOLE, set.name )

            end
            return

        end

        RunConsoleCommand( "huntersglee_misery", setName )

    end )

    return

end

local function autoComplete( cmd, argStr )
    if not LocalPlayer():IsSuperAdmin() then return {} end

    local typed = string.Trim( string.lower( argStr ) )

    local completions = {}
    for setName, _ in SortedPairs( GAMEMODE:GetSpawnSets() ) do
        if not string.find( string.lower( setName ), typed, 1, true ) then continue end
        table.insert( completions, cmd .. " " .. setName )

    end
    return completions

end

concommand.Add( "huntersglee_misery_setto", function( _, _, args, _ )
    net.Start( "glee_misery_setto" )
        net.WriteString( args[1] or "" )
    net.SendToServer()

end, autoComplete, "Set the Misery, superadmin only" )
