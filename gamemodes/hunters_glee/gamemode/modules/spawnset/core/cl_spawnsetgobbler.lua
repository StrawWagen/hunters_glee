
local developer = GetConVar( "developer" )

local function readOptionalFloat()
    if not net.ReadBool() then return end
    return net.ReadFloat()

end

-- mirrors sv_spawnsetgobbler's writePublicSet, field for field
local function readPublicSet()
    local name = net.ReadString()
    local prettyName = net.ReadString()
    local description = net.ReadString()
    local easy = net.ReadBool()
    local tutorialExit = net.ReadBool()
    local chanceToBeVotable = readOptionalFloat()
    local chanceToBeVotableWhenHard = readOptionalFloat()

    return {
        name = name,
        prettyName = prettyName,
        description = description,
        easy = easy,
        tutorialExit = tutorialExit,
        chanceToBeVotable = chanceToBeVotable,
        chanceToBeVotableWhenHard = chanceToBeVotableWhenHard,
    }

end

-- a spawnset's clientside file only exists to run Activate and OnRemove, it never spawns
-- anything, so it doesn't need the spawn table or any of the fields the server validates.
-- the server's public fields win over the file's, the server validated them
local function mergeClientFile( spawnSet )
    if not istable( spawnSet ) then ErrorNoHaltWithStack( "GLEE: clientside spawnset isn't a table" ) return end
    if not isstring( spawnSet.name ) then ErrorNoHaltWithStack( "GLEE: clientside spawnset has invalid .name" ) return end

    local registered = GAMEMODE.RegisteredSpawnSets[spawnSet.name]
    if not registered then
        local msg = "GLEE: spawnset " .. spawnSet.name .. " only exists clientside, it can never be picked.\nIt needs a sv_ or sh_ file too"
        if developer:GetBool() then
            ErrorNoHaltWithStack( msg )

        else
            permaPrint( msg )

        end
        return

    end

    for key, value in pairs( spawnSet ) do
        if registered[key] ~= nil then continue end
        registered[key] = value

    end
end

local function deactivate()
    local lifecycle = GAMEMODE.CurrSpawnSetLifecycle
    if not lifecycle then return end

    lifecycle:InternalTeardown()
    GAMEMODE.CurrSpawnSetLifecycle = nil

end

local function activate( setName )
    deactivate()

    -- nothing is registered until the first gobble arrives, and that gobble activates the misery itself
    local asRegistered = GAMEMODE.RegisteredSpawnSets[setName]
    if not asRegistered then return end

    GAMEMODE.CurrSpawnSetLifecycle = include( "hunters_glee/gamemode/modules/spawnset/core/sh_spawnsetlifecyclebase.lua" )
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

    local registered = {}
    local setCount = net.ReadUInt( 16 )
    for _ = 1, setCount do
        local publicSet = readPublicSet()
        registered[publicSet.name] = publicSet

    end

    local activeSetName = net.ReadString()

    deactivate()
    GAMEMODE.RegisteredSpawnSets = registered

    GLEE_SPAWNSETS = {}

    for _, fileName in ipairs( fileNames ) do
        ProtectedCall( function( nameProtected ) include( "glee_spawnsets/" .. nameProtected ) end, fileName )

    end

    for _, spawnSet in pairs( GLEE_SPAWNSETS ) do
        mergeClientFile( spawnSet )

    end
    GLEE_SPAWNSETS = nil

    permaPrint( "GLEE: CL Gobbled " .. setCount .. " spawnsets..." )
    hook.Run( "glee_post_spawnsetgobble" )

    if activeSetName == "" then return end
    activate( activeSetName )

end )

net.Receive( "glee_spawnsetactivated", function()
    activate( net.ReadString() )

end )
