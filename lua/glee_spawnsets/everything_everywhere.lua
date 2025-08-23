-- HIM stuff
local function deservesToExist(_, me)
	me.homeless_DeservesToExist = true
end

local function modelMan(_, me)
	me:SetModel("models/player/corpse1.mdl")
end

local function modelLost(_, me)
	me:SetModel("models/player/charple.mdl")
end

local function ANGRY(_, me)
	me.HomelessFrustration = me.HomelessFrustrationToAnger
	me.TryingToBeHidden = 0
end

local function scornOverride(_, me)
	me.TryingToBeHidden = math.random(-8, -4)
	me.homeless_IgnoreScornWisdom = true
	
	function me:homeless_ScornOverride(enemy)
		enemy:TakeDamage(math.huge, self, self)
		timer.Simple(5, function()
			if not IsValid(me) then return end
			ANGRY(nil, me)
		end)
	end
	
	local timerName = "homeless_findnewenemies_" .. me:GetCreationID()
	timer.Create(timerName, 1, 0, function()
		if not IsValid(me) then 
			timer.Remove(timerName) 
			return 
		end

		local enemy = me:GetEnemy()
		if IsValid(enemy) and enemy:Health() > 0 then return end
		me:SetEnemy(nil)
	end)
end

local overchargedChanceAtMinutes = {
    [0] = 0,
	[5] =  math.Rand( 5,  10 ),
    [10] = math.Rand( 15, 25 ),
    [15] = math.Rand( 35, 45 ),
    [20] = math.Rand( 65, 85 ),
    [25] = 100

}

local function postSpawnedOvercharge( spawnDat, spawned )
    local overchargedChance = 0
    local minutesWhenAdded = spawnDat.minutesWhenAdded
    for minutesNeeded, currChance in pairs( overchargedChanceAtMinutes ) do
        if minutesNeeded <= minutesWhenAdded and currChance >= overchargedChance then
            overchargedChance = currChance

        end
    end

    print( overchargedChance )
    if math.Rand( 0, 100 ) > overchargedChance then return end
    glee_Overcharge( spawned )

    local lightning = ents.Create( "glee_lightning" )
    lightning:SetOwner( spawned )
    lightning:SetPos( spawned:GetPos() )
    lightning:SetPowa( 12 )
    lightning:Spawn()

    if overchargedChance >= 10 and not GAMEMODE.roundExtraData.overchargedWarning then
        GAMEMODE.roundExtraData.overchargedWarning = true
        huntersGlee_Announce( player.GetAll(), 100, 10, "Overcharged hunters are coming..." )

    end
end

local everythingEverywhereSpawnSet = {
	name = "everything_everywhere",
	prettyName = "Everything Everywhere",
	description = "Everything is everywhere!",
	difficultyPerMin = "default", 
	waveInterval = "default",
	diffBumpWhenWaveKilled = "default",
	startingBudget = "default",
    spawnCountPerDifficulty = { 1 }, -- go up fast pls
    startingSpawnCount = 100,
	maxSpawnCount = 150, 
	maxSpawnDist = "default",
	chanceToBeVotable = 2, 
	roundEndSound = "ambient/intro/logosfx.wav",
	roundStartSound = "music/hl2_song28.mp3",
	spawns = {
        {
				hardRandomChance = nil,
				name = "jerma_scared",
				prettyName = "A Jerma",
				class = "terminator_nextbot_jerminator_scared",
				spawnType = "hunter",
				difficultyCost = { 0 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = nil,
				name = "jerma_normal",
				prettyName = "A Jerma",
				class = "terminator_nextbot_jerminator",
				spawnType = "hunter",
				difficultyCost = { 3, 4 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 5 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 5, 15 },
				name = "jerma_988",
				prettyName = "A Jerma988",
				class = "terminator_nextbot_jerminatorsmol",
				spawnType = "hunter",
				difficultyCost = { 7, 8 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 10 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 5, 15 },
				name = "jerma_985",
				prettyName = "A Jerma985",
				class = "terminator_nextbot_jerminator_realistic",
				spawnType = "hunter",
				difficultyCost = { 9, 10 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 6 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 3, 8 },
				name = "jerma_986",
				prettyName = "A Jerma986",
				class = "terminator_nextbot_jerminatorwraith",
				spawnType = "hunter",
				difficultyCost = { 21, 22 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 2 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 3, 8 },
				name = "jerma_987",
				prettyName = "A Jerma987",
				class = "terminator_nextbot_jerminatorhuge",
				spawnType = "hunter",
				difficultyCost = { 23, 24 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 4 },
				postSpawnedFuncs = { postSpawnedOvercharge }, -- i'm so evil for this
			},
			{
				hardRandomChance = { 4, 10 },
				name = "jerma_989",
				prettyName = "A Jerma989",
				class = "terminator_nextbot_jerminatorwide",
				spawnType = "hunter",
				difficultyCost = { 25, 26 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 4 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 3, 8 },
				name = "jerma_990",
				prettyName = "A Jerma990",
				class = "terminator_nextbot_jerminatorstronk",
				spawnType = "hunter",
				difficultyCost = { 27, 28 },
				countClass = "terminator_nextbot_jerminator*",
				maxCount = { 3 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 2, 6 },
				name = "terminator_fakeply",
				prettyName = "A Fake Player",
				class = "terminator_nextbot_fakeply",
				spawnType = "hunter",
				difficultyCost = { 3, 4 },
				countClass = "terminator_nextbot_fakeply*",
				maxCount = { 10 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = nil,
				name = "terminator",
				prettyName = "A Terminator",
				class = "terminator_nextbot_snail",
				spawnType = "hunter",
				difficultyCost = { 5, 6 },
				countClass = "terminator_nextbot_snail*",
				maxCount = { 8 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 2, 6 },
				name = "terminator_doppleganger",
				prettyName = "A Terminator Doppleganger",
				class = "terminator_nextbot_snail_disguised",
				spawnType = "hunter",
				difficultyCost = { 11, 12 },
				countClass = "terminator_nextbot_snail*",
				maxCount = { 3 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 2, 6 },
				name = "terminator_hard",
				prettyName = "A Terminator Hard",
				class = "terminator_nextbot_slower",
				spawnType = "hunter",
				difficultyCost = { 13, 14 },
				countClass = "terminator_nextbot_slower*",
				maxCount = { 8 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 2, 6 },
				name = "terminator_overcharged",
				prettyName = "A Terminator Overcharged",
				class = "terminator_nextbot",
				spawnType = "hunter",
				difficultyCost = { 15, 16 },
				countClass = "terminator_nextbot*",
				maxCount = { 4 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 2, 6 },
				name = "terminator_wraith",
				prettyName = "A Terminator Wraith",
				class = "terminator_nextbot_wraith",
				spawnType = "hunter",
				difficultyCost = { 29, 30 },
				countClass = "terminator_nextbot*",
				maxCount = { 3 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 2, 6 },
				name = "terminator_loreaccurate",
				prettyName = "A Lore Accurate Terminator",
				class = "terminator_nextbot_loreaccurate",
				spawnType = "hunter",
				difficultyCost = { 82, 85 },
				countClass = "terminator_nextbot_loreaccurate*",
				maxCount = { 4 },
				postSpawnedFuncs = { postSpawnedOvercharge }, -- big evil but not as evil as below
			},
			{
				hardRandomChance = nil,
				name = "zambie_normal",
				prettyName = "A Zombie",
				class = "terminator_nextbot_zambie",
				spawnType = "hunter",
				difficultyCost = { 1 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 12 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = nil,
				name = "zambie_slow",
				prettyName = "A Slow Zombie",
				class = "terminator_nextbot_zambie_slow",
				spawnType = "hunter",
				difficultyCost = { 2, 3 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 10 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = nil,
				name = "zambie_fast",
				prettyName = "A Fast Zombie",
				class = "terminator_nextbot_zambiefast",
				spawnType = "hunter",
				difficultyCost = { 2 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 8 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = nil,
				name = "zambie_tank",
				prettyName = "A Tank Zombie",
				class = "terminator_nextbot_zambietank",
				spawnType = "hunter",
				difficultyCost = { 35, 36 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 5, 15 },
				name = "zambie_flaming",
				prettyName = "A Flaming Zombie",
				class = "terminator_nextbot_zambieflame",
				spawnType = "hunter",
				difficultyCost = { 17, 18 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 4 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 5, 15 },
				name = "zambie_flamingfast",
				prettyName = "A Fast Flaming Zombie",
				class = "terminator_nextbot_zambieflamefast",
				spawnType = "hunter",
				difficultyCost = { 19, 20 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 3, 10 },
				name = "zambie_acid",
				prettyName = "An Acid Zombie",
				class = "terminator_nextbot_zambieacid",
				spawnType = "hunter",
				difficultyCost = { 31, 32 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 3, 10 },
				name = "zambie_acidfast",
				prettyName = "A Fast Acid Zombie",
				class = "terminator_nextbot_zambieacidfast",
				spawnType = "hunter",
				difficultyCost = { 33, 34 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 2 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 4, 12 },
				name = "zambie_wraith",
				prettyName = "A Wraith",
				class = "terminator_nextbot_zambiewraith",
				spawnType = "hunter",
				difficultyCost = { 37, 38 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 2, 8 },
				name = "zambie_wraith_elite",
				prettyName = "An Elite Wraith",
				class = "terminator_nextbot_zambiewraithelite",
				spawnType = "hunter",
				difficultyCost = { 39, 40 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 2 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 3, 10 },
				name = "zambie_grunt",
				prettyName = "A Zombie Grunt",
				class = "terminator_nextbot_zambiegrunt",
				spawnType = "hunter",
				difficultyCost = { 41, 42 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 4 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 2, 8 },
				name = "zambie_berserk",
				prettyName = "A Berserker Zombie",
				class = "terminator_nextbot_zambieberserk",
				spawnType = "hunter",
				difficultyCost = { 43, 44 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 2 }, 
				hardRandomChance = { 3, 10 },
			},
			{
				name = "zambie_fastgrunt",
				prettyName = "A Fast Zombie Grunt",
				class = "terminator_nextbot_zambiefastgrunt",
				spawnType = "hunter",
				difficultyCost = { 23, 25 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 1, 4 },
				name = "zambie_necromancer",
				prettyName = "A Necromancer Zombie",
				class = "terminator_nextbot_zambienecro",
				spawnType = "hunter",
				difficultyCost = { 47, 48 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 1 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 2, 6 },
				name = "zambie_tankelite",
				prettyName = "An Elite Tank Zombie",
				class = "terminator_nextbot_zambietankelite",
				spawnType = "hunter",
				difficultyCost = { 49, 50 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 1 },
				postSpawnedFuncs = { postSpawnedOvercharge },
			},
			{
				hardRandomChance = { 1, 3 },
				name = "zambie_necromancerelite",
				prettyName = "An Elite Necromancer Zombie",
				class = "terminator_nextbot_zambienecroelite",
				spawnType = "hunter",
				difficultyCost = { 52, 55 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 1 },
				postSpawnedFuncs = { postSpawnedOvercharge }, -- evil maybe also
			},
			{
				hardRandomChance = { 3, 10 },
				name = "zambie_torso",
				prettyName = "A Torso Zombie",
				class = "terminator_nextbot_zambietorso",
				spawnType = "hunter",
				difficultyCost = { 8, 10 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 6 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 3, 10 },
				name = "zambie_torsofast",
				prettyName = "A Fast Torso Zombie",
				class = "terminator_nextbot_zambietorsofast",
				spawnType = "hunter",
				difficultyCost = { 12, 14 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 4 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 4, 12 },
				name = "zambie_torsowraith",
				prettyName = "A Torso Wraith",
				class = "terminator_nextbot_zambietorsowraith",
				spawnType = "hunter",
				difficultyCost = { 21, 23 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 3 },
				postSpawnedFuncs = nil
			},
			{
				hardRandomChance = { 1, 3 },
				name = "zambie_demigodcrab",
				prettyName = "A Demigod Crab",
				class = "terminator_nextbot_zambiebigheadcrab",
				spawnType = "hunter",
				difficultyCost = { 62, 65 },
				countClass = "terminator_nextbot_zambie*", 
				maxCount = { 6 },
				postSpawnedFuncs = { postSpawnedOvercharge }, -- evil also truly
			},
			{
				hardRandomChance = nil,
				name = "fallen_supercop",
				prettyName = "A Fallen Supercop",
				class = "terminator_nextbot_zambiecop",
				spawnType = "hunter",
				difficultyCost = { 72, 75 },
				countClass = "terminator_nextbot_zambiecop",
				maxCount = { 3 },
				postSpawnedFuncs = { postSpawnedOvercharge }, -- evil also
			},
			{
				hardRandomChance = { 1, 2 },
				name = "zambie_godcrab",
				prettyName = "The God Crab",
				class = "terminator_nextbot_zambiebiggerheadcrab",
				spawnType = "hunter",
				difficultyCost = { 87, 90 },
				countClass = "terminator_nextbot_zambie*",
				maxCount = { 2 },
				postSpawnedFuncs = { postSpawnedOvercharge }, -- evil truly
			},
		    {
				hardRandomChance = nil,
				name = "homeless",
				prettyName = "HIM",
				class = "terminator_nextbot_homeless",
				spawnType = "hunter",
				difficultyCost = { 10, 25 },
				countClass = "terminator_nextbot_homeless",
				maxCount = { 1 },
				preSpawnedFuncs = { deservesToExist },
				postSpawnedFuncs = { scornOverride, modelMan },
			},
			{
				hardRandomChance = nil,
				name = "homeless_lost",
				prettyName = "HIM",
				class = "terminator_nextbot_homeless",
				spawnType = "hunter",
				difficultyCost = { 57, 60 },
				countClass = "terminator_nextbot_homeless",
				maxCount = { 1 },
				preSpawnedFuncs = { deservesToExist },
				postSpawnedFuncs = { scornOverride, ANGRY, modelLost },
			},
			{
				hardRandomChance = nil,
				name = "supercop",
				prettyName = "The Supercop",
				class = "terminator_nextbot_supercop",
				spawnType = "hunter",
				difficultyCost = { 340, 430 },
				countClass = "terminator_nextbot_supercop",
				maxCount = { 1 },
				postSpawnedFuncs = { postSpawnedOvercharge }, --  biggest evil that evil has ever eviled
			},
		}
	}

table.insert(GLEE_SPAWNSETS, everythingEverywhereSpawnSet )