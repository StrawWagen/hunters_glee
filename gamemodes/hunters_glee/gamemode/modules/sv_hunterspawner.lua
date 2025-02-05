
local isnumber = isnumber
local isstring = isstring
local isfunction = isfunction
local GAMEMODE = GAMEMODE or GM

local function errorCatchingMitt( errMessage )
    ErrorNoHaltWithStack( errMessage )

end


local debuggingVar = CreateConVar( "huntersglee_debug_spawner", 0 )
local function debugPrint( ... )
    if not debuggingVar:GetBool() then return end
    print( ... )

end

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
    maxSpawnDist = { 5500, 6500 },
    roundEndSound = "53937_meutecee_trumpethit07.wav",
    roundStartSound = "", -- no sound for glee
}

local spawnDefaults = {
    minCount = -1, -- makes it ignore these
    maxCount = -1, -- respects maxSpawnCount tho
}

local function asParsed( toParse, name, defaultsTbl )
    local default = defaultsTbl[name]
    if default then
        if not toParse then -- fallback,
            print( name, default )
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

    print( spawnSet.name, name, parsed )

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

    spawnSet.defaultRadius = spawnSet.maxSpawnDist * 0.9

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = spawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )
    SetGlobalString( "GLEE_SpawnSetPrettyName", spawnSet.prettyName )

    hook.Run( "glee_post_set_spawnset", setName, spawnSet )

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

    if GAMEMODE.nextSpawnWave < cur and not GAMEMODE.currentSpawnWave then
        local roundTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )
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
                addedOne = nil
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
                    if currSpawn.minCount > -1 then -- minCount bypasses budget
                        good = good or count < currSpawn.minCount

                    end
                    if currSpawn.maxCount > -1 then
                        good = good and count < currSpawn.maxCount

                    end
                    if good then
                        addedOne = true
                        budget = budget - currSpawn.difficultyCost
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
                GAMEMODE.nextSpawnWave = cur + spawnSet.waveInterval

            end
        else
            -- dont spam checks
            GAMEMODE.nextSpawnWave = cur + ( spawnSet.waveInterval / 20 )

        end
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
        local hunter = self:SpawnHunter( currSpawn.class )
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

function GM:SpawnHunter( class )
    local spawnPos, valid = self:getValidHunterPos()
    if not valid then return end

    local hunter = ents.Create( class )
    if not IsValid( hunter ) then return end

    hunter:SetPos( spawnPos )
    hunter:Spawn()
    table.insert( self.glee_Hunters, hunter )

    print( hunter ) -- i like this print, you cannot make me remove it 

    return hunter

end

local minRadius = 500
local fails = 0

-- spawn a hunter as far away as possible from every player by inching a distance check around
-- made to be really random/overcomplicated so you never really know where they'll spawn from
function GM:getValidHunterPos()
    local _, spawnSet = self:GetSpawnSet()
    local dynamicTooCloseFailCounts = spawnSet.dynamicTooCloseFailCounts or -2
    local dynamicTooCloseDist = spawnSet.dynamicTooCloseDist or spawnSet.defaultRadius

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

        local checkPos = spawnPos + Vector( 0,0,50 )
        local invalid = nil
        local wasTooClose = nil

        for _, pos in ipairs( playerShootPositions ) do
            local visible, visResult
            local hitCloseBy
            if not invalid then
                visible, visResult = terminator_Extras.PosCanSee( pos, checkPos )
                hitCloseBy = visResult.HitPos:DistToSqr( checkPos ) < 350^2

            end
            if visible or hitCloseBy then
                invalid = true

            -- always check for this
            elseif pos:DistToSqr( checkPos ) < dynamicTooCloseDist^2 then -- dist check!
                invalid = true
                wasTooClose = true
                break

            end
        end

        if randomArea:IsUnderwater() then
            -- make it a bit closer
            dynamicTooCloseDist = dynamicTooCloseDist - 100
            spawnSet.dynamicTooCloseDist = math.Clamp( dynamicTooCloseDist, minRadius, spawnSet.maxSpawnDist )

        elseif not invalid or ( fails > 2000 and not wasTooClose ) then
            fails = 0
            -- good spawnpoint, spawn here
            --debugoverlay.Cross( spawnPos, 100, 20, color_white, true )
            spawnSet.dynamicTooCloseFailCounts = -2
            return spawnPos, true

        end

        fails = fails + 1

        -- random picked area was too close, decrease cutoff radius
        if wasTooClose then
            --debugoverlay.Cross( spawnPos, 10, 20, Color( 255,0,0 ), true )
            spawnSet.dynamicTooCloseFailCounts = dynamicTooCloseFailCounts + 1
            dynamicTooCloseDist = dynamicTooCloseDist + ( -dynamicTooCloseFailCounts * 25 )
            spawnSet.dynamicTooCloseDist = math.Clamp( dynamicTooCloseDist, minRadius, spawnSet.maxSpawnDist )

        end
    end
    return nil, nil

end


local defaultSpawnSetName = "hunters_glee"

local spawnSetVar = CreateConVar( "huntersglee_spawnset", defaultSpawnSetName, { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }, "What spawnset the gamemode should use." )
cvars.AddChangeCallback( "huntersglee_spawnset", function( _, _old, new )
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

end )

-----------------------------------------
-- TEMPLATE IN
-- lua/glee_spawnsets/hunters_glee.lua
-----------------------------------------