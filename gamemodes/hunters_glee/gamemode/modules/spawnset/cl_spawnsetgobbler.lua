
local developer = GetConVar( "developer" )

local GM = GAMEMODE or GM

GM.RegisteredSpawnSets = GM.RegisteredSpawnSets or {}

-- the clientside half of a spawnset only exists to run Activate and OnRemove, it never spawns
-- anything, so it doesn't need the spawn table or any of the fields the server validates
local function registerSpawnSet( spawnSet )
    if not istable( spawnSet ) then ErrorNoHaltWithStack( "GLEE: clientside spawnset isn't a table" ) return end
    if not isstring( spawnSet.name ) then ErrorNoHaltWithStack( "GLEE: clientside spawnset has invalid .name" ) return end

    GAMEMODE.RegisteredSpawnSets[spawnSet.name] = spawnSet

    return true

end

local function deactivate()
    local lifecycle = GAMEMODE.CurrSpawnSetLifecycle
    if not lifecycle then return end

    lifecycle:InternalTeardown()
    GAMEMODE.CurrSpawnSetLifecycle = nil

end

local function activate( setName )
    deactivate()

    -- most miseries have no clientside file at all, that isn't a problem
    local asRegistered = GAMEMODE.RegisteredSpawnSets[setName]
    if not asRegistered then return end

    GAMEMODE.CurrSpawnSetLifecycle = include( "hunters_glee/gamemode/modules/spawnset/sh_spawnsetlifecyclebase.lua" )
    GAMEMODE.CurrSpawnSetLifecycle:Apply( asRegistered )

end

local nextGobble = 0

net.Receive( "glee_spawnsetgobble", function()
    if nextGobble > CurTime() then return end
    nextGobble = CurTime() + 0.1

    local fileNames = {}
    local fileCount = net.ReadUInt( 16 )
    for _ = 1, fileCount do
        table.insert( fileNames, net.ReadString() )

    end

    local serverSetNames = {}
    local setCount = net.ReadUInt( 16 )
    for _ = 1, setCount do
        serverSetNames[net.ReadString()] = true

    end

    local activeSetName = net.ReadString()

    deactivate()
    GAMEMODE.RegisteredSpawnSets = {}
    GLEE_SPAWNSETS = {}

    for _, fileName in ipairs( fileNames ) do
        ProtectedCall( function( nameProtected ) include( "glee_spawnsets/" .. nameProtected ) end, fileName )

    end

    local count = 0
    for _, spawnSet in pairs( GLEE_SPAWNSETS ) do
        if registerSpawnSet( spawnSet ) then
            count = count + 1

        end
    end
    GLEE_SPAWNSETS = nil

    -- a misery the server never registered can't be voted for or set, so it would just sit here dead
    for name, _ in pairs( GAMEMODE.RegisteredSpawnSets ) do
        if serverSetNames[name] then continue end

        local msg = "GLEE: spawnset " .. name .. " only exists clientside, it can never be picked.\nIt needs a sv_ or sh_ file too"
        if developer:GetBool() then
            ErrorNoHaltWithStack( msg )

        else
            permaPrint( msg )

        end
        GAMEMODE.RegisteredSpawnSets[name] = nil
        count = count - 1

    end

    permaPrint( "GLEE: CL Gobbled " .. count .. " spawnsets..." )
    hook.Run( "glee_post_spawnsetgobble" )

    if activeSetName == "" then return end
    activate( activeSetName )

end )

net.Receive( "glee_spawnsetactivated", function()
    activate( net.ReadString() )

end )
