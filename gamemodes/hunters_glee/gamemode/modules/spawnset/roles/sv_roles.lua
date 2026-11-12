local GM = GM or GAMEMODE

local setHelpers = GM.setHelpers

-- error level 3 blames whoever called the setHelper, not the helper
local function registeredRole( name )
    local role = GAMEMODE.gleeRoles[name]
    if not role then
        error( "GLEE: No role named '" .. tostring( name ) .. "', see lua/glee_spawnsetroles/", 3 )

    end
    return role

end

-- the same face every spawn, so the squad can tell each other apart
local function stablePick( ply, models )
    if isstring( models ) then return models end
    if not models or #models <= 0 then return end

    local index = tonumber( util.CRC( ply:SteamID64() ) ) % #models + 1
    return models[index]

end

-- every "what's their base?" goes through here
-- so team bases only have to change this, and variants keep working
local function baseRoleOf( roles, _ply )
    return roles.base

end

-- { name, role }, or nil for a plain base
local function variantOf( roles, ply )
    return roles.variantsById[ply:SteamID64()]

end

local function modelOf( roles, ply )
    local variant = variantOf( roles, ply )
    if variant and variant.role.models then
        return stablePick( ply, variant.role.models )

    end
    return stablePick( ply, baseRoleOf( roles, ply ).role.models )

end

local function giveWeapons( ply, weapons )
    for _, weapon in ipairs( weapons or {} ) do
        setHelpers.giveWeapon( ply, weapon )

    end
end

-- the base's and the variant's, as a set of names
local function statusEffectsOf( roles, ply )
    local effects = {}
    for _, name in ipairs( baseRoleOf( roles, ply ).role.statusEffects or {} ) do
        effects[name] = true

    end

    local variant = variantOf( roles, ply )
    if variant then
        for _, name in ipairs( variant.role.statusEffects or {} ) do
            effects[name] = true

        end
    end
    return effects

end

-- safe to call again, GiveStatusEffect skips effects they already have
local function giveStatusEffects( roles, ply )
    for name in pairs( statusEffectsOf( roles, ply ) ) do
        ply:GiveStatusEffect( name )

    end
end

-- the dead get their start weapons on their next spawn
-- taking a variant away doesn't touch the last one's weapons, they just stop coming back on respawn
-- its status effects do go, effects outlive death so the dead lose them too
local function setVariant( roles, ply, variant )
    local current = variantOf( roles, ply )
    local currentName = current and current.name
    local newName = variant and variant.name
    if currentName == newName then return end

    local oldEffects = statusEffectsOf( roles, ply )

    local id = ply:SteamID64()
    roles.variantsById[id] = variant
    roles.owedStartWeapons[id] = nil

    local newEffects = statusEffectsOf( roles, ply )
    for name in pairs( oldEffects ) do
        if newEffects[name] then continue end
        ply:RemoveStatusEffect( name )

    end

    if not ply:Alive() then
        if variant then
            roles.owedStartWeapons[id] = true

        end
        return

    end

    if variant then
        giveWeapons( ply, variant.role.startWeapons )
        giveWeapons( ply, variant.role.defaultWeapons )

    end
    giveStatusEffects( roles, ply )
    setHelpers.redressPlayer( ply )

end

local function sortForPicking( players, pick )
    local guilts = {}
    local tieBreaks = {}
    for _, ply in ipairs( players ) do
        local guilt = 0
        if pick.leastGuiltyFirst then
            guilt = GAMEMODE:GetPersistentGuilt( ply )

        elseif pick.mostGuiltyFirst then
            guilt = -GAMEMODE:GetPersistentGuilt( ply )

        end
        guilts[ply] = guilt
        tieBreaks[ply] = math.random()

    end

    table.sort( players, function( a, b )
        if guilts[a] ~= guilts[b] then
            return guilts[a] < guilts[b]

        end
        return tieBreaks[a] < tieBreaks[b]

    end )
end

-- fills the variant's open slots from candidates, skipping anyone off its base or already a variant
-- slots count who's connected, so someone leaving frees theirs
local function fillVariant( roles, variant, candidates )
    local pick = variant.pick
    local baseName = variant.role.base

    local onBase = 0
    local given = 0
    for _, ply in player.Iterator() do
        if baseRoleOf( roles, ply ).name ~= baseName then continue end
        onBase = onBase + 1

        local current = variantOf( roles, ply )
        if current and current.name == variant.name then
            given = given + 1

        end
    end
    if onBase < ( pick.minPlayers or 0 ) then return end

    local slots = pick.count or math.ceil( onBase * pick.ratio )
    local open = slots - given
    if open <= 0 then return end

    local eligible = {}
    for _, ply in ipairs( candidates ) do
        if baseRoleOf( roles, ply ).name ~= baseName then continue end
        if variantOf( roles, ply ) then continue end
        table.insert( eligible, ply )

    end
    sortForPicking( eligible, pick )

    for index = 1, math.min( open, #eligible ) do
        setVariant( roles, eligible[index], variant )

    end
end

-- in the order the misery added them, so earlier variants get first pick of the players
local function fillVariants( roles, candidates )
    for _, variant in ipairs( roles.autoVariants ) do
        fillVariant( roles, variant, candidates )

    end
end

-- everyone here now is in this round's picks
-- after this, only late joiners fill open slots, so a revived rebel doesn't become the medic someone left behind
local function startRoundPicks( roles )
    roles.seenThisRound = {}
    for _, ply in player.Iterator() do
        roles.seenThisRound[ply:SteamID64()] = true

    end
end

local pickFields = { "ratio", "count", "minPlayers", "leastGuiltyFirst", "mostGuiltyFirst" }

local function pickFieldsOf( role )
    local pick = {}
    for _, field in ipairs( pickFields ) do
        pick[field] = role[field]

    end
    return pick

end

--[[---------------------------------------------------------
    setHelpers.setBaseRole
    @desc Hands every player a role from lua/glee_spawnsetroles/, see the fields there.

    setHelpers.setBaseRole( self, "rebel" )
    setHelpers.addRoleVariant( self, "medic" )

    Call from a spawnset's Activate, serverside, once.
    It owns the misery's player models, don't also call overridePlayerModel.
--]]---------------------------------------------------------
function setHelpers.setBaseRole( lifecycle, name )
    if lifecycle.glee_Roles then
        error( "GLEE: This misery already has a base role, '" .. lifecycle.glee_Roles.base.name .. "'", 2 )

    end

    local role = registeredRole( name )
    if role.base then
        error( "GLEE: '" .. name .. "' is a variant of '" .. role.base .. "', use addRoleVariant or setPlayerRoleVariant", 2 )

    end

    local roles = {
        base = { name = name, role = role },
        -- what addRoleVariant hands out by itself, in the order it was called
        autoVariants = {},
        -- by SteamID64, so rejoining keeps it
        variantsById = {},
        owedStartWeapons = {},
        -- picks made since the last round ended are for the next round, eg a misery voted in during limbo
        rerollDue = false,
    }
    lifecycle.glee_Roles = roles
    startRoundPicks( roles )

    local function isOnBase( ply )
        return baseRoleOf( roles, ply ).name == name

    end
    for _, weapon in ipairs( role.startWeapons or {} ) do
        setHelpers.addStartWeapon( lifecycle, weapon, isOnBase )

    end
    for _, weapon in ipairs( role.defaultWeapons or {} ) do
        setHelpers.addDefaultWeapon( lifecycle, weapon, isOnBase )

    end

    setHelpers.overridePlayerModel( lifecycle, function( ply )
        return modelOf( roles, ply )

    end )

    for _, ply in player.Iterator() do
        if not ply:Alive() then continue end
        giveStatusEffects( roles, ply )

    end

    lifecycle:AddTeardown( function()
        for _, ply in player.Iterator() do
            for effectName in pairs( statusEffectsOf( roles, ply ) ) do
                ply:RemoveStatusEffect( effectName )

            end
        end
    end )

    lifecycle:Hook( "glee_true_PlayerSpawn", "glee_roles", function( ply )
        local id = ply:SteamID64()
        if not roles.seenThisRound[id] then
            roles.seenThisRound[id] = true
            fillVariants( roles, { ply } )

        end

        giveStatusEffects( roles, ply )

        local variant = variantOf( roles, ply )
        if not variant then return end

        if roles.owedStartWeapons[id] then
            roles.owedStartWeapons[id] = nil
            giveWeapons( ply, variant.role.startWeapons )

        end
        giveWeapons( ply, variant.role.defaultWeapons )

    end )

    lifecycle:Hook( "huntersglee_round_into_limbo", "glee_roles", function()
        roles.rerollDue = true

    end )

    -- setup, before the next round
    -- the map cleanup just before this wiped everyone's status effects, and bodied souls don't respawn to get them back
    lifecycle:Hook( "huntersglee_round_into_inactive", "glee_roles", function()
        if roles.rerollDue then
            roles.rerollDue = false
            startRoundPicks( roles )

            for _, ply in player.Iterator() do
                setVariant( roles, ply, nil )

            end
            fillVariants( roles, player.GetAll() )

        end

        for _, ply in player.Iterator() do
            if not ply:Alive() then continue end
            giveStatusEffects( roles, ply )

        end
    end )
end

--[[---------------------------------------------------------
    setHelpers.addRoleVariant
    @desc Hands a variant out by itself, by the ratio or count in its role file.

    setHelpers.addRoleVariant( self, "medic" )
    setHelpers.addRoleVariant( self, "medic", { ratio = 0.5, leastGuiltyFirst = true } )

    The table replaces all of the role file's picking fields, see them in lua/glee_spawnsetroles/.
    Picked again every round. Variants added first pick first, a player only gets one.
    Late joiners fill whatever's still open.

    Call from a spawnset's Activate, serverside, after setBaseRole.
--]]---------------------------------------------------------
function setHelpers.addRoleVariant( lifecycle, name, pick )
    local roles = lifecycle.glee_Roles
    if not roles then
        error( "GLEE: Call setBaseRole before addRoleVariant", 2 )

    end

    local role = registeredRole( name )
    if not role.base then
        error( "GLEE: '" .. name .. "' has no base, so it isn't a variant, use setBaseRole", 2 )

    end

    pick = pick or pickFieldsOf( role )
    if pick.ratio and pick.count then
        error( "GLEE: Variant '" .. name .. "' has both a ratio and a count, pick one", 2 )

    end
    if not pick.ratio and not pick.count then
        error( "GLEE: Variant '" .. name .. "' has no ratio or count, hand it out with setPlayerRoleVariant instead", 2 )

    end
    if pick.leastGuiltyFirst and pick.mostGuiltyFirst then
        error( "GLEE: Variant '" .. name .. "' is both leastGuiltyFirst and mostGuiltyFirst, pick one", 2 )

    end

    local variant = { name = name, role = role, pick = pick }
    table.insert( roles.autoVariants, variant )

    fillVariant( roles, variant, player.GetAll() )

end

--[[---------------------------------------------------------
    setHelpers.setPlayerRoleVariant
    @desc Gives one player a variant of their base role, any time.

    setHelpers.setPlayerRoleVariant( self, ply, "medic" )

    The alive get its weapons on the spot, the dead on their next spawn.
    They keep it until the round ends. nil takes it away, they keep any weapons it gave, but lose its status effects.

    Serverside, after setBaseRole.
--]]---------------------------------------------------------
function setHelpers.setPlayerRoleVariant( lifecycle, ply, name )
    local roles = lifecycle.glee_Roles
    if not roles then
        error( "GLEE: Call setBaseRole before setPlayerRoleVariant", 2 )

    end

    if name == nil then
        setVariant( roles, ply, nil )
        return

    end

    local role = registeredRole( name )
    local baseName = baseRoleOf( roles, ply ).name
    if role.base ~= baseName then
        error( "GLEE: '" .. name .. "' isn't a variant of their base role, '" .. baseName .. "'", 2 )

    end

    setVariant( roles, ply, { name = name, role = role } )

end
