-- overcharged hunters, dont have to copy this
local overchargedChanceAtMinutes = {
    [0] = math.Rand( 1, 5 ),
    [1] = math.Rand( 5, 25 ),
    [4] = math.Rand( 25, 75 ),
    [8] = 100,

}
local function postSpawnedOvercharge( spawnDat, spawned )
    local overchargedChance = 0
    local minutesWhenAdded = spawnDat.minutesWhenAdded
    for minutesNeeded, currChance in pairs( overchargedChanceAtMinutes ) do
        if minutesNeeded <= minutesWhenAdded and currChance >= overchargedChance then
            overchargedChance = currChance

        end
    end

    if math.Rand( 0, 100 ) > overchargedChance then return end
    glee_Overcharge( spawned )

    local lightning = ents.Create( "glee_lightning" )
    lightning:SetOwner( spawned )
    lightning:SetPos( spawned:GetPos() )
    lightning:SetPowa( 12 )
    lightning:Spawn()

    if overchargedChance >= 5 and not GAMEMODE.roundExtraData.overchargedWarning then
        GAMEMODE.roundExtraData.overchargedWarning = true
        huntersGlee_AnnounceDramatic( player.GetAll(), 100, 10, "The nightmare has begun..." )

    end
end

local set = {
    name = "hunters_glee_wraiths_nightmare", -- unique name
    prettyName = "Gleefully Wraithful Nightmare",
    description = "Overcharged, invisible enemies, almost as smart as you...",
    difficultyPerMin = "default*2.5", -- difficulty per minute
    waveInterval = "default", -- time between spawn waves
    diffBumpWhenWaveKilled = { 25, 50 }, -- when there's <= 1 hunter left, the difficulty is permanently bumped by this amount
    startingBudget = "default", -- so budget isnt 0
    spawnCountPerDifficulty = { 0.2, 0.35 },
    startingSpawnCount = { 1, 4 },
    maxSpawnCount = { 8 }, -- hard cap on count
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 0.5,
    chanceToBeVotableWhenHard = 5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator_invisible", -- unique name
            prettyName = "A Wraith Terminator",
            class = "terminator_nextbot_wraith", -- class spawned
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
            countClass = "terminator_nextbot_wraith", -- class COUNTED, uses findbyclass
            minCount = { 3 },
            maxCount = { 15 }, -- will never exceed this count, uses findbycount
            postSpawnedFuncs = { postSpawnedOvercharge }, -- this can be nil
        },
    }
}

-- put the spawnset IN the global table to be gobbled
table.insert( GLEE_SPAWNSETS, set )
