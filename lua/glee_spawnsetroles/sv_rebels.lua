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

-- every player model in a folder, eg "/group03/"
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

local function twoOrThreeClips()
    return math.random( 2, 3 )

end

-- every rebel gets one of these
local rebelPrimaries = {
    {
        class = "weapon_crossbow",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "weapon_shotgun",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "weapon_ar2",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "weapon_slam",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "weapon_smg1",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "termhunt_annabelle",
        purchaseClips = twoOrThreeClips,
    },
}

local function randomPrimary()
    return rebelPrimaries[math.random( #rebelPrimaries )]

end

local rebelSecondaries = {
    {
        class = "weapon_357",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "weapon_pistol",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "weapon_frag",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "termhunt_aeromatix_flare_gun",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "termhunt_weapon_beartrap",
        purchaseClips = twoOrThreeClips,
    },
    {
        class = "termhunt_lockpick",
    },
}

local function randomSecondary()
    return rebelSecondaries[math.random( #rebelSecondaries )]

end

local roles = {
    ["rebel"] = {
        models = modelsIn( "/group03/" ),
        startWeapons = { randomPrimary, randomSecondary },
    },
    -- heals and revives the squad
    ["medic"] = {
        base = "rebel",
        models = modelsIn( "/group03m/" ),
        startWeapons = { "termhunt_medkit", "termhunt_reviver" },
        -- rounded up, so a squad always has a medic
        ratio = 0.25,
        -- alone, there's nobody to heal or revive
        minPlayers = 2,
        -- the squad's trusted with their lives
        leastGuiltyFirst = true,
    },
    -- documents the glee
    ["reporter"] = {
        base = "rebel",
        startWeapons = { "weapon_glee_crapvidcam" },
        count = 1,
    },
    ["engineer"] = {
        base = "rebel",
        startWeapons = {
            "weapon_physcannon",
            "glee_backpackable_turret",
            {
                class = "termhunt_weapon_hammer",
                purchaseClips = 3,
            }
        },
        ratio = 0.25,
    },
    ["juggernaut"] = {
        base = "rebel",
        startWeapons = {
            {
                class = "termhunt_ar3",
                purchaseClips = 3,
            },
            {
                class = "weapon_rpg",
                purchaseClips = 4,
            },
        },
        statusEffects = { "juggernaut" },
        leastGuiltyFirst = true, -- reward innocent players with the best class
        ratio = 0.05,
        minPlayers = 5,
    },
}

GAMEMODE:GobbleRoles( roles )
