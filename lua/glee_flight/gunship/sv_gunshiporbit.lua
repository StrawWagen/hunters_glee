-- where the gunship heads while circling, and how high it flies
local gunship = terminator_Extras.glee_Gunship

local orbitCfg = gunship.OrbitCfg
local boomerangCfg = gunship.BoomerangCfg

local debugging = gunship.Debugging

local validateTrData = {
    mask = MASK_NPCSOLID,
    mins = Vector( -orbitCfg.validateHull, -orbitCfg.validateHull, -orbitCfg.validateHull ),
    maxs = Vector( orbitCfg.validateHull, orbitCfg.validateHull, orbitCfg.validateHull ),
}

-- degrees off the line to the center, steers us back toward the radius
function gunship.OrbitAngle( distToCenter, radius )
    if math.abs( distToCenter - radius ) <= orbitCfg.sweetBand then return orbitCfg.baseAngle end
    if distToCenter > radius then return orbitCfg.baseAngle - orbitCfg.angleCorrection end
    return orbitCfg.baseAngle + orbitCfg.angleCorrection

end

local function flatDirTo( from, to )
    local dir = to - from
    dir.z = 0
    dir:Normalize()
    return dir

end

local function rotatedOffCenter( toCenterFlat, angle, orbitDir )
    local rotated = Vector( toCenterFlat )
    rotated:Rotate( Angle( 0, angle * orbitDir, 0 ) )
    return rotated

end

-- where we're already going, the nose when we're barely moving
local function momentumDir( npc )
    local vel = npc.glee_FlightNav.measuredVel
    if vel:LengthSqr() < 100^2 then return npc:GetForward() end
    return vel:GetNormalized()

end

local function blendMomentum( dir, momentum )
    local blended = momentum * orbitCfg.momentum + dir * ( 1 - orbitCfg.momentum )
    blended:Normalize()
    return blended

end

-- picks the next heading, angle degrees off the line to the center
-- flips the orbit direction when the heading hits a wall, or would lose sight of the center
-- returns the heading, and "clear", "obscured" or "blocked"
function gunship.NextHeading( npc, state, center, angle, canSeeCenter )
    local myPos = npc:GetPos()
    local toCenterFlat = flatDirTo( myPos, center )
    local momentum = momentumDir( npc )

    local rotated = rotatedOffCenter( toCenterFlat, angle, state.orbitDir )
    local heading = blendMomentum( rotated, momentum )
    local carrot = myPos + heading * orbitCfg.carrotDist

    validateTrData.start = myPos
    validateTrData.endpos = carrot
    validateTrData.filter = npc
    local clear = not util.TraceHull( validateTrData ).Hit and util.IsInWorld( carrot )
    local unObscured = terminator_Extras.PosCanSee( center, myPos + heading * orbitCfg.sightCheckDist, MASK_SOLID_BRUSHONLY )

    local outcome
    if clear and ( unObscured or not canSeeCenter ) then
        outcome = "clear"

    elseif clear then
        -- back out the way we came, to where it could see
        state.orbitDir = -state.orbitDir
        heading = blendMomentum( -rotated, momentum )
        outcome = "obscured"

    else
        -- wall, swing round the other way
        state.orbitDir = -state.orbitDir
        heading = blendMomentum( rotatedOffCenter( toCenterFlat, angle, state.orbitDir ), momentum )
        outcome = "blocked"

    end

    if debugging:GetBool() then
        debugoverlay.Line( myPos, myPos + heading * orbitCfg.carrotDist, 2, Color( 255, 150, 0 ), true )
        debugoverlay.Text( myPos + heading * orbitCfg.carrotDist, outcome, 2 )

    end

    return heading, outcome

end

-- the radius pulls in where it keeps losing sight or hitting walls, and grows back out in the open
function gunship.AdaptOrbitRadius( state, outcome, canSeeCenter )
    local mul = state.radiusMul
    if outcome == "obscured" then
        mul = mul * orbitCfg.radiusShrinkObscured

    elseif outcome == "blocked" then
        mul = mul * orbitCfg.radiusShrinkBlocked

    elseif canSeeCenter then
        mul = mul * orbitCfg.radiusRecover

    end
    state.radiusMul = math.Clamp( mul, orbitCfg.radiusMinMul, 1 )

end

local function floorDistBelow( pos )
    return pos.z - terminator_Extras.getFloorTr( pos ).HitPos.z

end

-- cruise height over the floor under pos
-- no floor in reach, off the map or over a pit, and pos keeps its own height, the miss lands 6000 down
function gunship.CruiseZ( pos )
    local floorTr = terminator_Extras.getFloorTr( pos )
    if not floorTr.Hit or floorTr.StartSolid then return pos.z end
    return floorTr.HitPos.z + orbitCfg.cruiseHeight

end

local function bobHeight()
    local cur = CurTime()
    local height = 0
    for _, bob in ipairs( orbitCfg.bobs ) do
        if cur % bob.period < bob.period / 2 then
            height = height + bob.height

        end
    end
    return height

end

-- near the target's height when we're way too high, or it's above us, otherwise cruising above the floor
function gunship.OrbitAltitude( npc, carrot, targetZ )
    local myPos = npc:GetPos()
    local tooHigh = floorDistBelow( carrot ) > orbitCfg.tooHighCarrot or floorDistBelow( myPos ) > orbitCfg.tooHighMe
    if tooHigh or targetZ > myPos.z then
        local z = targetZ + orbitCfg.targetHeightBase + bobHeight()
        if util.IsInWorld( Vector( myPos.x, myPos.y, z ) ) then return z end

    end
    return gunship.CruiseZ( myPos )

end

-- dodging a rocket, it keeps going the way it was, and arcs round until it's heading back at the target
-- no wall checks or flips, it commits, the navigator still steers it round what's in the way
function gunship.StartBoomerang( npc, state )
    local startDir = momentumDir( npc )
    startDir.z = 0
    state.boomerangStartYaw = startDir:Angle().y
    state.boomerangStart = CurTime()

end

function gunship.BoomerangDone( state )
    return CurTime() - state.boomerangStart >= boomerangCfg.duration

end

-- the heading, and how many degrees it's still off the center
-- turned the short way round, further the longer it's been going, re-aimed every call as the center moves
function gunship.BoomerangHeading( npc, state, center )
    local progress = math.min( ( CurTime() - state.boomerangStart ) / boomerangCfg.duration, 1 )
    local centerYaw = flatDirTo( npc:GetPos(), center ):Angle().y
    local startYaw = state.boomerangStartYaw

    local yaw = startYaw + math.AngleDifference( centerYaw, startYaw ) * progress
    local offCenter = math.abs( math.AngleDifference( centerYaw, yaw ) )
    return Angle( 0, yaw, 0 ):Forward(), offCenter

end
