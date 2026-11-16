local GAMEMODE = GAMEMODE or GM

--[[
    The weapons players spawn with.

    startWeapons = { { class = "weapon_smg1", purchaseClips = 3 } }, -- once a round
    defaultWeapons = { "weapon_crowbar" },                           -- every life

    Each misery's .startWeapons and .defaultWeapons come in when it activates, see the default misery for everyone's kit.
    GM:AddMiserySpawnWeapon adds more, eg a role's.
    Everything leaves with the lifecycle that added it.
--]]

-- [kind] = entries, in the order they were added
-- on GAMEMODE so autorefresh keeps them, the running misery only hands its weapons out when it activates
GAMEMODE.glee_SpawnWeaponLists = GAMEMODE.glee_SpawnWeaponLists or {
    start = {},
    default = {},
}
local lists = GAMEMODE.glee_SpawnWeaponLists


-- one weapon

-- a function's pick is kept per player for the round, by SteamID64, so a top-up or a rejoin hands back the same thing
local function weaponFor( ply, entry )
    local weapon = entry.weapon
    if not isfunction( weapon ) then return weapon end

    local id = ply:SteamID64()
    local picked = entry.picks[id]
    if picked == nil then
        picked = weapon( ply )
        entry.picks[id] = picked

    end
    return picked

end

local function classOf( weapon )
    if istable( weapon ) then return weapon.class end
    return weapon

end

-- carried on the back, like the sentry turret, see glee_Carrying
local function isCarryable( class )
    return weapons.IsBasedOn( class, "glee_backpackable_base" )

end

-- what they hold of the weapon, given now or already had
-- nil when entry.shouldGiveFunc turns them down, or there's no room to carry it
local function giveWeapon( ply, entry )
    if entry.shouldGiveFunc and not entry.shouldGiveFunc( ply ) then return end

    local weapon = weaponFor( ply, entry )
    local class = classOf( weapon )
    local held = ply:GetWeapon( class )
    if IsValid( held ) then return held end

    if isCarryable( class ) then
        if not terminator_Extras.glee_Carrying.GiveNewCarryable( ply, class ) then return end
        return ply:GetWeapon( class )

    end

    if istable( weapon ) then
        local resolved = {}
        for key, value in pairs( weapon ) do
            if isfunction( value ) then
                value = value( ply )

            end
            resolved[key] = value

        end
        GAMEMODE.shopHelpers.purchaseWeapon( ply, resolved )
        return ply:GetWeapon( class )

    end
    return ply:Give( weapon )

end

local function makeWeaponEntry( weapon, shouldGiveFunc )
    return {
        weapon = weapon,
        shouldGiveFunc = shouldGiveFunc,
        picks = {},
        -- by SteamID64, so rejoining doesn't earn another, start weapons only
        given = {},
    }
end


-- adding

--[[---------------------------------------------------------
    GM:AddMiserySpawnWeapon
    @desc Hands weapon out until lifecycle ends, on top of the misery's .startWeapons and .defaultWeapons.
    Anyone alive gets it on the spot.
    "start" is once a round, late joiners get theirs on their first spawn.
    While the round's waiting to start it's topped up, except carryables like the sentry turret.
    Once the hunt's on, losing it is for keeps.
    "default" is every time they come back from the dead, round or no round.
    A spawn that isn't after a death doesn't count, eg the gamemode unsticking them, see glee_true_PlayerSpawn.
    @param lifecycle: What it leaves with, eg the misery's.
    @param kind: "start" or "default".
    @param weapon: A class, or a shopHelpers.purchaseWeapon table for one that comes with extra ammo.
    Any of the table's fields but class can be a function( ply ), eg ammo that depends on how many are playing.
    Or a function( ply ) returning either, eg a random pick, called once per player per round.
    @param shouldGiveFunc: Optional, function( ply ), return false to leave them out.
    @return: None
--]]---------------------------------------------------------
function GM:AddMiserySpawnWeapon( lifecycle, kind, weapon, shouldGiveFunc )
    local list = lists[kind]
    if not list then
        error( "GLEE: spawn weapon kind is \"start\" or \"default\", not " .. tostring( kind ), 2 )

    end

    local entry = makeWeaponEntry( weapon, shouldGiveFunc )
    table.insert( list, entry )
    lifecycle:AddTeardown( function()
        table.RemoveByValue( list, entry )

    end )

    for _, ply in ipairs( self:getAlivePlayers() ) do
        if kind == "start" then
            entry.given[ply:SteamID64()] = true

        end
        giveWeapon( ply, entry )

    end
end

--[[---------------------------------------------------------
    GM:GiveMiserySpawnWeapon
    @desc Gives ply weapon right now, a function weapon is rolled fresh every call.
    @param ply: Who gets it.
    @param weapon: Anything GM:AddMiserySpawnWeapon's weapon takes.
    @return: What they hold of it, nil when there's no room to carry it.
--]]---------------------------------------------------------
function GM:GiveMiserySpawnWeapon( ply, weapon )
    return giveWeapon( ply, makeWeaponEntry( weapon ) )

end


-- handing out

-- set when a round ends, so the setup after it hands out a fresh set
GAMEMODE.glee_SpawnWeaponsResetDue = GAMEMODE.glee_SpawnWeaponsResetDue or false

hook.Add( "huntersglee_round_into_limbo", "glee_spawnweapons", function()
    GAMEMODE.glee_SpawnWeaponsResetDue = true

end )

-- everyone's dead by setup, their free respawn brings a fresh set
hook.Add( "huntersglee_round_into_inactive", "glee_spawnweapons", function()
    if not GAMEMODE.glee_SpawnWeaponsResetDue then return end
    GAMEMODE.glee_SpawnWeaponsResetDue = false

    for _, list in pairs( lists ) do
        for _, entry in ipairs( list ) do
            entry.picks = {}
            entry.given = {}

        end
    end
end )

-- the first default weapon is what they're holding when they spawn, eg the default misery's crowbar
-- a tick late, Loadout's shove comes after glee_true_PlayerSpawn, and would be picked over it
local function holdFirstDefault( ply )
    local first = lists.default[1]
    if not first then return end

    local class = classOf( weaponFor( ply, first ) )
    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        if not ply:HasWeapon( class ) then return end
        ply:SelectWeapon( class )

    end )
end

hook.Add( "glee_true_PlayerSpawn", "glee_spawnweapons", function( spawned )
    for _, entry in ipairs( lists.default ) do
        giveWeapon( spawned, entry )

    end

    local id = spawned:SteamID64()
    for _, entry in ipairs( lists.start ) do
        if entry.given[id] then continue end
        entry.given[id] = true

        giveWeapon( spawned, entry )

    end

    holdFirstDefault( spawned )

end )

-- while the round's waiting to start, start weapons get topped up
-- remembers what it gave, so dropping a start weapon doesn't earn another, it has to be gone entirely
hook.Add( "glee_sv_validgmthink_inactive", "glee_spawnweapons", function()
    for _, ply in ipairs( GAMEMODE:getAlivePlayers() ) do
        ply.glee_StartWeapons = ply.glee_StartWeapons or {}
        for _, entry in ipairs( lists.start ) do
            local class = classOf( weaponFor( ply, entry ) )
            if IsValid( ply.glee_StartWeapons[class] ) then continue end
            -- placing a carryable removes its weapon, topping that up would hand out endless turrets
            if isCarryable( class ) then continue end

            ply.glee_StartWeapons[class] = giveWeapon( ply, entry )

        end
    end
end )
