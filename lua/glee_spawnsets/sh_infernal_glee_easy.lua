
local set = {
    name = "infernal_glee_easy", -- unique name
}
if SERVER then -- NavEFlags no exist on client
    local setSv = {
        prettyName = "Mildly Gleeful Inferno",
        description = "It burns, it burns! IT BURNS!",
        difficultyPerMin = "default*0.5", -- difficulty per minute
        waveInterval = "default*0.15", -- time between spawn waves
        diffBumpWhenWaveKilled = "default*4", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
        startingBudget = "default", -- so budget isnt 0
        spawnCountPerDifficulty = "default*0.5",
        startingSpawnCount = "default*5",
        maxSpawnCount = { 15 }, -- hard cap on count
        maxSpawnDist = "default*0.15", -- spawn close, these cant pathfind
        minSpawnDist = "default*0.15",
        roundEndSound = "default",
        roundStartSound = "default",
        chanceToBeVotable = 0.1,
        chanceToBeVotableWhenHard = 15, -- stick around when this is still a challenge
        easy = true,
        spawns = {
            {
                name = "infernal_ambler", -- unique name
                prettyName = "An Infernal Ambler",
                class = "terminator_nextbot_infernalskeleton_slow", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 2,
            },
            {
                name = "infernal_heckler_RAREEARLY", -- unique name
                prettyName = "An Infernal Heckler",
                class = "terminator_nextbot_infernalskeleton", -- class spawned
                spawnType = "hunter",
                spawnAbove = true,
                difficultyCost = 150,
                countClass = "terminator_nextbot_infernalskeleton",
                maxCount = { 1 },
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0

                end },
            },
            {
                name = "infernal_heckler", -- unique name
                prettyName = "An Infernal Heckler",
                class = "terminator_nextbot_infernalskeleton", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 100,
                minutesNeeded = { 1, 2 },
                countClass = "terminator_nextbot_infernalskeleton",
                maxCount = { 6 },
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHealth = spawned.SpawnHealth * 0.5
                    spawned.FistDamageMul = 0.2
                    spawned.SpawnHeadlessChance = 0

                end },
            },
            {
                hardRandomChance = 5,
                name = "the_infernal_rumbler_RAREEARLY", -- unique name
                prettyName = "The Infernal Rumbler",
                class = "terminator_nextbot_infernalskeleton_large", -- class spawned
                spawnType = "hunter",
                spawnAbove = true,
                difficultyCost = { 1500, 2500 }, -- super rare early one, just added in here for fun
                countClass = "terminator_nextbot_infernalskeleton_large",
                maxCount = { 1 },
                isBoss = true, -- kill it to win!
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHeadlessChance = 0

                end },
            },
            {
                hardRandomChance = 15,
                name = "the_infernal_rumbler", -- unique name
                prettyName = "The Infernal Rumbler",
                class = "terminator_nextbot_infernalskeleton_large", -- class spawned
                spawnType = "hunter",
                spawnSameZ = true,
                preferredEFlags = GAMEMODE.NavEFlags.UNDER_SKY,
                difficultyCost = 200,
                minutesNeeded = { 4, 6 },
                countClass = "terminator_nextbot_infernalskeleton_large",
                maxCount = { 1 },
                isBoss = true, -- kill it to win!
                preSpawnedFuncs = { function( _, spawned )
                    spawned.SpawnHeadlessChance = 0

                end },
            },
        }
    }
    table.Merge( set, setSv )

end

function set:Activate()
    self:Hook( "glee_shop_canshow", function( _identifier, itemData )
        if not itemData.tags.Essential then return false, "This item is not essential, it's for other modes.", true end

        return nil

    end )
    self:Hook( "glee_bargains_overridecount", function( _originalCount )
        return 3

    end )
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
