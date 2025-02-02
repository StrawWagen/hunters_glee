-- overcharged hunters, dont have to copy this
local overchargedChanceAtMinutes = {
    [0] = math.Rand( 0, 1 ),
    [5] = math.Rand( 5, 25 ),
    [15] = math.Rand( 50, 100 )

}
local function postSpawnedOvercharge( spawnDat, spawned )
    local minutesWhenAdded = spawnDat.minutesWhenAdded
    for minutesNeeded, currChance in pairs( overchargedChanceAtMinutes ) do
        if minutesNeeded <= minutesWhenAdded then
            overchargedChance = currChance

        else
            break

        end
    end

    if math.random( 0, 100 ) > overchargedChance then return end
    glee_Overcharge( spawned )

    local lightning = ents.Create( "glee_lightning" )
    lightning:SetOwner( spawned )
    lightning:SetPos( spawned:GetPos() )
    lightning:SetPowa( 12 )
    lightning:Spawn()

    if overchargedChance >= 5 and not GAMEMODE.roundExtraData.overchargedWarning then
        GAMEMODE.roundExtraData.overchargedWarning = true

    end
end

-- see jerma985 nextbot for example of how to modify this

local set = {
    name = "hunters_glee_nightmare", -- unique name
    prettyName = "Nightmare on glee street.",
    description = "Nightmare on glee street.\nMore hunters, sooner, and they're probably overcharged",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 25, 50 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = { 0.15, 0.2 },
    startingSpawnCount = { 1, 3 },
    maxSpawnCount = { 15 }, -- hard cap on count
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator", -- unique name
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 10, 20 },
            countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 10 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs = { postSpawnedOvercharge }, -- this can be nil
        },
        {
            hardRandomChance = { 1, 3 }, -- chance this is even checked
            name = "terminator_doppleganger",
            prettyName = "Terminator Doppleganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = { 20 },
            countClass = "terminator_nextbot_snail*",
            minCount = { 2 },
            maxCount = { 10 },
            postSpawnedFuncs = { postSpawnedOvercharge },
        }
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
