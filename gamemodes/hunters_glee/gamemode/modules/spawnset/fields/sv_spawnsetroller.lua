
-- GOLD GOLD GOLD
-- every round, the registered misery's number fields are rolled into this round's numbers
-- so each round plays a little different
--  .maxSpawnDist = 5000, always 5000
--  .maxSpawnDist = { 4000, 6000 }, a random value between 4k and 6k, different each round
-- everything else was filled in once, at gobble, see sv_spawnsetbaker

local schema = include( "hunters_glee/gamemode/modules/spawnset/fields/sv_spawnsetschema.lua" )
local yapErr = schema.yapErr
local rolledNumber = schema.rolledNumber
local defaultedFieldKinds = schema.defaultedFieldKinds
local spawnNumberFields = schema.spawnNumberFields

-- swaps tbl[field] for this round's number, nil is left nil
-- a function( spawnSet ) is called, and what it returns is rolled
--[[eg,
    .maxCount = function( spawnSet )
        return spawnSet.maxSpawnCount
    end,
--]]
local function roll( tbl, field, spawnSet )
    local value = tbl[field]
    if value == nil then return end

    if isfunction( value ) then
        local noErrors, returned = xpcall( value, ErrorNoHaltWithStack, spawnSet )
        if noErrors == false then
            yapErr( spawnSet, "." .. field .. " function errored! " )
            tbl[field] = nil
            return

        end
        value = returned

    end

    local rolled = rolledNumber( value )
    if rolled == nil then
        yapErr( spawnSet, "invalid ." .. field .. ", or an invalid return from its function" )
        tbl[field] = nil
        return

    end

    tbl[field] = rolled

end

--[[---------------------------------------------------------
    GM:RolledSpawnSet
    @desc Rolls a registered misery's number fields into this round's numbers.
    Runs on every GM:SetSpawnSet, so a new round, or picking a misery, rolls fresh.
    @param asRegistered: The registered misery, left untouched.
    @return: A rolled copy.
--]]---------------------------------------------------------
function GM:RolledSpawnSet( asRegistered )
    local spawnSet = table.Copy( asRegistered )

    for field, kind in pairs( defaultedFieldKinds ) do
        if kind ~= "number" then continue end
        roll( spawnSet, field, spawnSet )

    end

    local slotSizes = spawnSet.slotSizes
    if slotSizes then
        for slot, size in pairs( slotSizes ) do
            if istable( size ) and size.scale then continue end -- slotSize in sv_hunterspawner scales these each wave
            roll( slotSizes, slot, spawnSet )

        end
    end

    for _, spawn in ipairs( spawnSet.spawns ) do
        for field, _ in pairs( spawnNumberFields ) do
            roll( spawn, field, spawnSet )

        end
    end

    -- let consumers ( eg the spawner ) attach their own runtime fields to the rolled set
    -- the spawnset module deliberately knows nothing about what those fields are
    hook.Run( "glee_spawnset_rolled", spawnSet )

    return spawnSet

end
