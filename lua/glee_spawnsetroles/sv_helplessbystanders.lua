
-- every player model in a folder, eg "/group01/"
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

local citizenModels = modelsIn( "/group01/" )
table.Add( citizenModels, modelsIn( "/group02/" ) )

local roles = {
    -- nothing but their hands
    ["helplessBystander"] = {
        models = citizenModels,
        variants = {
            ["photographer"] = {
                startWeapons = { "gmod_camera" },
                ratio = 0.25,
            },
            -- documents the suffering
            ["reporter"] = {
                startWeapons = { "weapon_glee_crapvidcam" },
                count = 1,
            },
        },
    },
}

GAMEMODE:GobbleRoles( roles )
