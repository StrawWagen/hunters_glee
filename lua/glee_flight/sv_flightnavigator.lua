terminator_Extras = terminator_Extras or {}

-- bump-roomba steering for path_track flyers, npc_helicopter, npc_combinegunship, npc_combinedropship
-- every think, fan out hull traces around where we want to go, score where they land, point the track at the best
local gleeFlightNavigator = {}
terminator_Extras.gleeFlightNavigator = gleeFlightNavigator

-- heading away from the ideal pos for this many seconds ( net ) means we're not getting there
local awayFromIdealGiveUpTime = 10

local cachedTriggerPushes = {}
local triggerPushCacheTime = 0

function gleeFlightNavigator.RayHitsTriggerPush( origin, offset )
    local cur = CurTime()
    if triggerPushCacheTime < cur then
        cachedTriggerPushes = ents.FindByClass( "trigger_push" )
        triggerPushCacheTime = cur + 25

    end
    if #cachedTriggerPushes == 0 then return false end

    for _, push in ipairs( cachedTriggerPushes ) do
        if not IsValid( push ) then
            triggerPushCacheTime = 0
            continue

        end
        if util.IntersectRayWithOBB( origin, offset, push:GetPos(), push:GetAngles(), push:OBBMins(), push:OBBMaxs() ) then
            return true

        end
    end

    return false

end

local rayHitsTriggerPush = gleeFlightNavigator.RayHitsTriggerPush

local function isDebugging( navData )
    local debugConVar = navData.cfg.debugConVar
    return debugConVar and debugConVar:GetBool()

end

local function pointTrackAt( ent, navData, pos )
    SafeRemoveEntityDelayed( navData.track, 0.1 )

    local newTrack = ents.Create( "path_track" )
    newTrack:SetPos( pos )
    newTrack:SetKeyValue( "targetname", navData.trackName )
    navData.track = newTrack

    ent:Fire( "SetTrack", navData.trackName )

end

local function teleportTo( ent, navData, pos )
    ent:SetPos( pos )
    navData.lastPos = pos

end

local function manageSpeedLimit( ent, navData, idealMovePos, loveSkybox )
    local speedOverride = navData.speedOverride
    if speedOverride then
        ent:SetSaveValue( "m_flPathMaxSpeed", speedOverride )
        return speedOverride

    end

    local cfg = navData.cfg
    local obstacleHull = cfg.obstacleHull

    local myPos = ent:GetPos()
    local distToGoal = myPos:Distance( idealMovePos )

    local newSpeed = math.Clamp( distToGoal * 1.5, cfg.closeToObstacleSpeedLimit, cfg.speedLimit )
    local engineVel = ent:GetVelocity()
    local moveDir = engineVel:GetNormalized()
    local curSpeed = engineVel:Length()

    if curSpeed <= 150 then
        moveDir = ent:GetForward()

    end

    local range = math.min( distToGoal + 500, curSpeed * 4 )

    local blockedTrData = {
        start = myPos,
        endpos = myPos + moveDir * range,
        mask = MASK_SOLID_BRUSHONLY,
        mins = Vector( -obstacleHull, -obstacleHull, -obstacleHull / 4 ),
        maxs = Vector( obstacleHull, obstacleHull, obstacleHull / 4 ),

    }
    local blockedTrResult = util.TraceHull( blockedTrData )

    if loveSkybox and blockedTrResult.HitSky then
        newSpeed = cfg.speedLimit

    elseif blockedTrResult.Hit then
        newSpeed = cfg.closeToObstacleSpeedLimit

    end

    if isDebugging( navData ) then
        debugoverlay.SweptBox(
            blockedTrData.start,
            blockedTrResult.HitPos,
            blockedTrData.mins,
            blockedTrData.maxs,
            Angle( 0, 0, 0 ),
            1,
            Color( 255, 0, 0 )
        )

    end

    ent:SetSaveValue( "m_flPathMaxSpeed", newSpeed )
    return newSpeed

end

-- cfg:
--   speedLimit                 top speed, when the way ahead is clear
--   closeToObstacleSpeedLimit  speed near walls, also when the smaller slow hull kicks in
--   tooFarFromGround           above this, steer back down
--   tooCloseToGround           below this, steer back up
--   obstacleHull               half-width of the "is the way ahead blocked" trace
--   wayfindingHull             half-size of the sampling traces
--   slowMovingHull             half-size of the sampling traces when slow, to squeeze through gaps
--   startAtTopSpeed            optional, starts at full speed if the way's clear, for flyers arriving from the skybox
--   wanderHeight               above the floor, for WanderPos, see behaviours/sv_wander
--   debugConVar                optional, draws the traces
-- call after Spawn, ent has to take the SetTrack input
function gleeFlightNavigator.Attach( ent, cfg, firstGoalPos )
    local navData = {
        cfg = cfg,
        trackName = "glee_flightnav_track_" .. ent:GetCreationID(),
        measuredVel = Vector( 0, 0, 0 ),
        unstuckDist = 0,
        awayFromIdealTime = 0,
    }
    ent.glee_FlightNav = navData

    ent:CallOnRemove( "glee_flightnav_removetrack", function()
        SafeRemoveEntity( navData.track )

    end )

    pointTrackAt( ent, navData, firstGoalPos )

    local topSpeed = manageSpeedLimit( ent, navData, firstGoalPos )
    if cfg.startAtTopSpeed and topSpeed >= cfg.speedLimit * 0.5 then
        ent:Fire( "MoveTopSpeed", 1, 0.1 )

    end
end

-- call once per think, before Steer
-- measured from position, not GetVelocity
function gleeFlightNavigator.UpdateVelocity( ent )
    local navData = ent.glee_FlightNav
    local myPos = ent:GetPos()
    local now = CurTime()

    local sinceLastUpdate = math.max( now - ( navData.lastUpdate or now ), engine.TickInterval() )
    local oldPos = navData.lastPos or myPos

    navData.measuredVel = ( myPos - oldPos ) / sinceLastUpdate
    navData.sinceLastUpdate = sinceLastUpdate
    navData.lastUpdate = now
    navData.lastPos = myPos

    return navData.measuredVel

end

-- flat out at this speed, walls or not, nil goes back to the cfg's limits
function gleeFlightNavigator.SetSpeedOverride( ent, speed )
    ent.glee_FlightNav.speedOverride = speed

end

-- grows while we're stuck, shrinks back to 0 once we're moving
function gleeFlightNavigator.GetUnstuckDist( ent )
    return ent.glee_FlightNav.unstuckDist

end

-- moves us towards idealMovePos, around whatever's in the way
-- loveSkybox, flying into the skybox is the goal, not an obstacle
-- returns true when we've spent too long heading away from idealMovePos, it's probably unreachable
function gleeFlightNavigator.Steer( ent, idealMovePos, loveSkybox )
    local navData = ent.glee_FlightNav
    local cfg = navData.cfg
    local debugging = isDebugging( navData )

    local myPos = ent:GetPos()
    local ourVel = navData.measuredVel

    if debugging then
        debugoverlay.Sphere( idealMovePos, 25, 1, Color( 0, 255, 255 ), true )
        debugoverlay.Line( myPos, idealMovePos, 1, Color( 0, 255, 255 ), true )

    end

    local curSpeed = ourVel:Length()
    local distToIdeal = myPos:Distance( idealMovePos )
    local distance = math.min( curSpeed * 8, cfg.speedLimit * 2, distToIdeal * 1.5 )
    local moveDir = ourVel:GetNormalized()
    local dirToIdeal = ( idealMovePos - myPos ):GetNormalized()
    local trCheckDir = ( moveDir * 0.5 ) + ( dirToIdeal * 0.5 )

    local hull = cfg.wayfindingHull
    if curSpeed <= cfg.closeToObstacleSpeedLimit then
        hull = cfg.slowMovingHull

    end

    local traceDataMove = {
        start = myPos,
        endpos = nil,
        mask = MASK_NPCSOLID_BRUSHONLY,
        mins = Vector( -hull, -hull, -hull ),
        maxs = Vector( hull, hull, hull ),

    }
    local function getPenaltyForPos( pos, traceResult, rayCheck )
        local penalty = pos:Distance( idealMovePos )

        local floorTr = terminator_Extras.getFloorTr( pos )
        local floorDist = floorTr.HitPos:Distance( pos )
        if rayHitsTriggerPush( myPos, rayCheck ) then
            penalty = penalty * 10

        end

        if floorDist > cfg.tooFarFromGround then
            penalty = penalty + floorDist * 0.25 -- the higher this is? the worse the penalty

        elseif floorDist < cfg.tooCloseToGround then
            penalty = penalty * 1.5

        end
        if loveSkybox and traceResult.HitSky then
            penalty = penalty * 0.9

        elseif traceResult.Hit then
            penalty = penalty * 4

        end
        -- if bitflag contains water, avoid at all costs
        if bit.band( util.PointContents( pos ), CONTENTS_WATER ) ~= 0 then
            penalty = penalty * 1000

        end
        return penalty

    end

    local count = 30
    local results = {}
    local lastBest = navData.lastBestPos
    if lastBest then
        traceDataMove.endpos = lastBest
        local lastBestResult = util.TraceHull( traceDataMove )
        if not lastBestResult.StartSolid then
            local penalty = getPenaltyForPos( lastBestResult.HitPos, lastBestResult, lastBest - myPos )
            if navData.lastBestPenalty then
                penalty = math.max( penalty, navData.lastBestPenalty )

            end
            results[penalty * 1.15] = lastBestResult.HitPos

        end
    end
    local oneWasClear

    -- straight at the goal, the fan's short and scattered until we're up to speed, so it'd never line up with it on its own
    traceDataMove.endpos = idealMovePos
    local goalResult = util.TraceHull( traceDataMove )
    if not goalResult.StartSolid then
        oneWasClear = true
        local penalty = getPenaltyForPos( goalResult.HitPos, goalResult, idealMovePos - myPos )
        results[penalty] = goalResult.HitPos

        if debugging then
            debugoverlay.Line( myPos, goalResult.HitPos, 0.5, Color( 255, 0, 255 ), true )

        end
    end

    for i = 1, count do
        local currDist = distance
        if i > 2 then
            currDist = currDist * math.Rand( 0.75, 1.25 )

        else
            currDist = currDist * 1.25

        end

        -- bigger angle checks the further into the loop we are
        local integral = i / count

        -- if we're going slow, way less velocity bias
        if i > 2 and curSpeed < 500 then
            integral = 2

        end
        local offset = VectorRand()
        offset:Mul( integral )

        local offsetedDir = trCheckDir + offset
        offsetedDir:Normalize()

        traceDataMove.endpos = myPos + offsetedDir * currDist
        local traceResult = util.TraceHull( traceDataMove )

        -- dont add this if it's starting in a wall
        if traceResult.StartSolid then continue end
        oneWasClear = true

        local penalty = getPenaltyForPos( traceResult.HitPos, traceResult, offsetedDir * currDist )

        if debugging then
            debugoverlay.Line( myPos, traceResult.HitPos, 0.5, Color( 255, 0, 0 ), true )

        end

        results[penalty] = traceResult.HitPos

    end

    local bestPos = nil

    if not oneWasClear and ent:VisibleVec( idealMovePos ) and distToIdeal < 500 then
        bestPos = idealMovePos
        navData.lastBestPos = nil
        navData.lastBestPenalty = nil

    -- cant find somewhere to goto or we are literally not moving
    elseif not oneWasClear or curSpeed <= 1 then
        -- is there somewhere next to us we can go to?
        for _ = 1, 25 do
            local dir = VectorRand()
            local offfsettedPos1 = myPos + dir * 200
            if not util.IsInWorld( offfsettedPos1 ) then continue end
            local offfsettedPos2 = myPos + dir * 400
            if not util.IsInWorld( offfsettedPos2 ) then continue end

            bestPos = offfsettedPos2

            navData.lastBestPos = nil
            navData.lastBestPenalty = nil
            break

        end

        -- are we smashing into a wall?
        local collideTrStruc = {
            start = myPos,
            endpos = myPos + VectorRand() * 10,
            mask = MASK_SOLID_BRUSHONLY,
            mins = ent:OBBMins() * 1.1,
            maxs = ent:OBBMaxs() * 1.1,

        }
        local collisionCheckTrace = util.TraceHull( collideTrStruc )
        -- dont explode if we're crashing into what we want to hit
        local goodHit = collisionCheckTrace.HitSky and loveSkybox

        local colliding = collisionCheckTrace.Hit and not goodHit
        local unstuckEscapePos
        local trySoftUnstuckOffset
        local seeSoft
        if bestPos then
            -- 1.15x per second stuck
            local tpDist = navData.unstuckDist
            tpDist = math.max( 25, tpDist * 1.15 ^ navData.sinceLastUpdate )
            navData.unstuckDist = tpDist
            if not GAMEMODE.IsReallyHuntersGlee or tpDist < 200 then
                trySoftUnstuckOffset = terminator_Extras.dirToPos( myPos, bestPos ) * tpDist
                unstuckEscapePos = myPos + trySoftUnstuckOffset

            else
                local areas = GAMEMODE:GetAreasInOccupiedGroupWithEFlag( GAMEMODE.NavEFlags.UNDER_SKY )

                local minSize = 250
                local centerOffset = Vector( 0, 0, 250 )

                local anArea
                local perfectArea
                local perfectAreaDist = math.huge

                for _, area in ipairs( areas ) do
                    if not IsValid( area ) then continue end
                    if math.min( area:GetSizeX(), area:GetSizeY() ) < minSize then continue end

                    anArea = area
                    if not GAMEMODE.navmeshActivityHeatmap[area] then continue end
                    local areaCenter = area:GetCenter()
                    if not terminator_Extras.PosCanSee( myPos, areaCenter + centerOffset ) then continue end

                    local distSqr = myPos:DistToSqr( areaCenter )
                    if distSqr > perfectAreaDist then continue end
                    perfectAreaDist = distSqr
                    perfectArea = area

                end

                local foundArea = IsValid( perfectArea ) and perfectArea or anArea
                if IsValid( foundArea ) then
                    unstuckEscapePos = foundArea:GetCenter() + centerOffset

                end
            end

            seeSoft = terminator_Extras.PosCanSee( myPos, unstuckEscapePos )

        end

        -- we're smashing into a wall!!!
        -- 1,
        -- not a wall here, just bumping something
        -- try just nudging us out a bit
        if colliding and curSpeed < 250 and seeSoft then
            teleportTo( ent, navData, unstuckEscapePos )
            if debugging then
                permaPrint( "flightnav unstuck 1" )
                debugoverlay.SweptBox(
                    collideTrStruc.start,
                    collideTrStruc.endpos,
                    collideTrStruc.mins,
                    collideTrStruc.maxs,
                    Angle( 0, 0, 0 ),
                    10,
                    Color( 0, 255, 0 )

                )
            end
        -- 2,
        -- too fast or too stuck? taking damage time
        elseif colliding then
            local damageInfo = DamageInfo()
            damageInfo:SetDamage( 100 )
            damageInfo:SetDamageType( DMG_BLAST )
            damageInfo:SetAttacker( ent )
            damageInfo:SetInflictor( ent )
            damageInfo:SetDamagePosition( collisionCheckTrace.HitPos )
            ent:TakeDamageInfo( damageInfo )
            if debugging then
                permaPrint( "flightnav unstuck 2" )
                debugoverlay.SweptBox(
                    collideTrStruc.start,
                    collideTrStruc.endpos,
                    collideTrStruc.mins,
                    collideTrStruc.maxs,
                    Angle( 0, 0, 0 ),
                    10,
                    Color( 255, 0, 0 )

                )
            end

        -- 3,
        -- stuck on something but not colliding, probably a npc or small prop
        elseif not colliding and curSpeed <= 5 then

            if debugging then
                permaPrint( "flightnav unstuck 3 ", navData.unstuckDist )
                debugoverlay.SweptBox(
                    collideTrStruc.start,
                    collideTrStruc.endpos,
                    collideTrStruc.mins,
                    collideTrStruc.maxs,
                    Angle( 0, 0, 0 ),
                    10,
                    Color( 255, 255, 0 )

                )
            end

            local excluded = { [ent] = true }
            for _, child in ipairs( ent:GetChildren() ) do
                excluded[child] = true

            end
            local nearbyEnts = ents.FindAlongRay( collideTrStruc.start, collideTrStruc.endpos, ent:OBBMins() * 1.1, ent:OBBMaxs() * 1.1 )
            local smashEntity
            for _, nearbyEnt in ipairs( nearbyEnts ) do
                if excluded[nearbyEnt] then continue end
                if nearbyEnt:IsPlayer() then continue end
                smashEntity = nearbyEnt
                break

            end
            if IsValid( smashEntity ) then
                local damageInfo = DamageInfo()
                damageInfo:SetDamage( 5 )
                damageInfo:SetDamageType( DMG_CRUSH )
                damageInfo:SetAttacker( ent )
                damageInfo:SetInflictor( ent )
                damageInfo:SetDamagePosition( smashEntity:GetPos() )
                smashEntity:TakeDamageInfo( damageInfo )

            end

            if seeSoft then
                teleportTo( ent, navData, unstuckEscapePos )

            end
        end

    -- not stuck, find best result
    else
        local smallestPenalty = math.huge
        for penalty, pos in pairs( results ) do
            if penalty > smallestPenalty then continue end
            smallestPenalty = penalty
            bestPos = pos

        end

        navData.lastBestPos = bestPos
        navData.lastBestPenalty = smallestPenalty

        if curSpeed > 50 then
            navData.unstuckDist = 0

        end
    end

    local lostProgress = false

    -- bestPos is sometimes nil
    if bestPos then
        pointTrackAt( ent, navData, bestPos )

        if debugging then
            debugoverlay.Line( myPos, bestPos, 1, Color( 0, 255, 0 ), true )

        end

        local dirToBestPos = terminator_Extras.dirToPos( myPos, bestPos )

        -- TODO: do this better
        if dirToBestPos:Dot( dirToIdeal ) < 0 then
            navData.awayFromIdealTime = navData.awayFromIdealTime + navData.sinceLastUpdate

        else
            navData.awayFromIdealTime = math.max( 0, navData.awayFromIdealTime - navData.sinceLastUpdate )

        end

        if navData.awayFromIdealTime >= awayFromIdealGiveUpTime then
            navData.awayFromIdealTime = 0
            lostProgress = true

        end
    end

    manageSpeedLimit( ent, navData, idealMovePos, loveSkybox )

    return lostProgress

end
