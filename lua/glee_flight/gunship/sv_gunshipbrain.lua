local gunship = terminator_Extras.glee_Gunship
local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator
local gleeFlightHeavies = terminator_Extras.gleeFlightHeavies

local orbitCfg = gunship.OrbitCfg
local boomerangCfg = gunship.BoomerangCfg
local bombCfg = gunship.BombCfg
local chargeCfg = gunship.ChargeCfg
local spiteCfg = gunship.SpiteCfg

local debugging = gunship.Debugging

-- 1 is nearly dead, 3 is full health, most of the tuning is indexed by this
function gunship.HealthSegment( self )
    return math.Clamp( math.ceil( self:Health() / self:GetMaxHealth() * 3 ), 1, 3 )

end

-- whoever we're fighting, or chasing from memory
local function gunshipUpdateMemory( state, target, rocket )
    if IsValid( target ) then
        state.rememberedTarget = target
        state.forgetTargetTime = CurTime() + gunship.TargetMemory

    elseif rocket and not IsValid( state.rememberedTarget ) then
        -- shooting rockets at us gets attention
        local shooter = rocket:GetOwner()
        if IsValid( shooter ) then
            state.rememberedTarget = shooter
            state.forgetTargetTime = CurTime() + gunship.TargetMemory

        end
    end

    local rememberedTarget = state.rememberedTarget
    if not IsValid( rememberedTarget ) or rememberedTarget:Health() <= 0 or CurTime() > state.forgetTargetTime then
        state.rememberedTarget = nil
        return

    end
    return rememberedTarget

end

-- the last time it saw target, { target, pos, time, missilesSince }
-- nil if it never has, or it's seen someone else since, so nothing shoots at the wrong person's spot
function gunship.LastSighting( state, target )
    local sighting = state.sighting
    if not sighting or sighting.target ~= target then return end
    return sighting

end

-- owed missiles in all of these, moving between them keeps the ammo and skips the sounds
local attackModes = {
    bomb = true,
    bellycannon = true,
    charge = true,
    rage = true,
}

local function gunshipSetMode( self, state, mode, segment )
    if state.mode == mode then return end

    local wasAttacking = attackModes[state.mode]
    if wasAttacking and not attackModes[mode] then
        gunship.EndBombRun( self, state )
        state.hurtSinceBombRun = false

    end
    state.mode = mode

    if attackModes[mode] and not wasAttacking then
        gunship.StartBombRun( self, state, segment )

    elseif mode == "duel" then
        state.nextDuelBomb = CurTime() + bombCfg.duelToBombEvery[segment]
        -- the quiet gun has to go quiet again within this duel, or one long silence chains attack after attack
        state.lastGunVolley = math.max( state.lastGunVolley, CurTime() )

    end
end

-- it's owed missiles, they come out of the belly cannon when it's got a shot, otherwise it's a bomb run
local function gunshipAttack( self, state, target, segment, canSeeTarget )
    local plan = gunship.PlanBellyCannon( self, state, target, canSeeTarget )
    if plan then
        gunshipSetMode( self, state, "bellycannon", segment )
        gunship.StartBellyCannon( self, state, target, plan )
        return

    end
    gunshipSetMode( self, state, "bomb", segment )

end

local function inVehicle( ent )
    return ent.InVehicle and ent:InVehicle()

end

local function gunshipManageBoomerang( self, state, rocket, orbitCenter )
    if state.boomerangStart and gunship.BoomerangDone( state ) then
        state.boomerangStart = nil
        state.nextCarrot = 0 -- the old orbit heading's stale
        if state.fleeing then
            state.fleeing = nil
            gleeFlightNavigator.SetSpeedOverride( self, nil )

        end
    end

    if not rocket or state.boomerangStart then return end

    -- one more hit like the worst it's taken kills it, run like hell
    local lastHit = self:Health() <= state.biggestHitTaken
    -- raging, rockets don't faze it, unless the next one kills it
    if state.mode == "rage" then
        if not lastHit then return end

    -- not in the belly cannon routine, it's committed, rockets or not
    elseif state.mode ~= "duel" and state.mode ~= "bomb" then
        return

    end
    -- unhurt, it trusts its gun to shoot the rocket down, and holds its orbit
    if not state.hurtSinceBombRun then return end
    if not orbitCenter then return end

    gunship.StartBoomerang( self, state )

    if lastHit then
        state.fleeing = true
        gleeFlightNavigator.SetSpeedOverride( self, gunship.FleeSpeed )

    end
end

-- the carrot ahead of us along heading, at the altitude we want
local function gunshipCarrotAlong( self, rememberedTarget, heading )
    local carrot = self:GetPos() + heading * orbitCfg.carrotDist
    carrot.z = gunship.OrbitAltitude( self, carrot, rememberedTarget:GetPos().z )
    return carrot

end

-- refreshes the heading on its own clock
local function gunshipCirclingIdealPos( self, state, rememberedTarget, orbitCenter, canSeeTarget, angle )
    if CurTime() >= state.nextCarrot or not state.heading then
        state.nextCarrot = CurTime() + orbitCfg.carrotInterval
        local heading, outcome = gunship.NextHeading( self, state, orbitCenter, angle, canSeeTarget )
        state.heading = heading
        state.lastOutcome = outcome

    end
    return gunshipCarrotAlong( self, rememberedTarget, state.heading )

end

local function cruiseAbove( pos )
    return Vector( pos.x, pos.y, gunship.CruiseZ( pos ) )

end

function gunship.Think( self )
    local state = self.glee_GunshipState
    local myPos = self:GetPos()
    gleeFlightNavigator.UpdateVelocity( self )

    gleeFlightHeavies.PrioritizeKnownHeavies( self )

    -- its enemy's either a rocket coming at it, or someone to fight
    local currEnemy = self:GetEnemy()
    local validEnemy = IsValid( currEnemy )
    local rocket = validEnemy and currEnemy:GetClass() == "rpg_missile" and currEnemy or nil
    local target = validEnemy and not rocket and currEnemy or nil
    local rememberedTarget = gunshipUpdateMemory( state, target, rocket )
    -- raging, it picks who to fight itself, the engine never has to acquire them
    local rageTarget = gunship.ManageRage( self, state )
    if rageTarget then
        rememberedTarget = rageTarget

    end

    if not state.spottedAPlayer and target and target:IsPlayer() then
        state.spottedAPlayer = true
        hook.Run( "glee_gunship_firstspottedplayer", self, target )

    end

    -- a rocket as its enemy doesn't blind it to whoever fired it
    local fighting = rageTarget or target or rememberedTarget
    local canSeeTarget = false
    if fighting then
        local targetsCenter = fighting:WorldSpaceCenter()
        canSeeTarget = terminator_Extras.PosCanSee( myPos, targetsCenter, MASK_SOLID_BRUSHONLY )
        if canSeeTarget then
            state.sighting = {
                target = fighting,
                pos = targetsCenter,
                time = CurTime(),
                missilesSince = 0,
            }
        end
    end

    local segment = gunship.HealthSegment( self )
    local segmentDropped = segment < state.lastSegment
    state.lastSegment = segment

    -- down to its last third, where it goes mad at rockets and fires the belly cannon from anywhere
    if segment == 1 and not state.wentDesperate then
        state.wentDesperate = true
        hook.Run( "glee_gunship_desperate", self )

    end

    local distToTarget = rememberedTarget and myPos:Distance2D( rememberedTarget:GetPos() ) or math.huge
    local inRange = distToTarget < orbitCfg.engageDist
    -- a rocket's its enemy, and it's healthy enough to hold its missiles and belly cannon for it
    local distracted = rocket ~= nil and self:Health() >= self:GetMaxHealth() * bombCfg.rocketDistractsAbove

    -- where it last saw them, led a little
    local orbitCenter
    local sighting = rememberedTarget and gunship.LastSighting( state, rememberedTarget )
    if rememberedTarget then
        local seenAt = sighting and sighting.pos or rememberedTarget:WorldSpaceCenter()
        orbitCenter = seenAt + rememberedTarget:GetVelocity() * orbitCfg.centerLeadTime

    end

    if rocket and gunship.NextHitCouldKill( self ) then
        gunship.TerrorAtRocket( self, state, rocket )

    end

    state.canFire = false

    local idealMovePos
    local orbitRadius
    local currentTargPosName
    local wandering
    local searching
    local bellyCannoning

    -- a belly cannon shot it's lining up gets finished first
    if rageTarget and state.mode ~= "rage" and state.mode ~= "bellycannon" then
        gunshipSetMode( self, state, "rage", segment )

    end

    local currMode = state.mode
    -- nobody to fight
    -- chase whoever we remember
    -- OR fly to sound hint
    -- OR wander
    if currMode == "acquire" then
        if target then
            state.currentGunshipTask = "acquire_switchToHandler"
            gunshipSetMode( self, state, "handler", segment )

        elseif rememberedTarget and not inVehicle( rememberedTarget ) then
            local lostFor = sighting and CurTime() - sighting.time or math.huge

            -- long gone, it homes right in on them, coming over the rooftops like an ambush
            if lostFor > orbitCfg.searchFor then
                state.currentGunshipTask = "acquire_huntRememberedTarget"
                idealMovePos = cruiseAbove( rememberedTarget:GetPos() )

            elseif myPos:Distance2D( orbitCenter ) > orbitCfg.engageDist then
                state.currentGunshipTask = "acquire_chaseRememberedTarget"
                idealMovePos = cruiseAbove( orbitCenter )

            -- circle where we lost them, peeking in windows and doors, hovering on the roof never finds them
            else
                state.currentGunshipTask = "acquire_searchRememberedTarget"
                orbitRadius = orbitCfg.searchRadius
                searching = true

            end

        elseif state.lastHeardSoundPos then
            currentTargPosName = "lastHeardSoundPos"
            state.currentGunshipTask = "acquire_approachSoundHint"

            idealMovePos = cruiseAbove( state.lastHeardSoundPos )
            if myPos:Distance2D( state.lastHeardSoundPos ) < 1500 then
                state.lastHeardSoundPos = nil

            end
        else
            wandering = true
            state.currentGunshipTask = "acquire_wander"
            idealMovePos = gleeFlightNavigator.WanderPos( self )

        end
    -- pick how to fight whoever we've got
    elseif currMode == "handler" then
        state.currentGunshipTask = "handler_pickMode"
        local chargeWindowOpen = CurTime() < state.chargeWindowEnd

        if not target and sighting and chargeWindowOpen then
            state.chargeWindowEnd = 0
            gunshipSetMode( self, state, "charge", segment )
            state.ammo = state.ammo + chargeCfg.extraAmmo
            self:Fire( "MoveTopSpeed" )

        elseif not target then
            gunshipSetMode( self, state, "acquire", segment )

        elseif not inRange then
            gunshipSetMode( self, state, "approach", segment )

        elseif state.ammo <= 2 then
            gunshipSetMode( self, state, "duel", segment )

        else
            gunshipAttack( self, state, target, segment, canSeeTarget )

        end
    -- get in range
    elseif currMode == "approach" then
        if not target then
            state.currentGunshipTask = "approach_switchToHandler"
            gunshipSetMode( self, state, "handler", segment )

        elseif inRange then
            state.currentGunshipTask = "approach_switchToDuel"
            gunshipSetMode( self, state, "duel", segment )

        else
            state.currentGunshipTask = "approach_approachTarget"
            idealMovePos = cruiseAbove( rememberedTarget:GetPos() )

        end
    -- circle them, pulse gun blazing
    elseif currMode == "duel" then
        local spiteful = state.spite >= spiteCfg.attackAt
        local overhead = distToTarget < bombCfg.overheadRadius
        local gunQuiet = CurTime() - state.lastGunVolley > bombCfg.quietGunTime

        if rocket then
            state.currentGunshipTask = "duel_rocketIncoming"
            -- hurt, it hits back at whoever fired, instead of just dodging
            if not distracted then
                gunshipAttack( self, state, rememberedTarget, segment, canSeeTarget )

            end
        elseif not target or not inRange then
            state.currentGunshipTask = "duel_switchToHandler"
            gunshipSetMode( self, state, "handler", segment )

        elseif spiteful or segmentDropped or CurTime() >= state.nextDuelBomb then
            state.currentGunshipTask = "duel_attack"
            gunshipAttack( self, state, target, segment, canSeeTarget )

        -- a crowd around the target is worth the cannon, owed or not
        elseif gunship.PlanBellyCannon( self, state, target, canSeeTarget ) and gunship.TargetIsInACrowd( self, target ) then
            state.currentGunshipTask = "duel_attackCrowd"
            gunshipAttack( self, state, target, segment, canSeeTarget )

        -- right over them and the gun's gone quiet, it can't angle down that far, so they're owed missiles
        elseif overhead and gunQuiet then
            state.currentGunshipTask = "duel_attackFromOverhead"
            gunshipAttack( self, state, target, segment, canSeeTarget )

        else
            state.currentGunshipTask = "duel_orbit"
            orbitRadius = orbitCfg.duelRadius

        end
    -- circle wider, missiles away
    elseif currMode == "bomb" then
        if state.ammo <= 0 or not rememberedTarget then
            state.currentGunshipTask = "bomb_switchToHandler"
            gunshipSetMode( self, state, "handler", segment )

        -- the cannon's come off cooldown, or it's got a shot it didn't before, the rest of its missiles go into that
        elseif not distracted and gunship.PlanBellyCannon( self, state, rememberedTarget, canSeeTarget ) then
            state.currentGunshipTask = "bomb_switchToBellyCannon"
            gunshipAttack( self, state, rememberedTarget, segment, canSeeTarget )

        elseif rocket then
            state.currentGunshipTask = "bomb_rocketIncoming"
            -- low hp, about to die
            if segment == 1 then
                gunship.MadReload( state, rocket )

            end
        else
            state.currentGunshipTask = "bomb_orbit"
            state.canFire = true
            orbitRadius = orbitCfg.duelRadius * orbitCfg.bombRadiusMul

        end
    -- spite's boiled over, bombard whoever's hurt it, missiles never run out while the spite lasts
    elseif currMode == "rage" then
        if not rageTarget then
            state.currentGunshipTask = "rage_calmedDown"
            gunshipSetMode( self, state, "handler", segment )

        elseif state.spite >= spiteCfg.perBellyCannon and gunship.PlanBellyCannon( self, state, rageTarget, canSeeTarget ) then
            state.currentGunshipTask = "rage_bellyCannon"
            gunshipAttack( self, state, rageTarget, segment, canSeeTarget )

        else
            state.currentGunshipTask = "rage_bombard"
            state.canFire = true
            state.ammo = math.max( state.ammo, 2 )
            orbitRadius = orbitCfg.duelRadius * orbitCfg.bombRadiusMul

        end
    -- line the belly up, then fire
    elseif currMode == "bellycannon" then
        bellyCannoning = true
        state.currentGunshipTask = "bellycannon_lineUp"

        local outcome, plan = gunship.BellyCannonRoutine( self, state, distracted )
        if not outcome then
            idealMovePos = gunship.BellyCannonMovePos( self, state )

        end

        if outcome == "done" then
            -- paid in full
            state.currentGunshipTask = "bellycannon_done"
            state.ammo = 0
            gunship.SpendSpite( state, spiteCfg.perBellyCannon )
            -- backing off often loses them, if so, it'll charge back in
            if plan == "backoff" then
                state.chargeWindowEnd = CurTime() + chargeCfg.window

            end
            gunshipSetMode( self, state, "handler", segment )

        elseif outcome == "gaveup" then
            -- couldn't line it up, the missiles it's owed come the usual way
            state.currentGunshipTask = "bellycannon_gaveUp"
            gunshipSetMode( self, state, "bomb", segment )

        end
        state.nextCarrot = 0 -- the orbit picks a fresh heading after

    -- backed off for the belly cannon and lost them, charge where we last saw them, missiles away
    elseif currMode == "charge" then
        local reached = sighting and myPos:Distance2D( sighting.pos ) < chargeCfg.reachedDist
        if target or not sighting or state.ammo <= 0 or reached then
            state.currentGunshipTask = "charge_switchToHandler"
            gunshipSetMode( self, state, "handler", segment )

        else
            state.currentGunshipTask = "charge_chargeLastSeen"
            state.canFire = true
            idealMovePos = cruiseAbove( sighting.pos )

        end
    end

    gunshipManageBoomerang( self, state, rocket, orbitCenter )

    -- swinging back round at them wins over circling, and everything else bar the belly cannon
    if not bellyCannoning and state.boomerangStart and orbitCenter then
        state.currentGunshipTask = state.mode .. ( state.fleeing and "_boomerangFlee" or "_boomerang" )

        local heading, offCenter = gunship.BoomerangHeading( self, state, orbitCenter )
        idealMovePos = gunshipCarrotAlong( self, rememberedTarget, heading )
        local bombing = state.mode == "bomb" or state.mode == "rage"
        state.canFire = bombing and offCenter < boomerangCfg.canFireBelowAngle and not distracted

    elseif orbitRadius then
        if not state.wasCircling then
            state.nextCarrot = 0

        end
        orbitRadius = orbitRadius * state.radiusMul
        local angle = gunship.OrbitAngle( myPos:Distance( orbitCenter ), orbitRadius )
        local refreshed = CurTime() >= state.nextCarrot
        idealMovePos = gunshipCirclingIdealPos( self, state, rememberedTarget, orbitCenter, canSeeTarget, angle )
        -- searching never sees them, so the radius would shrink to nothing and carry into the next fight
        if refreshed and not searching then
            gunship.AdaptOrbitRadius( state, state.lastOutcome, canSeeTarget )

        end
    end
    state.wasCircling = orbitRadius ~= nil

    -- riding the belly cannon's recoil wins over everything
    local recoilPos = gunship.ManageBellyCannonRecoil( self, state )
    if recoilPos then
        idealMovePos = recoilPos

    end

    if state.canFire and rememberedTarget then
        -- raging, it fires as fast as it does nearly dead
        local missileSegment = state.mode == "rage" and 1 or segment
        gunship.ManageMissiles( self, state, missileSegment, rememberedTarget, distToTarget, canSeeTarget )

    end

    if debugging:GetBool() then
        debugoverlay.Text( myPos, state.currentGunshipTask .. " r" .. math.Round( state.radiusMul, 2 ), gunship.ThinkInterval )

    end

    if not idealMovePos or CurTime() < state.nextSteer then return end
    -- lining up the belly cannon, and riding its recoil, need a tighter hand on the stick
    if state.mode == "bellycannon" or recoilPos then
        state.nextSteer = CurTime() + gunship.ThinkInterval

    else
        state.nextSteer = CurTime() + gunship.SteerInterval

    end

    local lostProgress = gleeFlightNavigator.Steer( self, idealMovePos )
    if lostProgress and currentTargPosName then
        state[currentTargPosName] = nil

    elseif lostProgress and wandering then
        gleeFlightNavigator.RestartWander( self )

    end
end
