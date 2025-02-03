-- overcharged hunters, dont have to copy this
local overchargedChanceAtMinutes = {
    [0] = 0,
    [5] = math.Rand( 0, 1 ),
    [15] = math.Rand( 5, 25 ),
    [30] = math.Rand( 50, 100 ),

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
        huntersGlee_Announce( player.GetAll(), 100, 10, "This hunt has gone on too long...\nOvercharged Hunters are on the prowl..." )

    end
end

-- see jerma985 nextbot for example of how to modify this

local defaultSpawnSet = {
    name = "hunters_glee", -- unique name
    prettyName = "Hunter's Glee",
    description = "The default Hunter's Glee experience.",
    difficultyPerMin = "default", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = "default", -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = "default", -- max of ten at 10 minutes
    startingSpawnCount = "default",
    maxSpawnCount = "default", -- hard cap on count
    maxSpawnDist = "default",
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
            name = "terminator", -- unique name
            prettyName = "A Terminator",
            class = "terminator_nextbot_snail", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 15, 25 },
            countClass = "terminator_nextbot_snail*", -- class COUNTED, uses findbyclass
            minutesNeeded = { 4, 5 },
            minCount = { 0 }, -- will ALWAYS maintain this count
            maxCount = { 10 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs = { postSpawnedOvercharge }, -- this can be nil
        },
        {
            hardRandomChance = { 0, 2 }, -- chance this is even checked
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
table.insert( GLEE_SPAWNSETS, defaultSpawnSet )
