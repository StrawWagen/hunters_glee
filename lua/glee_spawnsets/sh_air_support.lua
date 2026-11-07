
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

-- rockets only come once a misery, so small squads split a minimum between them
-- the gunship takes about 10 + 1.5 per player perfect hits, so 1 or 2 players couldn't kill it on 6 each
local minRocketsTotal = 26
local minRocketsEach = 6
local rocketsWithLauncher = 3

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    setHelpers.setBaseRole( self, "rebel" )
    setHelpers.addRoleVariant( self, "medic" )

    setHelpers.addStartWeapon( self, {
        class = "weapon_rpg",
        ammoType = "RPG_Round",
        purchaseClips = function()
            local rockets = math.max( minRocketsEach, math.ceil( minRocketsTotal / player.GetCount() ) )
            return rockets - rocketsWithLauncher

        end,
    } )

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
