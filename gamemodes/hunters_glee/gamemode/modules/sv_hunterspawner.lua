
local isnumber = isnumber
local isstring = isstring
local bit_band = bit.band
local isfunction = isfunction
local util_PointContents = util.PointContents
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

local overrideCountVar = CreateConVar( "huntersglee_spawneroverridecount", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Overrides how many terminators will spawn, 0 for automatic count. Above 5 WILL lag.", 0, 32 )
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

local maxSpawnedVar = CreateConVar( "huntersglee_spawnermax", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Puts an upper limit on max hunters that can spawn. 0 to disable.", 0, 10000 )

GAMEMODE.RegisteredSpawnSets = GAMEMODE.RegisteredSpawnSets or {}

local minute = 60

local setDefaults = {
    difficultyPerMin = { 100 / 10, 150 / 10 }, -- 100-150% diff at 10 mins
    waveInterval = { minute, minute * 1.6 },
    diffBumpWhenWaveKilled = { 10, 20 },
    startingBudget = 20,
    spawnCountPerDifficulty = { 0.08, 0.1 },
    startingSpawnCount = { 1.8, 2 },
    maxSpawnCount = 10,
    maxSpawnDist = { 4500, 6500 },
    minSpawnDist = 500, -- if you spawn closer than this, it feels unfair
    roundEndSound = "53937_meutecee_trumpethit07.wav",
    roundStartSound = "", -- no sound for glee
    genericSpawnerRate = 1,
}

local spawnDefaults = {
    minCount = -1, -- makes it ignore these
    maxCount = -1, -- respects maxSpawnCount tho
}

local spawnIgnored = { -- these don't exist to be parsed
    preSpawnedFunc = true,
    postSpawnedFunc = true,
}

local hardMinSpawnDist = 500 -- absolute minimum spawn distance
local tooFarWhoCares = 5000^2 -- dont check visibility farther than this, leads to more spawns on big maps

local function asParsed( toParse, name, defaultsTbl )
    local finalMul = 1
    local default = defaultsTbl[name]
    if default then
        if not toParse then
            -- soft default
            toParse = default

        elseif isstring( toParse ) then
            -- explicit default
            if toParse == "default" then
                toParse = default

            -- dynamically mul the default!
            -- eg default*1.5, default*0.25
            -- much better than setting something independant from the default
            -- because the defaults will change eventually....
            elseif string.match( toParse, "^default%*[%d%.]+$" ) then
                local multiplier = tonumber( string.match( toParse, "[%d%.]+$" ) )
                if multiplier then
                    toParse = default
                    finalMul = multiplier

                end
            end
        end

    elseif not toParse then
        return nil -- no default, and nothing to parse

    end

    if isnumber( toParse ) then return toParse * finalMul end
    if isfunction( toParse ) then return toParse end

    if isstring( default ) and isstring( toParse ) then
        return toParse

    end

    if #toParse <= 1 and isnumber( toParse[1] ) then return toParse[1] * finalMul end
    if #toParse <= 2 and isnumber( toParse[1] ) and isnumber( toParse[2] ) then return math.Rand( toParse[1], toParse[2] ) * finalMul end

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

function GM:ParsedSpawnSet( asRegistered )
    local spawnSet = table.Copy( asRegistered )

    local setParsed = {}
    for name, _ in pairs( spawnSet ) do -- parse all existing spawnset variables
        parse( spawnSet, name, setDefaults, spawnSet )
        setParsed[name] = true

    end
    for name, _ in pairs( setDefaults ) do -- setup the nil defaults that weren't set
        if setParsed[name] then continue end
        parse( spawnSet, name, setDefaults, spawnSet )

    end

    for _, currSpawn in ipairs( spawnSet.spawns ) do
        local spawnParsed = {}
        for name, _ in pairs( currSpawn ) do -- parse all existing spawnset variables
            parse( currSpawn, name, spawnDefaults, spawnSet )
            spawnParsed[name] = true

        end
        for name, _ in pairs( spawnDefaults ) do -- get the nil defaults
            if spawnParsed[name] then continue end
            if spawnIgnored[name] then continue end
            parse( currSpawn, name, spawnDefaults, spawnSet )

        end
    end

    spawnSet.dynamicTooCloseDist = spawnSet.maxSpawnDist * 0.5
    spawnSet.dynamicTooFarDist = spawnSet.maxSpawnDist
    spawnSet.softMinRadius = spawnSet.minSpawnDist + 500

    return spawnSet

end

-- set spawnset
function GM:SetSpawnSet( setName )

    local oldSetName = self.CurrSpawnSetName
    -- local oldSet = self.CurrSpawnSet

    local asRegistered = self.RegisteredSpawnSets[setName]
    if not asRegistered then ErrorNoHaltWithStack( "GLEE: Tried to enable invalid spawnset " .. setName ) return end

    local spawnSet = self:ParsedSpawnSet( asRegistered )

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = spawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )
    SetGlobalString( "GLEE_SpawnSetPrettyName", spawnSet.prettyName )

    if oldSetName ~= setName then
        hook.Run( "glee_post_set_spawnset", setName, spawnSet )
        print( "GLEE: Mode set to, " .. setName )

    else
        hook.Run( "glee_post_refresh_spawnset", setName, spawnSet )

    end
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

local nextHunterSpawn = 0

hook.Add( "glee_sv_validgmthink_active", "glee_spawnhunters_datadriven", function( _, _, cur )
    if not GAMEMODE.HuntersGleeDoneTheGreedyPatch then return end
    if nextSpawnCheck > cur then return end
    nextSpawnCheck = cur + 0.2

    if terminator_Extras.empty then -- homeless
        if GAMEMODE:GetSpawnSet() == "explorers_glee" then return end

        GAMEMODE:SetSpawnSet( "explorers_glee" )
        return

    end

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
        local plyCount = player.GetCount()
        local plyCountBoost = math.min( plyCount, 8 )
        countWanted = spawnSet.spawnCountPerDifficulty * difficulty
        countWanted = countWanted + spawnSet.startingSpawnCount
        countWanted = math.max( countWanted, plyCountBoost ) -- full server? lots of bots at the start
        countWanted = math.min( countWanted, spawnSet.maxSpawnCount ) -- but never above the maxSpawnCount
        countWanted = math.floor( countWanted )

    end

    local maxAllowed = maxSpawnedVar:GetInt()
    if maxAllowed > 0 then
        countWanted = math.min( countWanted, maxAllowed )

    end

    if aliveCount < countWanted then
        local budget = difficulty + spawnSet.startingBudget
        local classCounts = {}
        local pickedSpawns = {}
        local spawns = spawnSet.spawns

        while budget > 0 do
            local addedOne
            local freebie
            debugPrint( "picking with " .. budget .. " remaining" )

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

    local cur = CurTime()
    if nextHunterSpawn > cur then return end

    if currSpawn.spawnType == "hunter" then
        local hunter = self:SpawnHunter( currSpawn.class, currSpawn )
        if IsValid( hunter ) then
            debugPrint( "spawned", hunter, currSpawn.name, currSpawn.prettyName )
            if currSpawn.postSpawnedFuncs then
                for _, func in ipairs( currSpawn.postSpawnedFuncs ) do
                    ProtectedCall( function( _currSpawn, _hunter ) func( _currSpawn, _hunter ) end, currSpawn, hunter )

                end
            end
            hunter.glee_PrettyName = currSpawn.prettyName
            self.currentSpawning = nil -- spawn next one pls
            self.waveWasAlive = aliveHuntersCount()

            -- ratelimit spawns
            -- slower spawns if lagging
            local lagFelt = physenv.GetLastSimulationTime() * 5000
            lagFelt = math.max( lagFelt, 1 )
            if lagFelt > 1 then
                lagFelt = lagFelt^2
                lagFelt = math.min( lagFelt, 10 )

            else
                lagFelt = math.Rand( 0, 0.5 )

            end
            nextHunterSpawn = cur + lagFelt

        else
            local _, spawnSet = self:GetSpawnSet()
            debugPrint( "didnt spawn", currSpawn.name, currSpawn.prettyName, spawnSet.dynamicTooCloseDist, spawnSet.dynamicTooFarDist )

        end
    end

    -- TODO, add type that passes responsibility to generic spawner 

end

hook.Add( "PostCleanupMap", "glee_resethunterspawnerstats", function()
    resetWave()

end )

-- how many seconds of the hunter's max health it needs to be without an enemy before it gets removed
-- 0.5 ratio means, 100 hp hunter needs to be without an enemy for 50 seconds before it gets removed
local staleRatio = 0.5

local krangledStaleRatioMin = 100 -- dont remove krangled npcs below this hp too fast! 

-- make the spawner spawn npcs closer if bots aren't finding enemies
local function manageIfStale( hunter ) -- dont let fodder npcs do whatever they want, remove them and march the spawn distances smaller if they're being boring
    local maxHp = hunter:GetMaxHealth()
    local noEnemyToRemove = maxHp * staleRatio -- enemies with more hp get more leeway
    local startingCount = math.random( -30, -15 )
    local krangled = true

    if hunter.GetEnemy then
        krangled = false

    elseif hunter.GetTarget then
        krangled = false

    end

    if krangled then
        startingCount = startingCount * 2
        noEnemyToRemove = math.max( noEnemyToRemove, krangledStaleRatioMin * staleRatio ) -- floor this for weird enemies

    end
    local goodHunter = hunter.isTerminatorHunterBased and not hunter.IsFodder
    if goodHunter then -- good enemy, give it more leeway
        noEnemyToRemove = noEnemyToRemove * 2

    end

    hunter.glee_StaleNoEnemyCount = startingCount
    hunter.glee_NoEnemyToRemove = noEnemyToRemove

    hook.Add( "glee_hunter_nearbyaply", hunter, function( me, nearestHunter ) -- so they dont delete when they're nearby a ply, eg, they bought chameleon 
        if me ~= nearestHunter then return end
        local new = nearestHunter.glee_StaleNoEnemyCount + -1
        new = math.Clamp( new, 0, math.huge )

        nearestHunter.glee_StaleNoEnemyCount = new

    end )

    local timerAdjusted
    local timerName = "glee_fodderhunter_removestale_" .. hunter:GetCreationID()
    timer.Create( timerName, math.Rand( 0.75, 1.25 ), 0, function()
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        if not IsValid( hunter ) then timer.Remove( timerName ) return end

        if not timerAdjusted and ( ( hunter.glee_FodderKills or 0 ) >= 1 or hunter.glee_InterestingHunter ) then -- it killed a player, it's doing its job!
            timerAdjusted = true
            local newInterval = math.Rand( 1.75, 2.25 )
            if not hunter.IsFodder then
                newInterval = newInterval * 2 -- good hunter, give it more leeway

            end
            timer.Adjust( timerName, newInterval, 0 ) -- dont count this guy up fast at all
            hunter.glee_StaleNoEnemyCount = startingCount -- and reset the count

        end

        local enemy
        if hunter.GetEnemy then
            enemy = hunter:GetEnemy()

        elseif hunter.GetTarget then
            enemy = hunter:GetTarget()

        end
        local oldCount = hunter.glee_StaleNoEnemyCount

        local seesEnemy = ( hunter.glee_SeeEnemy or 0 ) > CurTime()
        local goodEnemy = IsValid( enemy ) and enemy.isTerminatorHunterChummy ~= hunter.isTerminatorHunterChummy

        if seesEnemy or goodEnemy then
            hunter.glee_StaleNoEnemyCount = math.min( 0, oldCount + -1 ) -- good enemy, snap count down and march it into the negatives
            return

        end

        local itsRemovalTime = oldCount >= hunter.glee_NoEnemyToRemove

        if itsRemovalTime then -- booring enem
            local _, spawnSet = GAMEMODE:GetSpawnSet()
            if spawnSet then -- so boring, lets get ready to remove this bot, and maybe forgive them if we're wrong
                local tooFarDist = spawnSet.dynamicTooFarDist
                local noEnemyToRemoveI = hunter.glee_NoEnemyToRemove
                local spawnDistBite = noEnemyToRemoveI * 3

                debugPrint( "stale" )

                local _, nearestDistSqr = GAMEMODE:nearestAlivePlayer( hunter:GetPos() )
                local nearestDist = math.sqrt( nearestDistSqr )
                if nearestDist > tooFarDist * 5 then -- way too far
                    spawnDistBite = noEnemyToRemoveI * 8
                    debugPrint( "way too far" )

                elseif nearestDist > tooFarDist * 2.5 then -- too far
                    spawnDistBite = noEnemyToRemoveI * 6
                    debugPrint( "too far" )

                end
                GAMEMODE:AdjustDynamicTooCloseCutoff( spawnDistBite, spawnSet )
                GAMEMODE:AdjustDynamicTooFarCutoff( spawnDistBite * 1.5, spawnSet )

                if nearestDist < tooFarDist * 0.5 and not hunter.glee_FodderWasNearPlayerAtLeast then -- bot is close, give it a second chance, but still bite the cutoffs above
                    debugPrint( "FORGIVE STALE", hunter )
                    hunter.glee_FodderWasNearPlayerAtLeast = true
                    hunter.glee_NoEnemyToRemove = hunter.glee_NoEnemyToRemove * 2 -- still remove eventually
                    return

                end
            end
            SafeRemoveEntity( hunter )
            debugPrint( "REMOVE STALE", hunter )
            return

        end

        hunter.glee_StaleNoEnemyCount = oldCount + 1 -- boring

    end )
end

-- track kills from hunters, so we can not despawn ones getting the job done.
hook.Add( "PlayerDeath", "glee_fodderenemy_catchkrangled", function( _, inflic, attacker )
    local oldCount
    local killer

    if IsValid( inflic ) then
        oldCount = inflic.glee_StaleNoEnemyCount
        killer = inflic

    end
    if not oldCount and IsValid( attacker ) then
        oldCount = attacker.glee_StaleNoEnemyCount
        killer = attacker

    end

    if not oldCount then return end

    killer.glee_FodderKills = ( killer.glee_FodderKills or 0 ) + 1
    killer.glee_StaleNoEnemyCount = math.min( -30, oldCount + -30 )

end )


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
    hunter:SetNW2Bool( "glee_IsHunter", true )

    print( hunter ) -- i like this print, you cannot make me remove it
    if debuggingVar:GetBool() then
        local nearestPly = self:nearestAlivePlayer( spawnPos )
        debugoverlay.Line( spawnPos, nearestPly:GetShootPos() + nearestPly:GetAimVector() * 50, 10, color_white, true )

    end

    manageIfStale( hunter )

    return hunter

end

local fails = 0

-- OVERCOMPLICATED!!!!!!
function GM:AdjustDynamicTooCloseCutoff( adjust, spawnSet )
    if not spawnSet then
        _, spawnSet = self:GetSpawnSet()

    end
    local old = spawnSet.dynamicTooCloseDist
    local new = old + adjust
    if new < old and new < spawnSet.softMinRadius then -- slow down when we're below the soft radius
        new = old + ( adjust / 4 )

    end

    local min
    local max = spawnSet.maxSpawnDist

    local minSpawnDist = spawnSet.minSpawnDist
    if minSpawnDist <= hardMinSpawnDist then -- this will work fine on tiny maps
        min = minSpawnDist

    else -- wont work fine, just slow it down once when below minSpawnDist, otherwise bots wont spawn on tiny maps
        if new < old and new < minSpawnDist then
            new = old + ( adjust / 25 )

        end
        min = hardMinSpawnDist -- maps below this size are not supported
    end

    spawnSet.dynamicTooCloseDist = math.Clamp( new, min, max )

end

function GM:AdjustDynamicTooFarCutoff( adjust, spawnSet )
    if not spawnSet then
        _, spawnSet = self:GetSpawnSet()

    end
    local old = spawnSet.dynamicTooFarDist + adjust
    local new = old + adjust
    if new < old and new < spawnSet.softMinRadius then -- slow down when we're below the soft radius
        new = old + ( adjust / 4 )

    end
    local min = spawnSet.dynamicTooCloseDist + 1000
    local max = math.max( spawnSet.maxSpawnDist, spawnSet.dynamicTooCloseDist + 2000 )
    spawnSet.dynamicTooFarDist = math.Clamp( new, min, max )

end

local up20 = Vector( 0, 0, 20 )
local up50 = Vector( 0, 0, 50 )
local tries = 10
local shallowWaterOffset = Vector( 0, 0, 150 )

-- spawn a hunter as far away as possible from every player by inching a distance check around
-- made to be really random/overcomplicated so you never really know where they'll spawn from
-- RAAAGH WHY DID I MAKE THIS SO OVERCOMPLCATED
function GM:getValidHunterPos()
    local _, spawnSet = self:GetSpawnSet()
    local dynamicTooCloseFailCounts = spawnSet.dynamicTooCloseFailCounts or -2
    local dynamicTooCloseDist = spawnSet.dynamicTooCloseDist
    local dynamicTooFarDist = spawnSet.dynamicTooFarDist

    if not self.biggestNavmeshGroups then return nil, nil end

    local areas
    if fails == 15 or ( fails > 15 and math.random( 0, 100 ) < 50 ) then -- too many fails? map is probably too big, just get areas near a player!
        if fails == 15 then
            debugPrint( "FINDING IN BOX" )

        end
        local alivePlayer = self:anAlivePlayer()
        if IsValid( alivePlayer ) then
            local height = dynamicTooFarDist / 8
            if fails > 250 then
                height = dynamicTooFarDist / 4

            end
            local maxs = Vector( dynamicTooFarDist, dynamicTooFarDist, height )
            local pos = alivePlayer:GetPos()
            local pos1 = pos + maxs
            local pos2 = pos - maxs
            areas = navmesh.FindInBox( pos1, pos2 )
            if #areas > 5000 then
                local bite = -( #areas / 100 )
                GAMEMODE:AdjustDynamicTooCloseCutoff( bite, spawnSet ) -- prob laggy, shrink it!
                GAMEMODE:AdjustDynamicTooFarCutoff( bite * 0.75, spawnSet )

            end
        end
    end
    if not areas or #areas <= 0 then
        _, areas = self:GetAreaInOccupiedBigGroupOrRandomBigGroup()

    end

    local playerShootPositions = self:allAlivePlayerShootPositions()

    -- multiple attempts, will march distance down if we can't find a good option, marches up if there is a good spot
    -- makes it super random yet grounded
    local cost = 0
    while cost < tries do
        cost = cost + 0.1
        local randomArea
        if cost > 5 and spawnSet.lastGoodSpawnArea then -- if we have a good spawn area, use it NOW!
            randomArea = spawnSet.lastGoodSpawnArea
            spawnSet.lastGoodSpawnArea = nil

        else
            randomArea = areas[math.random( 1, #areas )] -- pick a random area

        end
        if not randomArea or not IsValid( randomArea ) then continue end -- outdated

        local spawnPos = randomArea:GetRandomPoint()
        spawnPos = spawnPos + up20

        if randomArea:IsUnderwater() then -- underwater spawning is lame
            cost = cost + 0.1
            local contentsAbove = util_PointContents( spawnPos + shallowWaterOffset )
            local butItsShallow = bit_band( contentsAbove, CONTENTS_WATER ) == 0
            if butItsShallow then -- but the water's so shallow....
                GAMEMODE:AdjustDynamicTooCloseCutoff( -25, spawnSet )
                GAMEMODE:AdjustDynamicTooFarCutoff( -10, spawnSet )
                debugPrint( "shallow underwater bite" )

            else
                -- make it a bit closer
                GAMEMODE:AdjustDynamicTooCloseCutoff( -75, spawnSet ) -- make it get closer
                GAMEMODE:AdjustDynamicTooFarCutoff( -25, spawnSet ) -- closer here too
                debugPrint( "underwater bite" )

            end
            continue

        end

        local checkPos = spawnPos + up50
        local nearestDist = math.huge
        local nearestPlyPos
        local visibleToAPly
        local tooClose
        local tooFar

        for _, pos in ipairs( playerShootPositions ) do
            local visible, visResult
            local hitCloseBy

            local distSqr = pos:DistToSqr( checkPos )

            -- dont check too far away, means nothing spawns on big maps
            -- and dont check if we already know a player can see it
            if distSqr < tooFarWhoCares and not visibleToAPly then
                visible, visResult = terminator_Extras.PosCanSee( pos, checkPos )
                hitCloseBy = visResult.HitPos:DistToSqr( checkPos ) < 350^2

            end
            if visible or hitCloseBy then
                visibleToAPly = true

            end

            if distSqr < nearestDist then
                nearestDist = distSqr
                nearestPlyPos = pos

            end

            if distSqr < dynamicTooCloseDist^2 then -- dist check!
                tooClose = true
                break -- only break here so the justSpawnSomething doesnt spawn stuff next to people!!!!!

            elseif distSqr > dynamicTooFarDist^2 then
                tooFar = true

            end
        end

        if not visibleToAPly and randomArea:IsPartiallyVisible( nearestPlyPos ) then -- double check, make sure the area is completely obscured
            visibleToAPly = true

        end

        cost = cost + 1

        local goodConventional = not visibleToAPly and not tooClose and not tooFar -- great spot to spawn!
        local justSpawnSomething = fails > 200 and not tooClose -- fallback, map has no great spots to spawn

        if goodConventional or justSpawnSomething then
            nearestDist = math.sqrt( nearestDist )

            GAMEMODE:AdjustDynamicTooCloseCutoff( 50, spawnSet ) -- make it get further
            GAMEMODE:AdjustDynamicTooFarCutoff( 100, spawnSet )
            debugPrint( "good spawn bump" )

            -- good spawnpoint, spawn here
            fails = 0
            spawnSet.dynamicTooCloseFailCounts = -2
            if justSpawnSomething then
                GAMEMODE.deadWaveDiffBump = GAMEMODE.deadWaveDiffBump + spawnSet.diffBumpWhenWaveKilled / 4 -- blast difficulty up

            end

            -- found a good spawn area, save it if we get stuck on the next spawn
            -- also leads to hordes spawning in one spot
            if math.random( 0, 100 ) <= 10 then -- chance to march goodspawnarea further away from nearest ply, so the spawns stack up less
                local potentials = randomArea:GetAdjacentAreas()
                table.Shuffle( potentials )
                for _, adjArea in ipairs( potentials ) do
                    if adjArea:GetSizeX() <= 25 or adjArea:GetSizeY() <= 25 then continue end -- too small
                    local areaCenter = adjArea:GetCenter()
                    if areaCenter:Distance( nearestPlyPos ) < nearestDist then continue end
                    if adjArea:IsPartiallyVisible( nearestPlyPos ) then continue end -- dont regress
                    spawnSet.lastGoodSpawnArea = adjArea
                    break

                end
            end
            if not IsValid( spawnSet.lastGoodSpawnArea ) then
                spawnSet.lastGoodSpawnArea = randomArea

            end

            return spawnPos, true

        end

        fails = fails + 1

        if tooClose then
            spawnSet.dynamicTooCloseFailCounts = dynamicTooCloseFailCounts + 1
            GAMEMODE:AdjustDynamicTooCloseCutoff( -( dynamicTooCloseFailCounts * 5 ), spawnSet ) -- let it get closer next time
            debugPrint( "too close bite" )

        end
    end

    -- didnt find a spot in the x tries, fatten the spawn donut a bit
    local bite = fails / tries
    GAMEMODE:AdjustDynamicTooCloseCutoff( -bite, spawnSet )
    GAMEMODE:AdjustDynamicTooFarCutoff( bite * 2, spawnSet )
    debugPrint( "no spawn bite", bite )

    return nil, nil

end


local defaultSpawnSetName = "hunters_glee"
local function postSetSpawnset( new ) -- validate the spawnset cvar
    if not GAMEMODE:IsValidSpawnSet( new ) then
        if GAMEMODE:IsValidSpawnSet( defaultSpawnSetName ) then
            RunConsoleCommand( "huntersglee_spawnset", defaultSpawnSetName )
            print( "Valid spawnsets are..." )
            for _, set in SortedPairsByMemberValue( GAMEMODE:GetSpawnSets(), "name" ) do
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


function GM:SpawnSetInitialThink()
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
    GLEE_SPAWNSETS = nil

    self.GobbledSpawnsets = true
    hook.Run( "glee_post_spawnsetgobble" )

    local spawnSetPicked = spawnSetVar:GetString()
    if not self:IsValidSpawnSet( spawnSetPicked ) then
        print( "GLEE: INVALID SPAWNSET " .. spawnSetPicked )
        spawnSetPicked = defaultSpawnSetName
        RunConsoleCommand( "huntersglee_spawnset", spawnSetPicked )

    end

    self:SetSpawnSet( spawnSetPicked )

end

-- gobble all the custom spawnsets
hook.Add( "huntersglee_round_firstsetup", "glee_spawnset_think", function() GAMEMODE:SpawnSetInitialThink() end )

-- re-parse the spawnset when a new round is started
-- so each round gets a different roll of all the random fields in the spawnsets
hook.Add( "huntersglee_round_leave_limbo", "glee_spawnset_reparse", function() GAMEMODE:SetSpawnSet( spawnSetVar:GetString() ) end )

-- let people joining the server have the default glee experience
hook.Add( "huntersglee_emptyserver", "glee_reset_spawnset", function( wasEmpty )
    if wasEmpty then return end -- only run this if there were people online, and are no longer people online
    local name = GAMEMODE:GetSpawnSet()
    if name == defaultSpawnSetName then return end
    RunConsoleCommand( "huntersglee_spawnset", defaultSpawnSetName )
    print( "GLEE: reset spawnset on empty server" )

end )

-----------------------------------------
-- SPAWNSET TEMPLATE IN
-- lua/glee_spawnsets/hunters_glee.lua
-----------------------------------------