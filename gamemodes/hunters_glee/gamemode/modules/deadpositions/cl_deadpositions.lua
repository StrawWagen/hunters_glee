-- The client's copy of where each player died, see sv_deadpositions.lua
-- a list of { ply, pos }, replaced whole by every send

potentialResurrectionData = {}

net.Receive( "glee_deadplayerpositions", function()
    local list = {}
    for _ = 1, net.ReadUInt( 8 ) do
        local ply = net.ReadEntity()
        local pos = net.ReadVector()
        table.insert( list, { ply = ply, pos = pos } )

    end
    potentialResurrectionData = list

end )
