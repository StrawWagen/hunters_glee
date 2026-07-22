
local isnumber = isnumber
local isstring = isstring
local isfunction = isfunction
local GAMEMODE = GAMEMODE or GM

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

GAMEMODE.RegisteredSpawnSets = GAMEMODE.RegisteredSpawnSets or {}

-- sibling data file in this same spawnset/ folder
local setDefaults = include( "sv_spawnsetdefaults.lua" )

local spawnDefaults = {
    minCount = -1, -- if these aren't defined, sets to -1 which makes them ignored
    maxCount = -1, -- just this is ignored, it still respects maxSpawnCount tho
}

local spawnIgnored = { -- dont parse these, they run on the ents during spawning
    preSpawnedFunc = true,
    postSpawnedFunc = true,
    isBoss = true, -- boolean, handled by sv_bosshandler
}

local function asParsed( toParse, name, defaultsTbl )
    local finalMul = 1
    local default = defaultsTbl[name]
    if default then
        if not toParse then
            -- soft default
            toParse = default

        elseif isstring( toParse ) then
            -- explicit default
            if toParse == "default" then
                toParse = default

            -- dynamically mul the default!
            -- eg default*1.5, default*0.25
            -- much better than setting something independant from the default
            -- because the defaults will change eventually....
            elseif string.match( toParse, "^default%*[%d%.]+$" ) then
                local multiplier = tonumber( string.match( toParse, "[%d%.]+$" ) )
                if multiplier then
                    toParse = default
                    finalMul = multiplier

                end
            end
        end

    elseif not toParse then
        return nil -- no default, and nothing to parse

    end

    -- number or parsed default
    if isnumber( toParse ) then return toParse * finalMul end

    -- accepts functions
    if isfunction( toParse ) then return toParse end

    -- allow strings if we expect them
    if isstring( default ) and isstring( toParse ) then
        return toParse

    end

    -- 1 member table
    if #toParse <= 1 and isnumber( toParse[1] ) then return toParse[1] * finalMul end
    -- 2 member tables, picked num will be between them, different each round
    if #toParse <= 2 and isnumber( toParse[1] ) and isnumber( toParse[2] ) then return math.Rand( toParse[1], toParse[2] ) * finalMul end

end

local function yapErr( spawnSet, yapStr )
    ErrorNoHaltWithStack( "GLEE: spawnSet " .. spawnSet.name .. " " .. yapStr )

end

function GM:IsValidSpawnSet( spawnSet )
    if isstring( spawnSet ) then
        local targetName = spawnSet
        local sets = self:GetSpawnSets()
        spawnSet = sets[targetName]
        if not spawnSet then ErrorNoHaltWithStack( targetName .. " is not a registered spawn set" ) return end

    end
    if not istable( spawnSet ) then ErrorNoHaltWithStack( "Spawnset is not a table" ) return end
    if not isstring( spawnSet.name ) then ErrorNoHaltWithStack( "Spawnset has invalid .name" ) return end
    if not isstring( spawnSet.prettyName ) then yapErr( spawnSet, "has invalid .prettyName" ) return end
    if not isstring( spawnSet.description ) then yapErr( spawnSet, "has invalid .description" ) return end

    for name, _ in pairs( setDefaults ) do
        if not asParsed( spawnSet[name], name, setDefaults ) then
            yapErr( spawnSet, "has invalid ." .. name )
            return

        end
    end

    local spawns = spawnSet.spawns
    if not istable( spawns ) then yapErr( spawnSet, "has invalid .spawns" ) return end
    for ind, spawn in ipairs( spawns ) do
        local name = spawn.name
        if not isstring( name ) then
            PrintTable( spawn )
            permaPrint( spawn.name )
            yapErr( spawnSet, "entry " .. ind .. " has invalid .name in .spawns" )
            return

        end
        if not isstring( spawn.prettyName ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .prettyname" ) return end
        if not isstring( spawn.class ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .class" ) return end

        local minCount = asParsed( spawn.minCount, "minCount", spawnDefaults )
        if not minCount then yapErr( spawnSet, ".spawns " .. name .. " invalid .minCount" ) return end
        local maxCount = asParsed( spawn.maxCount, "maxCount", spawnDefaults )
        if not maxCount then yapErr( spawnSet, ".spawns " .. name .. " invalid .maxCount" ) return end

        local thisEntryHasMinMax = maxCount > -1 or minCount > -1
        local countClass = spawn.countClass
        -- if min or max count, .countClass needs to be a string
        if thisEntryHasMinMax and not isstring( countClass ) then
            yapErr( spawnSet, ".spawns " .. name .. " invalid .countClass" )
            return

        -- else, .countClass needs to be a string or nil
        elseif not isstring( countClass ) and countClass ~= nil then
            yapErr( spawnSet, ".spawns " .. name .. " invalid .countClass" )
            return

        end

        if not asParsed( spawn.difficultyCost, "difficultyCost", spawnDefaults ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .difficultyCost" ) return end

    end

    return true
end

-- parse spawnset variables into numbers
local function parse( tbl, name, defaultsTbl, spawnSet )
    local toParse = tbl[name]
    local parsed = asParsed( toParse, name, defaultsTbl )

    if isfunction( parsed ) then
        -- it accepts functions!!!!!!
        --[[eg,
            .maxCount = function( spawnSet )
                return spawnset.maxSpawnCount
            end,
        --]]
        local noErrors, returned = xpcall( toParse, errorCatchingMitt, spawnSet )
        if noErrors == false then
            yapErr( spawnSet, " ." .. name .. " function errored! " )
            return

        end

        returned = asParsed( returned, name, defaultsTbl ) -- parse the result too...
        if not returned then yapErr( spawnSet, " invalid return from ." .. name ) return end

        tbl[name] = returned

    elseif isnumber( parsed ) or isstring( parsed ) then
        tbl[name] = parsed

    end
end

-- turn the spawnset config into usable data
-- eg;
--  .maxSpawnDist = 5000, always 5000
--  .maxSpawnDist = "default", always default, as defined by the setDefaults tbl
--  .maxSpawnDist = "default*0.75", always 75% of default
--  .maxSpawnDist = { 4000, 6000 }, a random value between 4k and 6k, different between each round

function GM:ParsedSpawnSet( asRegistered )
    local spawnSet = table.Copy( asRegistered )

    local setParsed = {}
    for name, _ in pairs( spawnSet ) do -- parse all existing spawnset variables
        parse( spawnSet, name, setDefaults, spawnSet )
        setParsed[name] = true

    end
    for name, _ in pairs( setDefaults ) do -- setup the nil defaults that weren't set
        if setParsed[name] then continue end
        parse( spawnSet, name, setDefaults, spawnSet )

    end

    for _, currSpawn in ipairs( spawnSet.spawns ) do
        local spawnParsed = {}
        for name, _ in pairs( currSpawn ) do -- parse all existing spawnset variables
            if spawnIgnored[name] then spawnParsed[name] = true continue end
            parse( currSpawn, name, spawnDefaults, spawnSet )
            spawnParsed[name] = true

        end
        for name, _ in pairs( spawnDefaults ) do -- get the nil defaults
            if spawnParsed[name] then continue end
            if spawnIgnored[name] then continue end
            parse( currSpawn, name, spawnDefaults, spawnSet )

        end
    end

    -- let consumers ( eg the spawner ) attach their own runtime fields to the parsed set
    -- the spawnset module deliberately knows nothing about what those fields are
    hook.Run( "glee_spawnset_parsed", spawnSet )

    return spawnSet

end

-- set spawnset
function GM:SetSpawnSet( setName )

    local oldSetName = self.CurrSpawnSetName

    local asRegistered = self.RegisteredSpawnSets[setName]
    if not asRegistered then ErrorNoHaltWithStack( "GLEE: Tried to enable invalid spawnset " .. setName ) return end

    local spawnSet = self:ParsedSpawnSet( asRegistered )

    self:HandleBossDetection( spawnSet )

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = spawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )
    SetGlobalString( "GLEE_SpawnSetPrettyName", spawnSet.prettyName )
    SetGlobalString( "GLEE_SpawnSetDescription", spawnSet.description or "" )

    if oldSetName ~= setName then
        hook.Run( "glee_post_new_spawnset", setName, spawnSet, oldSetName )
        permaPrint( "GLEE: Mode set to, " .. setName )

    else
        hook.Run( "glee_post_refresh_spawnset", setName, spawnSet, oldSetName )

    end

    hook.Run( "glee_post_set_spawnset", setName, spawnSet, oldSetName )

end

function GM:RegisterSpawnSet( spawnSet )
    if not self:IsValidSpawnSet( spawnSet ) then permaPrint( "GLEE: tried to register inavlid spawnset" ) return end

    local exists = self.RegisteredSpawnSets[spawnSet.name]
    if exists then permaPrint( "GLEE, overriding old " .. spawnSet.name .. " spawnSet" ) end

    self.RegisteredSpawnSets[spawnSet.name] = spawnSet

    return true

end

function GM:GetSpawnSets()
    return self.RegisteredSpawnSets

end

function GM:GetSpawnSet()
    return self.CurrSpawnSetName, self.CurrSpawnSet

end

function GM:ScaledGenericSpawnerRate( var )
    local set = self.CurrSpawnSet
    if not set then return var end

    return var * set.genericSpawnerRate

end

function GM:GetPrettyNameOfSpawnSet( setName )
    local asRegistered = GAMEMODE.RegisteredSpawnSets[setName]
    if not asRegistered then return "" end
    return asRegistered.prettyName

end

local defaultSpawnSetName = "hunters_glee"
local function postSetSpawnset( new ) -- validate the spawnset cvar
    if not GAMEMODE:IsValidSpawnSet( new ) then
        if GAMEMODE:IsValidSpawnSet( defaultSpawnSetName ) then
            RunConsoleCommand( "huntersglee_spawnset", defaultSpawnSetName )
            permaPrint( "Valid spawnsets are..." )
            for _, set in SortedPairsByMemberValue( GAMEMODE:GetSpawnSets(), "name" ) do
                permaPrint( set.name )

            end
        end
    else -- all good!
        GAMEMODE:SetSpawnSet( new )

    end
end


local spawnSetVar = CreateConVar( "huntersglee_spawnset", defaultSpawnSetName, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "What spawnset the gamemode should use." )
cvars.AddChangeCallback( "huntersglee_spawnset", function( _, _, new )
    if not GAMEMODE.GobbledSpawnsets then -- wait until spawnsets are valid
        hook.Add( "glee_post_spawnsetgobble", "glee_validatecvar_delayed", function()
            postSetSpawnset( new )
            hook.Remove( "glee_post_spawnsetgobble", "glee_validatecvar_delayed" )

        end )
    else
        postSetSpawnset( new )

    end

end, "glee_notifyinvalidspawnsets" )


function GM:SpawnSetInitialThink()
    GLEE_SPAWNSETS = {}

    local spawnsetFiles = file.Find( "glee_spawnsets/*.lua", "LUA" )
    for _, name in ipairs( spawnsetFiles ) do
        ProtectedCall( function( nameProtected ) include( "glee_spawnsets/" .. nameProtected ) end, name )

    end
    local count = 0
    for _, spawnSet in pairs( GLEE_SPAWNSETS ) do
        if self:RegisterSpawnSet( spawnSet ) then
            count = count + 1

        end
    end
    permaPrint( "GLEE: Gobbled " .. count .. " spawnsets..." )
    GLEE_SPAWNSETS = nil

    self.GobbledSpawnsets = true
    hook.Run( "glee_post_spawnsetgobble" )

    local spawnSetPicked = spawnSetVar:GetString()
    if not self:IsValidSpawnSet( spawnSetPicked ) then
        permaPrint( "GLEE: INVALID SPAWNSET " .. spawnSetPicked )
        spawnSetPicked = defaultSpawnSetName
        RunConsoleCommand( "huntersglee_spawnset", spawnSetPicked )

    end

    self:SetSpawnSet( spawnSetPicked )

end

-- gobble all the custom spawnsets
hook.Add( "huntersglee_round_firstsetup", "glee_spawnset_think", function() GAMEMODE:SpawnSetInitialThink() end )

-- re-parse the spawnset when a new round is started
-- so each round gets a different roll of all the random fields in the spawnsets
hook.Add( "huntersglee_round_leave_limbo", "glee_spawnset_reparse", function() GAMEMODE:SetSpawnSet( spawnSetVar:GetString() ) end )

-- let people joining the server have the default glee experience
hook.Add( "huntersglee_emptyserver", "glee_reset_spawnset", function( wasEmpty )
    if wasEmpty then return end -- only run this if there were people online, and are no longer people online
    local name = GAMEMODE:GetSpawnSet()
    if name == defaultSpawnSetName then return end
    RunConsoleCommand( "huntersglee_spawnset", defaultSpawnSetName )
    permaPrint( "GLEE: reset spawnset on empty server" )

end )
