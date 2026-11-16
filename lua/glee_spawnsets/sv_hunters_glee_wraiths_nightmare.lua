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
    name = "hunters_glee_wraiths_nightmare",
    prettyName = "Gleefully Wraithful Nightmare",
    description = "Overcharged, invisible enemies, almost as smart as you...",
    difficultyPerMin = "default*2.5",
    waveInterval = "default",
    diffBumpWhenWaveKilled = { 25, 50 },
    startingBudget = "default",
    spawnCountPerDifficulty = { 0.2, 0.35 },
    startingSpawnCount = { 1, 4 },
    maxSpawnCount = { 8 },
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 0.5,
    chanceToBeVotableWhenHard = 5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator_invisible",
            prettyName = "A Wraith Terminator",
            class = "terminator_nextbot_wraith",
            spawnType = "hunter",
            difficultyCost = { 5, 10 },
            minCount = { 3 },
            maxCount = { 15 },
            postSpawnedFuncs = { postSpawnedOvercharge },
        },
    }
}

table.insert( GLEE_SPAWNSETS, set )
