local SpawnTypes = { 
    "info_player_deathmatch", 
    "info_player_combine",
    "info_player_rebel", 
    "info_player_counterterrorist", 
    "info_player_terrorist",
    "info_player_axis", 
    "info_player_allies", 
    "gmod_player_start", 
    "info_player_start",
    "info_player_teamspawn",
}

local navCheckDist = 150
local belowOffset = Vector( 0, 0, -navCheckDist )
local tStartOffset = Vector( 0, 0, -2 )
local airCheckHull = Vector( 16, 16, 1 )

-- manage the BPM of ppl HERE

function GM:calculateBPM( cur )
    local players = player.GetAll()
    for _, ply in ipairs( players ) do
        if ply:Alive() then
            local plyPos = ply:GetShootPos()
            local nearestHunter = GAMEMODE:getNearestHunter( plyPos )
            local nextDistancePosSave = ply.nextDistancePosSave or 0
            local directlyUnderneathArea = navmesh.GetNearestNavArea( ply:GetPos(), true, navCheckDist, false, true )
            local canSee = nil
            local targetted = nil
            local mentosDist = math.huge
            local distanceToOldPosition = math.huge
            if IsValid( nearestHunter ) then
                -- is player inside mentos shaped volume?????
                local subtResult = nearestHunter:GetShootPos() - plyPos
                local vx, vy, vz = subtResult:Unpack()
                local vz = vz / 2
                local finalVec = Vector( vy, vx, vz )
                mentosDist = finalVec:Length()
                canSee = nearestHunter.IsSeeEnemy
                targetted = nearestHunter:GetEnemy() == ply
            end
            if nextDistancePosSave < cur then
                ply.nextDistancePosSave = cur + 1
                local plyPositions = ply.plyPositions or {}
                table.insert( plyPositions, plyPos ) 
                if table.Count( plyPositions ) >= 30 then -- 30 second delay
                    debugoverlay.Cross( plyPositions[1], 5, 5, Color( 255,255,255 ), true )
                    distanceToOldPosition = plyPositions[1]:Distance( plyPos ) -- laggy :distance()!
                    table.remove( plyPositions, 1 )
                end
                ply.plyPositions = plyPositions
            end

            local nextBPMCalc = ply.nextBPMCalc or 0

            if nextBPMCalc > cur then return end

            ply.nextBPMCalc = cur + math.random( 0.15, 0.25 )

            local restingBPM = 60
            local mentosBPM = 0
            if mentosDist < 2000 then
                local rawScalar = math.abs( mentosDist - 2000 ) / 35
                local bpmRampup = math.Clamp( rawScalar, 0, 30 ) 
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

            local coveringNewGround = distanceToOldPosition > 2500
            local speedBPMMul = 0.7
            if not coveringNewGround then 
                speedBPMMul = 0.05
            end 

            local onLadder = ply:GetMoveType() == MOVETYPE_LADDER
            local blockScore = false
            local onArea = nil 
            if directlyUnderneathArea then 
                onArea = directlyUnderneathArea:IsValid()
            end
            local tDat = {}
            tDat.start = plyPos + tStartOffset
            tDat.endpos = plyPos + belowOffset
            tDat.mask = MASK_NPCWORLDSTATIC
            tDat.maxs = airCheckHull
            tDat.mins = -airCheckHull
            local closeToGround = util.TraceHull( tDat ).Hit
            
            if ( not onArea ) and closeToGround then
                blockScore = true
            end
            if onLadder then
                blockScore = true
            end 

            local bpmPerSpeed = 0.03 * speedBPMMul
            local speedBPM = ply:GetVelocity():Length() * bpmPerSpeed 

            local scaredBpm = mentosBPM + canSeeBPM + targettedBPM 
            local idealBPM = restingBPM + speedBPM + scaredBpm 
            idealBPM = math.Round( idealBPM )

            local BPMHistoric = ply.BPMHistoric or {idealBPM}
            table.insert( BPMHistoric, idealBPM ) 
            local historySize = 80
            if table.Count( BPMHistoric ) > historySize then
                for I = 1, math.abs( table.Count( BPMHistoric ) - historySize ) do
                    table.remove( BPMHistoric, 1 )
                end
            end
            
            local extent = 0
            local additive = 0
            for _, cur in ipairs(BPMHistoric) do
                extent = extent+1
                additive = additive+cur
            end

            local BPM = additive / extent
            BPM = math.Round( math.Clamp( BPM, ( idealBPM / 2 ) + scaredBpm, math.huge ) )
            ply.BPMHistoric = BPMHistoric

            ply:SetNWInt( "termHuntPlyBPM", BPM ) 
            ply:SetNWBool( "termHuntBlockScoring", blockScore ) 
        else
            if istable( ply.BPMHistoric ) then
                ply.BPMHistoric = nil
            end
            ply:SetNWInt( "termHuntPlyBPM", 0 )
        end
    end
end

local BPMCriteria = 65 -- needs to match clientside var too

function GM:manageServersideCountOfBeats()
    local players = player.GetAll()
    for _, ply in ipairs( players ) do
        local BPMSubtracted = ply:GetNWInt( "termHuntPlyBPM" ) - BPMCriteria
        local BPMClamped = math.Clamp( BPMSubtracted, 0, math.huge )
        local blockingScore = ply:GetNWBool( "termHuntBlockScoring" ) 
        if BPMClamped < 1 or blockingScore then goto NextPlayer end

        local beatTime = math.Clamp( 60 / BPMClamped, 0, math.huge )
        local lastBeat = ply.lastBeatTime or 0 
        local doServersideBeat = ( lastBeat + beatTime ) < CurTime() 
        if doServersideBeat and GAMEMODE.canScore then
            ply.lastBeatTime = CurTime()
            ply:AddFrags( 1 ) -- use frags!
        end
        ::NextPlayer::

    end
end


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
    ply:SetNWBool( "termhunt_spectating", false )
    ply:UnSpectate()
    if ply:Alive() then
        ply:KillSilent()
    end
    ply:Spawn()
    ply.spectateDoFreecam = nil
    ply.termHuntTeam = GAMEMODE.TEAM_PLAYING
end

function GM:managePlayerSpectating()
    for _, ply in ipairs( player.GetAll() ) do
        local mode = ply:GetObserverMode()
        if ply.termHuntTeam == GAMEMODE.TEAM_SPECTATE then
            if GAMEMODE.canRespawn == true then
                GAMEMODE:unspectatifyPlayer( ply )
            else
                local followingPlayer = mode == OBS_MODE_CHASE or mode == OBS_MODE_IN_EYE
                if mode == OBS_MODE_DEATHCAM then -- follow our corpse
                    if ply.spectateDoFreecam < CurTime() or ply:KeyDown( IN_ATTACK2 ) then
                        ply.spectateDoFreecam = math.huge
                        ply:SetObserverMode( OBS_MODE_ROAMING )
                    end
                elseif mode == OBS_MODE_ROAMING then -- follow thiings
                    if ply:KeyDown( IN_ATTACK ) then
                        local trace = ply:GetEyeTrace()
                        local entity = trace.Entity
                        if IsValid( entity ) and entity:IsPlayer() then
                            ply:SpectateEntity( entity )
                            ply:SetObserverMode( OBS_MODE_CHASE )
                        end
                    end
                elseif followingPlayer then -- exit the thing follow
                    local nextChange = ply.nextSpectateChange or 0
                    if ply:KeyDown( IN_RELOAD ) and nextChange < CurTime() then
                        ply.nextSpectateChange = CurTime() + 0.5
                        if mode == OBS_MODE_CHASE then
                            ply:SetObserverMode( OBS_MODE_IN_EYE )
                        elseif mode == OBS_MODE_IN_EYE then
                            ply:SetObserverMode( OBS_MODE_CHASE )
                        end
                    end
                    if ply:KeyDown( IN_ATTACK2 ) then
                        ply:SpectateEntity( nil )
                        ply:SetObserverMode( OBS_MODE_ROAMING )
                    end
                end
            end
        elseif mode > 0 then -- ply is spectating but their team doesnt match!
            GAMEMODE:unspectatifyPlayer( ply )
        end
    end
end


function GM:PlayerDeathThink( ply )
    if GAMEMODE.canRespawn == false then
        if ply.termHuntTeam ~= GAMEMODE.TEAM_SPECTATE then
            GAMEMODE:spectatifyPlayer( ply )
        end
    elseif GAMEMODE.canRespawn == true then
        local lastForced = ply.nextForcedRespawn or 0
        if lastForced < CurTime() then
            ply:Spawn()
            ply.nextForcedRespawn = CurTime() + math.Rand( 3, 5 )
        end
    end
end


function GM:refreshPlyDamageModel( ply ) 
    if not IsValid( ply ) then return end
    local roundState = GAMEMODE.roundState 
    local maxHp = nil 
    local lastDeaths = ply.damageModelDeaths or 0
    local recentlyDied = ( lastDeaths < ply:Deaths() ) and ply:Alive()
    
    if ply:HasGodMode() ~= GAMEMODE.godmode then
        if GAMEMODE.godmode == true then 
            ply:GodEnable()
        else
            ply:GodDisable()
        end
    end

    if ply.lastDamageModel ~= roundState or recentlyDied then
        ply.damageModelDeaths = ply:Deaths()
        ply.lastDamageModel = roundState

        if roundState == GAMEMODE.ROUND_SETUP then
            maxHp = true

        elseif roundState == GAMEMODE.ROUND_ACTIVE then

        elseif roundState == GAMEMODE.ROUND_INACTIVE then
            maxHp = true

        elseif roundState == GAMEMODE.ROUND_LIMBO then

        end

        if maxHp then 
            ply:SetHealth( ply:GetMaxHealth() )

        end
    end
end

hook.Add( "PlayerCanHearPlayersVoice", "termhuntMaximumRange", function( listener, talker )
    local doProxChat = GAMEMODE.doProxChat
    if not doProxChat then return true, false end

    local tooFar = talker:GetPos():DistToSqr( listener:GetPos() ) > 1500^2

    local talkerTeam = talker.termHuntTeam
    local spectatorSpeaking = talkerTeam == GAMEMODE.TEAM_SPECTATE
    local playingListening = listener.termHuntTeam == GAMEMODE.TEAM_PLAYING
    local spectatorSpeakingToPlaying = playingListening and spectatorSpeaking

    local blockHearing = spectatorSpeakingToPlaying or tooFar

    if blockHearing then
        return false
    else 
        --print( talker, listener, "talk" )
        return true, true
    end
    
end )

local spaceCheckUpOffset = Vector( 0,0,64 )
local spaceCheckHull = Vector( 17, 17, 2 )
local occupiedSpawnAreas = {}

function GM:PlayerSpawn( pl, transiton )

    if GAMEMODE.canRespawn ~= false then

        local anotherAlivePlayer = nil 
        for _, ply in ipairs( player.GetAll() ) do
            if ply:Alive() and ply ~= pl then 
                anotherAlivePlayer = ply
                break 
            end
        end
        if IsValid( anotherAlivePlayer ) and GAMEMODE.hasNavmesh then
            local newPos = nil
            local center, area = nil, nil
            for ind = 1, 5 do

                local start = anotherAlivePlayer:GetPos()
                local res = GAMEMODE:getNearestPosOnNav( start )
                local startArea = res.area

                local scoreData = {}
                scoreData.startPos = res.pos
                scoreData.allowUnderwater = startArea:IsUnderwater()
            
                local scoreFunction = function( scoreData, area1, area2 )
                    local area2Center = area2:GetCenter()
                    local distanceTravelled = area2Center:DistToSqr( scoreData.startPos )
                    local score = distanceTravelled * math.Rand( 0.5, 1.5 )
            
                    if area2:IsUnderwater() and not scoreData.allowUnderwater then 
                        score = 1
                    end
                    if occupiedSpawnAreas[area2:GetID()] then
                        score = 0
                    end
                    if area2:GetSizeX() < 50 then
                        score = 1
                    end
                    if area2:GetSizeY() < 50 then
                        score = 1
                    end
            
                    -- debugoverlay.Text( area2:GetCenter(), math.Round( math.sqrt( score ) ), 5, false  )
            
                    return score
            
                end

                center, area = GAMEMODE:findValidNavResult( scoreData, start, math.random( 300, 800 ), scoreFunction )

                if center then 
                    center = center + Vector( 0,0,10 )
                    local tDat = {}
                    tDat.start = center
                    tDat.endpos = center + spaceCheckUpOffset
                    tDat.mask = MASK_SOLID
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
            if newPos then
                local offsettedNewPos = newPos + Vector(0,0,15)
                pl:SetPos( offsettedNewPos )
                local id = area:GetID()
                occupiedSpawnAreas[id] = true
                timer.Simple( 5, function()
                    occupiedSpawnAreas[id] = nil
                end )
                timer.Simple( engine.TickInterval(), function()
                    if not IsValid( pl ) then return end
                    pl:SetPos(newPos) -- setpos twice... because....
                end )
                timer.Simple( engine.TickInterval() * 2, function() 
                    if not IsValid( pl ) then return end
                    if not IsValid( anotherAlivePlayer ) then return end
                    local dirToMainPlayer = GAMEMODE:dirToPos( pl:GetShootPos(), anotherAlivePlayer:GetShootPos() )
                    local ang = dirToMainPlayer:Angle()
                    pl:SetAngles( ang )
                end )
            end 
        end
    end

    -- Stop observer mode
    pl:UnSpectate()

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

    timer.Simple( engine.TickInterval() * 2, function()
        if not IsValid( pl ) then return end
        GAMEMODE:refreshPlyDamageModel( pl )
    end )

    GAMEMODE.deadPlayers[pl:GetCreationID()] = nil

end

function GM:PlayerInitialSpawn( ply )
    player_manager.SetPlayerClass( ply, "player_termrunner" ) 
end

hook.Add( "PlayerDeath", "saveResurrectPos", function( victim )
    GAMEMODE.deadPlayers[victim:GetCreationID()] = { ply = victim, pos = victim:GetPos() } 
    net.Start( "storeResurrectPos" )
    net.WriteEntity( victim )
    net.Broadcast()
end )

util.AddNetworkString( "storeResurrectPos" )