--[[
    Roles are kits a misery hands its players, see setHelpers.setBaseRole.

    ["rebel"] = {
        models = "models/player/group03/male_07.mdl",
        startWeapons = { "weapon_crowbar" },
    },
    ["medic"] = {
        base = "rebel",
        startWeapons = { "termhunt_medkit" },
        ratio = 0.25,
        leastGuiltyFirst = true,
    },

    Every field is optional.
        models: a model path, or a list of them. Leave it out to wear their own.
        startWeapons: a list, each works like setHelpers.addStartWeapon's weapon.
        defaultWeapons: same, for addDefaultWeapon.
        statusEffects: a list of status effect names, kept for as long as they have the role.

    A role with a base is a variant of it.
        Its weapons and status effects come on top of the base's, its models replace the base's.

    How setHelpers.addRoleVariant picks who gets a variant, every round.
    Leave these out and only setHelpers.setPlayerRoleVariant hands it out.
        ratio: of the players on its base, rounded up, 0.25 of 5 is 2.
        count: a flat number of players, instead of ratio.
        minPlayers: with fewer on its base, nobody gets it.
        leastGuiltyFirst, mostGuiltyFirst: by persistent guilt, random otherwise.
--]]

local function twoOrThreeClips()
    return math.random( 4, 5 )

end

local function modelsIn( folder )
    local models = {}
    local seen = {}
    for _, path in SortedPairs( player_manager.AllValidModels() ) do
        local lowered = string.lower( path )
        if seen[lowered] then continue end
        if not string.find( lowered, folder, 1, true ) then continue end

        seen[lowered] = true
        table.insert( models, path )

    end
    return models

end

local roles = {
    ["swatGrunt"] = {
        models = {"models/player/swat.mdl"},
        startWeapons = {
            {
                class = "weapon_smg1",
                purchaseClips = twoOrThreeClips,
            },
            {
                class = "weapon_pistol",
                purchaseClips = twoOrThreeClips,
            },
        },
    },
    ["medic"] = {
        base = "grunt",
        models = modelsIn( "/group03m/" ),
        ratio = 0.25,
        minPlayers = 2,
        startWeapons = { "termhunt_medkit", "termhunt_reviver" },
        leastGuiltyFirst = true, -- the medic is important
    },
    ["tank"] = {
        base = "grunt",
        models = {"models/player/riot.mdl"},
        ratio = 0.25,
        startWeapons = {
            {
                class = "weapon_ar2",
                purchaseClips = twoOrThreeClips,
            },
            {
                class = "weapon_shotgun",
                purchaseClips = twoOrThreeClips,
            },
            "glee_backpackable_shield"
        },
    },
    ["sniper"] = {
        base = "grunt",
        models = {"models/player/urban.mdl"},
        minPlayers = 3, -- balancing purposes
        ratio = 0.25,
        startWeapons = {
            {
                class = "weapon_crossbow",
                purchaseClips = twoOrThreeClips,
            },
            {
                class = "weapon_357",
                purchaseClips = twoOrThreeClips,
            }
        },
    },
}

GAMEMODE:GobbleRoles( roles )
