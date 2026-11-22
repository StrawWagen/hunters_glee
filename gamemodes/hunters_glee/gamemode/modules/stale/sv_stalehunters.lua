
-- Removes hunters that go too long without finding anyone
-- and tells the spawner, so it spawns the next ones closer

local debuggingVar = GetConVar( "huntersglee_debug_hunterspawner" )
local function debugPrint( ... )
    if not debuggingVar:GetBool() then return end
    permaPrint( ... )

end

-- how many seconds of the hunter's max health it needs to be without an enemy before it gets removed
-- 0.5 ratio means, 100 hp hunter needs to be without an enemy for 50 seconds before it gets removed
local staleRatio = 0.5

local krangledStaleRatioMin = 100 -- dont remove krangled npcs below this hp too fast!

-- krangled npcs have no enemy to check, so closing in on the nearest player counts instead
local krangledProgressInterval = 5
local krangledProgressDist = 200 -- per interval, slow creepers still go stale

--[[---------------------------------------------------------
    GM:ManageIfStale
    @desc Removes this hunter once it's gone too long without an enemy, and has the spawner spawn closer.
    @param hunter: The hunter.
    @return: None
--]]---------------------------------------------------------
function GM:ManageIfStale( hunter ) -- dont let fodder npcs do whatever they want, remove them and march the spawn distances smaller if they're being boring
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
    hunter.glee_StaleKrangled = krangled

    hook.Add( "glee_hunter_nearbyaply", hunter, function( me, nearestHunter ) -- so they dont delete when they're nearby a ply, eg, they bought chameleon
        if me ~= nearestHunter then return end
        local count = nearestHunter.glee_StaleNoEnemyCount
        if count <= 0 then return end -- negative is spawn grace, leave it

        nearestHunter.glee_StaleNoEnemyCount = math.max( count - 1, 0 )

    end )

    local timerAdjusted
    local nextProgressSample = 0
    local lastProgressDist
    local closingIn
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

        if krangled and nextProgressSample < CurTime() then
            nextProgressSample = CurTime() + krangledProgressInterval
            local _, nearestDistSqr = GAMEMODE:nearestAlivePlayer( hunter:GetPos() )
            local nearestDist = math.sqrt( nearestDistSqr )
            closingIn = lastProgressDist and ( lastProgressDist - nearestDist ) > krangledProgressDist
            lastProgressDist = nearestDist

        end

        local krangledSeesEnemy = ( hunter.glee_SeeEnemy or 0 ) > CurTime()
        local seesEnemy = hunter.IsSeeEnemy or krangledSeesEnemy

        local goodEnemy = IsValid( enemy ) and enemy.isTerminatorHunterChummy ~= hunter.isTerminatorHunterChummy

        if seesEnemy or goodEnemy or closingIn then
            hunter.glee_StaleNoEnemyCount = math.min( 0, oldCount + -1 ) -- good enemy, snap count down and march it into the negatives
            return

        end

        -- a recent fight holds it at full leeway, without undoing what it banked above
        if GAMEMODE:IsHunterBattling( hunter ) then
            hunter.glee_StaleNoEnemyCount = math.min( oldCount, startingCount )
            return

        end

        local itsRemovalTime = oldCount >= hunter.glee_NoEnemyToRemove

        if itsRemovalTime then -- booring enem
            debugPrint( "stale" )

            local _, nearestDistSqr = GAMEMODE:nearestAlivePlayer( hunter:GetPos() )
            local nearestDist = math.sqrt( nearestDistSqr )

            local tooFarDist = GAMEMODE:GetDynamicTooFarDist()
            if tooFarDist and nearestDist < tooFarDist * 0.5 and not hunter.glee_FodderWasNearPlayerAtLeast then -- bot is close, give it a second chance
                debugPrint( "FORGIVE STALE", hunter, nearestDist < tooFarDist * 0.5, hunter.glee_FodderWasNearPlayerAtLeast )
                hunter.glee_FodderWasNearPlayerAtLeast = true
                hunter.glee_NoEnemyToRemove = hunter.glee_NoEnemyToRemove * 2 -- still remove eventually
                return

            end

            GAMEMODE:LearnFromStaleHunter( hunter, nearestDist, hunter.glee_NoEnemyToRemove )
            SafeRemoveEntity( hunter )
            debugPrint( "REMOVE STALE", hunter )
            return

        end

        hunter.glee_StaleNoEnemyCount = oldCount + 1 -- boring

    end )
end


-- Kills

local function staleTrackedHunterOf( ent )
    if not IsValid( ent ) then return end
    if ent.glee_StaleNoEnemyCount then return ent end

    local owner = ent:GetOwner() -- projectiles, thrown props
    if IsValid( owner ) and owner.glee_StaleNoEnemyCount then return owner end

end

-- for krangled npcs that kill with ply:Kill() or world damage, so nothing names them as the killer
local krangledKillCreditDistSqr = 250^2

local function nearestKrangledHunter( pos )
    local nearest
    local nearestDistSqr = krangledKillCreditDistSqr
    for _, hunter in pairs( GAMEMODE.glee_Hunters ) do
        if not IsValid( hunter ) then continue end
        if not hunter.glee_StaleKrangled then continue end

        local distSqr = hunter:GetPos():DistToSqr( pos )
        if distSqr < nearestDistSqr then
            nearest = hunter
            nearestDistSqr = distSqr

        end
    end
    return nearest

end

-- track kills from hunters, so we dont despawn the ones getting the job done.
hook.Add( "PlayerDeath", "glee_fodderenemy_catchkrangled", function( died, inflic, attacker )
    local killer = staleTrackedHunterOf( inflic ) or staleTrackedHunterOf( attacker ) or nearestKrangledHunter( died:GetPos() )
    if not killer then return end
    if not killer:GetNW2Bool( "glee_IsHunter" ) then return end

    GAMEMODE:MarkHunterAsBattling( killer )
    GAMEMODE:LearnFromHunterKill( killer, died )

    local oldCount = killer.glee_StaleNoEnemyCount

    killer.glee_FodderKills = ( killer.glee_FodderKills or 0 ) + 1
    killer.glee_StaleNoEnemyCount = math.min( -30, oldCount + -30 )

end )
