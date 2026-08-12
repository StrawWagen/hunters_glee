local GM = GM or GAMEMODE

local validPrefixes = {
    ["sh_"] = true,
    ["sv_"] = true,
    ["cl_"] = true,
}

-- two letters and an underscore is someone reaching for a prefix, so a wrong one is worth shouting about.
-- anything else was never trying to be prefixed and loads server only, like every spawnset written before this existed.
-- returns nil and the bad prefix when it was reaching and missed
local function prefixOf( fileName )
    local prefix = string.match( fileName, "^%a%a_" )
    if not prefix then
        return "sv_"

    end

    if not validPrefixes[prefix] then
        return nil, prefix

    end

    return prefix

end

-- clients ask for their files long before the first round sets up, so these go out at load,
-- not alongside the include pass in GobbleSpawnsets. bad prefixes are left for that pass to complain about
local filesAtLoad = file.Find( "glee_spawnsets/*.lua", "LUA" )
for _, fileName in ipairs( filesAtLoad ) do
    local prefix = prefixOf( fileName )
    if not prefix then continue end
    if prefix == "sv_" then continue end

    AddCSLuaFile( "glee_spawnsets/" .. fileName )

end

-- includes every spawnset file this realm should run, then registers what they defined.
-- clientside files are only listed here, the client includes those itself
function GM:GobbleSpawnsets()
    GLEE_SPAWNSETS = {}
    self.validClientSpawnsetFiles = {}

    local spawnsetFiles = file.Find( "glee_spawnsets/*.lua", "LUA" )
    for _, fileName in ipairs( spawnsetFiles ) do
        local prefix, badPrefix = prefixOf( fileName )
        if not prefix then
            ErrorNoHaltWithStack( "GLEE: Invalid spawnset prefix " .. badPrefix .. " in file " .. fileName .. "\nNeeds to be sh_, sv_, or cl_ or prefixless (becomes sv_)" )
            continue

        end

        if prefix ~= "cl_" then
            ProtectedCall( function( nameProtected ) include( "glee_spawnsets/" .. nameProtected ) end, fileName )

        end

        if prefix ~= "sv_" then
            self.validClientSpawnsetFiles[fileName] = true

        end
    end

    local count = 0
    for _, spawnSet in pairs( GLEE_SPAWNSETS ) do
        if self:RegisterSpawnSet( spawnSet ) then
            count = count + 1

        end
    end
    GLEE_SPAWNSETS = nil

    return count

end


-- we never send spawnsets to clients, just the files to include() and the names we registered.
-- the names are so a client can tell when it has a spawnset the server doesn't
util.AddNetworkString( "glee_spawnsetgobble" )

function GM:UpdateSpawnsetsFor( plyOrPlys )
    if not self.validClientSpawnsetFiles then return end

    net.Start( "glee_spawnsetgobble" )
        net.WriteUInt( table.Count( self.validClientSpawnsetFiles ), 16 )
        for fileName, _ in pairs( self.validClientSpawnsetFiles ) do
            net.WriteString( fileName )

        end

        net.WriteUInt( table.Count( self.RegisteredSpawnSets ), 16 )
        for name, _ in pairs( self.RegisteredSpawnSets ) do
            net.WriteString( name )

        end

        -- the client can't activate a lifecycle before it has gobbled, so the active misery
        -- rides along here rather than racing the gobble as its own message
        net.WriteString( self.CurrSpawnSetName or "" )
    net.Send( plyOrPlys )

end


util.AddNetworkString( "glee_spawnsetactivated" )

function GM:TellClientsSpawnsetActivated( setName )
    net.Start( "glee_spawnsetactivated" )
        net.WriteString( setName )
    net.Broadcast()

end


hook.Add( "glee_post_spawnsetgobble", "glee_spawnsetgobbler_resend", function()
    GAMEMODE:UpdateSpawnsetsFor( player.GetAll() )

end )

hook.Add( "glee_full_load", "glee_spawnsetgobbler_send", function( ply )
    GAMEMODE:UpdateSpawnsetsFor( ply )

end )
