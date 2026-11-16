local overchargedChanceAtMinutes = {
    [0] = math.Rand( 1, 5 ),
    [2] = math.Rand( 5, 25 ),
    [8] = math.Rand( 25, 75 ),
    [12] = 100,

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
        huntersGlee_Announce( player.GetAll(), 100, 10, "The nightmare has begun..." )

    end
end

local set = {
    name = "hunters_glee_loreacc_nightmare",
    prettyName = "Lore Accurate Nightmare",
    description = "There's too many of them,\nand they're unstoppable.\nWhat a nightmare.",
    difficultyPerMin = "default*2.5",
    waveInterval = "default",
    diffBumpWhenWaveKilled = "default",
    startingBudget = "default",
    spawnCountPerDifficulty = { 0.2, 0.35 },
    startingSpawnCount = { 1, 4 },
    maxSpawnCount = { 10 },
    maxSpawnDist = "default",
    roundEndSound = "default",
    roundStartSound = "default",
    roundEarlyStartSound = "default",
    chanceToBeVotable = 0.5,
    chanceToBeVotableWhenHard = 5,
    spawns = {
        {
            hardRandomChance = nil,
            name = "terminator_loreaccurate",
            prettyName = "A Lore Accurate Terminator",
            class = "terminator_nextbot_loreaccurate",
            spawnType = "hunter",
            difficultyCost = 5,
            countClass = "terminator_nextbot_loreaccurate*",
            postSpawnedFuncs = { postSpawnedOvercharge },
        },
        {
            hardRandomChance = { 0.1, 1 },
            name = "terminator_doppleganger",
            prettyName = "Terminator Doppleganger",
            class = "terminator_nextbot_snail_disguised",
            spawnType = "hunter",
            difficultyCost = 10,
            countClass = "terminator_nextbot_snail*",
            maxCount = { 1 },
            postSpawnedFuncs = { postSpawnedOvercharge },
        }
    }
}

table.insert( GLEE_SPAWNSETS, set )
