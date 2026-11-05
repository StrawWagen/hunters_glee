-- the belly cannon, a strider warp cannon shot paid instead of its owed missiles
-- it either holds right over where it last saw them, or backs away nose up until the belly bears, see plans
-- then it charges for a couple seconds and fires
-- the cannon entity does the shot and the visuals, this decides how and when, and gives up if it never lines up
local gunship = terminator_Extras.glee_Gunship

local cannonCfg = gunship.BellyCannonCfg

local hullMaxs = Vector( 20, 20, 20 )
local aimTrData = {
    mask = MASK_SHOT,
    mins = -hullMaxs,
    maxs = hullMaxs,
}

-- the cannon hangs off the bottom of the hull
function gunship.BellyOffset( npc )
    return Vector( 0, 0, npc:OBBMins().z )

end

function gunship.BellyPos( npc )
    return npc:LocalToWorld( gunship.BellyOffset( npc ) )

end

-- where the belly points, straight down when level, forward when it's tilted nose up
function gunship.BellyDir( npc )
    return -npc:GetUp()

end

-- the cannon only swings aimCone off straight out of the belly, past that it's pointed at the edge of the cone instead
local function clampToBellyCone( npc, dir )
    local bellyDir = gunship.BellyDir( npc )
    local along = bellyDir:Dot( dir )
    local cone = math.rad( cannonCfg.aimCone )
    if along >= math.cos( cone ) then return dir end

    -- the part of dir off to the side of the belly, the cone's edge is that way
    local across = dir - bellyDir * along
    if across:LengthSqr() < 0.0001 then
        -- dir's straight up through the hull, any edge will do
        across = npc:GetForward()

    end
    across:Normalize()
    return bellyDir * math.cos( cone ) + across * math.sin( cone )

end

-- where a shot from the belly aimed at aimPos would land, and what it'd hit
-- aimPos outside the belly's cone, and it lands where the cone's edge points
function gunship.BellyShotTrace( npc, aimPos, filter )
    local bellyPos = gunship.BellyPos( npc )
    local dir = clampToBellyCone( npc, ( aimPos - bellyPos ):GetNormalized() )
    aimTrData.start = bellyPos
    aimTrData.endpos = bellyPos + dir * 40000
    aimTrData.filter = filter or npc
    return util.TraceHull( aimTrData )

end

-- owed missiles, is the cannon worth setting up
-- nearly dead, it'll take the shot from anywhere
local function desperate( npc )
    return npc:Health() <= npc:GetMaxHealth() * cannonCfg.desperateHealth

end

local function tooFar( npc, aimPos )
    if desperate( npc ) then return false end
    return gunship.BellyPos( npc ):Distance( aimPos ) > cannonCfg.maxDist

end

local vecDown = Vector( 0, 0, -1 )

-- already within the belly cone of straight down, no backing off needed to bring the belly to bear
local function directlyBelow( npc, aimPos )
    local toAim = ( aimPos - gunship.BellyPos( npc ) ):GetNormalized()
    return toAim:Dot( vecDown ) >= math.cos( math.rad( cannonCfg.aimCone ) )

end

local roomHull = gunship.OrbitCfg.validateHull
local roomTrData = {
    mask = MASK_NPCSOLID_BRUSHONLY,
    mins = Vector( -roomHull, -roomHull, -roomHull ),
    maxs = Vector( roomHull, roomHull, roomHull ),
}

local function awayFrom( npc, pos )
    local away = npc:GetPos() - pos
    away.z = 0
    away:Normalize()
    return away

end

-- otherwise it backs into a wall until setupTimeout, glowing and growling at nothing
local function roomToBackOff( npc, aimPos )
    local myPos = npc:GetPos()
    local backedOff = myPos + awayFrom( npc, aimPos ) * cannonCfg.backoffRoom
    roomTrData.start = myPos
    roomTrData.endpos = backedOff
    roomTrData.filter = npc
    if util.TraceHull( roomTrData ).Hit then return false end

    aimTrData.start = backedOff + gunship.BellyOffset( npc )
    aimTrData.endpos = aimPos
    aimTrData.filter = npc
    return util.TraceHull( aimTrData ).HitPos:Distance( aimPos ) < cannonCfg.landTolerance

end

local function backingOff( npc )
    return npc.glee_FlightNav.measuredVel:Dot( npc:GetForward() ) < -cannonCfg.backingSpeed

end

-- straight away from where it's aiming, it keeps facing that way, so this flies it backwards
local function carrotAwayFrom( npc, target, aimPos )
    local carrot = npc:GetPos() + awayFrom( npc, aimPos ) * gunship.OrbitCfg.carrotDist
    carrot.z = gunship.OrbitAltitude( npc, carrot, target:GetPos().z )
    return carrot

end

-- the ways it takes the shot, picked once, when it decides to
-- aimPos is always where it last saw them
local plans = {
    -- already right over them, it holds there and shoots down, cover or not
    overhead = {
        canStart = function( npc, aimPos ) return directlyBelow( npc, aimPos ) end,
        inPosition = function( npc, aimPos ) return directlyBelow( npc, aimPos ) end,
        movePos = function( npc, _, aimPos ) return Vector( aimPos.x, aimPos.y, npc:GetPos().z ) end,
        tooOld = function() return false end,
    },
    -- backs away nose up until the belly bears, a big commitment
    -- so only on someone it can see right now, and called off once that sighting's stale
    backoff = {
        canStart = function( npc, aimPos, canSeeTarget ) return canSeeTarget and roomToBackOff( npc, aimPos ) end,
        inPosition = function( npc, aimPos ) return backingOff( npc ) or directlyBelow( npc, aimPos ) end,
        movePos = carrotAwayFrom,
        tooOld = function( sighting ) return CurTime() - sighting.time > cannonCfg.blindFireTime end,
    },
}
-- overhead's tried first, it's the cheaper shot
local planOrder = { "overhead", "backoff" }

-- how it'd take a belly cannon shot at target right now, "overhead", "backoff", or nil if it's got no shot
function gunship.PlanBellyCannon( npc, state, target, canSeeTarget )
    if CurTime() < state.nextBellyCannon then return end
    if not IsValid( target ) then return end
    local sighting = gunship.LastSighting( state, target )
    if not sighting then return end

    local aimPos = sighting.pos
    if tooFar( npc, aimPos ) then return end
    if gunship.BellyPos( npc ):Distance( aimPos ) < cannonCfg.minDist then return end

    for _, name in ipairs( planOrder ) do
        if plans[name].canStart( npc, aimPos, canSeeTarget ) then return name end

    end
end

-- enough things it hates bunched up around the target to be worth one big shot
function gunship.TargetIsInACrowd( npc, target )
    local hostiles = 0
    for _, thing in ipairs( ents.FindInSphere( target:GetPos(), cannonCfg.crowdRadius ) ) do
        if not ( thing:IsPlayer() or thing:IsNPC() or thing:IsNextBot() ) then continue end
        if thing:Health() <= 0 then continue end
        if npc:Disposition( thing ) ~= D_HT then continue end

        hostiles = hostiles + 1
        if hostiles >= cannonCfg.crowdCount then return true end

    end
    return false

end

-- where the plan wants it, belly aimed at it, and the shot would actually reach it
local function linedUp( npc, plan, aimPos )
    if not plan.inPosition( npc, aimPos ) then return false end

    local bellyPos = gunship.BellyPos( npc )
    if bellyPos:Distance( aimPos ) < cannonCfg.minDist then return false end

    local toAim = ( aimPos - bellyPos ):GetNormalized()
    local offAim = math.deg( math.acos( math.Clamp( gunship.BellyDir( npc ):Dot( toAim ), -1, 1 ) ) )
    if offAim > cannonCfg.aimCone then return false end

    return gunship.BellyShotTrace( npc, aimPos ).HitPos:Distance( aimPos ) < cannonCfg.landTolerance

end

-- the cannon's there from the moment it's decided, glowing small under the belly as a warning
-- planName from PlanBellyCannon
function gunship.StartBellyCannon( npc, state, target, planName )
    local cannon = ents.Create( "glee_gunshipbellybeam" )
    if IsValid( cannon ) then
        cannon:SetOwner( npc )
        cannon:SetPos( gunship.BellyPos( npc ) )
        cannon:SetParent( npc )
        cannon.target = target
        cannon:Spawn()

    end

    state.bellyCannon = {
        target = target,
        cannon = cannon,
        giveUpTime = CurTime() + cannonCfg.setupTimeout,
        planName = planName,
    }

    -- it's decided, a low growl as it starts lining up
    gunship.SweepSound( npc, state, "planSound", "npc/combine_gunship/see_enemy.wav", 100, 60, 1.2, 140 )

end

local function finish( npc, state )
    state.bellyCannon = nil
    state.nextBellyCannon = CurTime() + cannonCfg.cooldown[gunship.HealthSegment( npc )]

end

local function giveUp( npc, state )
    SafeRemoveEntity( state.bellyCannon.cannon )
    finish( npc, state )
    return "gaveup"

end

-- nil while it's still setting up or charging, "done" and the plan's name once it's fired, "gaveup" if it never lined up
-- distracted, it keeps lining up but won't start the charge, a charge already going still fires
function gunship.BellyCannonRoutine( npc, state, distracted )
    local routine = state.bellyCannon
    local target = routine.target
    local cannon = routine.cannon
    local plan = plans[routine.planName]
    if not IsValid( cannon ) then return giveUp( npc, state ) end

    if not cannon:IsCharging() then
        if not IsValid( target ) or target:Health() <= 0 or CurTime() > routine.giveUpTime then return giveUp( npc, state ) end
        -- it's seen someone else since, or what it saw's too old to commit to
        local sighting = gunship.LastSighting( state, target )
        if not sighting or plan.tooOld( sighting ) then return giveUp( npc, state ) end

        local aimPos = sighting.pos
        -- backed off too far to ever line it up
        if tooFar( npc, aimPos ) then return giveUp( npc, state ) end

        -- for tuning aimCone against how far it really tilts
        if gunship.Debugging:GetBool() then
            local bellyPos = gunship.BellyPos( npc )
            debugoverlay.Line( bellyPos, bellyPos + gunship.BellyDir( npc ) * 1500, gunship.ThinkInterval, Color( 0, 150, 255 ), true )

        end

        if distracted then return end
        if not linedUp( npc, plan, aimPos ) then return end

        cannon:StartCharge( aimPos )
        -- the strider's prefire
        npc:EmitSound( "ambient/materials/metal_stress1.wav", 100, 60, 1, CHAN_STATIC )
        gunship.SweepSound( npc, state, "prefireSound", "npc/combine_gunship/gunship_pain.wav", 120, 100, cannonCfg.prefireTime )
        return

    end

    -- the afterglow plays out on its own, it's free to move on once the shot's landed
    if not cannon:GetFired() then return end

    finish( npc, state )
    return "done", routine.planName

end

-- where it flies while lining up and charging, nil once there's nothing to line up on
function gunship.BellyCannonMovePos( npc, state )
    local routine = state.bellyCannon
    local target = routine.target
    if not IsValid( target ) then return end
    local sighting = gunship.LastSighting( state, target )
    if not sighting then return end

    return plans[routine.planName].movePos( npc, target, sighting.pos )

end

local function setSpeed( npc, state, speed )
    -- running for its life wins
    if state.fleeing then return end
    terminator_Extras.gleeFlightNavigator.SetSpeedOverride( npc, speed )

end

-- the shot shoves it back along the way it fired, and it's let off the leash to ride it
function gunship.BellyCannonRecoil( npc, shotDir )
    local state = npc.glee_GunshipState
    -- SetVelocity on an npc replaces its velocity, so add ours to it
    npc:SetVelocity( npc:GetVelocity() - shotDir * cannonCfg.recoilKick )

    state.recoilUntil = CurTime() + cannonCfg.recoilTime
    state.recoilPos = npc:GetPos() - shotDir * cannonCfg.recoilDist
    state.nextSteer = 0 -- steer into it now, not whenever the next steer was due
    setSpeed( npc, state, cannonCfg.recoilSpeed )

end

-- where the recoil's carrying it, nil once it's back under its own control
function gunship.ManageBellyCannonRecoil( npc, state )
    if not state.recoilUntil then return end
    if CurTime() < state.recoilUntil then return state.recoilPos end

    state.recoilUntil = nil
    state.recoilPos = nil
    setSpeed( npc, state, nil )

end
