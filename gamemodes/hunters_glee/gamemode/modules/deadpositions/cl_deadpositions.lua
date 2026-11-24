-- The client's copy of where each player died, see sv_deadpositions.lua
-- a list of { ply, pos, time }, replaced whole by every send. time is the CurTime they died

potentialResurrectionData = {}

net.Receive( "glee_deadplayerpositions", function()
    local list = {}
    for _ = 1, net.ReadUInt( 8 ) do
        local ply = net.ReadEntity()
        local pos = net.ReadVector()
        local time = net.ReadFloat()
        table.insert( list, { ply = ply, pos = pos, time = time } )

    end
    potentialResurrectionData = list

end )
