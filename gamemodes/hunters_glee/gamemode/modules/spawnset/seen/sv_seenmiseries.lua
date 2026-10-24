
-- Every misery each player knows the name of, see cl_seenmiseries
local seenMiseries = GM:CreateClientSet( "seenmiseries" )

function GM:HasSeenMisery( ply, setName )
    return seenMiseries:Has( ply, setName )

end

function GM:MarkMiserySeen( ply, setName )
    seenMiseries:Add( ply, setName )

end

hook.Add( "huntersglee_round_into_limbo", "glee_markmiseryseen", function()
    local setName = GAMEMODE:GetSpawnSet()
    if not setName then return end

    for _, ply in ipairs( player.GetHumans() ) do
        GAMEMODE:MarkMiserySeen( ply, setName )

    end
end )
