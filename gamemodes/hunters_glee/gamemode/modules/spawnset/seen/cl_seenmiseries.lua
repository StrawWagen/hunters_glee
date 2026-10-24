
-- Every misery this player knows the name of, from playing it, a vote offering it, or nominating it blind.
-- Not a lesson, lessons expire and this never should
local seenMiseries = GM:CreateClientSet( "seenmiseries", { fileName = "seenmiseries.json" } )

-- Takes ( setName ) or ( ply, setName ), like the lesson functions, so shared code can call it the
-- same way the server's is called. ply can only ever be LocalPlayer here
function GM:HasSeenMisery( plyOrName, setName )
    if isstring( plyOrName ) then
        setName = plyOrName

    end
    return seenMiseries:Has( setName )

end
