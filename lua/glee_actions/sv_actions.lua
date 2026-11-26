local glee_Actions = terminator_Extras.glee_Actions

util.AddNetworkString( "glee_actions_pick" )

-- runs key on ent, the action's own run, or the ent's OnGleeAction
-- true when it went through
-- checks nothing, see Pick for that
function glee_Actions.Run( ply, ent, key )
    local action = glee_Actions.Find( glee_Actions.Get( ent ), key )
    if not action then return end
    if action.run then return action.run( ent, ply ) end

    local def = glee_Actions.GetDef( ent )
    if not def.OnGleeAction then return end

    return def.OnGleeAction( ent, ply, key )

end

-- the client can't see everything that refuses an action, constraints for one, so it's told
local function notifyRefusal( ply, reason )
    if not reason then return end
    huntersGlee_Notify( { ply }, { text = reason, kind = "bad", time = 2 } )

end

-- ply picks key off ent, through the reach named reachName
-- checks it all again, the client's wheel can be out of date, eg someone else picked it up
-- true when it went through
function glee_Actions.Pick( ply, reachName, ent, key )
    local reach = glee_Actions.GetReach( reachName )
    if not reach or not IsValid( ent ) then return end
    if not reach.InReach( ply, ent ) then return end
    if not glee_Actions.Find( glee_Actions.Offered( reach, ent ), key ) then return end

    local canPick, reason = glee_Actions.CanPick( ply, ent, key )
    if not canPick then
        notifyRefusal( ply, reason )
        return

    end

    if reach.BeforeRun then reach.BeforeRun( ply, ent, key ) end

    return glee_Actions.Run( ply, ent, key )

end

local pickCooldown = 0.2

-- a wheel's pick, see SendPick in cl_actions.lua
net.Receive( "glee_actions_pick", function( _, ply )
    if ( ply.glee_NextActionPick or 0 ) > CurTime() then return end
    ply.glee_NextActionPick = CurTime() + pickCooldown

    local reachName = net.ReadString()
    local ent = net.ReadEntity()
    local key = net.ReadString()

    glee_Actions.Pick( ply, reachName, ent, key )

end )
