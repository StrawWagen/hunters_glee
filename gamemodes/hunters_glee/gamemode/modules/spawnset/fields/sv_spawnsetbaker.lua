
-- imagine a terminator in a baker's uniform
-- bakes raw miseries, as their files wrote them, into complete ones, once, when they're gobbled.
-- start at bakeMisery, it's every step in order. GM:BakeSpawnSets at the bottom runs it on every misery
--
--   maxSpawnCount = "zambies_glee*1.5",   1.5x zambies_glee's maxSpawnCount
--   roundEndSound = "zambies_glee",       zambies_glee's roundEndSound
--   importedMiserySpawns = { { name = "zambies_glee" } },   zambies_glee's .spawns, after this misery's own
--   importedMiserySpawns = { { name = "zambies_glee", optional = true } },   same, but skipped when zambies_glee isn't installed
--
-- what comes out has every field filled in and no references, so validation, the map check and sv_spawnsetroller never see one

local schema = include( "hunters_glee/gamemode/modules/spawnset/fields/sv_spawnsetschema.lua" )
local yapErr = schema.yapErr
local defaultedFieldKinds = schema.defaultedFieldKinds
local defaultSetName = schema.defaultSetName
local rawOnlyFields = schema.rawOnlyFields
local slotSizeScales = schema.slotSizeScales
local spawnDefaults = schema.spawnDefaults

-- every misery's file, by name, for the gobble in progress
local rawByName
-- [name] = baked misery, or false if it failed
local bakedByName
-- the miseries being baked right now, each one waiting on the next
local chain


-- the steps

-- NULL in an override drops that entry or unsets that field, anywhere else it's a mistake
-- rawequal, so an entity value never runs the entity == NULL comparison
local function nullFieldOf( entry )
    for key, value in pairs( entry ) do
        if rawequal( value, NULL ) then return key end

    end
end

-- own .spawns first, then each import in order
-- prerequisites holds each import's misery, already baked, by the import's index
-- nil for an optional import that isn't installed
-- imported entries get .importedEntryOriginalSource, the misery that wrote them, rotatingWaves groups by it
local function mergedSpawns( rawSet, prerequisites )
    local ownSpawns = rawSet.spawns
    local imports = rawSet.importedMiserySpawns
    if ownSpawns == nil and imports == nil then
        if rawSet.template then return {} end
        yapErr( rawSet, "needs .spawns, .importedMiserySpawns, or both" )
        return

    end
    if ownSpawns ~= nil and not istable( ownSpawns ) then yapErr( rawSet, "has invalid .spawns" ) return end
    if imports ~= nil and not istable( imports ) then yapErr( rawSet, "has invalid .importedMiserySpawns, expected a list like { { name = \"default\" } }" ) return end

    local spawns = {}
    -- [entry name] = { via = the misery it came in through, origin = the misery that wrote it }
    local cameFrom = {}

    -- validate our .spawns
    for _, entry in ipairs( ownSpawns or {} ) do
        if not istable( entry ) then -- give it to IsValidSpawnSet to complain about
            table.insert( spawns, entry )
            continue

        end

        local nullField = nullFieldOf( entry )
        if nullField then
            yapErr( rawSet, ".spawns " .. tostring( entry.name ) .. " has ." .. tostring( nullField ) .. " = NULL, NULL only unsets fields in .importedMiserySpawns overrides" )
            return

        end

        if isstring( entry.name ) then
            if cameFrom[entry.name] then yapErr( rawSet, "has more than one .spawns entry named " .. entry.name ) return end
            cameFrom[entry.name] = { via = rawSet.name, origin = rawSet.name }

        end
        -- a copy, the defaults filled in later are the baked misery's, not the file's
        table.insert( spawns, table.Copy( entry ) )

    end

    -- then import others into our .spawns
    for ind, import in ipairs( imports or {} ) do
        local importName = import.name
        local overrides = import.overrides or {}
        if not istable( overrides ) then yapErr( rawSet, ".importedMiserySpawns " .. importName .. " has invalid .overrides" ) return end

        local imported = prerequisites[ind]
        if not imported then continue end

        local importedNames = {}
        for _, entry in ipairs( imported.spawns ) do
            local entryName = istable( entry ) and entry.name
            if not isstring( entryName ) then
                table.insert( spawns, table.Copy( entry ) ) -- give it to IsValidSpawnSet to complain about
                continue

            end
            importedNames[entryName] = true

            local override = overrides[entryName]
            if rawequal( override, NULL ) then continue end
            if override ~= nil and not istable( override ) then
                yapErr( rawSet, ".importedMiserySpawns " .. importName .. " overrides " .. entryName .. " with something that isn't NULL or a table" )
                return

            end

            if override and rawequal( override.name, NULL ) then
                yapErr( rawSet, ".importedMiserySpawns " .. importName .. " overrides " .. entryName .. " with .name = NULL, every entry needs a name, set the whole entry to NULL to drop it" )
                return

            end

            local copy = table.Copy( entry )
            for key, value in pairs( override or {} ) do
                if rawequal( value, NULL ) then
                    copy[key] = nil

                else
                    copy[key] = value

                end
            end

            -- after the override, so an override can't move it
            local origin = entry.importedEntryOriginalSource or importName
            copy.importedEntryOriginalSource = origin

            local seen = cameFrom[copy.name]
            if seen and seen.via ~= importName then
                -- the same entry arriving twice, eg importing B and C when B already imports C
                -- extremely rare, this only tells it apart from two miseries sharing a name, so the error blames the right one
                if seen.origin == origin then
                    yapErr( rawSet, "imports .spawns entry " .. copy.name .. " from " .. importName .. ", but it already arrived through " .. seen.via .. ", which imports " .. origin .. " too" )

                else
                    yapErr( rawSet, "imports .spawns entry " .. copy.name .. " from " .. importName .. ", but " .. seen.via .. " already has its own entry with that name" )

                end
                return

            end
            cameFrom[copy.name] = { via = importName, origin = origin }

            table.insert( spawns, copy )

        end

        for overrideName, _ in pairs( overrides ) do
            if importedNames[overrideName] then continue end
            yapErr( rawSet, ".importedMiserySpawns " .. importName .. " overrides " .. tostring( overrideName ) .. ", but " .. importName .. " has no .spawns entry with that name" )
            return

        end
    end

    return spawns

end

-- "minutes*0.1" becomes { scale = "minutes", mul = 0.1 }, everything else passes through
-- false when it failed, nil when there's no .slotSizes
local function resolveSlotSizes( rawSet )
    local slotSizes = rawSet.slotSizes
    if not istable( slotSizes ) then return slotSizes end -- IsValidSpawnSet complains about anything but nil

    local resolvedSizes = {}
    for slot, size in pairs( slotSizes ) do
        if isstring( size ) then
            local scale, mulStr = string.match( size, "^(%a+)%*([%d%.]+)$" )
            local mul = tonumber( mulStr )
            if not ( mul and slotSizeScales[scale] ) then
                yapErr( rawSet, "has .slotSizes " .. tostring( slot ) .. " = \"" .. size .. "\", expected eg \"minutes*0.1\" or \"difficulty*0.01\"" )
                return false

            end
            size = { scale = scale, mul = mul }

        end
        resolvedSizes[slot] = size

    end
    return resolvedSizes

end


-- baking
-- a misery that borrows from another bakes that one first, as a prerequisite, so this recurses:
--   bakeMisery -> bakePrerequisite -> bakeOnce -> bakeMisery

-- filled in below bakeMisery, it calls bakeMisery
local bakeOnce

-- the misery setName names, baked, for a misery that borrows from it
-- askingPart is the field that named it, eg ".maxSpawnCount", for the error messages
-- nil when it failed, it's already yapped about why
-- with .needsEveryMisery, a misery that isn't installed drops rawSet quietly instead
local function bakePrerequisite( rawSet, askingPart, setName )
    local referenced = rawByName[setName]
    if not referenced and rawSet.needsEveryMisery then
        print( "GLEE: spawnSet " .. rawSet.name .. " isn't loading, it needs " .. setName .. ", which isn't installed" )
        return

    end
    if not referenced then yapErr( rawSet, askingPart .. " points at " .. setName .. ", but there's no misery with that name" ) return end

    local baked = bakeOnce( referenced )
    if not baked then yapErr( rawSet, "can't load, " .. askingPart .. " points at " .. setName .. ", which didn't load" ) return end

    return baked

end

-- "zambies_glee*1.5" gives "zambies_glee", 1.5
-- "zambies_glee" gives "zambies_glee", 1
-- nil for anything else, eg "zambies_glee*1.2.3"
local function splitReference( str )
    local setName, mulStr = string.match( str, "^([^%*/]+)%*([%d%.]+)$" )
    if setName then
        local mul = tonumber( mulStr )
        if not mul then return end
        return setName, mul

    end

    if string.match( str, "^[^%*/]+$" ) then return str, 1 end

end

-- whether a field's value borrows from another misery, by kind, see defaultedFieldKinds
-- returns ok, then the misery's name and the multiplier when it borrows, nothing more when it's a plain value
-- ok is false when the value's broken, it's already yapped about why
local function readReference( rawSet, field, kind, value )
    if not isstring( value ) then return true end -- IsValidSpawnSet checks everything that isn't a reference

    -- "" is silence, and a "/" means it's probably the path of a sound outside the root sounds folder
    local validNonRootSound = value == "" or string.find( value, "/", 1, true )
    if kind == "sound" and validNonRootSound then return true end

    -- only numbers can be multiplied
    if kind ~= "number" and string.find( value, "*", 1, true ) then
        yapErr( rawSet, "has ." .. field .. " = \"" .. value .. "\", only number fields can be multiplied" )
        return false

    end

    local setName, mul = splitReference( value )
    if not setName then
        local example = "eg \"default\""
        if kind == "number" then
            example = "eg \"default\" or \"default*0.5\""

        end
        yapErr( rawSet, "has ." .. field .. " = \"" .. value .. "\", a string here is always a misery's name, " .. example )
        return false

    end

    -- likely a sound path placed into the root folder, so say why it was read as a misery's name
    if kind == "sound" and not rawByName[setName] then
        yapErr( rawSet, "has ." .. field .. " = \"" .. value .. "\"\n" ..
            "In sound fields, a value without a \"/\" is ALWAYS the name of a misery to copy the sound from, and there's no misery named \"" .. value .. "\"\n" ..
            "Sounds MUST be in a subfolder, so a sound's path ALWAYS has a \"/\" in it, eg \"mymusic/" .. value .. "\""
        )
        return false

    end

    return true, setName, mul

end

-- scale numbers
-- if { min, max }, scales both ends
-- if function, wrap with a func that returns the num, scaled
local function scaled( value, mul )
    if mul == 1 then return value end
    if isnumber( value ) then return value * mul end

    if isfunction( value ) then
        return function( spawnSet )
            return scaled( value( spawnSet ), mul )

        end
    end

    if istable( value ) then
        local scaledRange = {}
        for ind, num in ipairs( value ) do
            if not isnumber( num ) then return value end -- IsValidSpawnSet complains about it
            scaledRange[ind] = num * mul

        end
        return scaledRange

    end

    return value

end

-- the baked misery, or nil when it failed
local function bakeMisery( rawSet )
    -- everything the file wrote
    local baked = {}
    for key, value in pairs( rawSet ) do
        if rawOnlyFields[key] then continue end
        baked[key] = value

    end

    -- fields that cannot be nil, will always fall back to default's values
    for field, kind in pairs( defaultedFieldKinds ) do
        local value = rawSet[field]

        -- nil borrows from the default misery
        if value == nil then
            if rawSet.name == defaultSetName then yapErr( rawSet, "is missing ." .. field .. ", every misery's nil ." .. field .. " comes from here" ) return end
            value = defaultSetName

        end

        local ok, setName, mul = readReference( rawSet, field, kind, value )
        if not ok then return end

        -- borrowed, so bake the misery it borrows from, and take its value
        if setName then
            local prerequisite = bakePrerequisite( rawSet, "." .. field, setName )
            if not prerequisite then return end

            value = prerequisite[field]
            if kind == "number" then
                value = scaled( value, mul )

            end
        end

        baked[field] = value

    end

    -- every misery it imports from, baked, so their finished .spawns come with their own imports already in
    local prerequisites = {}
    local imports = rawSet.importedMiserySpawns
    if istable( imports ) then -- mergedSpawns complains about anything but nil
        for ind, import in ipairs( imports ) do
            if not istable( import ) or not isstring( import.name ) then yapErr( rawSet, ".importedMiserySpawns entry " .. ind .. " needs a .name" ) return end
            -- only skipped when it isn't installed, one that's there but broken still errors
            if import.optional and not rawByName[import.name] then continue end

            local prerequisite = bakePrerequisite( rawSet, ".importedMiserySpawns", import.name )
            if not prerequisite then return end
            prerequisites[ind] = prerequisite

        end
    end

    -- own .spawns, then imported ones
    local spawns = mergedSpawns( rawSet, prerequisites )
    if not spawns then return end
    baked.spawns = spawns

    -- every .spawns entry's nil defaults
    for _, entry in ipairs( spawns ) do
        if not istable( entry ) then continue end -- IsValidSpawnSet complains about it
        for field, default in pairs( spawnDefaults ) do
            if entry[field] == nil then
                entry[field] = default

            end
        end
    end

    -- slot sizes that grow with the round
    local slotSizes = resolveSlotSizes( rawSet )
    if slotSizes == false then return end
    baked.slotSizes = slotSizes

    return baked

end

-- bakeMisery, but each misery only once, and a loop of miseries pointing at each other is caught
bakeOnce = function( rawSet )
    local name = rawSet.name
    local done = bakedByName[name]
    if done ~= nil then return done or nil end

    for ind, chainName in ipairs( chain ) do
        if chainName ~= name then continue end

        local loop = {}
        for loopInd = ind, #chain do
            table.insert( loop, chain[loopInd] )

        end
        table.insert( loop, name )
        yapErr( rawSet, "points at itself, " .. table.concat( loop, " -> " ) )
        return

    end

    table.insert( chain, name )
    local baked = bakeMisery( rawSet )
    table.remove( chain )

    bakedByName[name] = baked or false
    return baked

end


--[[---------------------------------------------------------
    GM:BakeSpawnSets
    @desc Bakes the values of every gobbled misery, converting their raw values into properly inherited values.
    @param rawSets: Everything GLEE_SPAWNSETS gathered in.
    @return: The miseries to register, and the templates, both by name. Templates only exist to be pointed at, they're never registered.
--]]---------------------------------------------------------
function GM:BakeSpawnSets( rawSets )
    rawByName = {}
    bakedByName = {}
    chain = {}

    for _, rawSet in pairs( rawSets ) do
        if not istable( rawSet ) then ErrorNoHaltWithStack( "GLEE: Spawnset is not a table" ) continue end
        if not isstring( rawSet.name ) then ErrorNoHaltWithStack( "GLEE: Spawnset has invalid .name" ) continue end
        if rawByName[rawSet.name] then permaPrint( "GLEE, overriding old " .. rawSet.name .. " spawnSet" ) end

        rawByName[rawSet.name] = rawSet

    end

    local toRegister = {}
    local templates = {}
    for name, rawSet in SortedPairs( rawByName ) do
        local baked = bakeOnce( rawSet )
        if not baked then continue end

        if rawSet.template then
            templates[name] = baked

        else
            toRegister[name] = baked

        end
    end

    rawByName = nil
    bakedByName = nil
    chain = nil

    return toRegister, templates

end
