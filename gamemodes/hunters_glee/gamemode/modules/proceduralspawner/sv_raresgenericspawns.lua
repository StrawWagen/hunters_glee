local spawns = {
    ["weapon_physgun"] = {
        prob = 0.005,
        areaSize = 50,
    },
    ["manhack_welder"] = {
        prob = 0.001,
        areaSize = 75,
    },
    ["sent_ball"] = {
        prob = 0.005,
        areaSize = 100,
    },
    ["combine_mine"] = {
        prob = 0.005,
        areaSize = 150,
    },

}

for className, data in pairs( spawns ) do
    local roll = math.Rand( 0, 100 )
    if roll > data.prob then continue end

    GAMEMODE:RandomlySpawnEnt(
        className,
        data.spawnCount or 1,
        data.enabledChance or 100,
        data.minAreaSize or 100,
        data.radius or 100,
        data.preSpawnedFunc,
        data.postSpawnedFunc

    )
end