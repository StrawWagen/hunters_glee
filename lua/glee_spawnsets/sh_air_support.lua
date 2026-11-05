
-- the hardcore take on The Combine Gunship, fought as a squad of rebels
local set = {
    name = "air_support", -- unique name
}

if SERVER then
    local setSv = {
        prettyName = "AIR SUPPORT",
        description = "They called for air support, now you hear something in the sky...\nYou have to take it down.",
        difficultyPerMin = "default", -- difficulty per minute
        waveInterval = "default", -- time between spawn waves
        diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
        startingSpawnCount = 1,
        maxSpawnCount = 1,
        roundEndSound = "music/hl2_song6.mp3",
        roundStartSound = "ambient/levels/streetwar/gunship_distant1.wav",
        chanceToBeVotable = 0.5,
        spawns = {
            {
                name = "the_gunship",
                prettyName = "The Combine Gunship",
                class = "npc_combinegunship",
                spawnType = "hunter",
                isBoss = true,
                difficultyCost = 1,
                countClass = "npc_combinegunship",
                maxCount = 1,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                firmPreferredEFlags = true,
                -- the gunship module loads with the addon, look it up when called
                canSpawnOnMap = function( ... ) return terminator_Extras.glee_Gunship.CanSpawnOnMap( ... ) end,
                areaFilter = function( ... ) return terminator_Extras.glee_Gunship.AreaFilter( ... ) end,
                preSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PreSpawn( ... ) end },
                postSpawnedFuncs = { function( ... ) terminator_Extras.glee_Gunship.PostSpawn( ... ) end },
            },
        }
    }
    table.Merge( set, setSv )

end

-- 1 in 4 players, rounded up, so a squad always has a medic
local medicShare = 0.25

-- rockets only come once a misery, so small squads split a minimum between them
-- the gunship takes about 10 + 1.5 per player perfect hits, so 1 or 2 players couldn't kill it on 6 each
local minRocketsTotal = 26
local minRocketsEach = 6
local rocketsWithLauncher = 3

local function twoOrThreeClips()
    return math.random( 2, 3 )

end

local function withExtraClips( class )
    return { class = class, purchaseClips = twoOrThreeClips }

end

-- everyone gets one of these on top of their RPG
local randomWeapons = {
    withExtraClips( "weapon_frag" ),
    withExtraClips( "weapon_crossbow" ),
    withExtraClips( "weapon_pistol" ),
    withExtraClips( "weapon_357" ),
    withExtraClips( "weapon_shotgun" ),
    withExtraClips( "weapon_ar2" ),
    withExtraClips( "weapon_slam" ),
    withExtraClips( "weapon_smg1" ),
    "weapon_physcannon",
    "glee_backpackable_turret",
}

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

-- the same face every spawn, so the squad can tell each other apart
local function stablePick( ply, models )
    if #models <= 0 then return end
    local index = tonumber( util.CRC( ply:SteamID64() ) ) % #models + 1
    return models[index]

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    -- picked once, and kept for as long as this misery is
    -- by SteamID64, so rejoining doesn't reroll it
    local medicsById = {}

    -- everyone without a pick yet is picked together, least persistent guilt first
    -- ties go in a random order, so whoever spawns first isn't always the medic
    local function pickMedics()
        local unpicked = {}
        local guilts = {}
        local tieBreaks = {}
        local medicCount = 0
        for _, ply in player.Iterator() do
            local isMedic = medicsById[ply:SteamID64()]
            if isMedic == nil then
                table.insert( unpicked, ply )
                guilts[ply] = GAMEMODE:GetPersistentGuilt( ply )
                tieBreaks[ply] = math.random()

            elseif isMedic then
                medicCount = medicCount + 1

            end
        end

        table.sort( unpicked, function( a, b )
            if guilts[a] ~= guilts[b] then
                return guilts[a] < guilts[b]

            end
            return tieBreaks[a] < tieBreaks[b]

        end )

        -- alone, there's nobody to heal or revive, so they're a plain rebel for good
        local wantedMedics = 0
        if player.GetCount() >= 2 then
            wantedMedics = math.ceil( player.GetCount() * medicShare )

        end
        for _, ply in ipairs( unpicked ) do
            local isMedic = medicCount < wantedMedics
            medicsById[ply:SteamID64()] = isMedic
            if isMedic then
                medicCount = medicCount + 1

            end
        end
    end

    local function isMedic( ply )
        if medicsById[ply:SteamID64()] == nil then
            pickMedics()

        end
        return medicsById[ply:SteamID64()]

    end

    local rebelModels = modelsIn( "/group03/" )
    local medicModels = modelsIn( "/group03m/" )

    setHelpers.overridePlayerModel( self, function( ply )
        if isMedic( ply ) then
            return stablePick( ply, medicModels )

        end
        return stablePick( ply, rebelModels )

    end )

    setHelpers.addStartWeapon( self, {
        class = "weapon_rpg",
        ammoType = "RPG_Round",
        purchaseClips = function()
            local rockets = math.max( minRocketsEach, math.ceil( minRocketsTotal / player.GetCount() ) )
            return rockets - rocketsWithLauncher

        end,
    } )
    setHelpers.addStartWeapon( self, function()
        return randomWeapons[math.random( #randomWeapons )]

    end )
    setHelpers.addStartWeapon( self, "termhunt_medkit", isMedic )
    setHelpers.addStartWeapon( self, "termhunt_reviver", isMedic )

    -- once per round, this misery can stay active across many rounds
    self:Hook( "glee_gunship_firstspottedplayer", function()
        local roundData = GAMEMODE.roundExtraData
        if roundData.gunshipPlayedTrack then return end
        roundData.gunshipPlayedTrack = true
        GAMEMODE:SendMusic( "tracks/gunshipBattle" )

    end )
    -- the track's list plays round robin, so this is a different song for the last stretch
    self:Hook( "glee_gunship_desperate", function()
        local roundData = GAMEMODE.roundExtraData
        if roundData.gunshipPlayedDesperateTrack then return end
        roundData.gunshipPlayedDesperateTrack = true
        GAMEMODE:SendMusic( "tracks/gunshipBattle" )

    end )
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
