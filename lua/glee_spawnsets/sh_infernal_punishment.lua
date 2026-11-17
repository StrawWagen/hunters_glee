-- the hardcore take on The Infernal Titans, suffered as unarmed citizens
local set = {
    name = "infernal_punishment",
}

if SERVER then
    local setSv = {
        prettyName = "INFERNAL PUNISHMENT",
        description = "NO HOPE",
        difficultyPerMin = "infernal_glee_titans",
        waveInterval = "infernal_glee_titans",
        diffBumpWhenWaveKilled = "infernal_glee_titans",
        startingSpawnCount = "infernal_glee_titans",
        maxSpawnCount = "infernal_glee_titans",
        maxSpawnDist = "infernal_glee_titans", -- spawn close, these cant pathfind
        roundEarlyStartSound = "infernal_glee_titans",
        chanceToBeVotable = 0.5,
        -- no crowbar, camera or radio, the citizen role hands out the rest
        defaultWeapons = {},
        importedMiserySpawns = {
            { name = "infernal_glee_titans" },
        },
    }
    table.Merge( set, setSv )

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    if CLIENT then return end

    setHelpers.setBaseRole( self, "helplessBystander" )
    -- first pick, so the photographers can't take everyone in a small group
    setHelpers.addRoleVariant( self, "reporter" )
    setHelpers.addRoleVariant( self, "photographer" )

end

table.insert( GLEE_SPAWNSETS, set )
