local IsValid = IsValid
local util_IsInWorld = util.IsInWorld
local math = math

local punishEscaping = CreateConVar( "huntersglee_punish_navmesh_escapers", 1, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Should the life of players who tread off the navmesh be sapped away?.", 0, 32 )

local navCheckDist = 150
local belowOffset = Vector( 0, 0, -navCheckDist )
local tStartOffset = Vector( 0, 0, -2 )
local airCheckHull = Vector( 17, 17, 1 )
local restingBPMPermanent = 60 -- needs to match clientside var too

local distNeededToBeOnArea = 25^2
local distWayTooFarOffNavmesh = 250^2
local posCanSeeComplex = terminator_Extras.PosCanSeeComplex
local defaultHeartAttackBpm = 290
local bpmStartScreamingLikeCrazy = 225

local entMeta = FindMetaTable( "Entity" )

local plyMeta = FindMetaTable( "Player" )

function plyMeta:GetNavAreaData()
    if not IsValid( self.glee_CachedNavArea ) then
        self:CacheNavArea()

    end
    return self.glee_CachedNavArea, self.glee_SqrDistToCachedNavArea

end

function plyMeta:CacheNavArea()
    local myPos = self:GetPos()
    if not util_IsInWorld( myPos ) then
        self.glee_CachedNavArea = nil
        self.glee_SqrDistToCachedNavArea = math.huge
        return

    end
    local area = navmesh.GetNearestNavArea( myPos, true, navCheckDist, false, true )

    self.glee_CachedNavArea = area
    if area then
        self.glee_SqrDistToCachedNavArea = myPos:DistToSqr( area:GetClosestPointOnArea( myPos ) )

        local oldArea = self.glee_CachedOldNavArea
        if oldArea and oldArea ~= area then
            hook.Run( "glee_ply_changednavareas", self, oldArea, newArea )
            self.glee_CachedOldNavArea = area

        elseif not oldArea then
            self.glee_CachedOldNavArea = area

        end
    else
        self.glee_SqrDistToCachedNavArea = math.huge

    end
end


-- manage the BPM of ppl HERE

function GM:calculateBPM( cur, players )
    local hasNavmesh = self.hasNavmesh
    local punishEscapingBool = punishEscaping:GetBool()
    local hunters = self.glee_Hunters
    for _, ply in ipairs( players ) do
        local plyHealth = ply:Health()
        if plyHealth <= 0 then
            if istable( ply.BPMHistoric ) then
                ply.BPMHistoric = nil

            end
            if ply.historicBPMDecrease then
                ply.historicBPMDecrease = nil

            end
            ply:SetNWInt( "termHuntPlyBPM", 0 )
            ply:SetNWBool( "termHuntBlockScoring", false )

            return

        end

        local plyPos = ply:GetShootPos()
        local plysMoveType = ply:GetMoveType()
        local nearestHunter = self:getNearestHunter( plyPos, hunters )
        local nextDistancePosSave = ply.nextDistancePosSave or 0
        local directlyUnderneathArea, distToAreaSqr = ply:GetNavAreaData()

        local canSee = nil
        local targetted = nil
        local mentosDist = math.huge
        local nearestHunterScaryness = 0

        -- fun variables
        ply.huntersGleeHunterThatIsTargetingPly = nil
        ply.huntersGleeHunterThatCanSeePly = nil
        ply.huntersGleeNearestHunterToPly = nil

        if IsValid( nearestHunter ) then
            ply.huntersGleeNearestHunterToPly = nearestHunter
            hook.Run( "glee_hunter_nearbyaply", nearestHunter, ply )

            -- is player inside mentos shaped volume?????
            -- means less score if ply is simply above enemy
            local mentosShapedDistance = nearestHunter:EyePos() - plyPos
            mentosShapedDistance.z = mentosShapedDistance.z / 2

            nearestHunterScaryness = self:GetBotScaryness( ply, nearestHunter )

            mentosDist = mentosShapedDistance:Length()

            if nearestHunter.TerminatorNextBot then
                canSee = nearestHunter.IsSeeEnemy
                targetted = nearestHunter:GetEnemy() == ply
            else
                canSee = terminator_Extras.PosCanSee( nearestHunter:EyePos(), plyPos )
                targetted = canSee

            end

            if targetted then
                ply.huntersGleeHunterThatIsTargetingPly = nearestHunter

            end
            if canSee then
                nearestHunter.glee_SeeEnemy = cur + 2
                ply.huntersGleeHunterThatCanSeePly = nearestHunter

            end
        end

        -- don't give movement score if player is walking in tight circles
        if nextDistancePosSave < cur then
            ply.nextDistancePosSave = cur + 1
            local plyPositions = ply.plyPositions or {}
            table.insert( plyPositions, plyPos )

            if #plyPositions >= 25 then -- x second delay
                --debugoverlay.Cross( plyPositions[1], 5, 5, Color( 255,255,255 ), true )
                ply.oldDistanceToOldPosition = plyPositions[1]:Distance( plyPos ) -- laggy :distance()!
                --print( distanceToOldPosition )
                table.remove( plyPositions, 1 )

            end

            ply.plyPositions = plyPositions

        end

        distanceToOldPosition = ply.oldDistanceToOldPosition or math.huge

        local nextBPMCalc = ply.nextBPMCalc or 0

        if nextBPMCalc > cur then return end

        ply.nextBPMCalc = cur + math.random( 0.15, 0.25 )

        local restingBPM = restingBPMPermanent

        -- for making resting bpm bigger
        local restingBpmScale = hook.Run( "huntersglee_restingbpmscale", ply ) or 1
        restingBPM = restingBPM * restingBpmScale

        local mentosBPM = 0
        if mentosDist < 2000 then
            -- magic numbers that make distance to hunter bpm feel good
            local rawScalar = math.abs( mentosDist - 2000 ) / 42
            local bpmRampup = math.Clamp( rawScalar, 15, 50 )
            mentosBPM = 10 + bpmRampup
            mentosBPM = mentosBPM * nearestHunterScaryness

        end

        local targettedBPM = 0
        local canSeeBPM = 0

        if canSee then
            canSeeBPM = 10 * nearestHunterScaryness
        end
        if targetted then
            targettedBPM = 8 * nearestHunterScaryness
        end

        -- here's the check that stops free bpm for running in circles
        local coveringNewGround = distanceToOldPosition > 2000
        local speedBPMMul = 1
        if not coveringNewGround then
            speedBPMMul = 0.05

        end

        local plyVel = ply:GetVelocity()
        local plySpeed = plyVel:Length()
        local fallingForever = plySpeed > 2000
        if fallingForever then
            local foreverTr = {
                start = plyPos,
                endpos = plyPos + plyVel * 1000,
                mask = MASK_NPCWORLDSTATIC,
                maxs = airCheckHull,
                mins = -airCheckHull,
            }
            local foreverResult = util.TraceHull( foreverTr )
            fallingForever = not foreverResult.hit

        end

        local tDat = {
            start = plyPos + tStartOffset,
            endpos = plyPos + belowOffset,
            mask = MASK_NPCWORLDSTATIC,
            maxs = airCheckHull,
            mins = -airCheckHull,
        }
        local closeToGround = util.TraceHull( tDat ).Hit
        local onArea = nil

        -- definitely not on the navmesh.
        if directlyUnderneathArea and distToAreaSqr > distWayTooFarOffNavmesh then
            onArea = false

        -- cheap
        elseif directlyUnderneathArea and distToAreaSqr < distNeededToBeOnArea and directlyUnderneathArea:Contains( plyPos ) then
            onArea = directlyUnderneathArea:IsValid()

        -- not cheap
        elseif directlyUnderneathArea and directlyUnderneathArea:IsValid() then
            -- only check horizontal, sometimes navareas end up underneath floors
            local closestPos = directlyUnderneathArea:GetClosestPointOnArea( plyPos )
            local highestZ = math.max( closestPos.z, plyPos.z )
            local lowestZ = math.min( closestPos.z, plyPos.z )
            closestPos.z = highestZ
            plyPos.z = highestZ

            local plyCanSeeArea = posCanSeeComplex( plyPos, closestPos, ply, MASK_SOLID_BRUSHONLY )

            -- handle "directly under navmeshed displacement floor" edge case
            closestPos.z = highestZ + 25
            plyPos.z = lowestZ + 25

            -- catch people behind displacements
            onArea = plyCanSeeArea and posCanSeeComplex( closestPos, plyPos, ply, MASK_SOLID_BRUSHONLY )

        end

        local onLadder = plysMoveType == MOVETYPE_LADDER
        local doBpmDecrease = false
        local blockScore = false

        -- if there's no valid area AND we are on the ground, then block
        local somewhereWrong = ( not onArea ) and closeToGround
        somewhereWrong = somewhereWrong or fallingForever

        if somewhereWrong then
            blockScore = true
            doBpmDecrease = true
            if not terminator_Extras.IsLivePatching then
                terminator_Extras.dynamicallyPatchPos( ply:GetPos() )

            end
        end
        if onLadder then
            blockScore = true
            doBpmDecrease = true

        end

        local bpmPerSpeed = 0.05 * speedBPMMul
        local speedBPM = plySpeed * bpmPerSpeed

        local initialScale = 1
        local nonRestingScale = hook.Run( "termhunt_scaleaddedbpm", ply, initialScale ) or initialScale

        local scaredBpm = mentosBPM + canSeeBPM + targettedBPM
        local speedAndScaredBPM = ( speedBPM + scaredBpm ) * nonRestingScale

        local minBPMHealth = 0
        if plyHealth <= 1 then
            minBPMHealth = 35

        elseif plyHealth <= 5 then
            minBPMHealth = 10

        elseif plyHealth <= 15 then
            minBPMHealth = 5

        end
        speedAndScaredBPM = math.Clamp( speedAndScaredBPM, minBPMHealth, math.huge )

        local idealBPM = restingBPM + speedAndScaredBPM
        idealBPM = math.Round( idealBPM )

        -- reward people who get high bpm with long-lasting bpm increase
        local BPMHistoric = ply.BPMHistoric or { idealBPM }
        table.insert( BPMHistoric, idealBPM )
        local historySize = 120
        if table.Count( BPMHistoric ) > historySize then
            -- munch
            for _ = 1, math.abs( table.Count( BPMHistoric ) - historySize ) do
                table.remove( BPMHistoric, 1 )
            end
        end

        local extent = 0
        local additive = 0
        -- add up historic bpm for math later
        for _, curHistoricBPM in ipairs( BPMHistoric ) do
            extent = extent + 1
            additive = additive + curHistoricBPM
        end

        -- if we have panic then bpm matches the panic
        local activitySpikeBPM = ( idealBPM / 2 ) + scaredBpm
        local panicBpmComponent = math.Clamp( self:GetPanic( ply ), 0, 110 )
        activitySpikeBPM = math.Clamp( activitySpikeBPM, panicBpmComponent, math.huge )

        -- start out with historic bpm
        local BPM = additive / extent
        -- then bring it up to the activity spike
        BPM = math.Round( math.Clamp( BPM, activitySpikeBPM, math.huge ) )
        ply.BPMHistoric = BPMHistoric

        -- when ply is off navmesh, slowly sap their life
        if doBpmDecrease and punishEscapingBool then
            local damaged
            local exceptionMovement = plysMoveType == MOVETYPE_NOCLIP or plyHealth <= 0 or ply:GetObserverMode() ~= OBS_MODE_NONE or ply:InVehicle()
            if not exceptionMovement and hasNavmesh then
                local BPMDecrease = ply.historicBPMDecrease or 0
                local added = 2
                if onLadder then
                    added = 0.5

                elseif fallingForever then
                    added = 8
                    self:GivePanic( ply, 25 )

                end
                ply.historicBPMDecrease = BPMDecrease + added

                BPM = math.Clamp( BPM + -BPMDecrease, 0, math.huge )
                BPM = math.Round( BPM )

                if BPM < restingBPMPermanent then
                    self:GivePanic( ply, 3 )

                end
                if BPM < restingBPMPermanent and BPMDecrease > restingBPMPermanent * 2 then
                    local divisor = 100
                    if BPMDecrease > restingBPMPermanent * 4 then
                        divisor = 10
                    elseif BPMDecrease > restingBPMPermanent * 3 then
                        divisor = 50
                    end
                    local damage = math.ceil( ply:GetMaxHealth() / divisor )
                    ply:TakeDamage( damage, game.GetWorld(), game.GetWorld() )
                    huntersGlee_Announce( { ply }, 100, 2.5, "Something is off.\nIt feels like you're somewhere wrong..." )

                    damaged = true

                end
            end
            -- simple fix!
            if damaged and self:IsUnderDisplacementExtensive( plyPos ) then
                ply:BeginUnstuck()

            end
        -- ramp down and then cleanup the decrease
        elseif ply.historicBPMDecrease then
            local BPMDecrease = ply.historicBPMDecrease
            if BPMDecrease and BPMDecrease > 0 then
                ply.historicBPMDecrease = ply.historicBPMDecrease + -1

            elseif BPMDecrease and BPMDecrease <= 0 then
                ply.historicBPMDecrease = nil

            end
        end

        ply:SetNWInt( "termHuntPlyBPM", BPM )
        ply:SetNWBool( "termHuntBlockScoring", blockScore )

        local heartAttackScore = ply.glee_HeartAttackScore or 0
        if heartAttackScore > 0 then
            self:DoHeartAttackThink( ply )

        end
    end
end

function GM:manageServersideCountOfBeats() -- actual firing, beating of beats, do the calculations for "beats per minute", slowly and above
    local players = player.GetAll()
    for _, ply in ipairs( players ) do
        local plysTbl = entMeta.GetTable( ply )
        -- scoring
        local BPM = entMeta.GetNWInt( ply, "termHuntPlyBPM" )
        -- block score, eg player is not on navmesh, or is on ladder
        local blockingScore = entMeta.Health( ply ) <= 0 or entMeta.GetNWBool( ply, "termHuntBlockScoring" ) or entMeta.GetNWBool( ply, "termHuntBlockScoring2" ) -- wow 2 of them
        if BPM > 1 and not blockingScore then

            -- get when we should do the next beat, it's this way instead of a timer so that if bpm gets super fast super quick, the actual new time between beats is respected
            local beatTime = math.Clamp( 60 / BPM, 0, math.huge )
            local lastBeat = plysTbl.lastBeatTime or 0
            local doServersideBeat = ( lastBeat + beatTime ) < CurTime()

            if doServersideBeat and GAMEMODE.canScore then
                plysTbl.lastBeatTime = CurTime()
                local scoreGiven = 1
                ply:GivePlayerScore( scoreGiven )

                hook.Run( "huntersglee_heartbeat_scoringbeat", ply )

            end
        end

        -- actual count of beats, not just when player is in scorable areas
        local RealBPMClamped = math.Clamp( BPM, 0, math.huge )

        if RealBPMClamped > 1 then
            local realBeatTime = math.Clamp( 60 / RealBPMClamped, 0, math.huge )
            local realLastBeat = plysTbl.lastRealBeatTime or 0
            local doServersideRealBeat = ( realLastBeat + realBeatTime ) < CurTime()

            if doServersideRealBeat then
                plysTbl.lastRealBeatTime = CurTime()
                local oldBeats = plysTbl.realHeartBeats or 0
                plysTbl.realHeartBeats = oldBeats + 1

                hook.Run( "huntersglee_heartbeat_beat", ply, RealBPMClamped )

            end
        end
    end
end


-- used by hunts tally
hook.Add( "huntersglee_givescore", "huntersglee_storealivescoring", function( scorer, addedscore )
    if not IsValid( scorer ) then return end
    if scorer:Health() <= 0 then return end
    if addedscore < 1 then return end
    if GAMEMODE:RoundState() ~= 1 then return end

    local oldPlyScore = GAMEMODE.roundScore[ scorer:GetCreationID() ] or 0
    GAMEMODE.roundScore[ scorer:GetCreationID() ] = oldPlyScore + addedscore

end )
function GM:DoHeartAttackThink( ply )
    if not IsValid( ply ) then return end
    local nextThink = ply.glee_NextHeartAttackThink or 0
    if nextThink > CurTime() then return end
    ply.glee_NextHeartAttackThink = CurTime() + math.Rand( 0.4, 0.6 )

    local heartAttackScore = ply.glee_HeartAttackScore or 0
    local threshold = GAMEMODE:GetHeartAttackThreshold( ply )

    -- you're done
    if heartAttackScore > threshold then
        heartAttackScore = heartAttackScore + 50

        local damage = ( ply:GetMaxHealth() / 10 ) + ( heartAttackScore / threshold )

        local world = game.GetWorld()
        ply:TakeDamage( damage, world, world )
        if math.random( 0, 100 ) < 50 then
            ply:SetNWInt( "termHuntPlyBPM", 0 )

        end
        GAMEMODE:GivePanic( ply, 50 )

    elseif heartAttackScore > threshold * 0.533 then
        heartAttackScore = heartAttackScore + 4
        GAMEMODE:GivePanic( ply, 12 )

    elseif heartAttackScore > threshold * math.Rand( 0.3, 0.4 ) then
        heartAttackScore = heartAttackScore + -0.5
        GAMEMODE:GivePanic( ply, 6 )

    else
        heartAttackScore = heartAttackScore + -2
        if not ply.glee_HasHeartAttackWarned then
            huntersGlee_Announce( { ply }, 5, 5, "You feel a deep, sharp pain..." )
            GAMEMODE:GivePanic( ply, 50 )
            ply.glee_HasHeartAttackWarned = true

        end
    end
end

function GM:GetHeartAttackThreshold( ply )
    local heartAttackBpm = defaultHeartAttackBpm
    local hookHeartAttackBpm = hook.Run( "huntersglee_getheartattackbpm", ply )
    if isnumber( hookHeartAttackBpm ) then
        heartAttackBpm = hookHeartAttackBpm

    end

    return heartAttackBpm

end

hook.Add( "huntersglee_heartbeat_beat", "glee_heartattack_think", function( ply, BPM )
    local threshold = GAMEMODE:GetHeartAttackThreshold( ply )
    if BPM > threshold then
        local added = math.abs( BPM - threshold )
        added = added / 4
        local oldScore = ply.glee_HeartAttackScore or 0
        ply.glee_HeartAttackScore = oldScore + added
        GAMEMODE:GivePanic( ply, ply.glee_HeartAttackScore )

    elseif BPM > bpmStartScreamingLikeCrazy then
        GAMEMODE:GivePanic( ply, 5 )

    end
end )


hook.Add( "PlayerDeath", "glee_resetbeatstuff", function( ply )
    ply.BPMHistoric = nil
    ply:SetNWInt( "termHuntPlyBPM", restingBPMPermanent )
    ply.glee_HasHeartAttackWarned = nil
    ply.glee_HeartAttackScore = nil

end )


hook.Add( "huntersglee_player_into_active", "glee_yaponroundstart", function( ply )
    if math.random( 0, 100 ) > 100 then return end -- 25% chance to play a line
    if player.GetCount() < 5 then return end -- only when it's PACKED!
    if GAMEMODE:GetPanic( ply ) > 25 then return end

    local line = GAMEMODE:GetRandModelLine( ply, "onRoundStart" )
    if not line then return end

    timer.Simple( math.Rand( 5, 15 ), function()
        if not IsValid( ply ) then return end
        if ply:Health() <= 0 then return end
        ply:EmitSound( line, 75, math.random( 99, 101 ), 1, CHAN_AUTO )

    end )
end )


GM.TEAM_PLAYING = 1
GM.TEAM_SPECTATE = 2

function GM:spectatifyPlayer( ply )
    ply:SetNWBool( "termhunt_spectating", true )
    ply:Spectate( OBS_MODE_DEATHCAM )

    ply.spectateDoFreecam = CurTime() + 8
    ply.spectateDoFreecamForced = CurTime() + 2
    ply.termHuntTeam = GAMEMODE.TEAM_SPECTATE

end

function GM:unspectatifyPlayer( ply )
    if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then return end

    ply.spectateDoFreecam = nil
    ply.spectateDoFreecamForced = nil
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING

    ply:SetNWBool( "termhunt_spectating", false )
    ply:UnSpectate()
    ply.overrideSpawnAction = true

end

function GM:ensureNotSpectating( ply ) -- this is kinda redundant
    if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then return end

    ply.spectateDoFreecam = nil
    ply.spectateDoFreecamForced = nil
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING

    ply:SetNWBool( "termhunt_spectating", false )
    ply:UnSpectate()

    if ply:Health() <= 0 then return end
    ply:KillSilent()

end

local isMovementKey

do
    local movementKeys = {
        [IN_ATTACK] = true,
        [IN_FORWARD] = true,
        [IN_BACK] = true,
        [IN_MOVELEFT] = true,
        [IN_MOVERIGHT] = true,
    }

    isMovementKey = function( keyPressed )
        return movementKeys[keyPressed]

    end
end

local function shutDownDeathCam( ply )
    ply.spectateDoFreecam = math.huge
    ply.spectateDoFreecamForced = math.huge

end

function GM:SpectateThing( ply, thing, msg )
    ply:SpectateEntity( thing )
    local newMode = OBS_MODE_CHASE
    if ply:GetObserverMode() == OBS_MODE_IN_EYE then
        newMode = OBS_MODE_IN_EYE

    end
    ply:SetObserverMode( newMode )
    if IsValid( thing ) then
        ply:SetParent( thing ) -- fixes alot of flashing light visual bugs
        ply:SetPos( thing:WorldSpaceCenter() )

    end
    msg = msg or "glee_followedsomething"
    net.Start( msg )
    net.Send( ply )

end

function GM:StopSpectatingThing( ply )
    local target = ply:GetObserverTarget()
    ply:SetObserverMode( OBS_MODE_ROAMING )
    if IsValid( ply:GetParent() ) then
        ply:SetParent( NULL )

    end
    if IsValid( target ) and target.GetShootPos then
        ply:SetPos( target:GetShootPos() )

    end

    net.Start( "glee_stoppedspectating" )
    net.Send( ply )

    local oldAng = ply:GetAngles()
    timer.Simple( 0.0, function()
        if not IsValid( ply ) then return end
        ply:SetAngles( Angle( oldAng.p, oldAng.y, 0 ) )
    end )
end

local nextSpectateIdleCheck = {}

-- if placing
    -- if following player, unfollow
    -- do nothing otherwise

-- elseif its been >0.5s since we were last placing ( stops peoples camera snapping to players right after they place stuff and havent let go of key )
    -- if left click
        --if not following ply, then follow nearest alive player
        --if following player, follow next alive player
    -- if right click
        -- if following ply
            -- switch between OBS_MODE_CHASE and OBS_MODE_IN_EYE

local function DoKeyPressSpectateSwitch( ply, keyPressed )
    if not SERVER then return end
    if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then return end
    local mode = ply:GetObserverMode()

    local followingThing = mode == OBS_MODE_CHASE or mode == OBS_MODE_IN_EYE
    local deathCamming = mode == OBS_MODE_DEATHCAM

    nextSpectateIdleCheck[ply] = CurTime() + 0.1

    local placing = ply.ghostEnt
    local actionTime = ply.glee_ghostEntActionTime or 0
    local wasGhostEnting = actionTime + 0.25 > CurTime()
    if IsValid( placing ) or wasGhostEnting then return end

    local spectated = nil
    local currentlySpectating = ply:GetObserverTarget()

    if deathCamming then
        if isMovementKey( keyPressed ) and ply.spectateDoFreecamForced < CurTime() then
            shutDownDeathCam( ply )
            GAMEMODE:StopSpectatingThing( ply )

        end
        if ply.spectateDoFreecam > CurTime() then return end

        shutDownDeathCam( ply )
        if ply.glee_KillerToSpectate then
            spectated = ply.glee_KillerToSpectate
            GAMEMODE:SpectateThing( ply, spectated )

            ply.glee_KillerToSpectate = nil

        else
            GAMEMODE:StopSpectatingThing( ply )

        end
    elseif keyPressed == IN_ATTACK or keyPressed == IN_ATTACK2 then
        local direction
        if keyPressed == IN_ATTACK then
            direction = 1

        elseif keyPressed == IN_ATTACK2 then
            direction = -1

        end
        local players = player.GetAll()
        local alivePlayers = GAMEMODE:returnAliveInTable( players )
        local protoStuffToSpectate = alivePlayers
        table.Add( protoStuffToSpectate, table.Copy( GAMEMODE.glee_Hunters ) )

        local stuffToSpectate = {}
        for _, thing in ipairs( protoStuffToSpectate ) do
            if IsValid( thing ) and thing:Health() >= 0 and thing ~= ply then
                table.insert( stuffToSpectate, thing )
            end
        end

        -- go to next player
        if followingThing then
            local toSpectateCheck = table.Copy( stuffToSpectate )
            if direction == -1 then
                toSpectateCheck = table.Reverse( stuffToSpectate )

            end
            local thingToFollow = toSpectateCheck[1] -- default to first in list
            local hitTheCurrent
            for _, thing in ipairs( toSpectateCheck ) do -- find after current thing
                if hitTheCurrent then
                    thingToFollow = thing
                    break

                elseif thing == currentlySpectating then
                    hitTheCurrent = true

                end
            end
            if thingToFollow then
                GAMEMODE:SpectateThing( ply, thingToFollow, "glee_followednexthing" )
                spectated = thingToFollow
                currentlySpectating = thingToFollow

            end

        -- not following player, follow what we're looking at, or nearest player
        else
            local thingToFollow = nil
            local eyeTrace = ply:GetEyeTrace()
            local eyeTraceHit = eyeTrace.Entity
            if IsValid( eyeTraceHit ) and eyeTraceHit:IsPlayer() or eyeTraceHit:IsNextBot() or eyeTraceHit:IsNPC() then
                thingToFollow = eyeTraceHit

            else
                if #stuffToSpectate <= 0 then return end
                local sortedStuffToSpectate = table.Copy( stuffToSpectate )
                local sortPos = ply:GetPos()
                if eyeTrace.Hit then
                    sortPos = eyeTrace.HitPos

                end

                table.sort( sortedStuffToSpectate, function( a, b ) -- sort followable stuff by distance to pos
                    local ADist = a:EyePos():DistToSqr( sortPos )
                    local BDist = b:EyePos():DistToSqr( sortPos )
                    return ADist < BDist

                end )

                thingToFollow = sortedStuffToSpectate[1]

            end

            if thingToFollow then
                spectated = thingToFollow
                GAMEMODE:SpectateThing( ply, spectated )

            end
        end
    elseif isMovementKey( keyPressed ) then
        if followingThing then
            GAMEMODE:StopSpectatingThing( ply )

        end
    elseif keyPressed == IN_JUMP then
        if followingThing then
            net.Start( "glee_switchedspectatemodes" )
            net.Send( ply )
            if mode == OBS_MODE_CHASE then
                ply:SetObserverMode( OBS_MODE_IN_EYE )

            elseif mode == OBS_MODE_IN_EYE then
                ply:SetObserverMode( OBS_MODE_CHASE )

            end
        end
    elseif followingThing and currentlySpectating.Health and currentlySpectating:Health() <= 0 then
        GAMEMODE:StopSpectatingThing( ply )

        local toWatch
        local time

        if currentlySpectating.glee_KillerToSpectate then
            toWatch = currentlySpectating.glee_KillerToSpectate
            time = 2

        else
            time = math.random( 10, 15 )

        end

        local afkCheckPos = ply:GetPos()

        timer.Simple( time, function()
            if not IsValid( ply ) then return end -- lol ragequit
            if ply:Health() > 0 then return end
            if ply:GetPos():Distance( afkCheckPos ) > 25 then return end

            toWatch = IsValid( toWatch ) and toWatch or GAMEMODE:anotherAlivePlayer( ply )
            if not IsValid( toWatch ) then return end -- everyone is dead

            GAMEMODE:SpectateThing( ply, toWatch )

        end )
    end

    if IsValid( spectated ) then
        if spectated.Nick and isstring( spectated:Nick() ) then
            huntersGlee_Announce( { ply }, 1, 1.5, "Spectating " .. spectated:Nick() .. "." )

        else
            huntersGlee_Announce( { ply }, 1, 1.5, "Spectating " .. GAMEMODE:GetNameOfBot( spectated ) )

        end
    end
end

hook.Add( "KeyPress", "glee_SwitchSpectateModes", DoKeyPressSpectateSwitch )

hook.Add( "glee_sv_validgmthink", "glee_SwitchSpectateModes", function( players )
    for _, ply in ipairs( players ) do
        local nextIdle = nextSpectateIdleCheck[ply] or 0
        if nextIdle < CurTime() then
            DoKeyPressSpectateSwitch( ply, 0 )

        end
    end
end )

function GM:SpectateOverrides( ply, mode, deadPlayers )
    local placing = ply.ghostEnt

    local isPlacing = IsValid( placing )

    if GAMEMODE.canRespawn == true then
        GAMEMODE:ensureNotSpectating( ply )
        return

    end
    if isPlacing and mode ~= OBS_MODE_ROAMING then -- stop following something, they're placing stuff!
        self:StopSpectatingThing( ply )

    end
    local followingThing = mode == OBS_MODE_CHASE or mode == OBS_MODE_IN_EYE
    if followingThing then
        local target = ply:GetObserverTarget()
        if not IsValid( target ) then
            self:StopSpectatingThing( ply )

        end
    end

    local pos = ply:GetPos()

    net.Start( "glee_sendtruesoullocations", true )
        net.WriteEntity( ply )
        net.WriteVector( pos )
        net.WriteAngle( ply:EyeAngles() )
        net.WriteInt( mode, 6 )
        net.WriteEntity( ply:GetObserverTarget() )
    net.Send( deadPlayers )

end

function GM:managePlayerSpectating()
    local deadPlayers = self:getDeadListeners()
    for _, ply in player.Iterator() do
        local newMode = ply:GetObserverMode()
        if ply.termHuntTeam == GAMEMODE.TEAM_SPECTATE then
            GAMEMODE:SpectateOverrides( ply, newMode, deadPlayers )
        elseif newMode > 0 and not ply.gleeIsMimic then -- ply is spectating but their team doesnt match!
            GAMEMODE:ensureNotSpectating( ply )
        end
    end
end

GM.waitForSomeoneToLive = nil

hook.Add( "PlayerDeath", "glee_spectatedeadplayers", function( died, _, killer )
    if not IsValid( killer ) then return end
    if died == killer then return end
    died.glee_KillerToSpectate = killer

end )

hook.Add( "PlayerDeath", "glee_default_waittospawn", function( ply )
    ply.nextForcedRespawn = CurTime() + 0.25

end )

function GM:PlayerDeathThink( ply )
    local hasHp = ply:Health() > 0
    if GAMEMODE.canRespawn == false and not hasHp then
        if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then
            GAMEMODE:spectatifyPlayer( ply )

        end
    elseif GAMEMODE.canRespawn == true or ply.overrideSpawnAction or hasHp then
        local lastForced = ply.nextForcedRespawn or 0

        if lastForced < CurTime() then
            local plys = player.GetAll()
            local aliveCount = GAMEMODE:countAlive( plys )

            -- let 1 person spawn so that the auto placement script can catch up
            if aliveCount == 0 then
                if not GAMEMODE.waitForSomeoneToLive then
                    GAMEMODE.waitForSomeoneToLive = true
                    timer.Simple( 5, function()
                        GAMEMODE.waitForSomeoneToLive = nil
                    end )
                    ply:Spawn()
                    ply.overrideSpawnAction = nil

                    for _, currPly in ipairs( plys ) do
                        currPly.nextForcedRespawn = CurTime() + math.Rand( 0.5, 1 )

                    end
                else return end
            else
                ply:Spawn()
                ply.overrideSpawnAction = nil
                GAMEMODE.waitForSomeoneToLive = nil

            end
        end
    end
end


local spaceCheckUpOffset = Vector( 0,0,64 )
local spaceCheckHull = Vector( 17, 17, 2 )
local occupiedSpawnAreas = {}

function GM:PlayerSpawn( pl, transiton )

    if IsValid( pl:GetParent() ) then
        pl:SetParent( NULL )

    end

    local anotherAlivePlayer = GAMEMODE:anotherAlivePlayer( pl )
    local newPos = nil
    local center, area = nil, nil

    if pl.unstuckOrigin then
        newPos = pl.unstuckOrigin

    elseif IsValid( anotherAlivePlayer ) and not hook.Run( "huntersglee_blockspawn_nearplayers", pl, anotherAlivePlayer ) and GAMEMODE.hasNavmesh then
        for count = 1, 12 do

            local start = anotherAlivePlayer:GetPos()

            center, area = GAMEMODE:GetNearbyWalkableArea( anotherAlivePlayer, start, count )

            if center then

                center = center + Vector( 0,0,10 )
                local tDat = {}
                tDat.start = center
                tDat.endpos = center + spaceCheckUpOffset
                tDat.mask = bit.bor( MASK_SOLID, CONTENTS_PLAYERCLIP )
                tDat.maxs = spaceCheckHull
                tDat.mins = -spaceCheckHull
                local isClear = not util.TraceHull( tDat ).Hit
                local valid = isClear

                if valid then
                    newPos = center
                    break

                end
            end
        end
    -- if map has tp rooms then override spawnpoints
    elseif GAMEMODE.doNotUseMapSpawns and GAMEMODE.biggestNavmeshGroups then
        -- if we aren't the first person spawning, then always spawn us in occupied groups
        if IsValid( anotherAlivePlayer ) then
            local randomUsedArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
            if randomUsedArea and randomUsedArea.IsValid and randomUsedArea:IsValid() then
                newPos = randomUsedArea:GetCenter()

            -- fallback
            else
                newPos = GAMEMODE:FindValidNavAreaCenter( GAMEMODE.biggestNavmeshGroups )

            end
        -- we are first person spawning, use a random group and then everyone will spawn around us
        else
            newPos = GAMEMODE:FindValidNavAreaCenter( GAMEMODE.biggestNavmeshGroups )

        end
    end
    if newPos then
        local offsettedNewPos = newPos + Vector( 0, 0, 15 )
        timer.Simple( engine.TickInterval(), function()
            if not IsValid( pl ) then return end
            pl:TeleportTo( offsettedNewPos )

        end )
        -- look at other ply so its easy to find eachother
        timer.Simple( engine.TickInterval() * 2, function()
            if not IsValid( pl ) then return end
            if not IsValid( anotherAlivePlayer ) then return end
            local dirToMainPlayer = terminator_Extras.dirToPos( pl:GetShootPos(), anotherAlivePlayer:GetShootPos() )
            local ang = dirToMainPlayer:Angle()
            pl:SetEyeAngles( ang )

        end )
        -- dont put another player here!
        if area then
            local id = area:GetID()
            occupiedSpawnAreas[id] = true
            timer.Simple( 5, function()
                occupiedSpawnAreas[id] = nil

            end )
        end
    end

    -- Stop observer mode
    GAMEMODE:unspectatifyPlayer( pl )

    player_manager.OnPlayerSpawn( pl, transiton )
    player_manager.RunClass( pl, "Spawn" )

    -- If we are in transition, do not touch player's weapons
    if ( !transiton ) then
        -- Call item loadout function
        hook.Call( "PlayerLoadout", GAMEMODE, pl )
    end

    -- Set player model
    hook.Call( "PlayerSetModel", GAMEMODE, pl )

    pl:SetupHands()

    GAMEMODE.deadPlayers[pl:GetCreationID()] = nil

end

-- dont spawn players in spots that people died.
hook.Add( "PlayerDeath", "glee_dontspawnindeadspots", function( died, inflic, attacker )
    if died == attacker then return end

    local nearestNav = GAMEMODE:getNearestPosOnNav( died:GetPos(), 2000 )

    if not nearestNav or not nearestNav.IsValid or not nearestNav:IsValid() then return end
    local id = nearestNav:GetID()

    occupiedSpawnAreas[id] = true
    timer.Simple( 25, function()
        occupiedSpawnAreas[id] = nil

    end )
end )

function GM:IsSpawnpointSuitable()
    return true

end

function GM:PlayerInitialSpawn( ply )
    player_manager.SetPlayerClass( ply, "player_termrunner" )
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING

end

hook.Add( "PlayerDeath", "glee_DropScoreOnSuicide", function( victim, inflictor, attacker )
    if victim ~= inflictor or victim ~= attacker then return end-- not a suicide

    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

    local theirScore = victim:GetScore()
    scoreToDrop = theirScore / 4
    if scoreToDrop < 10 then return end

    scoreToDrop = math.ceil( scoreToDrop )

    victim:GivePlayerScore( -scoreToDrop )
    huntersGlee_Announce( { victim }, 1, 5, "You've suicided.\n" .. scoreToDrop .. " score is left behind." )

    while scoreToDrop > 0 do
        local droppedBall = ents.Create( "termhunt_score_pickup" )
        droppedBall:SetPos( victim:GetPos() + vector_up * 25 )

        local theBallsScore = math.Clamp( scoreToDrop, 0, math.random( 90, 110 ) )
        scoreToDrop = scoreToDrop + -theBallsScore
        droppedBall:SetScore( theBallsScore )
        droppedBall:Spawn()

        if IsValid( droppedBall:GetPhysicsObject() ) then
            droppedBall:GetPhysicsObject():SetVelocity( VectorRand() * math.random( 10, 30 ) )

        end
    end
end )

local goodPickupClasses = {
    ["weapon_frag"] = true,
    ["weapon_slam"] = true,

}

hook.Add( "PlayerUse", "useToAllowDoublePickup", function( user, used )
    if not used:IsWeapon() then return end
    used.glee_bypassPickupBlock = CurTime() + 0.5

end )

hook.Add( "PlayerCanPickupWeapon", "noDoublePickup", function( ply, weapon )
    local class = weapon:GetClass()
    if goodPickupClasses[class] then return true end
    if weapon.huntersglee_allowpickup then return true end
    if ply:HasWeapon( class ) then
        local bypassPickupBlock = weapon.glee_bypassPickupBlock or 0
        local usedTheWeapon = bypassPickupBlock > CurTime()

        local theWeapTheyHave = ply:GetWeapon( class )
        local theWeapsAmmo = theWeapTheyHave:GetPrimaryAmmoType()
        -- no ammo!?!?!
        if theWeapsAmmo == -1 or not theWeapsAmmo then return false end
        local ammoCount = ply:GetAmmoCount( theWeapsAmmo )

        if ammoCount == 0 or usedTheWeapon then
            return true

        else
            return false

        end
    end
end )

hook.Add( "EntityTakeDamage", "huntersglee_makepvpreallybad", function( dmgTarg, dmg )
    local attacker = dmg:GetAttacker()
    local inflictor = dmg:GetInflictor()
    local areBothPlayers = dmgTarg:IsPlayer() and attacker:IsPlayer()
    local selfDamage = dmgTarg == attacker
    if areBothPlayers and GAMEMODE.blockPvp == true then
        dmg:ScaleDamage( 0 )

    elseif areBothPlayers and not selfDamage and not dmg:IsExplosionDamage() then --lol explode
        if dmg:IsDamageType( DMG_DISSOLVE ) and inflictor and inflictor:GetClass() == "prop_combine_ball" then
            local nextpermittedballdamage = dmgTarg.huntersglee_nextpermittedballdamage or 0
            if nextpermittedballdamage > CurTime() then
                dmg:ScaleDamage( 0 )
                return

            end
            dmgTarg.huntersglee_nextpermittedballdamage = CurTime() + 0.5

            dmg:SetDamage( dmgTarg:GetMaxHealth() * 0.9 )
            dmg:SetDamageForce( dmg:GetDamageForce() * 12 )
            dmgTarg:EmitSound( "NPC_CombineBall.KillImpact" )

            damagedplayercount = inflictor.huntersglee_ball_damagedplayercount or 0
            inflictor.huntersglee_ball_damagedplayercount = damagedplayercount + 1

            if inflictor.huntersglee_ball_damagedplayercount >= 6 then
                inflictor:Fire( "Explode" )

            end
        else
            dmg:ScaleDamage( 0.5 )

        end
    end
end )


hook.Add( "glee_sv_validgmthink", "glee_cachenavareas", function( players )
    for _, ply in ipairs( players ) do
        if ply:Health() > 0 then
            ply:CacheNavArea()

        end
    end
end )

function GM:HasHomicided( homicider, homicided )
    local allHomicides = GAMEMODE.roundExtraData.homicides or {}
    -- breaks on bots!
    -- all bots have same steamid!
    local homicidersCides = allHomicides[ homicider:SteamID() ]
    if not homicidersCides then return false end
    if homicidersCides[ homicided:SteamID() ] then return true end
    return false

end

hook.Add( "PlayerDeath", "glee_storehomicides", function( died, _, attacker )
    if not IsValid( attacker ) then return end
    if attacker == died then return end
    if not attacker:IsPlayer() then return end
    local attackasId = attacker:SteamID()

    if not GAMEMODE.roundExtraData.homicides then GAMEMODE.roundExtraData.homicides = {} end

    local allHomicides = GAMEMODE.roundExtraData.homicides
    local homicidersCides = allHomicides[ attackasId ] or {}
    homicidersCides[ died:SteamID() ] = true

    GAMEMODE.roundExtraData.homicides[ attackasId ] = homicidersCides

end )


-- maps that spawn players high up....
local hasGrace = {}
hook.Add( "PlayerSpawn", "glee_firstfallgrace", function( ply )
    hasGrace[ply] = true

end )

hook.Add( "OnPlayerHitGround", "glee_firstfallgrace", function( ply )
    if not hasGrace[ply] then return end
    timer.Simple( 0, function()
        hasGrace[ply] = nil

    end )
end )

hook.Add( "EntityTakeDamage", "glee_firstfallgrace", function( victim, dmg )
    if not dmg:IsFallDamage() then return end
    if not hasGrace[victim] then return end

    local maxDamage = victim:Health() + -1
    if dmg:GetDamage() < maxDamage then return end
    dmg:SetDamage( maxDamage )
    GAMEMODE:GivePanic( victim, maxDamage )

end )