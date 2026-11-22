-- the hardcore take on Combine Gunship Armageddon, fought as a squad of rebels
local set = {
    name = "wailing_sky",
}

if SERVER then
    -- rockets only come once a misery, so small squads split a minimum between them
    -- the opening pair's worth, nowhere near the whole flock's, it's meant to be unwinnable
    local minRocketsTotal = 52
    local minRocketsEach = 12
    local rocketsWithLauncher = 3

    local setSv = {
        prettyName = "WAILING SKY",
        description = "And in our darkest hour, they sent a gunship, then another gunship, another. And we wailed. We screamed, we grieved our own deaths, for nothing but the utmost misery overcomes us. There is no escape. The sky HATES.",
        startingSpawnCount = "combines_glee_gunship_armageddon",
        startingBudget = "combines_glee_gunship_armageddon",
        maxSpawnCount = "combines_glee_gunship_armageddon*2",
        spawnCountPerDifficulty = "combines_glee_gunship_armageddon*0.5",
        roundStartSound = "combines_glee_gunship_armageddon",
        chanceToBeVotable = 0.1,
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
            { name = "combines_glee_gunship_armageddon" },
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

    -- every gunship that finds the squad brings a song, unless one's still playing
    self:Hook( "glee_gunship_firstspottedplayer", function()
        GAMEMODE:SendMusic( "tracks/gunshipBattle", {
            trackAdditions = {
                neverOverrides = { "gunshipBattle" },
            },
        } )

    end )
end

table.insert( GLEE_SPAWNSETS, set )
