local spawns = {
    ["weapon_physgun"] = {
        prob = 0.005,
        minAreaSize = 50,
    },
    ["manhack_welder"] = {
        prob = 0.001,
        minAreaSize = 75,
    },
    ["sent_ball"] = {
        prob = 0.005,
        minAreaSize = 100,
    },
    ["combine_mine"] = {
        prob = 0.005,
        minAreaSize = 150,
    },

}

for className, data in pairs( spawns ) do
    local roll = math.Rand( 0, 100 )
    if roll > data.prob then continue end

    data.maxCount = data.maxCount or 1
    data.chance = data.chance or 100

    GAMEMODE:RandomlySpawnEntTbl( className, data )
end