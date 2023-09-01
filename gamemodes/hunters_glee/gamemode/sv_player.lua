local IsValid = IsValid

local punishEscaping = CreateConVar( "huntersglee_punish_navmesh_escapers", 1, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Should the life of players who tread off the navmesh be sapped away?.", 0, 32 )

local navCheckDist = 150
local belowOffset = Vector( 0, 0, -navCheckDist )
local tStartOffset = Vector( 0, 0, -2 )
local airCheckHull = Vector( 17, 17, 1 )
local restingBPMPermanent = 60 -- needs to match clientside var too

local plyMeta = FindMetaTable( "Player" )
local distNeededToBeOnArea = 25^2
local posCanSee = GM.posCanSee

-- manage the BPM of ppl HERE

function GM:calculateBPM( cur, players )
    local hasNavmesh = GAMEMODE.hasNavmesh
    local punishEscapingBool = punishEscaping:GetBool()
    local hunters = table.Copy( GAMEMODE.termHunt_hunters )
    for _, ply in ipairs( players ) do
        if ply:Alive() then
            local plyPos = ply:GetShootPos()
            local plysMoveType = ply:GetMoveType()
            local nearestHunter = GAMEMODE:getNearestHunter( plyPos, hunters )
            local nextDistancePosSave = ply.nextDistancePosSave or 0
            local directlyUnderneathArea, distToAreaSqr = ply:GetNavAreaData()

            local canSee = nil
            local targetted = nil
            local mentosDist = math.huge

            -- fun variables
            ply.huntersGleeHunterThatIsTargetingPly = nil
            ply.huntersGleeHunterThatCanSeePly = nil
            ply.huntersGleeNearestHunterToPly = nil

            if IsValid( nearestHunter ) then

                ply.huntersGleeNearestHunterToPly = nearestHunter

                -- is player inside mentos shaped volume?????
                local mentosShapedDistance = nearestHunter:GetShootPos() - plyPos
                mentosShapedDistance.z = mentosShapedDistance.z / 2

                mentosDist = mentosShapedDistance:Length()
                canSee = nearestHunter.IsSeeEnemy
                targetted = nearestHunter:GetEnemy() == ply

                if targetted then
                    ply.huntersGleeHunterThatIsTargetingPly = nearestHunter

                end
                if canSee then
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

            local initialRestingScale = 1
            -- make resting bpm bigger
            local restingBpmScale = hook.Run( "termhunt_restingbpmscale", ply, initialRestingScale ) or initialRestingScale

            local restingBPM = restingBPMPermanent * restingBpmScale
            local mentosBPM = 0
            if mentosDist < 2000 then
                -- magic numbers that make distance to hunter bpm feel good
                local rawScalar = math.abs( mentosDist - 2000 ) / 42
                local bpmRampup = math.Clamp( rawScalar, 15, 50 )
                mentosBPM = 10 + bpmRampup

            end

            local targettedBPM = 0
            local canSeeBPM = 0

            if canSee then
                canSeeBPM = 10
            end
            if targetted then
                targettedBPM = 8
            end

            -- here's the check that stops free bpm for running in circles
            local coveringNewGround = distanceToOldPosition > 2000
            local speedBPMMul = 1
            if not coveringNewGround then
                speedBPMMul = 0.05

            end

            local tDat = {}
            tDat.start = plyPos + tStartOffset
            tDat.endpos = plyPos + belowOffset
            tDat.mask = MASK_NPCWORLDSTATIC
            tDat.maxs = airCheckHull
            tDat.mins = -airCheckHull
            local closeToGround = util.TraceHull( tDat ).Hit
            local onArea = nil

            -- cheap
            if directlyUnderneathArea and distToAreaSqr < distNeededToBeOnArea then
                onArea = directlyUnderneathArea:IsValid()

            -- not cheap
            elseif directlyUnderneathArea and directlyUnderneathArea:IsValid() then
                local plysShootPos = ply:GetShootPos()
                -- only check horisontal, sometimes navareas end up underneath floors
                local closestPos = directlyUnderneathArea:GetClosestPointOnArea( plysShootPos )
                closestPos.z = plysShootPos.z

                onArea = posCanSee( _, plysShootPos, closestPos, MASK_SOLID_BRUSHONLY )

            end

            local onLadder = plysMoveType == MOVETYPE_LADDER
            local doBpmDecrease = false
            local blockScore = false

            -- if there's no valid area AND we are on the ground, then block
            if ( not onArea ) and closeToGround then
                blockScore = true
                doBpmDecrease = true

            end
            if onLadder then
                blockScore = true
                doBpmDecrease = true

            end

            local bpmPerSpeed = 0.05 * speedBPMMul
            local speedBPM = ply:GetVelocity():Length() * bpmPerSpeed

            local initialScale = 1
            local nonRestingScale = hook.Run( "termhunt_scaleaddedbpm", ply, initialScale ) or initialScale

            local scaredBpm = mentosBPM + canSeeBPM + targettedBPM
            local speedAndScaredBPM = ( speedBPM + scaredBpm ) * nonRestingScale
            local idealBPM = restingBPM + speedAndScaredBPM
            idealBPM = math.Round( idealBPM )

            if ply:Health() <= 0 then
                ply.BPMHistoric = nil

            end

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
            local panicBpmComponent = math.Clamp( GAMEMODE:GetPanic( ply ), 0, 110 )
            activitySpikeBPM = math.Clamp( activitySpikeBPM, panicBpmComponent, math.huge )

            -- start out with historic bpm
            local BPM = additive / extent
            -- then bring it up to the activity spike
            BPM = math.Round( math.Clamp( BPM, activitySpikeBPM, math.huge ) )
            ply.BPMHistoric = BPMHistoric

            -- when ply is off navmesh, slowly sap their life
            if doBpmDecrease and punishEscapingBool then
                local badMovement = plysMoveType == MOVETYPE_NOCLIP or ply:Health() <= 0 or ply:GetObserverMode() ~= OBS_MODE_NONE or ply:InVehicle()
                if not badMovement and hasNavmesh then
                    local BPMDecrease = ply.historicBPMDecrease or 0
                    local added = 3
                    if onLadder then
                        added = 1

                    end
                    ply.historicBPMDecrease = BPMDecrease + added

                    BPM = math.Clamp( BPM + -BPMDecrease, 0, math.huge )
                    BPM = math.Round( BPM )

                    if BPM < restingBPMPermanent then
                        GAMEMODE:GivePanic( ply, 3 )

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
                        huntersGlee_Announce( { ply }, 100, 5, "Something is off.\nIt feels like you're somewhere wrong..." )

                    end
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

        else
            if istable( ply.BPMHistoric ) then
                ply.BPMHistoric = nil

            end
            if ply.historicBPMDecrease then
                ply.historicBPMDecrease = nil

            end
            ply:SetNWInt( "termHuntPlyBPM", 0 )
        end
    end
end

function GM:manageServersideCountOfBeats()
    local players = player.GetAll()
    for _, ply in ipairs( players ) do
        -- scoring
        local BPM = ply:GetNWInt( "termHuntPlyBPM" )
        -- block score, eg player is not on navmesh, or is on ladder
        local blockingScore = ply:Health() <= 0 or ply:GetNWBool( "termHuntBlockScoring" ) or ply:GetNWBool( "termHuntBlockScoring2" ) -- wow 2 of them
        if BPM > 1 and not blockingScore then

            -- get when we should do the next beat, it's this way instead of a timer so that if bpm gets super fast super quick, the actual new time between beats is respected
            local beatTime = math.Clamp( 60 / BPM, 0, math.huge )
            local lastBeat = ply.lastBeatTime or 0
            local doServersideBeat = ( lastBeat + beatTime ) < CurTime()

            if doServersideBeat and GAMEMODE.canScore then
                ply.lastBeatTime = CurTime()
                local scoreGiven = 1
                ply:GivePlayerScore( scoreGiven )

                hook.Run( "huntersglee_heartbeat_scoringbeat", ply )

            end
        end

        -- actual count of beats, not just when player is in scorable areas
        local RealBPMClamped = math.Clamp( BPM, 0, math.huge )

        if RealBPMClamped > 1 then
            local realBeatTime = math.Clamp( 60 / RealBPMClamped, 0, math.huge )
            local realLastBeat = ply.lastRealBeatTime or 0
            local doServersideRealBeat = ( realLastBeat + realBeatTime ) < CurTime()

            if doServersideRealBeat then
                ply.lastRealBeatTime = CurTime()
                local oldBeats = ply.realHeartBeats or 0
                ply.realHeartBeats = oldBeats + 1

                hook.Run( "huntersglee_heartbeat_beat", ply )

            end
        end
    end
end

hook.Add( "huntersglee_givescore", "huntersglee_storealivescoring", function( scorer, addedscore )
    if not IsValid( scorer ) then return end
    if not scorer:Alive() then return end
    if addedscore < 1 then return end
    if GAMEMODE:RoundState() ~= 1 then return end

    local oldPlyScore = GAMEMODE.roundScore[ scorer:GetCreationID() ] or 0
    GAMEMODE.roundScore[ scorer:GetCreationID() ] = oldPlyScore + addedscore

end )


GM.TEAM_PLAYING = 1
GM.TEAM_SPECTATE = 2

function GM:spectatifyPlayer( ply )
    ply:SetNWBool( "termhunt_spectating", true )
    ply:Spectate( OBS_MODE_DEATHCAM )
    ply.spectateDoFreecam = CurTime() + 8
    ply.termHuntTeam = GAMEMODE.TEAM_SPECTATE

end

function GM:unspectatifyPlayer( ply )
    if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then return end

    ply.spectateDoFreecam = nil
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING

    ply:SetNWBool( "termhunt_spectating", false )
    ply:UnSpectate()
    ply.overrideSpawnAction = true

end

function GM:ensureNotSpectating( ply ) -- this is kinda redundant
    if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then return end

    ply.spectateDoFreecam = nil
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING

    ply:SetNWBool( "termhunt_spectating", false )
    ply:UnSpectate()

    if ply:Alive() then
        ply:KillSilent()
    end
end

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

    local placing = ply.ghostEnt
    if IsValid( placing ) then return end

    local spectated = nil

    if keyPressed == IN_ATTACK then
        local players = player.GetAll()
        local alivePlayers = GAMEMODE:returnAliveInTable( players )
        local protoStuffToSpectate = alivePlayers
        table.Add( protoStuffToSpectate, table.Copy( GAMEMODE.termHunt_hunters ) )

        local stuffToSpectate = {}
        for _, thing in ipairs( protoStuffToSpectate ) do
            if IsValid( thing ) then
                table.insert( stuffToSpectate, thing )
            end
        end

        -- go to next player
        if followingThing then
            local thingToFollow = stuffToSpectate[1] -- default to first ply
            local currentlySpectating = ply:GetObserverTarget()
            local hitTheCurrent
            for _, thing in ipairs( stuffToSpectate ) do
                if hitTheCurrent then
                    thingToFollow = thing
                    break

                elseif thing == currentlySpectating then
                    hitTheCurrent = true

                end
            end
            if thingToFollow then
                spectated = thingToFollow
                ply:SpectateEntity( thingToFollow )

            end

        -- not following player, follow what we're looking at, or nearest player
        else
            local thingToFollow = nil
            local eyeTrace = ply:GetEyeTrace()
            local eyeTraceHit = eyeTrace.Entity
            if IsValid( eyeTraceHit ) and eyeTraceHit:IsPlayer() or eyeTraceHit:IsNextBot() then
                thingToFollow = eyeTraceHit

            else
                if #stuffToSpectate <= 0 then return end
                local sortedStuffToSpectate = table.Copy( stuffToSpectate )
                local sortPos = ply:GetPos()

                table.sort( sortedStuffToSpectate, function( a, b ) -- sort players by distance to pos
                    local ADist = a:GetShootPos():DistToSqr( sortPos )
                    local BDist = b:GetShootPos():DistToSqr( sortPos )
                    return ADist < BDist

                end )

                thingToFollow = sortedStuffToSpectate[1]

            end

            if thingToFollow then
                spectated = thingToFollow
                ply:SpectateEntity( thingToFollow )
                ply:SetObserverMode( OBS_MODE_CHASE )
                net.Start( "glee_followedsomething" )
                net.Send( ply )

            end
        end
    elseif keyPressed == IN_ATTACK2 then
        if followingThing then
            ply:SetObserverMode( OBS_MODE_ROAMING )
            net.Start( "glee_stoppedspectating" )
            net.Send( ply )

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
    end
    if IsValid( spectated ) then
        if spectated.Nick and isstring( spectated:Nick() ) then
            huntersGlee_Announce( { ply }, 1, 2, "Spectating " .. spectated:Nick() .. "." )

        else
            huntersGlee_Announce( { ply }, 1, 2, "Spectating a Terminator." )

        end
    end
end

hook.Add( "KeyPress", "glee_SwitchSpectateModes", DoKeyPressSpectateSwitch )

function GM:SpectateOverrides( ply, mode )
    local placing = ply.ghostEnt
    local isPlacing = IsValid( placing )

    if GAMEMODE.canRespawn == true then
        GAMEMODE:ensureNotSpectating( ply )
        return

    end
    if mode == OBS_MODE_DEATHCAM then -- follow our corpse
        if ply.spectateDoFreecam < CurTime() or ply:KeyDown( IN_ATTACK2 ) then
            ply.spectateDoFreecam = math.huge
            ply:SetObserverMode( OBS_MODE_ROAMING )
        end
        return
    end
    if isPlacing and mode ~= OBS_MODE_ROAMING then
        ply:SetObserverMode( OBS_MODE_ROAMING )

    end
    local followingThing = mode == OBS_MODE_CHASE or mode == OBS_MODE_IN_EYE
    if followingThing then
        local target = ply:GetObserverTarget()
        if not IsValid( target ) then
            ply:SetObserverMode( OBS_MODE_ROAMING )

        end
    end
end

function GM:managePlayerSpectating()
    for _, ply in ipairs( player.GetAll() ) do
        local mode = ply:GetObserverMode()
        if ply.termHuntTeam == GAMEMODE.TEAM_SPECTATE then
            GAMEMODE:SpectateOverrides( ply, mode )
        elseif mode > 0 and not ply.gleeIsMimic then -- ply is spectating but their team doesnt match!
            GAMEMODE:ensureNotSpectating( ply )
        end
    end
end

GM.waitForSomeoneToLive = nil

function GM:PlayerDeathThink( ply )
    if GAMEMODE.canRespawn == false then
        if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then
            GAMEMODE:spectatifyPlayer( ply )
        end
    elseif GAMEMODE.canRespawn == true or ply.overrideSpawnAction then
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
                ply.nextForcedRespawn = CurTime() + math.Rand( 3, 5 )
                GAMEMODE.waitForSomeoneToLive = nil

            end
        end
    end
end

-- dumber
hook.Add( "EntityTakeDamage", "termhunt_damagescalerattackerhook", function( _, damageInfo )
    local attacker = damageInfo:GetAttacker()
    if not attacker.termhuntDamageAttackingMult then return end
    local damage = damageInfo:GetDamage()
    damageInfo:SetDamage( damage * attacker.termhuntDamageAttackingMult )

end )

local teamPlaying = GM.TEAM_PLAYING
local teamSpectating = GM.TEAM_SPECTATE
local distToBlockProxy = 1250^2

local doProxChatCached = nil
local hasdonetheconfirmprint = nil
local _IsValid = IsValid

hook.Add( "Think", "glee_cachedoproxchat", function()
    doProxChatCached = GAMEMODE.doProxChat

end )

hook.Add( "PlayerCanHearPlayersVoice", "glee_voicechat_system", function( listener, talker )
    if not doProxChatCached then return true, false end

    local talkerTeam = talker.termHuntTeam
    local listenerTeam = listener.termHuntTeam

    local talkerIsSpectator = talkerTeam == teamSpectating
    local talkerIsPlaying = talkerTeam == teamPlaying

    local listenerIsSpectator = listenerTeam == teamSpectating
    local listenerIsPlaying = listenerTeam == teamPlaying

    if listenerIsSpectator then
        if talkerIsPlaying then
            if _IsValid( talker.termhuntRadio ) and talker.glee_RadioChannel == 666 then
                return true

            end
            return true, true

        elseif talkerIsSpectator then
            return true

        end
    elseif listenerIsPlaying then
        if talkerIsPlaying then
            if _IsValid( talker.termhuntRadio ) and _IsValid( listener.termhuntRadio ) and talker.glee_RadioChannel > 0 and listener.glee_RadioChannel > 0 then
                local talkerChannel = talker.glee_RadioChannel
                local listenerChannel = listener.glee_RadioChannel

                local sameRadio = talkerChannel == listenerChannel
                if sameRadio then
                    return true

                end
            end
            if talker:GetPos():DistToSqr( listener:GetPos() ) > distToBlockProxy then
                return false

            else
                return true, true

            end
        elseif talkerIsSpectator then
            if _IsValid( listener.termhuntRadio ) and listener.glee_RadioChannel == 666 then
                if not hasdonetheconfirmprint then
                    hasdonetheconfirmprint = true
                    print( "omg " .. listener:Name() .. " heard " .. talker:Name() )

                end
                return true

            end
            return false

        end
    end
end )

local spaceCheckUpOffset = Vector( 0,0,64 )
local spaceCheckHull = Vector( 17, 17, 2 )
local occupiedSpawnAreas = {}

function GM:PlayerSpawn( pl, transiton )

    local anotherAlivePlayer = GAMEMODE:anotherAlivePlayer( pl )
    local newPos = nil
    local center, area = nil, nil

    if pl.resurrectPos then
        newPos = pl.resurrectPos

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
            pl:SetPos( offsettedNewPos ) -- setpos twice... because....
        end )
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

function GM:PlayerInitialSpawn( ply )
    player_manager.SetPlayerClass( ply, "player_termrunner" )
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING

end

-- check if this map has all spawns in a separate room
function GM:TeleportRoomCheck()

    if not GAMEMODE.biggestNavmeshGroups or not GAMEMODE.navmeshGroups then
        GAMEMODE.navmeshGroups = GAMEMODE:GetConnectedNavAreaGroups( navmesh.GetAllNavAreas() )
        GAMEMODE.biggestNavmeshGroups = GAMEMODE:FilterNavareaGroupsForGreaterThanPercent( GAMEMODE.navmeshGroups, GAMEMODE.biggestGroupsRatio or 0.4 )

    end

    local doReset = nil
    local reason = ""

    local forceReset = #GAMEMODE.biggestNavmeshGroups > 1 and math.random( 0, 100 ) > ( 100 / #GAMEMODE.biggestNavmeshGroups )

    for _, ply in ipairs( player.GetAll() ) do
        -- dont use cache here because its rarely called
        local plysNearestNav = GAMEMODE:getNearestNav( ply:GetPos(), 200 )
        if forceReset then
            doReset = true
            reason = "HUNTER'S GLEE: Map has other accommodating sections...\nRespawning..."

        elseif not plysNearestNav or not plysNearestNav.IsValid then
            doReset = true
            reason = "HUNTER'S GLEE: Someone was off the navmesh...\nRespawning..."

        else
            if not GAMEMODE:NavAreaExistsInGroups( plysNearestNav, GAMEMODE.biggestNavmeshGroups ) then
                doReset = true
                reason = "HUNTER'S GLEE: Someone was/is outside the biggest parts of the map!\nReturning..."
            end
        end
        if doReset then
            break
        end
    end
    if doReset then
        GAMEMODE.doNotUseMapSpawns = true
        for _, plyGettinRespawned in ipairs( player.GetAll() ) do
            plyGettinRespawned:KillSilent()

        end
        PrintMessage( HUD_PRINTTALK, reason )

    end
end

local nextSendAttempt = 0

function GM:SendDeadPlayersToClients()
    if nextSendAttempt > CurTime() then return end
    local count = table.Count( GAMEMODE.deadPlayers )
    nextSendAttempt = CurTime() + 0.05 + count * 0.05

    count = 0

    for _, currentDeadPlayerData in pairs( GAMEMODE.deadPlayers ) do
        count = count + 1
        timer.Simple( count * 0.05, function()
            local ply = currentDeadPlayerData.ply
            local pos = currentDeadPlayerData.pos
            net.Start( "glee_storeresurrectpos" )
            net.WriteEntity( ply )
            net.WriteVector( pos )
            net.Broadcast()
        end )
    end
end

hook.Add( "PlayerDeath", "saveResurrectPos", function( victim )
    GAMEMODE.deadPlayers[victim:GetCreationID()] = { ply = victim, pos = victim:GetPos() }
    GAMEMODE:SendDeadPlayersToClients()

end )

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
    if areBothPlayers and GAMEMODE.blockpvp == true then
        dmg:ScaleDamage( 0 )

    elseif areBothPlayers and not dmg:IsExplosionDamage() then --lol explode
        if dmg:IsDamageType( DMG_DISSOLVE ) and inflictor and inflictor:GetClass() == "prop_combine_ball" then
            local nextpermittedballdamage = dmgTarg.huntersglee_nextpermittedballdamage or 0
            if nextpermittedballdamage > CurTime() then
                dmg:ScaleDamage( 0 )
                return

            end
            dmgTarg.huntersglee_nextpermittedballdamage = CurTime() + 0.75

            dmg:SetDamage( dmgTarg:GetMaxHealth() * 0.55 )
            dmg:SetDamageForce( dmg:GetDamageForce() * 12 )
            dmgTarg:EmitSound( "NPC_CombineBall.KillImpact" )

            damagedplayercount = inflictor.huntersglee_ball_damagedplayercount or 0
            inflictor.huntersglee_ball_damagedplayercount = damagedplayercount + 1

            if inflictor.huntersglee_ball_damagedplayercount >= 3 then
                inflictor:Fire( "Explode" )

            end
        else
            dmg:ScaleDamage( 0.25 )

        end
    end
end )

function GM:CacheNavareas( players )
    for _, ply in ipairs( players ) do
        ply:CacheNavArea()

    end
end

function plyMeta:GetNavAreaData()
    if not self.CachedNavArea then
        self:CacheNavArea()
    end
    return self.CachedNavArea, self.SqrDistToCachedNavArea

end

function plyMeta:CacheNavArea()
    local myPos = self:GetPos()
    local area = navmesh.GetNearestNavArea( myPos, true, navCheckDist, false, true )
    self.CachedNavArea = area
    if area then
        self.SqrDistToCachedNavArea = myPos:DistToSqr( area:GetClosestPointOnArea( myPos ) )

    else
        self.SqrDistToCachedNavArea = math.huge

    end
end