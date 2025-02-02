
local GAMEMODE = GAMEMODE or GM

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

local defaults = {
    difficultyPerMin = 100 / 10, -- 100% diff at 10 mins
    waveInterval = { minute, minute * 1.6 },
    diffBumpWhenWaveKilled = { 10, 20 },
    startingBudget = 20,
    spawnCountPerDifficulty = { 0.08, 0.1 },
    startingSpawnCount = { 1.8, 2 },
    maxSpawnCount = 10,
}

local function asNum( toParse, name )
    if isstring( toParse ) then
        if toParse == "default" and defaults[name] then
            toParse = defaults[name]

        else
            return

        end
    end

    if isnumber( toParse ) then return toParse end
    if #toParse <= 1 and isnumber( toParse[1] ) then return toParse[1] end
    if #toParse <= 2 and isnumber( toParse[1] ) and isnumber( toParse[2] ) then return math.Rand( toParse[1], toParse[2] ) end

end

local function parse( tbl, name )
    local toParse = tbl[name]
    local parsed = asNum( toParse, name )
    if isnumber( parsed ) then
        tbl[name] = parsed

    end
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

    for name, _ in pairs( defaults ) do
        if not asNum( spawnSet[name], name ) then
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

        if not asNum( spawn.difficultyCost, "difficultyCost" ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .difficultyCost" ) return end
        if not asNum( spawn.minCount, "minCount" ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .minCount" ) return end
        if not asNum( spawn.maxCount, "maxCount" ) then yapErr( spawnSet, ".spawns " .. name .. " invalid .maxCount" ) return end

    end

    return true
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

-- set spawnset
function GM:SetSpawnSet( setName )
    local asRegistered = self.RegisteredSpawnSets[setName]
    if not asRegistered then ErrorNoHaltWithStack( "GLEE: Tried to enable invalid spawnset " .. setName ) return end

    local spawnSet = table.Copy( asRegistered )

    for name, _ in pairs( spawnSet ) do
        parse( spawnSet, name )

    end

    for _, currSpawn in ipairs( spawnSet.spawns ) do
        for name, _ in pairs( currSpawn ) do
            parse( currSpawn, name )

        end
    end

    self.CurrSpawnSetName = setName
    self.CurrSpawnSet = spawnSet

    SetGlobalString( "GLEE_SpawnSetName", setName )
    SetGlobalString( "GLEE_SpawnSetPrettyName", spawnSet.prettyName )

    hook.Run( "glee_post_set_spawnset", setName, spawnSet )

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

                    local minutesNeeded = currSpawn.minutesNeeded
                    if minutesNeeded and minutes < minutesNeeded then
                        continue

                    end

                    local countClass = currSpawn.countClass or currSpawn.class
                    local count = classCounts[countClass]
                    if not count then
                        count = #ents.FindByClass( countClass )
                        debugPrint( count, countClass )
                        classCounts[countClass] = count

                    end

                    local good = currSpawn.difficultyCost <= budget or count < currSpawn.minCount
                    good = good and count < currSpawn.maxCount
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
                    ProtectedCall( function() func( currSpawn, hunter ) end )

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

local defaultRadius = 7000
local maxRadius = 8000
local minRadius = 500
local fails = 0

-- spawn a hunter as far away as possible from every player by inching a distance check around
-- made to be really random/overcomplicated so you never really know where they'll spawn from
function GM:getValidHunterPos()
    local dynamicTooCloseFailCounts = self.roundExtraData.dynamicTooCloseFailCounts or -2
    local dynamicTooCloseDist = self.roundExtraData.dynamicTooCloseDist or defaultRadius

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
            self.roundExtraData.dynamicTooCloseDist = math.Clamp( dynamicTooCloseDist, minRadius, maxRadius )

        end

        if not invalid or ( fails > 2000 and not wasTooClose ) then
            fails = 0
            -- good spawnpoint, spawn here
            --debugoverlay.Cross( spawnPos, 100, 20, color_white, true )
            self.roundExtraData.dynamicTooCloseFailCounts = -2
            return spawnPos, true

        end

        fails = fails + 1

        -- random picked area was too close, decrease cutoff radius
        if wasTooClose then
            --debugoverlay.Cross( spawnPos, 10, 20, Color( 255,0,0 ), true )
            self.roundExtraData.dynamicTooCloseFailCounts = dynamicTooCloseFailCounts + 1
            dynamicTooCloseDist = dynamicTooCloseDist + ( -dynamicTooCloseFailCounts * 25 )
            self.roundExtraData.dynamicTooCloseDist = math.Clamp( dynamicTooCloseDist, minRadius, maxRadius )

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

-----------------------------------------
-- TEMPLATE IN
-- lua/glee_spawnsets/hunters_glee.lua
-----------------------------------------