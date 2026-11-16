
local isstring = isstring
local GAMEMODE = GAMEMODE or GM

-- what every field holds, and its validators
local schema = include( "hunters_glee/gamemode/modules/spawnset/fields/sv_spawnsetschema.lua" )
local yapErr = schema.yapErr
local isRollable = schema.isRollable
local isWeaponList = schema.isWeaponList
local defaultedFieldKinds = schema.defaultedFieldKinds
local validSpawnTypes = schema.validSpawnTypes
local unrolledSpawnFieldValidators = schema.unrolledSpawnFieldValidators
local setCommonTypos = schema.setCommonTypos
local spawnCommonTypos = schema.spawnCommonTypos

local developerVar = GetConVar( "developer" )

local function findTypo( tbl, commonTypos )
    for typo, correct in pairs( commonTypos ) do
        if tbl[typo] ~= nil then return typo, correct end

    end
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

    -- validate more complex variables
    for name, kind in pairs( defaultedFieldKinds ) do
        local value = spawnSet[name]
        local valid
        if kind == "sound" then
            valid = isstring( value )

        elseif kind == "weapons" then
            valid = isWeaponList( value )

        else
            valid = isRollable( value )

        end

        if not valid then
            yapErr( spawnSet, "has invalid ." .. name )
            return

        end
    end

    local slotSizes = spawnSet.slotSizes
    if slotSizes ~= nil then
        if not istable( slotSizes ) then yapErr( spawnSet, "has invalid .slotSizes" ) return end
        for slot, size in pairs( slotSizes ) do
            local isScaled = istable( size ) and size.scale ~= nil
            if not isScaled and not isRollable( size ) then
                yapErr( spawnSet, "has invalid .slotSizes " .. slot )
                return

            end
        end
    end

    local spawns = spawnSet.spawns
    if not istable( spawns ) then yapErr( spawnSet, "has invalid .spawns" ) return end
    for ind, spawn in ipairs( spawns ) do
        local name = spawn.name
        if not isstring( name ) then
            permaPrintTable( spawn ) -- give them a hint to find this invalid spawn entry, otherwise just giving them a shot in the dark
            permaPrint( spawn.name )
            yapErr( spawnSet, "entry " .. ind .. " has invalid .name in .spawns" )
            return

        end

        local spawnTypo, spawnCorrect = findTypo( spawn, spawnCommonTypos )
        if spawnTypo then yapErr( spawnSet, ".spawns " .. name .. " has ." .. spawnTypo .. ", did you mean ." .. spawnCorrect .. "?" ) return end

        if not isstring( spawn.prettyName ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .prettyname" ) return end
        if not isstring( spawn.class ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .class" ) return end
        if not validSpawnTypes[spawn.spawnType] then yapErr( spawnSet, ".spawns " .. name .. " invalid .spawnType" ) return end

        for fieldName, validator in pairs( unrolledSpawnFieldValidators ) do
            local whatSpawnHas = spawn[fieldName]
            if not whatSpawnHas then continue end
            local valid, notValidReason = validator( whatSpawnHas )
            if not valid then yapErr( spawnSet, ".spawns " .. name .. " " .. fieldName .. " " .. notValidReason ) return end

        end

        if not isRollable( spawn.minCount ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .minCount" ) return end
        if not isRollable( spawn.maxCount ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .maxCount" ) return end

        -- nil falls back to .class
        local countClass = spawn.countClass
        if not isstring( countClass ) and countClass ~= nil then
            yapErr( spawnSet, ".spawns " .. name .. " invalid .countClass" )
            return

        end
        -- only .minCount and .maxCount read it
        local hasMinMax = spawn.maxCount ~= -1 or spawn.minCount ~= -1 -- -1 is the baker's default, see spawnDefaults
        if countClass and not hasMinMax and developerVar:GetBool() then
            permaPrint( "GLEE: spawnSet " .. spawnSet.name .. " .spawns entry " .. name .. " has a .countClass but no .minCount or .maxCount" )

        end
        if countClass == spawn.class and developerVar:GetBool() then
            permaPrint( "GLEE: spawnSet " .. spawnSet.name .. " .spawns entry " .. name .. " has a .countClass that's the same as its .class, it can be left out" )

        end

        if not isRollable( spawn.difficultyCost ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .difficultyCost" ) return end

        if spawn.cooldown ~= nil and not isRollable( spawn.cooldown ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .cooldown" ) return end

        -- without .slotSizes, every slot holds 1
        if slotSizes and spawn.slots then
            for _, slot in ipairs( spawn.slots ) do
                if slotSizes[slot] == nil then yapErr( spawnSet, ".spawns " .. name .. " has slot " .. slot .. " that isn't in .slotSizes" ) return end

            end
        end

    end

    return true

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

    local rolledSpawnSet = self:RolledSpawnSet( asRegistered )

    self:HandleBossDetection( rolledSpawnSet )

    if newLifecycle and self.CurrSpawnSetLifecycle then
        self.CurrSpawnSetLifecycle:InternalTeardown()
        self.CurrSpawnSetLifecycle = nil

    end

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = rolledSpawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )

    if newLifecycle then
        self.CurrSpawnSetLifecycle = include( "hunters_glee/gamemode/modules/spawnset/core/sh_spawnsetlifecyclebase.lua" )
        self.CurrSpawnSetLifecycle:Apply( asRegistered )

        self:TellClientsSpawnsetActivated( setName )

    end

    if isNewSet then
        hook.Run( "glee_post_new_spawnset", setName, rolledSpawnSet, oldSetName )
        permaPrint( "GLEE: Misery set to, " .. setName )

    else
        hook.Run( "glee_post_refresh_spawnset", setName, rolledSpawnSet, oldSetName )

    end

    hook.Run( "glee_post_set_spawnset", setName, rolledSpawnSet, oldSetName )

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
    if not GAMEMODE.SpawnSetsLoaded then -- wait until spawnsets are valid
        hook.Add( "glee_post_spawnsetload", "glee_validatecvar_delayed", function()
            postSetSpawnset( new )
            hook.Remove( "glee_post_spawnsetload", "glee_validatecvar_delayed" )

        end )
    else
        postSetSpawnset( new )

    end

end, "glee_notifyinvalidspawnsets" )


-- re-roll the spawnset when a new round is started
-- so each round gets a different roll of all the random fields in the spawnsets
hook.Add( "huntersglee_round_leave_limbo", "glee_spawnset_reroll", function() GAMEMODE:SetSpawnSet( spawnSetVar:GetString() ) end )


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


function GM:SpawnSetInitialThink()

    -- all raw unbaked spawnsets
    local gobbled = self:GobbleSpawnSets()
    permaPrint( "GLEE: Gobbled " .. #gobbled .. " spawnsets..." )

    -- do spawnset inheritance, etc
    local toRegister, templates = self:BakeSpawnSets( gobbled )

    -- finally, register them, put them in a spot, ready to be applied, played
    local count = self:RegisterSpawnSets( toRegister, templates )
    permaPrint( "GLEE: Registered " .. count .. " spawnsets..." )

    self.SpawnSetsLoaded = true
    hook.Run( "glee_post_spawnsetload" )

    local spawnSetPicked = spawnSetVar:GetString()
    if not self:IsValidSpawnSet( spawnSetPicked ) then
        permaPrint( "GLEE: INVALID SPAWNSET " .. spawnSetPicked )
        spawnSetPicked = defaultSpawnSetName
        RunConsoleCommand( "huntersglee_misery", spawnSetPicked )

    end

    -- startup, or gmod_admin_cleanup, which just reloaded every spawnset
    self:SetSpawnSet( spawnSetPicked, true )

end
