local rescueHeli = terminator_Extras.glee_RescueHeli
local gleeVehicles = terminator_Extras.gleeVehicles
local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator

-- heli model is from 2293373301, which got it from Codename CURE
local heliModel = "models/glee/combine_helicopter_glee.mdl"
local heliArmModel = "models/props_trainstation/mount_connection001a.mdl"
local heliMissileModel = "models/props_phx/amraam.mdl"

-- no lagspikes pls
util.PrecacheModel( heliModel )
util.PrecacheModel( heliArmModel )
util.PrecacheModel( heliMissileModel )

-- npc_helicopter precaches its own models, gibs and sounds on first Spawn
-- so get that over with during map load, instead of mid round
hook.Add( "InitPostEntity", "glee_rescueheli_warmprecache", function()
    local dummy = ents.Create( "npc_helicopter" )
    if not IsValid( dummy ) then return end

    dummy:Spawn()
    dummy:Remove()

end )

local heli_seatPositions = {
    { pos = Vector( -51.1, 1.1, -19.8 ), ang = Angle( 0, -90, -15 ) },
    { pos = Vector( -51.1, 28.9, -19.8 ), ang = Angle( 0, -90, -15 ) },
    { pos = Vector( -51.1, -26.8, -19.8 ), ang = Angle( 0, -90, -15 ) },
    { pos = Vector( 59.6, -0.4, -48 ), ang = Angle( 0, 90, 15 ) },
    { pos = Vector( 61, 26, -47.4 ), ang = Angle( 15, -0.3, 0 ) },
    { pos = Vector( 61.5, -26.9, -47.6 ), ang = Angle( -15, -179.7, 0 ) },
}

local heli_TryAndRescueDuration = 120
-- try and find people for 2 minutes
-- afterwards we switch to flying towards any skybox we can find, or where we spawned

function rescueHeli.Spawn( spawnPos, faceDir, targetPos )
    local heli = ents.Create( "npc_helicopter" )
    if not IsValid( heli ) then return end

    heli:SetPos( spawnPos )
    heli:SetAngles( faceDir:Angle() )

    -- the brain's
    local state = {
        currentHeliGoal = "rescue",
        currentHeliTask = "rescue_flyToFlare",
        originalRescuePos = targetPos,
        rescueHeliArrivedFromPos = spawnPos,
        giveUpAndRunAwayTime = CurTime() + heli_TryAndRescueDuration,
        nextAngerEverything = CurTime() + 10,
        nextMissileFire = 0,
        missiles = {},
    }
    heli.glee_RescueHeliState = state

    -- fly towards valuable sounds when wandering
    terminator_Extras.RegisterListener( heli )
    function heli:SaveSoundHint( source, valuable, emitterEnt )
        if not valuable then return end
        if IsValid( emitterEnt ) and not emitterEnt:IsPlayer() then return end
        state.lastHeardSoundPos = source

    end

    heli:Fire( "EnableDeadlyShooting", 1, 0.1 )

    heli.isGleeRescueHeli = true
    heli:SetNWBool( "isGleeRescueHeli", true )

    heli:Spawn()

    local mins, maxs = heli:GetCollisionBounds()

    heli:SetModel( heliModel )
    heli:SetCollisionBounds( mins, maxs )
    heli:Activate()

    -- missile hardpoint support
    local mountingRight = terminator_Extras.AttachParentedDetail( heli, heliArmModel, Vector( 44.5, -83.2, -17.8 ), Angle( 0, -89.9, 164 ) )
    if IsValid( mountingRight ) then
        local missileRight = ents.Create( "glee_helimissile" )
        missileRight:SetStartsInactive( true )
        missileRight:SetAttacker( heli )
        missileRight:SetInflictor( missileRight )
        missileRight:SetOwner( heli )
        terminator_Extras.AttachParentedDetail( heli, missileRight, Vector( 40.6, -106.3, -31.5 ), Angle( 16, 0, 90 ) )

        table.insert( state.missiles, missileRight )

    end

    local mountingLeft = terminator_Extras.AttachParentedDetail( heli, heliArmModel, Vector( 45, 83.2, -17.9 ), Angle( 0, 89.9, -164 ) )
    if IsValid( mountingLeft ) then
        local missileLeft = ents.Create( "glee_helimissile" )
        missileLeft:SetStartsInactive( true )
        missileLeft:SetAttacker( heli )
        missileLeft:SetInflictor( missileLeft )
        missileLeft:SetOwner( heli )
        terminator_Extras.AttachParentedDetail( heli, missileLeft, Vector( 40.7, 106.3, -31.4 ), Angle( 16, 0, -90 ) )

        table.insert( state.missiles, missileLeft )

    end

    rescueHeli.SetupStanding( heli )

    gleeFlightNavigator.Attach( heli, rescueHeli.FlightCfg, targetPos )

    heli:SetNWString( "glee_PrettyName", "The Rescue Heli" )

    heli:SetNW2Bool( "glee_IsSpectatable", true )

    gleeVehicles.Setup( heli, {
        seats = heli_seatPositions,
        exitOffset = Vector( 0, 0, -100 ),
        exitText = "Exiting the heli...",
        canBoard = rescueHeli.CanBoard,
        trueEscape = true,
    } )

    hook.Add( "OnNPCKilled", heli, function( self, npc )
        if npc ~= self then return end

        gleeVehicles.KillRiders( self )

    end )

    local timerName = "glee_rescuehelithink_" .. heli:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( heli ) then
            timer.Remove( timerName )
            return
        end

        ProtectedCall( rescueHeli.Think, heli )

    end )

    terminator_Extras.glee_CurrentRescueHeli = heli

    return heli

end

concommand.Add( "glee_test_escapeheli", function( ply )
    if not ply:IsAdmin() then return end
    local spawnPos = ply:GetPos() + Vector( 0, 0, 50 )
    local faceDir = -ply:GetForward()
    local targetPos = spawnPos + faceDir * 500

    rescueHeli.Spawn( spawnPos, faceDir, targetPos )

end )
