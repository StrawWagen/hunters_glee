local gunship = terminator_Extras.glee_Gunship
local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator

-- before Spawn, spawnflags are only read then
-- also a spawnset .preSpawnedFuncs
function gunship.PreSpawn( _, npc )
    npc:SetKeyValue( "spawnflags", SF_NPC_LONG_RANGE )

end

-- after Spawn, makes an npc_combinegunship into a glee gunship
function gunship.Setup( npc )
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

    gleeFlightNavigator.Attach( npc, gunship.FlightCfg, npc:GetPos() + npc:GetForward() * 1000 )

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
    npc:SetPos( gunship.LiftedPos( npc:GetPos() ) )
    gunship.Setup( npc )

end

-- rises off groundPos, as high as it fits up to cruise height
function gunship.Spawn( groundPos, ang )
    local npc = ents.Create( "npc_combinegunship" )
    if not IsValid( npc ) then return end

    npc:SetPos( gunship.LiftedPos( groundPos ) )
    npc:SetAngles( ang or angle_zero )
    gunship.PreSpawn( nil, npc )
    npc:Spawn()
    npc:Activate()

    gunship.Setup( npc )

    return npc

end

concommand.Add( "glee_test_gunship", function( ply )
    if not ply:IsAdmin() then return end
    gunship.Spawn( ply:GetPos(), Angle( 0, ply:EyeAngles().y, 0 ) )

end )
