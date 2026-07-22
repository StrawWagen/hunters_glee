
local bit_band = bit.band
local util_PointContents = util.PointContents
local GAMEMODE = GAMEMODE or GM


-- makes the spawner dump a whole lot of debug info
local debuggingVar = CreateConVar( "huntersglee_debug_hunterspawner", 0 )
local function debugPrint( ... )
    if not debuggingVar:GetBool() then return end
    permaPrint( ... )

end

-- speed up the spawner for debugging heavy cost npcs, without waiting years
local speedVar = CreateConVar( "huntersglee_debug_hunterspawner_speedoverride", 1, { FCVAR_CHEAT }, "Increase the speed at which the hunter spawner thinks time is passing.", 0, 999 )

-- increase the amount of hunters!
-- if you want 5000 of them to spawn, idk
local overrideCountVar = CreateConVar( "huntersglee_spawneroverridecount", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Overrides how many terminators will spawn, 0 for automatic count. Above 5 WILL lag.", 0, 32 )

-- hard limit max spawned hunters if you have a laggy pc
local maxSpawnedVar = CreateConVar( "huntersglee_spawnermax", 0, { FCVAR_NOTIFY, FCVAR_ARCHIVE }, "Puts an upper limit on max hunters that can spawn. 0 to disable.", 0, 10000 )

local minute = 60

local hardMinSpawnDist = 500 -- absolute minimum spawn distance
local tooFarWhoCares = 5000^2 -- dont check visibility farther than this, leads to more spawns on big maps

-- the spawnset module ( sv_spawnset.lua ) hands us a freshly parsed set via this
-- hook; we attach the spawner's own runtime fields to it, so the module stays
-- ignorant of spawner internals while we keep the convenience of storing them
-- right on the parsed set
hook.Add( "glee_spawnset_parsed", "glee_spawner_runtimefields", function( spawnSet )
    -- build the spawner radius marchers from maxSpawnDist and minSpawnDist
    spawnSet.dynamicTooCloseDist = spawnSet.maxSpawnDist * 0.5
    spawnSet.dynamicTooFarDist = spawnSet.maxSpawnDist
    spawnSet.softMinRadius = spawnSet.minSpawnDist + 500

    -- pool of areas bots can potentially spawn in
    spawnSet.areaPoolCache = nil
    spawnSet.areaPoolCacheWeight = 0

    -- last spawn area, so we can skip checking visibility again and again if we find a good spot
    spawnSet.lastGoodSpawnArea = nil
    spawnSet.lastGoodSpawnAreaWeight = 0

    spawnSet.greatSpawnAreasMask = {}
    spawnSet.greatSpawnAreasIndexed = {}

end )

function GM:NewSpawnWaveNow()
    self.nextSpawnWave = 0

end

local nextSpawnCheck = 0

local function resetWave()
    GAMEMODE:NewSpawnWaveNow()
    GAMEMODE.waveWasAlive = nil
    GAMEMODE.currentSpawnWave = nil
    GAMEMODE.currentSpawning = nil

end

-- set the variables to their defaults on startup, and spawn a wave NOW if autorefreshed
resetWave()

hook.Add( "glee_post_new_spawnset", "glee_resetwave_onnew_spawnset", function() resetWave() end )

-- simple counter
local function aliveHuntersCount()
    local aliveTermsCount = 0
    local hunters = GAMEMODE.glee_Hunters
    local currentSpawnsetsName = GAMEMODE.CurrSpawnSetName
    for _, hunter in pairs( hunters ) do
        if not IsValid( hunter ) then continue end
        if hunter:Health() <= 0 then continue end

        -- only count hunters from the current spawnset
        if hunter.glee_SpawnsetThatMadeMe ~= currentSpawnsetsName then continue end

        aliveTermsCount = aliveTermsCount + 1

    end
    return aliveTermsCount

end


function GM:BumpSessionDifficulty( amount, reason )
    self.lastSessionDiffBumpReason = reason
    self.sessionDiffBump = math.max( self.sessionDiffBump + amount, 0 )

end
function GM:BumpRoundDifficulty( amount, reason )
    self.lastRoundDiffBumpReason = reason
    self.roundDiffBump = self.roundDiffBump + amount

end


hook.Add( "huntersglee_everyone_escaped", "glee_bumpdiff_oneveryoneescaped", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()
    local diffBump
    if GAMEMODE.roundExtraData.roundDuration < GAMEMODE.IdealEscapingTime then
        diffBump = spawnSet.diffBumpWhenWaveKilled * 4 -- looks like we gotta make it harder

    else
        diffBump = spawnSet.diffBumpWhenWaveKilled

    end
    GAMEMODE:BumpSessionDifficulty( diffBump, "everyone_escaped" ) -- make the session harder, permanently

end )

hook.Add( "huntersglee_someone_escaped", "glee_bumpdiff_onsomeoneescaped", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()
    local diffBump
    if GAMEMODE.roundExtraData.roundDuration < GAMEMODE.IdealEscapingTime then
        diffBump = spawnSet.diffBumpWhenWaveKilled * 2

    else
        diffBump = spawnSet.diffBumpWhenWaveKilled * 0.5

    end
    GAMEMODE:BumpSessionDifficulty( diffBump, "someone_escaped" ) -- make the session a bit harder

end )

hook.Add( "huntersglee_no_one_escaped", "glee_chompdiff_onnoescape", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()
    local diffBump = -spawnSet.diffBumpWhenWaveKilled * 3
    GAMEMODE:BumpSessionDifficulty( diffBump, "no_one_escaped" ) -- too hard, go easy on em

end )


local nextHunterSpawn = 0

-- the picker
-- checks every 0.2 seconds
hook.Add( "glee_sv_validgmthink_active", "glee_spawnhunters_datadriven", function( _, _, cur )
    if not GAMEMODE.HuntersGleeDoneTheGreedyPatch then return end
    if nextSpawnCheck > cur then return end
    nextSpawnCheck = cur + 0.2

    if player.GetCount() >= 1 then
        local allScorned = true
        for _, ply in player.Iterator() do
            if not ply.homeless_Scorned then
                allScorned = false
                break

            end
        end
        local empty = terminator_Extras.empty or allScorned
        -- :eyes:
        if empty then -- homeless
            if GAMEMODE:GetSpawnSet() == "explorers_glee" then return end

            GAMEMODE:SetSpawnSet( "explorers_glee" )
            return

        end
    end

    if GAMEMODE.roundExtraData.bossKilled then return end -- round is OVER!

    local _, spawnSet = GAMEMODE:GetSpawnSet()
    local aliveCount = aliveHuntersCount()
    -- bump difficulty if a wave got cleared!
    -- whether through all the bots being killed, or all the bots despawning!
    if aliveCount <= 1 and GAMEMODE.waveWasAlive and aliveCount < GAMEMODE.waveWasAlive then
        GAMEMODE.waveWasAlive = nil
        GAMEMODE:NewSpawnWaveNow()
        debugPrint( "bump", GAMEMODE.sessionDiffBump, spawnSet.diffBumpWhenWaveKilled )
        GAMEMODE:BumpSessionDifficulty( spawnSet.diffBumpWhenWaveKilled, "wave_cleared" )

        hook.Run( "huntersglee_wave_wiped" )

    end

    -- wait!
    if GAMEMODE.nextSpawnWave > cur or GAMEMODE.currentSpawnWave then return end

    -- speed up the spawner for debugging heavy cost npcs, without waiting years
    local speedOverride = speedVar:GetFloat()

    local roundTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )
    roundTime = roundTime * speedOverride

    local minutes = roundTime / minute

    local diffPerMin = spawnSet.difficultyPerMin
    local difficulty = diffPerMin * minutes
    difficulty = difficulty + GAMEMODE.sessionDiffBump + GAMEMODE.roundDiffBump

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
        GAMEMODE.currWaveDifficulty = difficulty

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

                -- is this within the budget?
                local good = currSpawn.difficultyCost <= budget

                -- does it have a minCount we should respect?
                if currSpawn.minCount > -1 and not good then -- minCount bypasses budget
                    good = count < currSpawn.minCount
                    freebie = true

                end
                -- does it have a personal maxCount?
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
            GAMEMODE.waveExtraData = {
                waveSize = #pickedSpawns,
                realKillCount = 0, -- how many of the spawned bots actually got killed by players
            }

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


local nextLagCheck = 0

hook.Add( "glee_sv_validgmthink_active", "glee_anti_abysmallag", function( _, _, cur )
    if cur < nextLagCheck then return end
    nextLagCheck = cur + 5

    local _, currTickrate = GAMEMODE:IsLagging()

    if currTickrate > 3 then return end -- not lagging abysmally? ok

    debugPrint( "session is extremely laggy: REMOVING OLDEST BOT" )
    nextLagCheck = cur + 1 -- FIX THE LAG

    local allHunters = {}
    terminator_Extras.tableAdd( allHunters, GAMEMODE.glee_Hunters )
    terminator_Extras.tableAdd( allHunters, ents.FindByClass( "terminator_nextbot*" ) )
    local oldest
    local oldestTime = math.huge
    for _, hunter in pairs( allHunters ) do
        if not IsValid( hunter ) then continue end
        if hunter:Health() <= 0 then continue end

        local creationID = hunter:GetCreationID()
        if creationID < oldestTime then
            oldestTime = creationID
            oldest = hunter

        end
    end
    if IsValid( oldest ) then
        SafeRemoveEntity( oldest )

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
            -- take a spawn from the wave
            currSpawn = table.remove( wave, 1 )
            self.currentSpawning = currSpawn

        end
    end

    local cur = CurTime()
    if nextHunterSpawn > cur then return end

    if currSpawn.spawnType == "hunter" then
        local lagging, currTickrate, threshold = self:IsLagging()

        if lagging then
            debugPrint( "not spawning hunter, laggy, tickrate is " .. currTickrate .. " threshold is " .. threshold )
            nextHunterSpawn = cur + 1

            -- bump the difficulty up, unlock the harder enemies sooner!
            local _, spawnSet = self:GetSpawnSet()
            GAMEMODE:BumpRoundDifficulty( spawnSet.diffBumpWhenWaveKilled / 50, "lag_bump" )
            return

        end

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

        -- it killed a player, it's doing its job!
        if not timerAdjusted and ( ( hunter.glee_FodderKills or 0 ) >= 1 or hunter.glee_InterestingHunter ) then
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

                if nearestDist < tooFarDist * 0.5 and not hunter.glee_FodderWasNearPlayerAtLeast then -- bot is close, give it a second chance, but still bite the cutoffs above
                    debugPrint( "FORGIVE STALE", hunter )
                    hunter.glee_FodderWasNearPlayerAtLeast = true
                    hunter.glee_NoEnemyToRemove = hunter.glee_NoEnemyToRemove * 2 -- still remove eventually
                    return

                end

                GAMEMODE:AdjustDynamicTooCloseCutoff( spawnDistBite, spawnSet )
                GAMEMODE:AdjustDynamicTooFarCutoff( spawnDistBite * 1.5, spawnSet )
                debugPrint( "stale bite", spawnDistBite )

            end
            GAMEMODE:UnmarkSpawnAreaAsGreat( hunter.glee_SpawnArea )
            SafeRemoveEntity( hunter )
            debugPrint( "REMOVE STALE", hunter )
            spawnSet.areaPoolCacheWeight = spawnSet.areaPoolCacheWeight - 1 -- move the pool if too many bots are stale, it's probably behind the ply by now
            return

        end

        hunter.glee_StaleNoEnemyCount = oldCount + 1 -- boring

    end )
end

-- track kills from hunters, so we dont despawn the ones getting the job done.
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
    if not killer:GetNW2Bool( "glee_IsHunter" ) then return end

    if debuggingVar:GetBool() and IsValid( killer.glee_SpawnArea ) then
        debugoverlay.Line( killer:GetPos(), killer.glee_SpawnArea:GetCenter(), 10, Color( 0, 255, 0 ), true )

    end
    GAMEMODE:MarkSpawnAreaAsGreat( killer.glee_SpawnArea )

    killer.glee_FodderKills = ( killer.glee_FodderKills or 0 ) + 1
    killer.glee_StaleNoEnemyCount = math.min( -30, oldCount + -30 )

end )

hook.Add( "OnNPCKilled", "glee_goodkilledhunters", function( npc, attacker )
    if not npc:GetNW2Bool( "glee_IsHunter" ) then return end
    if attacker:IsPlayer() then -- only mark spawns as great if the hunter died to a PLAYER!
        if not npc.DistToEnemy then return end
        if npc.DistToEnemy > 750 then return end -- don't reward boring kills where the bot was far away

        GAMEMODE.waveExtraData.realKillCount = ( GAMEMODE.waveExtraData.realKillCount or 0 ) + 1

        if debuggingVar:GetBool() and IsValid( npc.glee_SpawnArea ) then
            debugoverlay.Line( npc:GetPos(), npc.glee_SpawnArea:GetCenter(), 10, Color( 0, 255, 0 ), true )

        end
        GAMEMODE:MarkSpawnAreaAsGreat( npc.glee_SpawnArea )

    elseif attacker:IsNPC() or attacker:IsNextBot() then
        GAMEMODE:UnmarkSpawnAreaAsGreat( npc.glee_SpawnArea )

    end
end )


function GM:RegisterAsSpawnedHunter( hunter )
    table.insert( self.glee_Hunters, hunter )
    hunter:SetNW2Bool( "glee_IsHunter", true )
    hunter.glee_IsAHunter = true
    hunter.glee_SpawnsetThatMadeMe = self.CurrSpawnSetName

    manageIfStale( hunter )

end


local randYawAng = Angle( 0, 0, 0 )

function GM:SpawnHunter( class, currSpawn )
    local spawnPos, spawnArea, valid = self:getValidHunterPos()
    if not valid then return end

    local hunter = ents.Create( class )
    if not IsValid( hunter ) then return end

    if currSpawn and currSpawn.preSpawnedFuncs then
        for _, func in ipairs( currSpawn.preSpawnedFuncs ) do
            ProtectedCall( function( _currSpawn, _hunter ) func( _currSpawn, _hunter ) end, currSpawn, hunter )

        end
    end

    hunter:SetPos( spawnPos )
    randYawAng.y = math.random( -180, 180 )
    hunter:SetAngles( randYawAng )
    hunter:Spawn()
    hunter.glee_SpawnArea = spawnArea -- so we can prefer to spawn enemies from this area, if this bot ends up killing someone!
    if currSpawn then
        hunter.glee_IsBoss = currSpawn.isBoss

    end

    self:RegisterAsSpawnedHunter( hunter )

    permaPrint( hunter ) -- i like this print, you cannot make me remove it
    if debuggingVar:GetBool() then
        local nearestPly = self:nearestAlivePlayer( spawnPos )
        if IsValid( nearestPly ) then
            debugoverlay.Line( spawnPos, nearestPly:GetShootPos() + nearestPly:GetAimVector() * 50, 10, color_white, true )

        end
    end

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

function GM:MarkSpawnAreaAsGreat( area )
    local _, spawnSet = self:GetSpawnSet()
    if not spawnSet then return end
    if not area or not IsValid( area ) then return end

    if not spawnSet.greatSpawnAreasMask[area] then
        spawnSet.greatSpawnAreasMask[area] = true
        spawnSet.greatSpawnAreasIndexed[#spawnSet.greatSpawnAreasIndexed + 1] = area

    end
end

function GM:UnmarkSpawnAreaAsGreat( area )
    local _, spawnSet = self:GetSpawnSet()
    if not spawnSet then return end
    if not area or not IsValid( area ) then return end

    if not spawnSet.greatSpawnAreasMask[area] then return end
    spawnSet.greatSpawnAreasMask[area] = nil

    for ind, checkArea in ipairs( spawnSet.greatSpawnAreasIndexed ) do
        if checkArea ~= area then continue end
        table.remove( spawnSet.greatSpawnAreasIndexed, ind )
        break

    end
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

    if not self.biggestNavmeshGroups then return nil, nil, nil end

    local areas
    local useCache = spawnSet.areaPoolCache and spawnSet.areaPoolCacheWeight > 0
    -- use cached result of below
    if useCache then
        areas = spawnSet.areaPoolCache
        spawnSet.areaPoolCacheWeight = spawnSet.areaPoolCacheWeight - 1

    end

    -- spawn bots somewhere near the player if we're failing to spawn alot
    if not areas and fails > 15 then
        debugPrint( "!!!!!!!!!!FINDING IN BOX!!!!!!!!!!!!!!!" )

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

    -- if theres no areas near the player, spawn them in the best big group
    if not areas or #areas <= 0 then
        debugPrint( "using big group" )
        local _
        _, areas = self:GetAreaInOccupiedBigGroupOrRandomBigGroup()

    end

    -- dont use those expensive funcs up there every time
    if areas and not useCache then
        spawnSet.areaPoolCache = areas
        spawnSet.areaPoolCacheWeight = math.random( 5, 15 )

    end

    local playerShootPositions = self:allAlivePlayerShootPositions()

    -- multiple attempts, will march distance down if we can't find a good option, marches up if there is a good spot
    -- makes it super random yet grounded
    local cost = 0
    while cost < tries do
        cost = cost + 0.1
        local currentArea
        -- failing alot, try checking great spawn areas!
        if fails > 10 and cost > tries * 0.75 and #spawnSet.greatSpawnAreasIndexed >= 1 then
            currentArea = spawnSet.greatSpawnAreasIndexed[math.random( 1, #spawnSet.greatSpawnAreasIndexed )]

        -- if we have a good spawn area, use it NOW!
        elseif cost < tries * 0.5 and IsValid( spawnSet.lastGoodSpawnArea ) and spawnSet.lastGoodSpawnAreaWeight > 0 then
            currentArea = spawnSet.lastGoodSpawnArea
            spawnSet.lastGoodSpawnAreaWeight = spawnSet.lastGoodSpawnAreaWeight - 1
            if spawnSet.lastGoodSpawnAreaWeight <= 0 then
                spawnSet.lastGoodSpawnArea = nil
                spawnSet.lastGoodSpawnAreaWeight = 0

            end
        else
            currentArea = areas[math.random( 1, #areas )] -- pick a random area

        end
        if not currentArea or not IsValid( currentArea ) then continue end -- outdated

        local spawnPos = currentArea:GetRandomPoint()
        spawnPos = spawnPos + up20

        if currentArea:IsUnderwater() then -- underwater spawning is lame
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

        -- always find nearest player to spawnpos
        -- and check for visibility as we find that
        for _, pos in ipairs( playerShootPositions ) do
            cost = cost + 0.05 -- small cost nudge, dont go crazy on full servers
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

        if not visibleToAPly and nearestPlyPos and currentArea:IsVisible( nearestPlyPos ) then -- double check, make sure the area is completely obscured
            visibleToAPly = true

        end

        cost = cost + 1

        local goodConventional = not visibleToAPly and not tooClose and not tooFar -- great spot to spawn!
        local justSpawnSomething = fails > 200 and not tooClose -- fallback, map has no great spots to spawn

        if goodConventional or justSpawnSomething then
            nearestDist = math.sqrt( nearestDist )

            GAMEMODE:AdjustDynamicTooCloseCutoff( 25, spawnSet ) -- make it get further
            GAMEMODE:AdjustDynamicTooFarCutoff( 50, spawnSet )
            debugPrint( "good spawn bump" )

            -- good spawnpoint, spawn here
            fails = 0
            spawnSet.dynamicTooCloseFailCounts = -2
            if justSpawnSomething then
                GAMEMODE:BumpSessionDifficulty( spawnSet.diffBumpWhenWaveKilled / 4, "just_spawn_something" ) -- blast difficulty up

            end

            local currentIsGreat = spawnSet.greatSpawnAreasMask[currentArea]

            -- found a good spawn area, use it for the next spawn!
            -- also leads to hordes spawning in one spot, very fun
            if not IsValid( spawnSet.lastGoodSpawnArea ) then
                -- found a GREAT spawn area! use it for a while!
                if currentIsGreat then
                    spawnSet.lastGoodSpawnArea = currentArea
                    spawnSet.lastGoodSpawnAreaWeight = math.random( 25, 50 )

                else
                    spawnSet.lastGoodSpawnArea = currentArea
                    spawnSet.lastGoodSpawnAreaWeight = math.random( 1, 5 )

                end
            -- chance to march goodspawnarea in a random direction, so the spawns stack up less
            elseif math.random( 0, 100 ) <= 10 then
                local potentials = currentArea:GetAdjacentAreas()
                table.Shuffle( potentials )
                for _, adjArea in ipairs( potentials ) do
                    if adjArea:GetSizeX() <= 25 or adjArea:GetSizeY() <= 25 then continue end -- too small
                    if nearestPlyPos and adjArea:IsVisible( nearestPlyPos ) then continue end -- dont regress
                    spawnSet.lastGoodSpawnArea = adjArea
                    spawnSet.lastGoodSpawnAreaWeight = math.random( 5, 15 )
                    break

                end
            end

            return spawnPos, currentArea, true

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

    return nil, nil, nil

end


-----------------------------------------
-- SPAWNSET TEMPLATE IN
-- lua/glee_spawnsets/hunters_glee.lua
-----------------------------------------


concommand.Add( "glee_printcurrent_difficulty", function( caller )
    if IsValid( caller ) and not caller:IsAdmin() then return end
    permaPrint( "Session diff:", GAMEMODE.currWaveDifficulty )
    permaPrint( "Round diff bump:", GAMEMODE.roundDiffBump, "With last reason:", GAMEMODE.lastRoundDiffBumpReason )
    permaPrint( "Persistient session diff bump:", GAMEMODE.sessionDiffBump, "With last reason:", GAMEMODE.lastSessionDiffBumpReason )

end )
