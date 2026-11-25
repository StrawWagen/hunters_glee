
-- Flies the watching camera, see sh_spectatewatching.lua for the mode as a whole, cl_watchscorer.lua for who it watches.
-- One search, borrowed from the flight navigator's sampling, always hunting for a better spot to watch from.
-- It scores spots three ways:
--   drifting, following the target around, quick to move. It also goes round them, see updateSwing
--   settled, holding still in a room, backed off from the group against a wall, slow to move, see settledScore
--   pulling in, orbiting closer and closer to a lone skull, until it's staring it in the face, see updatePullInWant
-- Distances from the target are from its edge, see bodyExtent
-- The camera is the player's own free roam body, nothing stops it going through walls, so it stops itself.
-- It sweeps a small hull wherever it goes, and keeps wallGap off whatever that hits.
-- The void's fine for a ghost, but flying round things looks better. It digs in when it's slow and far from the target, see updateVoidCost.
-- Once it's in a wall or the void, it flies straight through whatever's in the way.

-- Most tweaked first, the search's insides last
local tune = {
    -- starting up, and taking back control, see GM:SpectateWatchingRamp
    rampTime = 10, -- seconds its grip takes to tighten fully, started on its own. No teleports till then, so taking over isn't overwhelming
    inputSlack = 0.25, -- seconds of them pushing as hard as they can, at a full grip, before it lets go. Less loosens it, a bump only slows it
    fullLookSpeed = 90, -- degrees a second of them turning the view, by any means, that's pushing as hard as they can
    handSpeed = 400, -- their own movement, keys held fully, on top of the camera's

    -- moving
    speedPerUnit = 2, -- speed wanted, per unit away from the best spot
    maxSpeed = 1500, -- the server won't take more than 3000, see sh_spectatewatching.lua
    velocityRate = 2, -- how fast velocity eases towards what's wanted, this is the acceleration and deceleration
    guardTime = 0.3, -- seconds ahead it checks it won't fly into anything

    -- aiming
    aimPointRate = 4, -- how fast the aim point catches up to where it wants to be, higher is snappier
    viewRate = 3, -- how fast the view turns towards the aim point
    maxTurnSpeed = 120, -- degrees per second, a big jump in the aim point becomes a fast pan, not a snap
    maxPitch = 80, -- straight up or down spins the yaw, never quite get there
    groupPosRate = 0.5, -- how fast the camera's copy of the group's spot catches up. Slow, it moves when the camera does, and the camera moves relative to it

    -- how far it watches from, distances from the target's edge
    viewDistMin = 150, -- closest a spot should be
    viewDistMax = 500, -- furthest a spot should be
    viewDistSoftMax = 250, -- drifting, further than this from a target it can see, the camera creeps in...
    creepPerUnit = 4, -- ...this fast per unit past it. Too small a change for a spot's score to bother with
    creepMaxSpeed = 150,
    elevation = 15, -- degrees above or below the target that spots prefer, looking straight up or down spins the view

    -- going round the target, drifting and seeing them, see updateSwing
    faceMinSpeed = 50, -- them moving faster than this, the camera swings round to their face...
    faceAngleMin = 20, -- ...this far off dead ahead, their face and where they're going. Rolled between these
    faceAngleMax = 50,
    swingPerDegree = 3, -- speed round them, per degree from there
    swingMaxSpeed = 300,
    faceMaxTurnRate = 180, -- degrees a second of them turning that stops the swing, someone looking around would whip the camera round
    turnRateRate = 3, -- how fast the measured turn rate catches up
    faceGroupFade = 300, -- the group's spot this far from the target, their face stops mattering, it's not the group's
    orbitSpeed = 40, -- them idle without company, speed round them
    orbitChance = 0.5, -- each roll, the chance it orbits. Otherwise it holds still, and can settle
    rollMin = 6, -- seconds between rerolling the orbit and the face angle, random between these
    rollMax = 15,
    orbitLookAhead = 1, -- seconds of orbit ahead it checks it can still see them, and won't hit a wall. It turns round if not
    flapFlips = 30, -- swapping between swinging to their face and orbiting this many times in a second...
    flapCalmChance = 0.5, -- ...rolls this chance it calms down, holding still for a roll's time, so it can settle

    -- pulling in, any lone idle skull, the same search, scored on how close spots are to a point just ahead
    pullInDist = 50, -- how close to the skull's edge it ends up, closer is down in the floor's wallGap
    pullInSpeed = 50, -- speed in
    pullInOrbitSpeed = 20, -- speed round it
    pullInFaceArrive = 16, -- this close to the face on spot, it heads straight there and holds
    pullInPerUnit = 10, -- score lost per unit from the wanted point. Steep, so small steps win
    pullInReach = 30, -- random spots this far from the wanted point, give or take reachRandomness
    pullInKeepBestMargin = 5,
    pullInMaxSpeed = 150,

    -- settling, drifting's best spot staying close and the camera staying still settles
    settleRadius = 48, -- the best spot staying this close...
    settleSpeed = 5, -- ...while the camera moves slower than this...
    settleTime = 1.5, -- ...for this many seconds, in a room, seeing the group's spot and the target, with company, settles
    roomSize = 600, -- a room is somewhere these traces, 8 flat and 1 up, this long...
    enclosedHits = 6, -- ...this many of hit something
    enclosureCheckInterval = 2, -- seconds between checks it's still in one, while settled

    -- settled, the same search, scored for holding still, see settledScore. Distances are from the group's spot, which the camera can't move
    settledSearchRate = 10,
    settledReach = 60, -- random spots this far from the camera, give or take reachRandomness
    settledDistMin = 150, -- closest to the group's spot
    settledDistMax = 350, -- furthest from it
    settledFarScore = 300, -- for the far end of that range, it backs off from them
    wallBackReach = 100, -- a wall this much past wallGap behind a spot...
    wallBackScore = 300, -- ...scores up to this, closer is more, it's backed up against it
    cornerScore = 200, -- a wall beside it too, it's in a corner
    settledTravelPerUnit = 1, -- per unit from the camera, so it only moves for a real improvement
    settledKeepBestMargin = 100,
    settledMaxSpeed = 20,

    -- unsettling
    groupRadius = 500, -- a new target this close to the group's spot, or one the camera can see, is the same group, settling carries on
    groupRunSpeed = 250, -- the group's spot moving this fast...
    groupRunTime = 1, -- ...for this long is the group moving on, unsettles. Longer than a switch between two of them takes
    lostSightTime = 1, -- seconds without seeing the target, unsettles
    aloneTime = 1, -- seconds of the target without company, a skull, or the roll saying orbit, unsettles, see GM:WatchAimPoint

    -- the void, inside walls and past the map's edge. Fine for a ghost, but flying round things looks better, see updateVoidCost
    voidCostMax = 2000, -- from open air, moving well. More than getting closer through it could gain
    voidCostInside = 50, -- already in it, just a bit worse than open air
    voidFullSpeed = 300, -- the target out of range, moving slower than this makes the void cheaper, down to voidCostInside standing still
    voidAppealRate = 0.5, -- how fast that catches up. Slow, so speeding up on the way in doesn't put the cost straight back up

    -- what a spot scores. Line of sight leads, the wall penalties sit under everything
    losScore = 1000, -- seeing the target
    clearLosScore = 500, -- seeing them with no window or grate in the way either, some of those look solid, see GM:WatchCanSee
    groupLosScore = 500, -- seeing the group's spot, only on top of seeing the target
    predictedLosScore = 300, -- seeing where the target's about to be
    outOfRangePenalty = 300, -- per band width, viewDistMax - viewDistMin, outside that range
    elevationPenalty = 2, -- per degree off the nearest of elevation above or below
    travelPenalty = 200, -- for a spot the search's reach or further from the camera, so small moves win. Relative to the reach, so going fast isn't penalised
    keepBestMargin = 100, -- a different spot has to beat the best by this much, so it doesn't flip between two. Staying put doesn't
    clippingPenalty = 3000, -- a spot whose middle is clear, but the camera's hull clips something

    -- looking for spots to watch from
    searchRate = 30, -- searches a second, the same at any frame rate
    samplesPerSearch = 3, -- random spots tried each search, about 4 traces each
    -- how far from the camera random spots are tried, it grows with speed, so going fast keeps finding spots further on
    reachTime = 1, -- seconds of travel at the camera's speed
    reachToTargetMul = 1.5, -- never further than this many times the distance to the target
    minReach = 150, -- standing still
    maxReach = 2000,
    reachRandomness = 0.25, -- each spot's distance is the reach, give or take this fraction
    stuckReach = 400, -- can't see the target, or past viewDistMax, and the speed's reach is shorter than this is stuck, the reach starts here...
    stuckReachGrowth = 1.15, -- ...and grows this much a second until it's unstuck
    velocityBias = 1, -- how much random spots lean along the way the camera's moving

    -- the camera's size
    clearance = 16, -- half width of the camera's hull, spots it doesn't fit score worse, and the room check sweeps it
    smallHull = 4, -- half width of the hull its movement checks sweep, it keeps wallGap off walls itself rather than relying on its hull
    wallGap = 25, -- how far off walls, floors and ceilings it keeps, its paths and its velocity stop this short

    -- the target's predicted spot
    leadTime = 1, -- seconds ahead
    predictedWallGap = 16, -- a prediction that runs into a wall stops this far off it

    -- teleports
    landingTimeout = 1, -- seconds to wait for the server's teleport to reach us
    landedDist = 64, -- this close to the landing spot counts as landed
}

local LocalPlayer = LocalPlayer
local CurTime = CurTime
local vecZero = Vector( 0, 0, 0 )

local debugging = GetConVar( "huntersglee_debug_spectatewatching" ):GetBool()
cvars.AddChangeCallback( "huntersglee_debug_spectatewatching", function( _, _, new )
    debugging = tobool( new )

end, "glee_watchcamera_debugging" )

local debugLife = 0.05 -- seconds, redrawn every frame anyway
local snapTolerance = 12 -- units a frame's movement can be off what was asked for before it's printed as a snap
local debugBuried = Color( 100, 100, 100 ) -- a spot in a wall or the void
local debugSampled = Color( 255, 0, 0 )
local debugBest = Color( 0, 255, 0 )
local debugAim = Color( 255, 255, 0 )
local debugWantAim = Color( 255, 150, 0 )
local debugGroup = Color( 0, 150, 255 )
local debugPredicted = Color( 255, 0, 255 )
local debugPullIn = Color( 0, 255, 255 )

local MODE_DRIFT = 1
local MODE_SETTLED = 2
local MODE_PULLIN = 3
local modeNames = {
    [MODE_DRIFT] = "drifting",
    [MODE_SETTLED] = "settled",
    [MODE_PULLIN] = "pulling in",
}

local mode = MODE_DRIFT
local velocity = Vector( 0, 0, 0 ) -- what we're asking for, eased
local measuredVel = Vector( 0, 0, 0 ) -- what we actually got, a teleport or the server's clamp can differ
local lastCamPos
local aimPoint -- the eased aim point, where the view looks
local viewDir -- the eased view direction, eased as a direction so yaw never wraps the long way round
local snapAim = false -- the next frame jumps straight to the aim and the group, after a teleport
local lastTarget
local landing -- { eyePos, timeout } while the server's teleport is on its way

-- this frame's view of things, set at the top of SpectateWatchingDrive
local camPos
local watchPos -- the target's own spot
local predicted
local groupPos -- the eased group's spot, where the camera moves relative to, see GM:WatchAimPoint
local rawGroupPos -- this frame's, not eased
local buried -- the camera's in a wall, or the void
local watchBody -- what the target's spot is on, see GM:WatchAimPosOf
local pullInWant -- see updatePullInWant
local targetExtent = 0 -- see bodyExtent
local hasCompany = false -- see GM:WatchAimPoint

local best -- the best spot to watch from so far
local bestScore
local bestThroughWalls = false -- best sees the target and we don't, or it's in the void, so the camera flies straight through to it
local voidCost = tune.voidCostMax -- see updateVoidCost
local voidAppeal = 0 -- 0 to 1, how cheap the void's getting
local camSeesTarget = false -- as of the last search
local searchReach = tune.minReach -- how far this search's random spots go, see tune.reachTime
local stuckReach = tune.stuckReach
local nextSearch = 0
local settledFor = 0

local nextEnclosureCheck = 0
local lastRawGroupPos
local groupRunFor = 0
local lostSightFor = 0
local aloneFor = 0

local function ease( rate, dt )
    return 1 - math.exp( -rate * dt )

end

local function resetMovement()
    mode = MODE_DRIFT
    best = nil
    bestScore = nil
    bestThroughWalls = false
    settledFor = 0
    voidAppeal = 0

end


--[[ Traces, world only ]]

local hullTrace = {
    mask = MASK_SOLID_BRUSHONLY,
    mins = Vector( -tune.clearance, -tune.clearance, -tune.clearance ),
    maxs = Vector( tune.clearance, tune.clearance, tune.clearance ),
}

-- The camera's hull, for whether a spot has room, and the room check.
-- Windows and grates block every trace here, it shouldn't fly through glass
local function sweep( from, to )
    hullTrace.start = from
    hullTrace.endpos = to
    return util.TraceHull( hullTrace )

end

local smallTrace = {
    mask = MASK_SOLID_BRUSHONLY,
    mins = Vector( -tune.smallHull, -tune.smallHull, -tune.smallHull ),
    maxs = Vector( tune.smallHull, tune.smallHull, tune.smallHull ),
}

local function sweepSmall( from, to )
    smallTrace.start = from
    smallTrace.endpos = to
    return util.TraceHull( smallTrace )

end

-- actually in the wall, brushing one isn't buried
local function isBuried( pos )
    return GAMEMODE:IsInWall( pos ) or sweepSmall( pos, pos ).StartSolid

end


--[[ Aiming ]]

-- pull, 0 to 1, how hard the view's pulled to the aim point, their mouse fights it, see GM:SpectateWatchingRamp
local function updateAim( dt, wantPoint, pull )
    if snapAim or not aimPoint then
        aimPoint = wantPoint

    else
        aimPoint = LerpVector( ease( tune.aimPointRate, dt ), aimPoint, wantPoint )

    end

    local wantDir = ( aimPoint - camPos ):GetNormalized()
    if snapAim or not viewDir then
        viewDir = wantDir

    end

    local blended = LerpVector( ease( tune.viewRate * pull, dt ), viewDir, wantDir )
    if blended:LengthSqr() < 0.0001 then -- right behind us, the lerp passes through nothing
        blended = viewDir + viewDir:Angle():Right() * 0.1

    end
    blended:Normalize()

    local turned = math.deg( math.acos( math.Clamp( viewDir:Dot( blended ), -1, 1 ) ) )
    local maxTurn = tune.maxTurnSpeed * dt
    if turned > maxTurn then
        blended = LerpVector( maxTurn / turned, viewDir, blended )
        blended:Normalize()

    end

    local ang = blended:Angle()
    ang.p = math.Clamp( math.NormalizeAngle( ang.p ), -tune.maxPitch, tune.maxPitch )
    ang.y = math.NormalizeAngle( ang.y )
    ang.r = 0

    viewDir = ang:Forward() -- the clamped direction, or it creeps past maxPitch

    return ang

end

local function updateGroupPos( dt )
    if snapAim or not groupPos then
        groupPos = rawGroupPos

    else
        groupPos = LerpVector( ease( tune.groupPosRate, dt ), groupPos, rawGroupPos )

    end
end


--[[ The target's predicted spot ]]

-- never in a wall or out in the void, it stops short of whatever they'd run into
local function predictedPos( targetVel )
    local ahead = watchPos + targetVel * tune.leadTime
    local result = sweepSmall( watchPos, ahead )
    if not result.Hit then return ahead end
    if result.StartSolid then return watchPos end

    return result.HitPos + result.HitNormal * tune.predictedWallGap

end


--[[ The target's size ]]

-- Half the biggest side of its collision box, or of anything it's riding, the whole way up.
-- Not modelscale, some hunters are scaled far past the box they're given.
-- Returns that, and the top of what it's riding, itself when it isn't
local function bodyExtent( body )
    local biggest = 0
    local root = body
    local ent = body
    while IsValid( ent ) do
        local size = ent:OBBMaxs() - ent:OBBMins()
        biggest = math.max( biggest, size.x, size.y, size.z )
        root = ent
        ent = ent:GetParent()

    end

    return biggest / 2, root

end


--[[ Going round the target ]]

-- The search moves the camera between spots that score far apart.
-- Going round someone, each step scores nearly the same as the last, the travel penalty and keepBestMargin would swallow it.
-- So like the creep, it's a velocity, added while drifting and seeing them.
-- Moving steadily, it swings round to their face, at an angle off it rerolled every so often.
-- Idle without company, every so often it rolls whether to orbit them, or hold still, and maybe settle

local swingVel = Vector( 0, 0, 0 ) -- this frame's
local swingState -- what it did this frame, for the debug text
local lastFaceYaw
local turnRate = 0 -- eased, degrees a second
local faceSide -- 1 or -1, which side of their face, picked when they start moving, so it can't flip right behind them
local faceAngle -- degrees off dead ahead, see tune.faceAngleMin
local nextFaceRoll = 0
local orbitDir -- 1 or -1 orbiting, 0 holding still, nil not rolled yet. Kept while they move, so shuffling about doesn't reroll it
local nextOrbitRoll = 0
local calmUntil = 0 -- CurTime it stops holding still after flapping, see noteSwingKind
local lastSwingKind -- "face" or "orbit"
local flips = 0
local flipsWindowEnd = 0

local function resetSwing()
    lastFaceYaw = nil
    turnRate = 0
    faceSide = nil
    nextFaceRoll = 0
    orbitDir = nil
    calmUntil = 0
    lastSwingKind = nil
    flips = 0

end

-- Someone stop starting right on faceMinSpeed swaps it between swinging to their face and orbiting, over and over.
-- Swapping flapFlips times in a second, an extra roll whether to calm down, holding still for a roll's time, so it can settle
local function noteSwingKind( kind )
    if kind == lastSwingKind then return end

    local cur = CurTime()
    if flipsWindowEnd <= cur then
        flips = 0
        flipsWindowEnd = cur + 1

    end

    if lastSwingKind then
        flips = flips + 1

    end
    lastSwingKind = kind

    if flips < tune.flapFlips then return end
    flips = 0
    if math.random() >= tune.flapCalmChance then return end

    calmUntil = cur + math.Rand( tune.rollMin, tune.rollMax )
    orbitDir = 0
    nextOrbitRoll = calmUntil

end

-- the orbit's next second would lose sight of them, or hit a wall
local function orbitBlocked( around, dir )
    local step = around * ( dir * tune.orbitSpeed * tune.orbitLookAhead )
    local ahead = camPos + step
    if sweepSmall( camPos, ahead + step:GetNormalized() * tune.wallGap ).Hit then return true end

    return not GAMEMODE:WatchCanSee( ahead, watchPos, watchBody )

end

-- nil when there's no telling
local function facingYaw( body, root )
    if not IsValid( body ) then return end

    -- riding something, a vehicle's angles can face anywhere, where it's going can't
    if root ~= body then
        local vel = root:GetVelocity()
        if vel:Length2DSqr() < tune.faceMinSpeed * tune.faceMinSpeed then return end
        return vel:Angle().y

    end

    if body:IsPlayer() then return body:EyeAngles().y end
    if body:IsNPC() or body:IsNextBot() then return body:GetAngles().y end

end

local function updateSwing( dt, body, root )
    swingVel:Zero()
    swingState = nil

    local faceYaw = facingYaw( body, root )
    if faceYaw and lastFaceYaw and dt > 0 then
        local rate = math.abs( math.AngleDifference( faceYaw, lastFaceYaw ) ) / dt
        turnRate = Lerp( ease( tune.turnRateRate, dt ), turnRate, rate )

    end
    lastFaceYaw = faceYaw

    if calmUntil > CurTime() then
        swingState = "calmed down, it was flapping"
        return

    end

    local offset = camPos - watchPos
    offset.z = 0
    local radius = offset:Length()
    if radius < 1 then return end

    local around = Vector( -offset.y / radius, offset.x / radius, 0 ) -- anticlockwise round them, seen from above

    local moving = IsValid( root ) and root:GetVelocity():Length2DSqr() >= tune.faceMinSpeed * tune.faceMinSpeed
    if moving then
        if not faceYaw then
            faceSide = nil
            return

        end

        local camYaw = math.deg( math.atan2( offset.y, offset.x ) )
        if not faceSide then
            faceSide = math.AngleDifference( camYaw, faceYaw ) >= 0 and 1 or -1

        end

        local cur = CurTime()
        if nextFaceRoll <= cur then
            nextFaceRoll = cur + math.Rand( tune.rollMin, tune.rollMax )
            faceAngle = math.Rand( tune.faceAngleMin, tune.faceAngleMax )

        end

        local off = math.AngleDifference( faceYaw + faceSide * faceAngle, camYaw )
        local steady = math.Clamp( 1 - turnRate / tune.faceMaxTurnRate, 0, 1 )
        local together = math.Clamp( 1 - groupPos:Distance( watchPos ) / tune.faceGroupFade, 0, 1 )
        local speed = math.min( math.abs( off ) * tune.swingPerDegree, tune.swingMaxSpeed ) * steady * together

        swingVel:Set( around )
        swingVel:Mul( off > 0 and speed or -speed )
        swingState = string.format( "swinging to %.0f off their face at %.0f, turning %.0f", faceAngle, speed, turnRate )
        noteSwingKind( "face" )
        return

    end

    faceSide = nil
    if hasCompany then return end

    local cur = CurTime()
    if not orbitDir or nextOrbitRoll <= cur then
        nextOrbitRoll = cur + math.Rand( tune.rollMin, tune.rollMax )
        if math.random() >= tune.orbitChance then
            orbitDir = 0

        elseif not orbitDir or orbitDir == 0 then
            orbitDir = around:Dot( measuredVel ) >= 0 and 1 or -1 -- carry on the way it's already going round

        end
    end

    if orbitDir == 0 then
        swingState = "holding still, rolled"
        return

    end

    -- turns round before it gets there, rather than finding out by losing them and lurching back
    if orbitBlocked( around, orbitDir ) then
        if orbitBlocked( around, -orbitDir ) then
            swingState = "orbit blocked both ways"
            return

        end
        orbitDir = -orbitDir

    end

    swingVel:Set( around )
    swingVel:Mul( orbitDir * tune.orbitSpeed )
    swingState = "orbiting"
    noteSwingKind( "orbit" )

end


--[[ Scoring spots to watch from ]]

local function elevationOf( spot )
    local offset = spot - watchPos
    local len = offset:Length()
    if len < 1 then return 0 end

    return math.deg( math.asin( math.Clamp( offset.z / len, -1, 1 ) ) )

end

-- degrees off the nearest of elevation above or below the target
local function elevationOff( spot )
    local spotsElevation = elevationOf( spot )
    return math.min( math.abs( spotsElevation - tune.elevation ), math.abs( spotsElevation + tune.elevation ) )

end

-- drifting, a viewing range from the target, and moving is cheap
local function driftScore( spot )
    local dist = spot:Distance( watchPos ) - targetExtent
    local outOfRange = math.max( 0, tune.viewDistMin - dist, dist - tune.viewDistMax )
    local bands = outOfRange / ( tune.viewDistMax - tune.viewDistMin ) -- never capped, far off, every step closer has to count

    local score = -bands * tune.outOfRangePenalty
    score = score - math.min( spot:Distance( camPos ) / searchReach, 1 ) * tune.travelPenalty

    return score

end

-- a wall close behind the spot, away from the group, and better still one beside it too
local function wallBackScore( spot )
    local away = spot - groupPos
    away.z = 0
    if away:LengthSqr() < 1 then return 0 end
    away:Normalize()

    local reach = tune.wallGap + tune.wallBackReach
    local back = sweepSmall( spot, spot + away * reach )
    if not back.Hit or back.StartSolid then return 0 end

    local pastGap = math.max( back.Fraction * reach - tune.wallGap, 0 )
    local score = tune.wallBackScore * ( 1 - pastGap / tune.wallBackReach )

    local side = Vector( -away.y, away.x, 0 )
    if sweepSmall( spot, spot + side * reach ).Hit or sweepSmall( spot, spot - side * reach ).Hit then
        score = score + tune.cornerScore

    end

    return score

end

-- Settled, everything's from the group's spot, which the camera barely moves, its slow ease keeps it from chasing its own tail.
-- The far end of a range from them, a wall behind, moving is dear
local function settledScore( spot )
    local score = 0

    local dist = spot:Distance( groupPos ) - targetExtent
    local width = tune.settledDistMax - tune.settledDistMin
    local outOfRange = math.max( 0, tune.settledDistMin - dist, dist - tune.settledDistMax )
    local far = math.Clamp( ( dist - tune.settledDistMin ) / width, 0, 1 )
    score = score + far * tune.settledFarScore - outOfRange / width * tune.outOfRangePenalty

    score = score + wallBackScore( spot )
    score = score - spot:Distance( camPos ) * tune.settledTravelPerUnit

    return score

end

-- Spots in the void are scored like the rest, less voidCost.
-- Nothing's visible from in there, so they never earn the line of sight scores, they only win by getting closer.
-- seesTarget, when the caller's already traced it, nil to trace here
local function scoreSpot( spot, seesTarget )
    local score = 0
    if GAMEMODE:IsInWall( spot ) then
        score = score - voidCost

    else
        if sweep( spot, spot ).StartSolid then
            score = score - tune.clippingPenalty

        end

        if seesTarget == nil then
            seesTarget = GAMEMODE:WatchCanSee( spot, watchPos, watchBody )

        end
        if seesTarget then
            score = score + tune.losScore

            if GAMEMODE:WatchCanSee( spot, watchPos, watchBody, MASK_SOLID ) then
                score = score + tune.clearLosScore

            end

            -- the rest of the group in view too, on top of the target, never instead of them
            if GAMEMODE:WatchCanSee( spot, groupPos ) then
                score = score + tune.groupLosScore

            end
        end
        if GAMEMODE:WatchCanSee( spot, predicted, watchBody ) then
            score = score + tune.predictedLosScore

        end
    end

    score = score - elevationOff( spot ) * tune.elevationPenalty

    if mode == MODE_PULLIN then
        return score - spot:Distance( pullInWant ) * tune.pullInPerUnit

    end
    if mode == MODE_SETTLED then
        return score + settledScore( spot )

    end

    return score + driftScore( spot )

end

-- around the camera, pulling in, around the wanted point
local function randomSpot()
    local dir = VectorRand()
    local speed = measuredVel:Length()
    if speed > 1 then
        dir:Add( measuredVel * ( tune.velocityBias / speed ) )

    end
    dir:Normalize()

    local center = mode == MODE_PULLIN and pullInWant or camPos
    local randomness = tune.reachRandomness
    return center + dir * ( searchReach * math.Rand( 1 - randomness, 1 + randomness ) )

end


--[[ The search ]]

-- Normally only as far as the camera can fly without going through anything.
-- But drifting, when we can't see the target and the spot can, whatever's between us doesn't matter, it's going straight through.
-- Without that, a short wall between us and them stops the camera at the wall.
-- Drifting, a spot in the void is dug straight into too, its cost is in its score.
-- Buried, it's going through regardless
local function considerSpot( spot )
    local inVoid = GAMEMODE:IsInWall( spot )
    local seesTarget
    local throughWalls = false
    if mode == MODE_DRIFT then
        if inVoid then
            throughWalls = true

        elseif not camSeesTarget then
            seesTarget = GAMEMODE:WatchCanSee( spot, watchPos, watchBody )
            throughWalls = seesTarget

        end
    end

    if not buried and not throughWalls then
        local dir = ( spot - camPos ):GetNormalized()
        local result = sweepSmall( camPos, spot + dir * tune.wallGap )
        if result.Hit then
            -- off the wall, not back along the path, a path meeting it at a shallow angle would stop right against it
            spot = result.HitPos + result.HitNormal * tune.wallGap
            seesTarget = nil -- a different spot now

        end
    end

    local score = scoreSpot( spot, seesTarget )
    if debugging then
        debugoverlay.Line( camPos, spot, debugLife, GAMEMODE:IsInWall( spot ) and debugBuried or debugSampled, true )

    end

    local margin = tune.keepBestMargin
    if mode == MODE_SETTLED then
        margin = tune.settledKeepBestMargin

    elseif mode == MODE_PULLIN then
        margin = tune.pullInKeepBestMargin

    end
    if score <= bestScore + margin then return end

    best = spot
    bestScore = score
    bestThroughWalls = throughWalls

end

-- drifting's reach, see tune.reachTime
local function driftReach()
    -- The flight navigator's unstuck, a reach that grows while we're stuck.
    -- Blind, or far off, and slow, the speed's reach is short, spots that close never see them or gain enough
    -- to beat the travel penalty, so staying put keeps winning, and it never picks up speed
    local targetDist = camPos:Distance( watchPos )
    local speedsReach = measuredVel:Length() * tune.reachTime
    local needsToGo = not camSeesTarget or targetDist - targetExtent > tune.viewDistMax
    if needsToGo and speedsReach < stuckReach then
        stuckReach = stuckReach * tune.stuckReachGrowth ^ ( 1 / tune.searchRate )
        return math.min( stuckReach, tune.maxReach )

    end

    stuckReach = tune.stuckReach
    local targetsReach = targetDist * tune.reachToTargetMul
    return math.Clamp( math.min( speedsReach, targetsReach ), tune.minReach, tune.maxReach )

end

-- Drifting, out of range of the target, out of view, and slow, the void gets cheaper, it might be the only way to them.
-- Seeing them, there's a way through the air, so it never does. Call after camSeesTarget's updated.
-- Inside it already, it's just a bit worse than open air
local function updateVoidCost( dt )
    if GAMEMODE:IsInWall( camPos ) then
        voidCost = tune.voidCostInside
        return

    end

    if camSeesTarget then
        voidAppeal = 0
        voidCost = tune.voidCostMax
        return

    end

    local slowness = 0
    if mode == MODE_DRIFT and camPos:Distance( watchPos ) - targetExtent > tune.viewDistMax then
        slowness = 1 - math.min( velocity:Length() / tune.voidFullSpeed, 1 )

    end

    voidAppeal = Lerp( ease( tune.voidAppealRate, dt ), voidAppeal, slowness )
    voidCost = Lerp( voidAppeal, tune.voidCostMax, tune.voidCostInside )

end

-- A spot through a wall is committed to, until it's reached or beaten by keepBestMargin.
-- Glimpsing the target over a short wall on the way would otherwise drop it, and stop the camera at the wall
local function search( dt )
    camSeesTarget = GAMEMODE:WatchCanSee( camPos, watchPos, watchBody )
    updateVoidCost( dt )
    if mode == MODE_SETTLED then
        searchReach = tune.settledReach

    elseif mode == MODE_PULLIN then
        searchReach = tune.pullInReach

    else
        searchReach = driftReach()

    end

    -- the target moves, so the best spot's worth changes with it
    if best then
        if not buried and not bestThroughWalls and sweepSmall( camPos, best ).Hit then
            best = nil
            bestThroughWalls = false

        else
            bestScore = scoreSpot( best )

        end
    end

    -- staying put needs no margin, unless we're committed to going through
    local stayScore = scoreSpot( camPos, camSeesTarget )
    local stayMargin = bestThroughWalls and tune.keepBestMargin or 0
    if not best or stayScore >= bestScore + stayMargin then
        best = Vector( camPos )
        bestScore = stayScore
        bestThroughWalls = false

    end

    -- the wanted point itself, the random spots round it find a way when it's in a wall or out of view
    if mode == MODE_PULLIN then
        considerSpot( pullInWant )

    end

    for _ = 1, tune.samplesPerSearch do
        considerSpot( randomSpot() )

    end
end

local function searchIfDue()
    local cur = CurTime()
    if nextSearch > cur then return end

    local rate = mode == MODE_SETTLED and tune.settledSearchRate or tune.searchRate
    nextSearch = cur + 1 / rate
    search( 1 / rate )

end

local function drawBest()
    debugoverlay.Sphere( best, 8, debugLife, debugBest, true )
    debugoverlay.Line( camPos, best, debugLife, debugBest, true )

end


--[[ Rooms ]]

-- Settling is for rooms, out in the open, drifting does better
local enclosureDirs = { Vector( 0, 0, 1 ) }
for i = 0, 7 do
    local yaw = math.rad( i * 45 )
    table.insert( enclosureDirs, Vector( math.cos( yaw ), math.sin( yaw ), 0 ) )

end

-- returns whether it's a room, and how many traces hit, for the debug prints
local function isEnclosed()
    local hits = 0
    for _, dir in ipairs( enclosureDirs ) do
        if sweep( camPos, camPos + dir * tune.roomSize ).Hit then
            hits = hits + 1

        end
    end

    return hits >= tune.enclosedHits, hits

end

local function enclosureText( hits )
    return hits .. " of " .. #enclosureDirs .. " room traces hit, " .. tune.enclosedHits .. " needed"

end


--[[ Switching modes ]]

local function enterSettled()
    mode = MODE_SETTLED
    bestThroughWalls = false
    bestScore = nil -- drifting's score, the next search rescores it as settled
    nextSearch = 0
    nextEnclosureCheck = CurTime() + tune.enclosureCheckInterval
    lastRawGroupPos = nil
    groupRunFor = 0
    lostSightFor = 0
    aloneFor = 0

end

local function leaveMode( why )
    if debugging and mode ~= MODE_DRIFT then
        permaPrint( "watching: " .. modeNames[mode] .. " > drifting,", why )

    end
    resetMovement()

end

-- drifting's best spot has stayed close, and the camera's stayed still, long enough.
-- Only settles in a room, seeing the group and the target, with company. Alone, only when the roll said hold still, see updateSwing
local function trySettling()
    if not hasCompany and orbitDir ~= 0 then
        if debugging then
            permaPrint( "watching: would settle, but the target has no company, and it's not rolled to hold still" )

        end
        return false

    end

    -- right now, camSeesTarget is a search old
    local seesGroup = GAMEMODE:WatchCanSee( camPos, groupPos )
    local seesTarget = seesGroup and GAMEMODE:WatchCanSee( camPos, watchPos, watchBody )
    if not seesTarget then
        if debugging then
            permaPrint( "watching: would settle, but it can't see", seesGroup and "the target" or "the group's spot" )

        end
        return false

    end

    local enclosed, hits = isEnclosed()
    if not enclosed then
        if debugging then
            permaPrint( "watching: would settle, but it's too open here,", enclosureText( hits ) )

        end
        return false

    end

    enterSettled()
    if debugging then
        permaPrint( string.format( "watching: drift > settle, %.0f from the group's spot, %s", camPos:Distance( groupPos ), enclosureText( hits ) ) )

    end
    return true

end


--[[ Pulling in ]]

-- A lone idle skull, orbiting closer and closer, until it's staring it in the face.
-- The same search, spots scored on how close they are to a point just ahead of the camera.
-- When that point's in a wall, or can't see the skull, the search finds the nearest that's fine

local function isSkull( ent )
    return IsValid( ent ) and ent:GetClass() == "termhunt_skull_pickup"

end

local function skullStill()
    return watchBody:GetVelocity():LengthSqr() < tune.faceMinSpeed * tune.faceMinSpeed

end

-- From drifting, always, the orbit roll's for the living
local function tryPullingIn()
    if not isSkull( watchBody ) or not skullStill() then return false end
    if hasCompany then return false end
    if buried or bestThroughWalls or not camSeesTarget then return false end

    mode = MODE_PULLIN
    bestThroughWalls = false
    bestScore = nil -- drifting's score, the next search rescores it
    nextSearch = 0
    lostSightFor = 0

    if debugging then
        permaPrint( string.format( "watching: drift > pull in, %.0f from the skull", camPos:Distance( watchPos ) ) )

    end
    return true

end

-- In towards the skull, and round it whichever way the camera's already going.
-- Up close, round to its face, -skull:GetForward() looks at it head on, then straight there
local function updatePullInWant()
    local toSkull = watchPos - camPos
    local dist = toSkull:Length()
    if dist < 1 then
        pullInWant = Vector( camPos )
        return

    end
    local inward = toSkull / dist
    local fromEdge = dist - targetExtent

    local faceSpot = watchPos + watchBody:GetForward() * ( tune.pullInDist + targetExtent )
    local toFace = faceSpot - camPos
    local close = fromEdge <= tune.pullInDist + tune.pullInFaceArrive
    if close and toFace:Length() <= tune.pullInFaceArrive then
        pullInWant = faceSpot
        return

    end

    -- steps the size of the speed wanted, the camera's speed comes from how far the best spot is, see tune.speedPerUnit
    local inStep = tune.pullInSpeed / tune.speedPerUnit
    local want = camPos + inward * math.Clamp( fromEdge - tune.pullInDist, -inStep, inStep )

    -- the way round, with whatever's towards or away from the skull taken out
    local roundVelocity = velocity - inward * velocity:Dot( inward )
    local roundToFace = toFace - inward * toFace:Dot( inward )
    local around
    if close then
        around = roundToFace:LengthSqr() >= 1 and roundToFace or roundVelocity

    else
        around = roundVelocity:LengthSqr() >= 1 and roundVelocity or roundToFace

    end

    if around:LengthSqr() >= 1 then
        local roundStep = tune.pullInOrbitSpeed / tune.speedPerUnit
        if close then
            roundStep = math.min( roundStep, toFace:Length() )

        end
        want:Add( around:GetNormalized() * roundStep )

    end

    pullInWant = want

end

-- Why pulling in ends. nil while it carries on. A different target ends it too, see onTargetChanged
local function pullInExit( dt )
    if buried then return "buried" end
    if not isSkull( watchBody ) then return "the target's not a skull any more" end
    if not skullStill() then return "the skull's moving" end

    if camSeesTarget then
        lostSightFor = 0

    else
        lostSightFor = lostSightFor + dt
        if lostSightFor >= tune.lostSightTime then
            return debugging and string.format( "couldn't see the skull for %.1fs", lostSightFor ) or true

        end
    end
end

-- returns the velocity wanted
local function pullInThink( dt )
    local why = pullInExit( dt )
    if why then
        leaveMode( why )
        return vecZero

    end

    updatePullInWant()
    searchIfDue()
    if not best then return vecZero end

    if debugging then
        drawBest()
        debugoverlay.Cross( pullInWant, 6, debugLife, debugPullIn, true )

    end

    local toBest = best - camPos
    local dist = toBest:Length()
    if dist < 1 then return vecZero end

    local speed = math.min( dist * tune.speedPerUnit, tune.pullInMaxSpeed )
    return toBest * ( speed / dist )

end


--[[ Drifting ]]

-- returns the velocity wanted
local function driftThink( dt )
    if tryPullingIn() then return velocity end -- carries on round, the pull in's first search picks it up

    searchIfDue()
    if not best then return vecZero end

    if debugging then
        drawBest()

    end

    local toBest = best - camPos
    local dist = toBest:Length()

    -- through, walls count again
    if bestThroughWalls and not buried and dist <= tune.settleRadius then
        bestThroughWalls = false

    end

    -- only somewhere it can see them, settling behind a wall just holds it looking at the wall
    local canSettle = not buried and not bestThroughWalls and camSeesTarget
    if canSettle and dist <= tune.settleRadius and measuredVel:Length() <= tune.settleSpeed then
        settledFor = settledFor + dt
        if settledFor >= tune.settleTime then
            settledFor = 0 -- not settling, it checks again after another settleTime
            if trySettling() then return vecZero end

        end
    else
        settledFor = 0

    end

    local toTarget = watchPos - camPos
    local targetDist = toTarget:Length()

    -- Speed comes from how far the best spot is, the creep and the swing only add small moves the search can't see.
    -- It still keeps its speed in the open, the search reaches further the faster it goes, so the best spot stays well ahead.
    -- Near a wall the search finds nothing far, so it slows, as it should
    local wantVel = Vector( 0, 0, 0 ) -- not vecZero, the creep and swing below add to it
    if dist >= 1 then
        local speed = math.min( dist * tune.speedPerUnit, tune.maxSpeed )
        wantVel = toBest * ( speed / dist )

    end

    if not camSeesTarget then return wantVel end

    local pastSoftMax = targetDist - targetExtent - tune.viewDistSoftMax
    if pastSoftMax > 0 then
        local creepSpeed = math.min( pastSoftMax * tune.creepPerUnit, tune.creepMaxSpeed )
        wantVel:Add( toTarget * ( creepSpeed / targetDist ) )

    end

    wantVel:Add( swingVel )

    return wantVel

end


--[[ Settled ]]

-- Why settling ends. nil while it carries on
local function settledExit( dt )
    if buried then
        return debugging and ( GAMEMODE:IsInWall( camPos ) and "buried, inside a wall or the void" or "buried, within a few units of a wall" ) or true

    end

    -- the group as a whole moving on, not just one of them. Its unsmoothed spot, smoothed it'd notice too late
    local groupSpeed = 0
    if lastRawGroupPos and dt > 0 then
        groupSpeed = rawGroupPos:Distance( lastRawGroupPos ) / dt

    end
    lastRawGroupPos = rawGroupPos
    if groupSpeed >= tune.groupRunSpeed then
        groupRunFor = groupRunFor + dt

    else
        groupRunFor = 0

    end
    if groupRunFor >= tune.groupRunTime then
        return debugging and string.format( "the group moved on, its spot doing %.0f for %.1fs, past %d for %.1fs unsettles",
            groupSpeed, groupRunFor, tune.groupRunSpeed, tune.groupRunTime ) or true

    end

    -- alone, a skull always gets pulled in on, the living get the roll, see updateSwing
    local staysAlone = orbitDir == 0 and not isSkull( watchBody )
    if hasCompany or staysAlone then
        aloneFor = 0

    else
        aloneFor = aloneFor + dt
        if aloneFor >= tune.aloneTime then
            return debugging and "the target's alone, it orbits or pulls in instead" or true

        end
    end

    if GAMEMODE:WatchCanSee( camPos, watchPos, watchBody ) then
        lostSightFor = 0

    else
        lostSightFor = lostSightFor + dt
        if lostSightFor >= tune.lostSightTime then
            return debugging and string.format( "couldn't see the target, %s, for %.1fs, %.0f away",
                tostring( lastTarget ), lostSightFor, camPos:Distance( watchPos ) ) or true

        end
    end

    local cur = CurTime()
    if nextEnclosureCheck <= cur then
        nextEnclosureCheck = cur + tune.enclosureCheckInterval
        local enclosed, hits = isEnclosed()
        if not enclosed then
            return debugging and ( "it's opened up, " .. enclosureText( hits ) ) or true

        end
    end
end

-- returns the velocity wanted
local function settledThink( dt )
    local why = settledExit( dt )
    if why then
        leaveMode( why )
        return vecZero

    end

    searchIfDue()
    if not best then return vecZero end

    if debugging then
        drawBest()

    end

    local toBest = best - camPos
    local dist = toBest:Length()
    if dist < 1 then return vecZero end

    local speed = math.min( dist * tune.speedPerUnit, tune.settledMaxSpeed )
    return toBest * ( speed / dist )

end


--[[ Writing the input ]]

-- A safety net, never flies into anything, slides along it instead.
-- Its spots are already wallGap off what their paths hit, so this should rarely have anything to do.
-- Returns the velocity, and the wall's normal when it cut it
local function guardVelocity( vel )
    local speed = vel:Length()
    if speed < 1 then return vel end

    local reach = speed * tune.guardTime + tune.wallGap
    local result = sweepSmall( camPos, camPos + vel * ( reach / speed ) )
    if not result.Hit or result.StartSolid then return vel end

    local into = vel:Dot( result.HitNormal )
    if into >= 0 then return vel end

    return vel - result.HitNormal * into, result.HitNormal

end


--[[ Debugging movement ]]

local lastWrittenVel = Vector( 0, 0, 0 ) -- what the last frame asked for
local nextGuardPrint = 0

-- The camera moving well past what it asked for, something else moved it. A prediction correction, the engine, a teleport.
-- Its own movement is always eased, so a jump is never the camera's doing
local function checkForSnap( moved, dt )
    local asked = lastWrittenVel * dt
    local gap = ( moved - asked ):Length()
    -- the position only moves on ticks, so a frame can move a whole tick's worth, or nothing
    local tolerance = math.max( snapTolerance, lastWrittenVel:Length() * engine.TickInterval() * 2 )
    if gap <= tolerance then return end

    permaPrint( string.format( "watching: SNAP, moved %.0f but asked for %.0f, %.0f off. moved ( %.0f %.0f %.0f ), asked ( %.0f %.0f %.0f ), %s%s%s",
        moved:Length(), asked:Length(), gap,
        moved.x, moved.y, moved.z, asked.x, asked.y, asked.z,
        modeNames[mode],
        bestThroughWalls and ", through walls" or "",
        buried and ", buried" or "" ) )

end

local function printGuardCut( before, after, normal, wanted, modeBefore )
    local cur = CurTime()
    if nextGuardPrint > cur then return end
    nextGuardPrint = cur + 0.25

    local modeName = modeNames[mode]
    if modeBefore ~= mode then
        modeName = modeName .. ", changed mode this frame"

    end

    local bestText = "no best spot"
    if best then
        local toBest = best - camPos
        local side = toBest:Dot( normal ) < 0 and "BEHIND the wall" or "this side of the wall"
        bestText = string.format( "best spot %.0f away, %s%s", toBest:Length(), side, bestThroughWalls and ", through walls" or "" )

    end

    permaPrint( string.format( "watching: guard cut %.0f to %.0f, wanted %.0f, wall normal ( %.2f %.2f %.2f ), %s, %s",
        before:Length(), after:Length(), wanted:Length(), normal.x, normal.y, normal.z, bestText, modeName ) )

end

--[[ Their input, fighting the camera for control ]]

-- Whatever they do to the command comes through, on top of the camera.
-- Moving by any means is the move values. Looking by any means, mouse, stick or keys, is the view moving off what the camera wrote last frame.
-- Buttons pass straight through untouched, the server acts on them, see sh_spectatewatching.lua.
-- Pushing loosens the camera's grip, so it pulls back weaker, see GM:SpectateWatchingRamp. All the way loose, it lets go.
-- Read the command before writeMove, it overwrites the move values

local forwardSpeedVar = GetConVar( "cl_forwardspeed" ) -- what a move key held fully writes
local rampEnd = 0 -- CurTime its grip's tight again, see tune.rampTime
local drivenFrame -- FrameNumber() of the last drive
local drivenAng -- the view it wrote then, nil when it left the view alone

-- how far through their move values are, 0 to 1
local function moveAmount( cmd )
    local forward = cmd:GetForwardMove()
    local side = cmd:GetSideMove()
    local up = cmd:GetUpMove()

    return math.min( math.sqrt( forward * forward + side * side + up * up ) / forwardSpeedVar:GetFloat(), 1 )

end

-- How hard they're pushing, 0 to 1, the harder of moving and looking
local function pushing( cmd, dt )
    local push = moveAmount( cmd )
    if not drivenAng or dt <= 0 then return push end

    local ang = cmd:GetViewAngles()
    local turned = math.max( math.abs( math.AngleDifference( ang.p, drivenAng.p ) ), math.abs( math.AngleDifference( ang.y, drivenAng.y ) ) )

    return math.max( push, math.min( turned / dt / tune.fullLookSpeed, 1 ) )

end

-- Their move values as a world velocity, the way free roam flies. nil when there aren't any
local function handVelocity( cmd )
    local amount = moveAmount( cmd )
    if amount <= 0 then return end

    local ang = cmd:GetViewAngles()
    local wish = ang:Forward() * cmd:GetForwardMove() + ang:Right() * cmd:GetSideMove()
    wish.z = wish.z + cmd:GetUpMove()
    wish:Normalize()
    wish:Mul( tune.handSpeed * amount )

    return wish

end

-- returns whether it's all the way loose
local function loosenGrip( push, dt )
    local cur = CurTime()
    local loosened = dt * push * tune.rampTime / tune.inputSlack
    rampEnd = math.min( math.max( rampEnd, cur ) + loosened, cur + tune.rampTime )

    return rampEnd >= cur + tune.rampTime

end

-- The impulse marks the command as the camera's, then its move values are a world velocity, see sh_spectatewatching.lua.
-- hand, their own on top, see handVelocity. Returns what it wrote
local function writeMove( cmd, vel, hand )
    if hand then
        vel = vel + hand

    end

    cmd:SetForwardMove( vel.x )
    cmd:SetSideMove( vel.y )
    cmd:SetUpMove( vel.z )
    cmd:SetImpulse( GAMEMODE.SpectateWatchingImpulse )

    return vel

end


--[[ Each frame ]]

-- another of the group we're settled on, the scorer swaps between them, settling carries on
local function onTargetChanged( oldTarget, target )
    if mode ~= MODE_SETTLED then
        resetMovement()
        return

    end

    if not target or not groupPos then
        leaveMode( "the target changed to nothing" )
        return

    end

    local newPos, _, newBody = GAMEMODE:WatchAimPosOf( target )
    local fromGroup = newPos:Distance( groupPos )
    if fromGroup <= tune.groupRadius or GAMEMODE:WatchCanSee( camPos, newPos, newBody ) then
        lostSightFor = 0
        if debugging then
            permaPrint( "watching: still settled, the target changed to", target, "in the same group" )

        end
        return

    end

    leaveMode( debugging and string.format( "the target changed, %s to %s, %.0f from the group's spot, past %d and out of view isn't the same group",
        tostring( oldTarget ), tostring( target ), fromGroup, tune.groupRadius ) )

end

--[[---------------------------------------------------------
    GM:SpectateWatchingDrive
    @desc Writes the camera's movement and view into cmd, on top of whatever they're doing themselves.
        Their pushing loosens its grip, see the input block above.
    @param cmd: This frame's CUserCmd, still as they made it.
    @return boolean: True once they've taken back control. cmd's left as they made it, and watching should stop.
--]]---------------------------------------------------------
function GM:SpectateWatchingDrive( cmd )
    local hand = handVelocity( cmd )

    -- CreateMove can run more than once a frame, everything eased here would step twice. The repeats get the same answer
    local frame = FrameNumber()
    if frame == drivenFrame then
        if drivenAng then
            cmd:SetViewAngles( drivenAng )

        end
        writeMove( cmd, velocity, hand )
        return false

    end

    local dt = FrameTime()
    local push = pushing( cmd, dt )
    if push > 0 and loosenGrip( push, dt ) then
        drivenAng = nil
        return true

    end

    drivenFrame = frame

    -- their look, on top of where the camera left the view. It turns it back from there
    if drivenAng then
        viewDir = cmd:GetViewAngles():Forward()

    end
    drivenAng = nil

    local me = LocalPlayer()
    camPos = me:EyePos()

    local landed = true
    if landing then
        if landing.timeout < CurTime() or camPos:Distance( landing.eyePos ) < tune.landedDist then
            landing = nil

        else
            camPos = landing.eyePos
            landed = false

        end
    end

    if landed and lastCamPos and dt > 0 then
        measuredVel = ( camPos - lastCamPos ) / dt

        if debugging then
            checkForSnap( camPos - lastCamPos, dt )

        end
    else
        measuredVel = Vector( 0, 0, 0 )

    end
    lastCamPos = landed and camPos or nil

    local target = self:WatchTarget()
    if target ~= lastTarget then
        local oldTarget = lastTarget
        lastTarget = target
        resetSwing()
        onTargetChanged( oldTarget, target )

    end

    if not target then
        velocity = LerpVector( ease( tune.velocityRate, dt ), velocity, vecZero )
        writeMove( cmd, velocity, hand )
        return

    end

    local wantAim, targetsGroup, targetPos, targetVel, targetBody, company = self:WatchAimPoint( target, camPos )
    watchPos = targetPos
    rawGroupPos = targetsGroup
    hasCompany = company
    predicted = predictedPos( targetVel )
    buried = isBuried( camPos )

    local root
    watchBody = targetBody
    targetExtent, root = bodyExtent( targetBody )

    updateGroupPos( dt )
    updateSwing( dt, targetBody, root )
    local ramp = self:SpectateWatchingRamp()
    local ang = updateAim( dt, wantAim, ramp )
    snapAim = false
    cmd:SetViewAngles( ang )
    drivenAng = ang

    local modeBefore = mode
    local wantVel = vecZero
    if not landed then
        velocity:Zero()

    elseif mode == MODE_SETTLED then
        wantVel = settledThink( dt )

    elseif mode == MODE_PULLIN then
        wantVel = pullInThink( dt )

    else
        wantVel = driftThink( dt )

    end

    velocity = LerpVector( ease( tune.velocityRate, dt ), velocity, wantVel * ramp )
    local throughWalls = mode == MODE_DRIFT and bestThroughWalls
    if not buried and not throughWalls then
        local unguarded = velocity
        local wallNormal
        velocity, wallNormal = guardVelocity( velocity )
        if debugging and wallNormal then
            printGuardCut( unguarded, velocity, wallNormal, wantVel, modeBefore )

        end
    end
    lastWrittenVel = writeMove( cmd, velocity, hand )

    if debugging then
        debugoverlay.Cross( aimPoint, 12, debugLife, debugAim, true )
        debugoverlay.Cross( wantAim, 6, debugLife, debugWantAim, true )
        debugoverlay.Cross( groupPos, 16, debugLife, debugGroup, true )
        debugoverlay.Line( watchPos, predicted, debugLife, debugPredicted, true )

        local modeName = modeNames[mode]
        local text = "watching " .. tostring( target ) .. ", " .. modeName .. ( buried and ", buried" or "" ) .. ( throughWalls and ", through walls" or "" )
        local motion = string.format( "wants %.0f, asks %.0f, moving %.0f, best spot %.0f away scoring %.0f, %s, extent %.0f%s",
            wantVel:Length(), velocity:Length(), measuredVel:Length(),
            best and best:Distance( camPos ) or -1, bestScore or 0,
            swingState or "not swinging", targetExtent, hasCompany and ", has company" or "" )
        debugoverlay.ScreenText( 0.02, 0.5, text, debugLife, color_white )
        debugoverlay.ScreenText( 0.02, 0.52, motion, debugLife, color_white )

    end
end

-- Fresh start, carry on from wherever they were looking.
-- ramped, it started on its own, so its grip tightens slowly, see tune.rampTime
function GM:SpectateWatchingStarted( ramped )
    rampEnd = ramped and CurTime() + tune.rampTime or 0
    resetMovement()
    velocity = Vector( 0, 0, 0 )
    lastCamPos = nil
    aimPoint = nil
    groupPos = nil
    viewDir = LocalPlayer():EyeAngles():Forward()
    lastTarget = nil
    landing = nil
    drivenFrame = nil
    drivenAng = nil
    self:ResetWatchTarget()

end

--[[---------------------------------------------------------
    GM:SpectateWatchingRamp
    @desc How tight the camera's grip is. It tightens over tune.rampTime, their pushing loosens it.
        Started on purpose, it's tight straight away.
    @return number: 0 loose, to 1 tight.
--]]---------------------------------------------------------
function GM:SpectateWatchingRamp()
    return 1 - math.Clamp( ( rampEnd - CurTime() ) / tune.rampTime, 0, 1 )

end

-- The view cuts here, so easing out of the old spot would only look wrong.
-- pos is the player's new GetPos, it reaches us before the new position does
function GM:SpectateWatchingTeleported( pos )
    local me = LocalPlayer()
    landing = {
        eyePos = pos + ( me:EyePos() - me:GetPos() ),
        timeout = CurTime() + tune.landingTimeout,
    }

    leaveMode( debugging and string.format( "teleported, %.0f away", me:EyePos():Distance( landing.eyePos ) ) )
    velocity = Vector( 0, 0, 0 )
    lastCamPos = nil
    snapAim = true

end
