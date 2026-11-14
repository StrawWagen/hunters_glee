
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
        models = { "models/player/swat.mdl" },
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
        startWeapons = { "glee_tissue_reclaimer" },
        leastGuiltyFirst = true, -- the medic is important
    },
    ["tank"] = {
        base = "grunt",
        models = { "models/player/riot.mdl" },
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
        models = { "models/player/urban.mdl" },
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
