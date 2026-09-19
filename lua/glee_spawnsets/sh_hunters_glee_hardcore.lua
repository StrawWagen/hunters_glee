
local set = {
    name = "hunters_glee_hardcore", -- unique name
}

if SERVER then
    local postSpawnedOvercharge = GAMEMODE.setHelpers.postSpawnedOvercharge

    local setSv = {
        prettyName = "Hardcore Glee",
        description = "Smart, cruel enemies.\nThe shop is CLOSED.",
        difficultyPerMin = 0.05, -- very little difficulty per minute, let wave clears primarily bump difficulty
        waveInterval = "default", -- time between spawn waves
        diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
        startingBudget = "default", -- so budget isnt 0
        spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
        startingSpawnCount = "default",
        maxSpawnCount = 6, -- hard cap on count
        maxSpawnDist = "default",
        roundEndSound = "default",
        roundStartSound = "default",
        roundEarlyStartSound = "default", -- plays 10s before round start
        genericSpawnerRate = "default", -- speeds up or slows down the crate/beartrap/etc spawner
        chanceToBeVotable = 2,
        spawns = {
            {
                hardRandomChance = nil,
                name = "terminator", -- unique name
                prettyName = "A Terminator",
                class = "terminator_nextbot_snail", -- class spawned
                spawnType = "hunter",
                difficultyCost = { 10 },
                countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
                minCount = { 2 }, -- will ALWAYS maintain this count
                maxCount = { 2 }, -- will never exceed this count, uses findbycount
                postSpawnedFuncs = { postSpawnedOvercharge }, -- this can be nil
            },
            {
                hardRandomChance = nil,
                name = "terminator_MORE", -- unique name
                prettyName = "A Terminator",
                class = "terminator_nextbot_snail", -- class spawned
                spawnType = "hunter",
                difficultyCost = { 15, 25 },
                countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
                minutesNeeded = { 4, 6 },
                postSpawnedFuncs = { postSpawnedOvercharge }, -- this can be nil
            },
            {
                hardRandomChance = { 0, 2 }, -- chance this is even checked
                name = "terminator_doppleganger",
                prettyName = "A Terminator Doppleganger",
                class = "terminator_nextbot_snail_disguised",
                spawnType = "hunter",
                difficultyCost = { 20 },
                countClass = "terminator_nextbot_snail*",
                minCount = { 2 },
                postSpawnedFuncs = { postSpawnedOvercharge },
            }
        }
    }
    table.Merge( set, setSv )

end

local noShopReason = "There is no shop in Hardcore Glee."

function set:Activate()
    self:Hook( "glee_blockshopopen", function()
        return true, noShopReason

    end )
    -- the shop panel is only one way in, termhunt_purchase is the other, and this closes both
    self:Hook( "glee_shop_canshow", function()
        return false, noShopReason

    end )
end

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
