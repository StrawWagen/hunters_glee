
-- Client sets, per-player progress kept in the player's own data folder, so it follows them to every
-- server and no server has to store anything per player. This is the server's copy, for the session.
-- A client can write anything into its file, so never gate something that matters on one.
-- The netmessage finds a set by name, so create each under the same name in both realms
util.AddNetworkString( "glee_clientsets" )

local modeAdd = 1
local modeReset = 2

local setMeta = {}
setMeta.__index = setMeta

-- [name] = set
local sets = {}

function GM:CreateClientSet( name )
    local set = setmetatable( { name = name }, setMeta )
    sets[name] = set

    return set

end

-- keys is the client's set, serverAdded is what this server added this session
local function stateFor( ply, name )
    local states = ply.glee_ClientSets or {}
    ply.glee_ClientSets = states

    local state = states[name]
    if not state then
        state = { keys = {}, serverAdded = {} }
        states[name] = state

    end
    return state

end

function setMeta:Has( ply, key )
    local states = ply.glee_ClientSets
    if not states or not states[self.name] then return false end

    return states[self.name].keys[key] == true

end

-- Returns true only the first time, same as the clientside one
function setMeta:Add( ply, key )
    local state = stateFor( ply, self.name )
    if state.keys[key] then return false end

    state.keys[key] = true
    state.serverAdded[key] = true

    net.Start( "glee_clientsets" )
        net.WriteString( self.name )
        net.WriteUInt( modeAdd, 2 )
        net.WriteString( key )
    net.Send( ply )

    return true

end

function setMeta:ResetFor( plys )
    for _, ply in ipairs( plys ) do
        local states = ply.glee_ClientSets
        if not states then continue end
        states[self.name] = nil

    end

    net.Start( "glee_clientsets" )
        net.WriteString( self.name )
        net.WriteUInt( modeReset, 2 )
    net.Send( plys )

end

net.Receive( "glee_clientsets", function( _, ply )
    local set = sets[net.ReadString()]
    if not set then return end

    local state = stateFor( ply, set.name )

    -- the client already batches a burst of adds into one send, so this only has to stop
    -- a client sending faster than that
    local nextSync = state.nextSync or 0
    if nextSync > CurTime() then return end
    state.nextSync = CurTime() + 0.01

    -- the client sends its whole set every time, so this replaces rather than merges, an empty set
    -- arrives as a reset. what we added ourselves is kept, the client may not have had it when it sent
    local keys = table.Copy( state.serverAdded )

    local count = net.ReadUInt( 12 )
    for _ = 1, count do
        keys[net.ReadString()] = true

    end

    state.keys = keys

    hook.Run( "glee_clientset_synced", ply, set.name )

end )
