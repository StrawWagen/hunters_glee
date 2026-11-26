-- Great SCOTT!!!!
local set = {
    name = "mad_science",
}

if SERVER then
    local setSv = {
        prettyName = "Mad Science",
        description = "Great scott!\nIt's time for some MAD SCIENCE!!!",
        difficultyPerMin = "default*2",
        waveInterval = "default*0.5",
        diffBumpWhenWaveKilled = "default*2",
        startingSpawnCount = { 6, 8 },
        maxSpawnCount = "default*3",
        hordeSpawn = true,
        chanceToBeVotable = 0.5,
        defaultWeapons = {
            "gmod_camera",
            "termhunt_radio",
            { class = "termhunt_taucannon", ammoType = "Uranium_235", purchaseClips = 1 },
        },
        spawns = {
            {
                name = "kleiner_doppelganger",
                prettyName = "A Doppelganger",
                class = "terminator_nextbot_snail_disguised",
                spawnType = "hunter",
                difficultyCost = { 3, 5 },
                countClass = "terminator_nextbot_snail*",
                minCount = { 4 },
            },
        },
    }
    table.Merge( set, setSv )

end

function set:Activate()
    local setHelpers = GAMEMODE.setHelpers
    setHelpers.makeHardcore( self )

    -- doppelgangers copy a player's model as they spawn, so they come out as Kleiner too
    setHelpers.overridePlayerModel( self, function()
        return "models/player/kleiner.mdl"

    end )
end

table.insert( GLEE_SPAWNSETS, set )
