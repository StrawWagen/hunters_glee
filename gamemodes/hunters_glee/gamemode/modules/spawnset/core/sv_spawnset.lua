
local isnumber = isnumber
local isstring = isstring
local isfunction = isfunction
local GAMEMODE = GAMEMODE or GM

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end

-- sibling file in this same core/ folder, field defaults and validators
local schema = include( "sv_spawnsetschema.lua" )
local setDefaults = schema.setDefaults
local rawSpawnSetFields = schema.rawSpawnSetFields
local spawnDefaults = schema.spawnDefaults
local slotSizeDefaults = schema.slotSizeDefaults
local validSpawnTypes = schema.validSpawnTypes
local rawSpawnFieldValidators = schema.rawSpawnFieldValidators
local slotSizeScales = schema.slotSizeScales
local setCommonTypos = schema.setCommonTypos
local spawnCommonTypos = schema.spawnCommonTypos

local developerVar = GetConVar( "developer" )

local function findTypo( tbl, commonTypos )
    for typo, correct in pairs( commonTypos ) do
        if tbl[typo] ~= nil then return typo, correct end

    end
end

-- "default*1.5" gives "default", 1.5
-- nil for anything else, eg "default*1.2.3" or 5
local function splitMul( str )
    if not isstring( str ) then return end

    local word, mulStr = string.match( str, "^(%a+)%*([%d%.]+)$" )
    if not word then return end

    local mul = tonumber( mulStr )
    if not mul then return end

    return word, mul

end

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

            else
                -- dynamically mul the default!
                -- eg default*1.5, default*0.25
                -- much better than setting something independant from the default
                -- because the defaults will change eventually....
                local word, mul = splitMul( toParse )
                if word == "default" then
                    toParse = default
                    finalMul = mul

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

    local setTypo, setCorrect = findTypo( spawnSet, setCommonTypos )
    if setTypo then yapErr( spawnSet, "has ." .. setTypo .. ", did you mean ." .. setCorrect .. "?" ) return end

    if not isstring( spawnSet.prettyName ) then yapErr( spawnSet, "has invalid .prettyName" ) return end
    if not isstring( spawnSet.description ) then yapErr( spawnSet, "has invalid .description" ) return end
    if spawnSet.author ~= nil and not isstring( spawnSet.author ) then yapErr( spawnSet, "has invalid .author" ) return end

    for name, _ in pairs( setDefaults ) do
        if not asParsed( spawnSet[name], name, setDefaults ) then
            yapErr( spawnSet, "has invalid ." .. name )
            return

        end
    end

    local slotSizes = spawnSet.slotSizes
    if slotSizes ~= nil then
        if not istable( slotSizes ) then yapErr( spawnSet, "has invalid .slotSizes" ) return end
        for slot, size in pairs( slotSizes ) do
            local scale = splitMul( size )
            local isScaled = scale and slotSizeScales[scale]
            if not isScaled and not asParsed( size, slot, slotSizeDefaults ) then
                yapErr( spawnSet, "has invalid .slotSizes " .. slot )
                return

            end
        end
    end

    local spawns = spawnSet.spawns
    if not istable( spawns ) then yapErr( spawnSet, "has invalid .spawns" ) return end
    local seenNames = {}
    for ind, spawn in ipairs( spawns ) do
        local name = spawn.name
        if not isstring( name ) then
            PrintTable( spawn )
            permaPrint( spawn.name )
            yapErr( spawnSet, "entry " .. ind .. " has invalid .name in .spawns" )
            return

        end

        -- .cooldown is tracked by name, so entries sharing one share a cooldown
        if seenNames[name] and developerVar:GetBool() then
            permaPrint( "GLEE: spawnSet " .. spawnSet.name .. " has more than one .spawns entry named " .. name )

        end
        seenNames[name] = true

        local spawnTypo, spawnCorrect = findTypo( spawn, spawnCommonTypos )
        if spawnTypo then yapErr( spawnSet, ".spawns " .. name .. " has ." .. spawnTypo .. ", did you mean ." .. spawnCorrect .. "?" ) return end

        if not isstring( spawn.prettyName ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .prettyname" ) return end
        if not isstring( spawn.class ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .class" ) return end
        if not validSpawnTypes[spawn.spawnType] then yapErr( spawnSet, ".spawns " .. name .. " invalid .spawnType" ) return end

        for fieldName, validator in pairs( rawSpawnFieldValidators ) do
            local whatSpawnHas = spawn[fieldName]
            if not whatSpawnHas then continue end
            local valid, notValidReason = validator( whatSpawnHas )
            if not valid then yapErr( spawnSet, ".spawns " .. name .. " " .. fieldName .. " " .. notValidReason ) return end

        end

        local minCount = asParsed( spawn.minCount, "minCount", spawnDefaults )
        if not minCount then yapErr( spawnSet, ".spawns " .. name .. " invalid .minCount" ) return end
        local maxCount = asParsed( spawn.maxCount, "maxCount", spawnDefaults )
        if not maxCount then yapErr( spawnSet, ".spawns " .. name .. " invalid .maxCount" ) return end

        -- nil falls back to .class
        local countClass = spawn.countClass
        if not isstring( countClass ) and countClass ~= nil then
            yapErr( spawnSet, ".spawns " .. name .. " invalid .countClass" )
            return

        end
        -- only .minCount and .maxCount read it
        local hasMinMax = maxCount > -1 or minCount > -1
        if countClass and not hasMinMax and developerVar:GetBool() then
            permaPrint( "GLEE: spawnSet " .. spawnSet.name .. " .spawns entry " .. name .. " has a .countClass but no .minCount or .maxCount" )

        end
        if countClass == spawn.class and developerVar:GetBool() then
            permaPrint( "GLEE: spawnSet " .. spawnSet.name .. " .spawns entry " .. name .. " has a .countClass that's the same as its .class, it can be left out" )

        end

        if not asParsed( spawn.difficultyCost, "difficultyCost", spawnDefaults ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .difficultyCost" ) return end

        if spawn.cooldown ~= nil and not asParsed( spawn.cooldown, "cooldown", spawnDefaults ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .cooldown" ) return end

        -- without .slotSizes, every slot holds 1
        if slotSizes and spawn.slots then
            for _, slot in ipairs( spawn.slots ) do
                if slotSizes[slot] == nil then yapErr( spawnSet, ".spawns " .. name .. " has slot " .. slot .. " that isn't in .slotSizes" ) return end

            end
        end

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
        if not returned then yapErr( spawnSet, " invalid return from ." .. name .. "\n(or an unexpected function on the spawnset tbl)" ) return end

        tbl[name] = returned

    elseif isnumber( parsed ) or isstring( parsed ) then
        tbl[name] = parsed

    end
end

-- spawnsets are parsed when they're set via rtm, on setup
-- but they're ALSO parsed EVERY ROUND

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
        if rawSpawnSetFields[name] then setParsed[name] = true continue end
        parse( spawnSet, name, setDefaults, spawnSet )
        setParsed[name] = true

    end
    for name, _ in pairs( setDefaults ) do -- setup the nil defaults that weren't set
        if setParsed[name] then continue end
        if rawSpawnSetFields[name] then continue end
        parse( spawnSet, name, setDefaults, spawnSet )

    end

    local slotSizes = spawnSet.slotSizes
    if slotSizes then
        for slot, size in pairs( slotSizes ) do
            local scale, mul = splitMul( size )
            if scale then
                slotSizes[slot] = { scale = scale, mul = mul }

            else
                parse( slotSizes, slot, slotSizeDefaults, spawnSet )

            end
        end
    end

    for _, currSpawn in ipairs( spawnSet.spawns ) do
        local spawnParsed = {}
        for name, _ in pairs( currSpawn ) do -- parse all existing spawnset variables
            if rawSpawnFieldValidators[name] then spawnParsed[name] = true continue end
            parse( currSpawn, name, spawnDefaults, spawnSet )
            spawnParsed[name] = true

        end
        for name, _ in pairs( spawnDefaults ) do -- get the nil defaults
            if spawnParsed[name] then continue end
            if rawSpawnFieldValidators[name] then continue end
            parse( currSpawn, name, spawnDefaults, spawnSet )

        end
    end

    -- let consumers ( eg the spawner ) attach their own runtime fields to the parsed set
    -- the spawnset module deliberately knows nothing about what those fields are
    hook.Run( "glee_spawnset_parsed", spawnSet )

    return spawnSet

end

-- set spawnset
-- the same misery again only rerolls its random fields, it's called that way every round
-- rebuildLifecycle runs its Activate fresh anyway, so gmod_admin_cleanup applies edits to the misery that's running
function GM:SetSpawnSet( setName, rebuildLifecycle )

    local oldSetName = self.CurrSpawnSetName
    local isNewSet = oldSetName ~= setName
    local newLifecycle = isNewSet or rebuildLifecycle

    local asRegistered = self.RegisteredSpawnSets[setName]
    if not asRegistered then ErrorNoHaltWithStack( "GLEE: Tried to enable invalid spawnset " .. setName ) return end

    local spawnSet = self:ParsedSpawnSet( asRegistered )

    self:HandleBossDetection( spawnSet )

    if newLifecycle and self.CurrSpawnSetLifecycle then
        self.CurrSpawnSetLifecycle:InternalTeardown()
        self.CurrSpawnSetLifecycle = nil

    end

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = spawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )

    if newLifecycle then
        self.CurrSpawnSetLifecycle = include( "hunters_glee/gamemode/modules/spawnset/core/sh_spawnsetlifecyclebase.lua" )
        self.CurrSpawnSetLifecycle:Apply( asRegistered )

        self:TellClientsSpawnsetActivated( setName )

    end

    if isNewSet then
        hook.Run( "glee_post_new_spawnset", setName, spawnSet, oldSetName )
        permaPrint( "GLEE: Misery set to, " .. setName )

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

function GM:GetSpawnSet( setName )
    if setName then error( "GAMEMODE:GetSpawnSet is for getting the current spawnset's name, and data\nUse GAMEMODE:GetRegisteredSpawnSet" ) end
    return self.CurrSpawnSetName, self.CurrSpawnSet

end

-- lifecycle object, changes when spawnset changes
-- for having spawnsets apply hooks
function GM:GetSpawnsetLifecycle()
    return self.CurrSpawnSetLifecycle

end

function GM:ScaledGenericSpawnerRate( var )
    local set = self.CurrSpawnSet
    if not set then return var end

    return var * set.genericSpawnerRate

end

local defaultSpawnSetName = GAMEMODE.TheTutorialMisery
local function postSetSpawnset( new ) -- validate the spawnset cvar
    if not GAMEMODE:IsValidSpawnSet( new ) then
        if GAMEMODE:IsValidSpawnSet( defaultSpawnSetName ) then
            RunConsoleCommand( "huntersglee_misery", defaultSpawnSetName )
            permaPrint( "Valid spawnsets are..." )
            for _, set in SortedPairsByMemberValue( GAMEMODE:GetSpawnSets(), "name" ) do
                permaPrint( set.name )

            end
        end
    else -- all good!
        GAMEMODE:SetSpawnSet( new )

    end
end


local spawnSetVar = CreateConVar( "huntersglee_misery", defaultSpawnSetName, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "What spawnset the gamemode should use." )
cvars.AddChangeCallback( "huntersglee_misery", function( _, _, new )
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
    -- first, the misery activated below can hand out roles
    self:RolesInitialThink()

    local count = self:GobbleSpawnsets()
    permaPrint( "GLEE: Gobbled " .. count .. " spawnsets..." )

    self.GobbledSpawnsets = true
    hook.Run( "glee_post_spawnsetgobble" )

    local spawnSetPicked = spawnSetVar:GetString()
    if not self:IsValidSpawnSet( spawnSetPicked ) then
        permaPrint( "GLEE: INVALID SPAWNSET " .. spawnSetPicked )
        spawnSetPicked = defaultSpawnSetName
        RunConsoleCommand( "huntersglee_misery", spawnSetPicked )

    end

    -- startup, or gmod_admin_cleanup, which just reloaded every spawnset
    self:SetSpawnSet( spawnSetPicked, true )

end

-- gobble all the custom spawnsets
hook.Add( "huntersglee_round_firstsetup", "glee_spawnset_think", function() GAMEMODE:SpawnSetInitialThink() end )

-- re-parse the spawnset when a new round is started
-- so each round gets a different roll of all the random fields in the spawnsets
hook.Add( "huntersglee_round_leave_limbo", "glee_spawnset_reparse", function() GAMEMODE:SetSpawnSet( spawnSetVar:GetString() ) end )


local veteranSpawnSetName = "hunters_glee"

-- let people joining the server have the default glee experience
hook.Add( "huntersglee_emptyserver", "glee_reset_spawnset", function()
    GAMEMODE.DeadServerPendingUpgrade = true

    permaPrint( "GLEE: empty server, setting to tutorial mode, will reset to " .. veteranSpawnSetName .. " if a veteran joins" )
    RunConsoleCommand( "huntersglee_misery", defaultSpawnSetName )

end )

hook.Add( "glee_ply_escaped", "learn_hardspawnset_lesson", function( ply )
    if GAMEMODE:IsSpawnsetEasy() then return end

    GAMEMODE:LearnLesson( ply, "WonAHardMisery" )

end )
hook.Add( "glee_full_load", "glee_resetspawnset_onjoin", function( ply )
    if not GAMEMODE.DeadServerPendingUpgrade then return end

    -- give their lessons time to sync
    -- keep this shorter than spawn protection's removal, or the round can start before the mode switches
    timer.Simple( 1, function()
        if not IsValid( ply ) then return end
        if not GAMEMODE.DeadServerPendingUpgrade then return end
        GAMEMODE.DeadServerPendingUpgrade = nil

        if not GAMEMODE:HasLearnedLesson( ply, "WonAHardMisery" ) then return end
        RunConsoleCommand( "huntersglee_misery", veteranSpawnSetName )

        permaPrint( "GLEE: Updating spawnset, veteran is joining dead server" )

    end )
end )
