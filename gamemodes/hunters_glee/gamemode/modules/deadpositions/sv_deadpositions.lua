-- Where each player died, kept in GAMEMODE.deadPlayers, see cl_deadpositions.lua for the client's copy
-- the tissue reclaimer revives them there
-- every client gets the whole list whenever it changes, each send replaces the last, so the respawned drop off it too

util.AddNetworkString( "glee_deadplayerpositions" )

local syncQueued = false
local nextSync = 0
local syncInterval = 0.1 -- deaths in a burst go out together

-- sent on the next Think, however many queue it up before then
function GM:QueueDeadPlayersSync()
    syncQueued = true

end

local function sendDeadPlayers()
    local list = {}
    for _, data in pairs( GAMEMODE.deadPlayers ) do
        if IsValid( data.ply ) then
            table.insert( list, data )

        end
    end

    net.Start( "glee_deadplayerpositions" )
    net.WriteUInt( #list, 8 )
    for _, data in ipairs( list ) do
        net.WriteEntity( data.ply )
        net.WriteVector( data.pos )

    end
    net.Broadcast()

end

hook.Add( "Think", "glee_reclaimer_syncdeadplayers", function()
    if not syncQueued then return end
    if nextSync > CurTime() then return end

    syncQueued = false
    nextSync = CurTime() + syncInterval
    sendDeadPlayers()

end )

-- GM:PlayerSpawn takes them off the list after the hooks, it's gone by the time the sync goes out
hook.Add( "PlayerSpawn", "glee_reclaimer_syncrespawned", function()
    GAMEMODE:QueueDeadPlayersSync()

end )

-- joining mid round, they've missed every sync so far
hook.Add( "glee_full_load", "glee_reclaimer_syncjoined", function()
    GAMEMODE:QueueDeadPlayersSync()

end )

hook.Add( "PlayerDeath", "saveResurrectPos", function( victim )
    -- snap DOWN underneath the death pos
    -- dont snap to a cliff edge a player suicided just off of
    -- snap to the ground at the bottom of the cliff
    local pos = victim:GetPos()
    local tr = util.TraceHull( {
        start = pos,
        endpos = pos + Vector( 0, 0, -5000 ),
        mins = victim:OBBMins() * Vector( 0, 0, 0.01 ),
        maxs = victim:OBBMaxs() * Vector( 0, 0, 0.01 ),
        mask = MASK_PLAYERSOLID_BRUSHONLY,
    } )

    local area = navmesh.GetNearestNavArea( tr.HitPos, false, 500, false, true )

    if IsValid( area ) then
        pos = area:GetClosestPointOnArea( pos )

    end

    GAMEMODE.deadPlayers[victim:GetCreationID()] = { ply = victim, pos = pos }
    GAMEMODE:QueueDeadPlayersSync()

end )
