local gunship = terminator_Extras.glee_Gunship
local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator

-- before Spawn, spawnflags are only read then
-- also a spawnset .preSpawnedFuncs
function gunship.PreSpawn( _, npc )
    npc:SetKeyValue( "spawnflags", SF_NPC_LONG_RANGE )

end

-- the spawner waits on every try, so not too many
local skyEntryTries = 25
-- each try searches from somewhere this close to where it lifted to
local skyEntryJitter = 1000

local jitterHull = gunship.SkyCorridorCfg.minHull
local jitterTrData = {
    mask = MASK_NPCSOLID_BRUSHONLY,
    mins = Vector( -jitterHull, -jitterHull, -jitterHull / 2 ),
    maxs = Vector( jitterHull, jitterHull, jitterHull / 2 ),
}

-- somewhere near pos, without going through a wall to get there
local function jitteredPos( pos )
    local offset = VectorRand()
    offset.z = 0
    offset:Normalize()
    offset:Mul( math.Rand( 0, skyEntryJitter ) )

    jitterTrData.start = pos
    jitterTrData.endpos = pos + offset

    return util.TraceHull( jitterTrData ).HitPos

end

-- where it enters the map from, out by the skybox, and the spot that way in leads to
-- no way in found, it rises off groundPos, with no spot to head to
function gunship.SkyEntry( groundPos )
    local liftedPos = gunship.LiftedPos( groundPos )
    local search = gleeFlightNavigator.NewSkyCorridorSearch( gunship.SkyCorridorCfg )

    for _ = 1, skyEntryTries do
        local entryPos, goalPos = search:Step( jitteredPos( liftedPos ) )
        if entryPos then return entryPos, goalPos end

    end

    local fallbackPos = search:GetFallbackPos()
    if fallbackPos then return fallbackPos, liftedPos end

    return liftedPos

end

-- puts it at its sky entry, facing in, returns the spot it should head to first, if it found one
local function placeAtSkyEntry( npc, groundPos )
    local entryPos, goalPos = gunship.SkyEntry( groundPos )
    npc:SetPos( entryPos )
    if not goalPos then return end

    npc:SetAngles( Angle( 0, ( goalPos - entryPos ):Angle().y, 0 ) )
    return goalPos

end

-- after Spawn, makes an npc_combinegunship into a glee gunship
-- firstGoalPos, optional, where it flies before its brain takes over
function gunship.Setup( npc, firstGoalPos )
    local state = {
        mode = "handler",
        currentGunshipTask = "handler_pickMode",
        orbitDir = 1,
        radiusMul = 1,
        nextCarrot = 0,
        nextSteer = 0,
        lastSegment = 3,
        ammo = 0,
        nextMissile = 0,
        forgetTargetTime = 0,
        nextBellyCannon = 0,
        chargeWindowEnd = 0,
    }
    npc.glee_GunshipState = state

    gunship.SetupStanding( npc )

    -- its belly cannon, way too much
    npc:Fire( "DisableGroundAttack" )

    -- fly towards valuable sounds when it's got nobody to fight
    terminator_Extras.RegisterListener( npc )
    function npc:SaveSoundHint( source, valuable, emitterEnt )
        if not valuable then return end
        if IsValid( emitterEnt ) and not emitterEnt:IsPlayer() then return end
        state.lastHeardSoundPos = source

    end

    firstGoalPos = firstGoalPos or npc:GetPos() + npc:GetForward() * 1000
    gleeFlightNavigator.Attach( npc, gunship.FlightCfg, firstGoalPos )

    npc:CallOnRemove( "glee_gunship_stopsounds", function()
        for _, slot in ipairs( { "bombSound", "terrorSound", "prefireSound", "planSound" } ) do
            if state[slot] then state[slot]:Stop() end

        end
    end )

    local timerName = "glee_gunshipthink_" .. npc:GetCreationID()
    timer.Create( timerName, gunship.ThinkInterval, 0, function()
        if not IsValid( npc ) then
            timer.Remove( timerName )
            return

        end
        if npc:Health() <= 0 then return end

        ProtectedCall( gunship.Think, npc )

    end )
end

-- spawnset .postSpawnedFuncs, the spawner left it on the ground
function gunship.PostSpawn( _, npc )
    local firstGoalPos = placeAtSkyEntry( npc, npc:GetPos() )
    gunship.Setup( npc, firstGoalPos )

end

-- flies in from the skybox, towards groundPos
function gunship.Spawn( groundPos )
    local npc = ents.Create( "npc_combinegunship" )
    if not IsValid( npc ) then return end

    local firstGoalPos = placeAtSkyEntry( npc, groundPos )
    gunship.PreSpawn( nil, npc )
    npc:Spawn()
    npc:Activate()

    gunship.Setup( npc, firstGoalPos )

    return npc

end

concommand.Add( "glee_test_gunship", function( ply )
    if not ply:IsAdmin() then return end
    gunship.Spawn( ply:GetPos() )

end )
