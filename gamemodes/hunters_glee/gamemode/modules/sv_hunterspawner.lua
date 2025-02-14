
local isnumber = isnumber
local isstring = isstring
local isfunction = isfunction
local GAMEMODE = GAMEMODE or GM

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end


local debuggingVar = CreateConVar( "huntersglee_debug_hunterspawner", 0 )
local function debugPrint( ... )
    if not debuggingVar:GetBool() then return end
    print( ... )

end

local speedVar = CreateConVar( "huntersglee_debug_hunterspawner_speedoverride", 1, { FCVAR_CHEAT }, "Increase the speed at which the hunter spawner thinks time is passing.", 0, 999 )

local overrideCountVar = CreateConVar( "huntersglee_spawneroverridecount", 0, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Overrides how many terminators will spawn, 0 for automatic count. Above 5 WILL lag.", 0, 32 )
local function aliveHuntersCount()
    local aliveTermsCount = 0
    local hunters = GAMEMODE.glee_Hunters
    for _, hunter in pairs( hunters ) do
        if IsValid( hunter ) and hunter:Health() > 0 then
            aliveTermsCount = aliveTermsCount + 1

        end
    end
    return aliveTermsCount

end

GAMEMODE.RegisteredSpawnSets = GAMEMODE.RegisteredSpawnSets or {}

local minute = 60

local setDefaults = {
    difficultyPerMin = 100 / 10, -- 100% diff at 10 mins
    waveInterval = { minute, minute * 1.6 },
    diffBumpWhenWaveKilled = { 10, 20 },
    startingBudget = 20,
    spawnCountPerDifficulty = { 0.08, 0.1 },
    startingSpawnCount = { 1.8, 2 },
    maxSpawnCount = 10,
    maxSpawnDist = { 6500, 8500 },
    roundEndSound = "53937_meutecee_trumpethit07.wav",
    roundStartSound = "", -- no sound for glee
    genericSpawnerRate = 1,
}

local spawnDefaults = {
    minCount = -1, -- makes it ignore these
    maxCount = -1, -- respects maxSpawnCount tho
}

local function asParsed( toParse, name, defaultsTbl )
    local default = defaultsTbl[name]
    if default then
        if not toParse then -- fallback,
            toParse = default

        elseif isstring( toParse ) and toParse == "default" then -- explicit default
            toParse = default

        end
    end

    if isnumber( toParse ) then return toParse end
    if isfunction( toParse ) then return toParse end

    if isstring( default ) and isstring( toParse ) then
        return toParse

    end

    if #toParse <= 1 and isnumber( toParse[1] ) then return toParse[1] end
    if #toParse <= 2 and isnumber( toParse[1] ) and isnumber( toParse[2] ) then return math.Rand( toParse[1], toParse[2] ) end

end

local function yapErr( spawnSet, yapStr )
    ErrorNoHaltWithStack( "GLEE: spawnSet " .. spawnSet.name .. " " .. yapStr )

end

function GM:IsValidSpawnSet( spawnSet )
    if isstring( spawnSet ) then
        local targetName = spawnSet
        local sets = self:GetSpawnSets()
        spawnSet = sets[targetName]
        if not spawnSet then ErrorNoHaltWithStack( targetName .. " is not a registered spawn set" ) return end

    end
    if not istable( spawnSet ) then ErrorNoHaltWithStack( "Spawnset is not a table" ) return end
    if not isstring( spawnSet.name ) then ErrorNoHaltWithStack( "Spawnset has invalid .name" ) return end
    if not isstring( spawnSet.prettyName ) then yapErr( spawnSet, "has invalid .prettyName" ) return end
    if not isstring( spawnSet.description ) then yapErr( spawnSet, "has invalid .description" ) return end

    for name, _ in pairs( setDefaults ) do
        if not asParsed( spawnSet[name], name, setDefaults ) then
            yapErr( spawnSet, "has invalid ." .. name )
            return

        end
    end

    local spawns = spawnSet.spawns
    if not istable( spawns ) then yapErr( spawnSet, "has invalid .spawns" ) return end
    for ind, spawn in ipairs( spawns ) do
        local name = spawn.name
        if not isstring( name ) then
            PrintTable( spawn )
            print( spawn.name )
            yapErr( spawnSet, "entry " .. ind .. " has invalid .name in .spawns" )
            return

        end
        if not isstring( spawn.prettyName ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .prettyname" ) return end
        if not isstring( spawn.class ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .class" ) return end
        if not isstring( spawn.countClass ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .countClass" ) return end

        if not asParsed( spawn.difficultyCost, "difficultyCost", spawnDefaults ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .difficultyCost" ) return end
        if not asParsed( spawn.minCount, "minCount", spawnDefaults ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .minCount" ) return end
        if not asParsed( spawn.maxCount, "maxCount", spawnDefaults ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .maxCount" ) return end

    end

    return true
end

local function parse( tbl, name, defaultsTbl, spawnSet )
    local toParse = tbl[name]
    local parsed = asParsed( toParse, name, defaultsTbl )

    if isfunction( parsed ) then
        -- it accepts functions!!!!!!
        --[[ eg,
            .maxCount = function( spawnSet )
                return spawnset.maxSpawnCount
            end,
        --]]
        local noErrors, returned = xpcall( toParse, errorCatchingMitt, spawnSet )
        if noErrors == false then
            yapErr( spawnSet, " ." .. name .. " function errored! " )
            return

        end

        returned = asParsed( returned, name, defaultsTbl ) -- parse the result too...
        if not returned then yapErr( spawnSet, " invalid return from ." .. name ) return end

        tbl[name] = returned

    elseif isnumber( parsed ) or isstring( parsed ) then
        tbl[name] = parsed

    end
end

-- set spawnset
function GM:SetSpawnSet( setName )
    local asRegistered = self.RegisteredSpawnSets[setName]
    if not asRegistered then ErrorNoHaltWithStack( "GLEE: Tried to enable invalid spawnset " .. setName ) return end

    local spawnSet = table.Copy( asRegistered )

    local setParsed = {}
    for name, _ in pairs( spawnSet ) do
        parse( spawnSet, name, setDefaults, spawnSet )
        setParsed[name] = true

    end
    for name, _ in pairs( setDefaults ) do -- get the nil defaults
        if setParsed[name] then continue end
        parse( spawnSet, name, setDefaults, spawnSet )

    end

    for _, currSpawn in ipairs( spawnSet.spawns ) do
        local spawnParsed = {}
        for name, _ in pairs( currSpawn ) do
            parse( currSpawn, name, spawnDefaults, spawnSet )
            spawnParsed[name] = true

        end
        for name, _ in pairs( spawnDefaults ) do -- get the nil defaults
            if spawnParsed[name] then continue end
            parse( currSpawn, name, spawnDefaults, spawnSet )

        end
    end

    spawnSet.dynamicTooCloseDist = spawnSet.maxSpawnDist * 0.5
    spawnSet.dynamicTooFarDist = spawnSet.maxSpawnDist

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = spawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )
    SetGlobalString( "GLEE_SpawnSetPrettyName", spawnSet.prettyName )

    hook.Run( "glee_post_set_spawnset", setName, spawnSet )
    print( "GLEE: Mode set to, " .. setName )

end

function GM:RegisterSpawnSet( spawnSet )
    if not self:IsValidSpawnSet( spawnSet ) then print( "GLEE: tried to register inavlid spawnset" ) return end

    local exists = self.RegisteredSpawnSets[spawnSet.name]
    if exists then print( "GLEE, overriding old " .. spawnSet.name .. " spawnSet" ) end

    self.RegisteredSpawnSets[spawnSet.name] = spawnSet

    return true

end

function GM:GetSpawnSets()
    return self.RegisteredSpawnSets

end

function GM:GetSpawnSet()
    return self.CurrSpawnSetName, self.CurrSpawnSet

end

function GM:GenSpawnAdjusted( var )
    local set = self.CurrSpawnSet
    if not set then return var end

    return var * set.genericSpawnerRate

end

function GM:GetPrettyNameOfSpawnSet( setName )
    local asRegistered = GAMEMODE.RegisteredSpawnSets[setName]
    if not asRegistered then return "" end
    return asRegistered.prettyName

end

local nextSpawnCheck = 0

GAMEMODE.deadWaveDiffBump = 0 -- dont reset this, so cheesable maps get harder and harder 

local function resetWave()
    GAMEMODE.nextSpawnWave = 0
    GAMEMODE.waveWasAlive = nil
    GAMEMODE.currentSpawnWave = nil
    GAMEMODE.currentSpawning = nil

end

resetWave()

hook.Add( "glee_sv_validgmthink_active", "glee_spawnhunters_datadriven", function( _, _, cur )
    if not GAMEMODE.HuntersGleeDoneTheGreedyPatch then return end
    if nextSpawnCheck > cur then return end
    nextSpawnCheck = cur + 0.2

    local _, spawnSet = GAMEMODE:GetSpawnSet()
    local aliveCount = aliveHuntersCount()
    if aliveCount <= 1 and GAMEMODE.waveWasAlive and aliveCount < GAMEMODE.waveWasAlive then
        GAMEMODE.waveWasAlive = nil
        GAMEMODE.nextSpawnWave = 0
        debugPrint( "bump", GAMEMODE.deadWaveDiffBump, spawnSet.diffBumpWhenWaveKilled )
        GAMEMODE.deadWaveDiffBump = GAMEMODE.deadWaveDiffBump + spawnSet.diffBumpWhenWaveKilled

    end

    if GAMEMODE.nextSpawnWave > cur or GAMEMODE.currentSpawnWave then return end

    local speedOverride = speedVar:GetFloat()

    local roundTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )
    roundTime = roundTime * speedOverride

    local minutes = roundTime / minute

    local diffPerMin = spawnSet.difficultyPerMin
    local difficulty = diffPerMin * minutes
    difficulty = difficulty + GAMEMODE.deadWaveDiffBump

    local countWanted
    local overrideCount = overrideCountVar:GetInt()
    if overrideCount > 0 then
        countWanted = overrideCount

    else
        countWanted = spawnSet.spawnCountPerDifficulty * difficulty
        countWanted = countWanted + spawnSet.startingSpawnCount
        countWanted = math.min( countWanted, spawnSet.maxSpawnCount )
        countWanted = math.floor( countWanted )

    end

    if aliveCount < countWanted then
        local budget = difficulty + spawnSet.startingBudget
        local classCounts = {}
        local pickedSpawns = {}
        local spawns = spawnSet.spawns

        while budget > 0 do
            local addedOne
            local freebie

            for _, currSpawn in SortedPairsByMemberValue( spawns, "difficultyCost", true ) do -- go from most to least cost
                if ( aliveCount + #pickedSpawns ) >= countWanted then break end

                local hardRandomChance = currSpawn.hardRandomChance
                if hardRandomChance and math.Rand( 0, 100 ) > hardRandomChance then
                    continue

                end

                -- for when you dont want this to spawn early
                -- default is 100% difficulty at 10 minutes
                local difficultyNeeded = currSpawn.difficultyNeeded
                if difficultyNeeded and difficulty < difficultyNeeded then
                    continue

                end
                -- for when you want it to stop spawning after some time
                local difficultyStopAfter = currSpawn.difficultyStopAfter
                if difficultyStopAfter and difficulty > difficultyStopAfter then
                    continue

                end

                local countClass = currSpawn.countClass or currSpawn.class
                local count = classCounts[countClass]
                if not count then
                    count = #ents.FindByClass( countClass ) -- cache it
                    debugPrint( count, countClass )
                    classCounts[countClass] = count

                end

                local good = currSpawn.difficultyCost <= budget
                if currSpawn.minCount > -1 and not good then -- minCount bypasses budget
                    good = count < currSpawn.minCount
                    freebie = true

                end
                if currSpawn.maxCount > -1 then
                    good = good and count < currSpawn.maxCount

                end
                if good then
                    addedOne = true
                    if not freebie then
                        budget = budget - currSpawn.difficultyCost

                    end
                    currSpawn.minutesWhenAdded = minutes
                    table.insert( pickedSpawns, currSpawn )
                    classCounts[countClass] = count + 1
                    debugPrint( "added", currSpawn.prettyName )
                    break

                end
            end
            if not addedOne then break end

        end
        if #pickedSpawns >= 1 then
            if not GAMEMODE.currentSpawnWave then
                GAMEMODE.currentSpawnWave = {}
                hook.Add( "glee_sv_validgmthink_active", "glee_spawnawave", function() GAMEMODE:SpawnWaveSpawnIn() end )

            end
            table.Add( GAMEMODE.currentSpawnWave, pickedSpawns )
            GAMEMODE.nextSpawnWave = cur + spawnSet.waveInterval / speedOverride

        else
            -- dont spam checks
            GAMEMODE.nextSpawnWave = cur + ( spawnSet.waveInterval / 20 ) / speedOverride

        end
    else
        -- dont spam checks
        GAMEMODE.nextSpawnWave = cur + ( spawnSet.waveInterval / 20 ) / speedOverride

    end
end )

GAMEMODE.currentSpawning = nil

function GM:SpawnWaveSpawnIn()
    local currSpawn = self.currentSpawning
    if not currSpawn then
        local wave = self.currentSpawnWave
        if not wave or #wave <= 0 then
            hook.Remove( "glee_sv_validgmthink_active", "glee_spawnawave" ) -- wave is all done
            self.currentSpawnWave = nil
            return

        else
            currSpawn = table.remove( wave, 1 )
            self.currentSpawning = currSpawn

        end
    end

    if currSpawn.spawnType == "hunter" then
        debugPrint( "spawning", currSpawn.name, currSpawn.prettyName )
        local hunter = self:SpawnHunter( currSpawn.class, currSpawn )
        if IsValid( hunter ) then
            if currSpawn.postSpawnedFuncs then
                for _, func in ipairs( currSpawn.postSpawnedFuncs ) do
                    ProtectedCall( function( _currSpawn, _hunter ) func( _currSpawn, _hunter ) end, currSpawn, hunter )

                end
            end
            hunter.glee_PrettyName = currSpawn.prettyName
            self.currentSpawning = nil -- spawn next one pls
            self.waveWasAlive = aliveHuntersCount()

        end
    end

    -- TODO, add type that passes responsibility to generic spawner 

end

hook.Add( "PostCleanupMap", "glee_resethunterspawnerstats", function()
    resetWave()

end )

local minRadius = 500 -- hardcoded num, if you spawn closer than this, it feels unfair
local defaultStaleRatio = 0.75

local function manageIfStale( hunter ) -- dont let fodder npcs do whatever they want, remove them and march the spawn distances smaller if they're being boring
    hunter.glee_FodderNoEnemyCount = math.random( -30, -15 )
    hunter.glee_FodderNoEnemyRatio = defaultStaleRatio

    hook.Add( "glee_hunter_nearbyaply", hunter, function( me, nearestHunter ) -- so they dont delete when they're nearby a ply, eg, they bought chameleon 
        if me ~= nearestHunter then return end
        local new = nearestHunter.glee_FodderNoEnemyCount + -1
        new = math.Clamp( new, 0, math.huge )

        nearestHunter.glee_FodderNoEnemyCount = new

    end )

    local timerName = "glee_fodderhunter_removestale_" .. hunter:GetCreationID()
    timer.Create( timerName, math.Rand( 0.5, 2 ), 0, function()
        if not IsValid( hunter ) then timer.Remove( timerName ) return end
        if hunter.terminator_OverCharged then timer.Remove( timerName ) return end
        local maxHp = hunter:GetMaxHealth()
        local enemy = hunter:GetEnemy()
        local oldCount = hunter.glee_FodderNoEnemyCount

        if IsValid( enemy ) and enemy.isTerminatorHunterChummy ~= hunter.isTerminatorHunterChummy then
            hunter.glee_FodderNoEnemyCount = math.min( 0, oldCount + -1 )
            return

        end

        if oldCount >= maxHp * hunter.glee_FodderNoEnemyRatio then -- booring enem
            local _, spawnSet = GAMEMODE:GetSpawnSet()
            if spawnSet then -- make the spawner spawn npcs closer if fodder hunters aren't finding enemies
                local tooFarDist = spawnSet.dynamicTooFarDist
                local bite = -maxHp

                local _, nearestDistSqr = GAMEMODE:nearestAlivePlayer( hunter:GetPos() )
                local nearestDist = math.sqrt( nearestDistSqr )
                if nearestDist > tooFarDist * 5 then
                    bite = bite * 4

                elseif nearestDist > tooFarDist * 2.5 then
                    bite = bite * 2

                end
                GAMEMODE:AdjustDynamicTooCloseCutoff( bite, spawnSet )
                GAMEMODE:AdjustDynamicTooFarCutoff( bite * 1.5, spawnSet )

                if nearestDist < tooFarDist * 0.75 and hunter.glee_FodderNoEnemyRatio == defaultStaleRatio then -- bot is close, give it a second chance, but still bite the cutoffs
                    hunter.glee_FodderNoEnemyRatio = 2
                    return

                end
            end
            SafeRemoveEntity( hunter )
            return

        end
        hunter.glee_FodderNoEnemyCount = oldCount + 1

    end )
end

function GM:SpawnHunter( class, currSpawn )
    local spawnPos, valid = self:getValidHunterPos()
    if not valid then return end

    local hunter = ents.Create( class )
    if not IsValid( hunter ) then return end

    if currSpawn and currSpawn.preSpawnedFuncs then
        for _, func in ipairs( currSpawn.preSpawnedFuncs ) do
            ProtectedCall( function( _currSpawn, _hunter ) func( _currSpawn, _hunter ) end, currSpawn, hunter )

        end
    end

    hunter:SetPos( spawnPos )
    hunter:Spawn()
    table.insert( self.glee_Hunters, hunter )

    print( hunter ) -- i like this print, you cannot make me remove it

    if hunter.IsFodder or not hunter.TerminatorNextBot then -- prune fodder hunters if they're being boring
        manageIfStale( hunter )
    end
    return hunter

end

local fails = 0

-- OVERCOMPLICATED!!!!!!
function GM:AdjustDynamicTooCloseCutoff( adjust, spawnSet )
    if not spawnSet then
        _, spawnSet = self:GetSpawnSet()

    end
    local new = spawnSet.dynamicTooCloseDist + adjust
    local min = minRadius
    local max = spawnSet.maxSpawnDist
    spawnSet.dynamicTooCloseDist = math.Clamp( new, min, max )

    if debuggingVar:GetBool() then
        print( "tooCLOSE_adjust", adjust, "\nnow", new )

    end
end

function GM:AdjustDynamicTooFarCutoff( adjust, spawnSet )
    if not spawnSet then
        _, spawnSet = self:GetSpawnSet()

    end
    local new = spawnSet.dynamicTooFarDist + adjust
    local min = spawnSet.dynamicTooCloseDist + 1000
    local max = math.max( spawnSet.maxSpawnDist, spawnSet.dynamicTooCloseDist + 2000 )
    spawnSet.dynamicTooFarDist = math.Clamp( new, min, max )

    if debuggingVar:GetBool() then
        print( "tooFAR_adjust", adjust, "\nnow", new )

    end
end

-- spawn a hunter as far away as possible from every player by inching a distance check around
-- made to be really random/overcomplicated so you never really know where they'll spawn from
-- RAAAGH WHY DID I MAKE THIS SO OVERCOMPLCATED
function GM:getValidHunterPos()
    local _, spawnSet = self:GetSpawnSet()
    local dynamicTooCloseFailCounts = spawnSet.dynamicTooCloseFailCounts or -2
    local dynamicTooCloseDist = spawnSet.dynamicTooCloseDist
    local dynamicTooFarDist = spawnSet.dynamicTooFarDist

    if not self.biggestNavmeshGroups then return nil, nil end

    local _, theMainGroup = self:GetAreaInOccupiedBigGroupOrRandomBigGroup()

    local playerShootPositions = self:allPlayerShootPositions()

    -- multiple attempts, will march distance down if we can't find a good option, marches up if there is a good spot
    -- makes it super random yet grounded
    for _ = 0, 10 do
        local spawnPos = nil
        local randomArea = table.Random( theMainGroup )
        if not randomArea or not IsValid( randomArea ) then continue end
        spawnPos = randomArea:GetCenter()

        if not isvector( spawnPos ) then continue end
        spawnPos = spawnPos + Vector( 0,0,20 )

        if randomArea:IsUnderwater() then
            -- make it a bit closer
            GAMEMODE:AdjustDynamicTooCloseCutoff( -150, spawnSet ) -- make it get closer
            GAMEMODE:AdjustDynamicTooFarCutoff( -50, spawnSet ) -- closer here too
            continue

        end

        local checkPos = spawnPos + Vector( 0, 0, 50 )
        local visibleToAPly
        local tooClose
        local tooFar

        for _, pos in ipairs( playerShootPositions ) do
            local visible, visResult
            local hitCloseBy
            if not visibleToAPly then
                visible, visResult = terminator_Extras.PosCanSee( pos, checkPos )
                hitCloseBy = visResult.HitPos:DistToSqr( checkPos ) < 350^2

            end
            if visible or hitCloseBy then
                visibleToAPly = true

            end

            local distSqr = pos:DistToSqr( checkPos )
            if distSqr < dynamicTooCloseDist^2 then -- dist check!
                tooClose = true
                break -- only break here so the justSpawnSomething doesnt spawn stuff next to people!!!!!

            elseif distSqr > dynamicTooFarDist^2 then
                tooFar = true

            end
        end

        local goodConventional = not visibleToAPly and not tooClose and not tooFar
        local justSpawnSomething = fails > 2000 and not tooClose

        if goodConventional or justSpawnSomething then
            GAMEMODE:AdjustDynamicTooCloseCutoff( 50, spawnSet ) -- make it get further
            GAMEMODE:AdjustDynamicTooFarCutoff( 100, spawnSet ) -- let it get further next time

            -- good spawnpoint, spawn here
            fails = 0
            spawnSet.dynamicTooCloseFailCounts = -2
            return spawnPos, true

        end

        fails = fails + 1

        if tooClose then
            spawnSet.dynamicTooCloseFailCounts = dynamicTooCloseFailCounts + 1
            GAMEMODE:AdjustDynamicTooCloseCutoff( -( dynamicTooCloseFailCounts * 5 ), spawnSet ) -- let it get closer next time

        end
    end
    return nil, nil

end


local defaultSpawnSetName = "hunters_glee"
local function postSetSpawnset( new )
    if not GAMEMODE:IsValidSpawnSet( new ) then
        if GAMEMODE:IsValidSpawnSet( defaultSpawnSetName ) then
            RunConsoleCommand( "huntersglee_spawnset", defaultSpawnSetName )
            print( "Valid spawnsets are..." )
            for _, set in ipairs( GAMEMODE:GetSpawnSets() ) do
                print( set.name )

            end
        end
    else -- all good!
        GAMEMODE:SetSpawnSet( new )

    end
end


local spawnSetVar = CreateConVar( "huntersglee_spawnset", defaultSpawnSetName, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "What spawnset the gamemode should use." )
cvars.AddChangeCallback( "huntersglee_spawnset", function( _, _, new )
    if not GAMEMODE.GobbledSpawnsets then -- wait until spawnsets are valid
        hook.Add( "glee_post_spawnsetgobble", "glee_validatecvar_delayed", function()
            postSetSpawnset( new )
            hook.Remove( "glee_post_spawnsetgobble", "glee_validatecvar_delayed" )

        end )
    else
        postSetSpawnset( new )

    end

end, "glee_notifyinvalidspawnsets" )


function GM:SpawnSetThink()
    GLEE_SPAWNSETS = {}

    local spawnsetFiles = file.Find( "glee_spawnsets/*.lua", "LUA" )
    for _, name in ipairs( spawnsetFiles ) do
        ProtectedCall( function( nameProtected ) include( "glee_spawnsets/" .. nameProtected ) end, name )

    end
    local count = 0
    for _, spawnSet in pairs( GLEE_SPAWNSETS ) do
        if self:RegisterSpawnSet( spawnSet ) then
            count = count + 1

        end
    end
    print( "GLEE: Gobbled " .. count .. " spawnsets..." )
    GLEE_SPAWNSETS = {}

    GAMEMODE.GobbledSpawnsets = true
    hook.Run( "glee_post_spawnsetgobble" )

    local spawnSetPicked = spawnSetVar:GetString()
    if not self:IsValidSpawnSet( spawnSetPicked ) then
        print( "GLEE: INVALID SPAWNSET " .. spawnSetPicked )
        spawnSetPicked = defaultSpawnSetName
        RunConsoleCommand( "huntersglee_spawnset", spawnSetPicked )

    end

    self:SetSpawnSet( spawnSetPicked )

end

hook.Add( "huntersglee_round_firstsetup", "glee_spawnset_think", function() GAMEMODE:SpawnSetThink() end )

-- let people joining the server have the default glee experience
hook.Add( "huntersglee_emptyserver", "glee_reset_spawnset", function( wasEmpty )
    if wasEmpty then return end -- only run this if there were people online, and are no longer people online
    local name = GAMEMODE:GetSpawnSet()
    if name == defaultSpawnSetName then return end
    RunConsoleCommand( "huntersglee_spawnset", defaultSpawnSetName )
    print( "GLEE: reset spawnset on empty server" )

end )

-----------------------------------------
-- TEMPLATE IN
-- lua/glee_spawnsets/hunters_glee.lua
-----------------------------------------