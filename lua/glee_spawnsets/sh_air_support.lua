-- the hardcore take on The Combine Gunship, fought as a squad of rebels
local set = {
    name = "air_support",
}

if SERVER then
    -- rockets only come once a misery, so small squads split a minimum between them
    -- the gunship takes about 10 + 1.5 per player perfect hits, so 1 or 2 players couldn't kill it on 6 each
    local minRocketsTotal = 26
    local minRocketsEach = 6
    local rocketsWithLauncher = 3

    local setSv = {
        prettyName = "AIR SUPPORT",
        description = "They called for air support, now you hear something in the sky...\nYou have to take it down.",
        startingSpawnCount = "combines_glee_gunship",
        maxSpawnCount = "combines_glee_gunship",
        roundEndSound = "combines_glee_gunship",
        roundStartSound = "combines_glee_gunship",
        chanceToBeVotable = 0.5,
        startWeapons = {
            {
                class = "weapon_rpg",
                ammoType = "RPG_Round",
                purchaseClips = function()
                    local rockets = math.max( minRocketsEach, math.ceil( minRocketsTotal / player.GetCount() ) )
                    return rockets - rocketsWithLauncher

                end,
            },
        },
        importedMiserySpawns = {
            { name = "combines_glee_gunship" },
        },
    }
    table.Merge( set, setSv )

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    setHelpers.setBaseRole( self, "rebel" )
    setHelpers.addRoleVariant( self, "medic" )
    setHelpers.addRoleVariant( self, "reporter" )

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

table.insert( GLEE_SPAWNSETS, set )
