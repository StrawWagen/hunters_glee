terminator_Extras = terminator_Extras or {}

-- seats bolted onto any entity, boarded with use or a rappel rope, left by holding use
-- every host is an escape transport, its riders escape when it departs
local gleeVehicles = {}
terminator_Extras.gleeVehicles = gleeVehicles

local exitBarId = "glee_vehicle_exit"
local invisCol = Color( 255, 255, 255, 1 )

local EntityPairs

do
    local e

    -- Custom iterator, similar to ipairs, but made to iterate
    -- over a table of entities, while skipping invalid entities.
    -- CREDIT GLIDE, STYLED
    local function EntIterator( array, i )
        i = i + 1
        e = array[i]

        while e and not ( e.IsValid and e:IsValid() ) do
            i = i + 1
            e = array[i]
        end

        if e then
            return i, e
        end
    end

    function EntityPairs( array )
        return EntIterator, array, 0
    end
end

-- trimmed glide code 👀
local function spawnSeat( host, offset, angle )
    local seats = host.glee_Vehicle.seats
    local seat = ents.Create( "prop_vehicle_prisoner_pod" )

    if not IsValid( seat ) then
        host:Remove()
        error( "Failed to spawn glee vehicle seat!" )

        return
    end

    seat:SetModel( "models/nova/airboat_seat.mdl" )
    seat:SetPos( host:LocalToWorld( offset or Vector() ) )
    seat:SetAngles( host:LocalToWorldAngles( angle or Angle( 0, 270, 10 ) ) )
    seat:SetMoveType( MOVETYPE_NONE )
    seat:SetOwner( host )
    seat:Spawn()
    seat:Activate()

    seat:SetKeyValue( "limitview", 0 )
    seat:SetNotSolid( true )
    seat:SetParent( host )
    seat:DrawShadow( false )
    seat:PhysicsDestroy()
    seat:SetColor( invisCol )
    seat:SetRenderMode( RENDERMODE_TRANSALPHA )

    seat.PhysgunDisabled = true
    seat.DoNotDuplicate = true
    seat.DisableDuplicator = true

    host:DeleteOnRemove( seat )

    seats[#seats + 1] = seat
    seat.glee_SeatHost = host

    return seat

end

local defaultRiderHeal = 5
local defaultRiderCalm = 5
-- infernal deals end at full health, stopping here keeps them infernal
local riderHealCap = 0.5

-- true escape riders are safe now, patch them up and calm them down
local function startComfortingRiders( host )
    local cfg = host.glee_Vehicle.cfg
    local heal = cfg.riderHeal or defaultRiderHeal
    local calm = cfg.riderCalm or defaultRiderCalm

    local timerName = "glee_vehicle_comfortriders_" .. host:GetCreationID()
    timer.Create( timerName, 1, 0, function()
        if not IsValid( host ) then
            timer.Remove( timerName )
            return

        end

        for _, seat in EntityPairs( host.glee_Vehicle.seats ) do
            local rider = seat:GetDriver()
            if not IsValid( rider ) then continue end
            if not rider:Alive() then continue end

            local healCap = rider:GetMaxHealth() * riderHealCap
            if rider:Health() < healCap then
                rider:SetHealth( math.min( rider:Health() + heal, healCap ) )
                rider.glee_LastSetHealthReason = "glee_trueescape_regen"

            end

            -- gamemode only, there's no panic outside it
            if GAMEMODE.GivePanic then
                GAMEMODE:GivePanic( rider, -calm )

            end
        end
    end )
end

-- cfg:
--   seats       { { pos = Vector, ang = Angle }, ... }, local to the host
--   exitOffset  world space, from the seat they left
--   exitText    progress bar text while holding use to leave
--   canBoard    optional, function( host, ply ), false refuses them
--   trueEscape  optional, a vehicle earned with a countdown, that protects its riders and carries them out of the map
--               boarding it runs glee_blockboard_trueescape( ply, host ), true refuses them
--               riders heal up to half health, and calm down
--   riderHeal   optional, trueEscape health healed a second, default 5
--   riderCalm   optional, trueEscape panic calmed a second, default 5
function gleeVehicles.Setup( host, cfg )
    host.glee_Vehicle = {
        cfg = cfg,
        seats = {},
    }

    for _, data in ipairs( cfg.seats ) do
        spawnSeat( host, data.pos, data.ang )

    end

    if cfg.trueEscape then
        startComfortingRiders( host )

    end
end

function gleeVehicles.GetSeatHost( ply )
    local vehicle = ply:GetVehicle()
    if not IsValid( vehicle ) then return end

    local host = vehicle.glee_SeatHost
    if not IsValid( host ) then return end

    return host

end

function gleeVehicles.IsRiding( ply, host )
    return gleeVehicles.GetSeatHost( ply ) == host

end

function gleeVehicles.IsInEscapeSeat( ply )
    return gleeVehicles.GetSeatHost( ply ) ~= nil

end

function gleeVehicles.GetFreeSeat( host )
    for _, seat in EntityPairs( host.glee_Vehicle.seats ) do
        if not IsValid( seat:GetDriver() ) then
            return seat

        end
    end
end

function gleeVehicles.AllSeatsFull( host )
    return gleeVehicles.GetFreeSeat( host ) == nil

end

function gleeVehicles.KillRiders( host )
    for _, seat in EntityPairs( host.glee_Vehicle.seats ) do
        local driver = seat:GetDriver()
        if IsValid( driver ) then
            driver:Kill()

        end
    end
end

-- returns true if they're now seated
function gleeVehicles.TryBoard( host, ply )
    local cfg = host.glee_Vehicle.cfg
    if cfg.trueEscape and hook.Run( "glee_blockboard_trueescape", ply, host ) == true then return false end
    if cfg.canBoard and not cfg.canBoard( host, ply ) then return false end

    local freeSeat = gleeVehicles.GetFreeSeat( host )
    if not freeSeat then return false end

    ply:SetAllowWeaponsInVehicle( false )
    ply:EnterVehicle( freeSeat )

    return ply:GetVehicle() == freeSeat

end

-- escapes whoever can, drops everyone else out where they sat, then removes the host
function gleeVehicles.Depart( host )
    local vehicleData = host.glee_Vehicle
    if vehicleData.departed then return end
    vehicleData.departed = true

    hook.Run( "glee_vehicle_depart", host )

    for _, seat in EntityPairs( vehicleData.seats ) do
        local rider = seat:GetDriver()
        if IsValid( rider ) then
            rider:ExitVehicle()

        end
    end

    SafeRemoveEntityDelayed( host, 0.1 )

end

hook.Add( "PlayerUse", "glee_vehicles_board", function( ply, ent )
    if not ent.glee_Vehicle then return end

    if ply:KeyDown( IN_WALK ) then return end
    -- PlayerUse fires every tick use is held, and leaving is done by holding use
    if not ply:KeyPressed( IN_USE ) then return end

    local nextInteract = ply.glee_nextVehicleSeatInteract or 0
    if CurTime() < nextInteract then return end
    ply.glee_nextVehicleSeatInteract = CurTime() + 1

    gleeVehicles.TryBoard( ent, ply )

end )

-- fires every tick they're at the vehicle
hook.Add( "OnPlayerRappelReachedVehicle", "glee_vehicles_rappelboard", function( ply, ent )
    if not ent.glee_Vehicle then return end

    if ply:KeyDown( IN_WALK ) then return end
    if gleeVehicles.TryBoard( ent, ply ) then return end

    -- can't board, lower them out of reach instead of cutting the rope
    local anchorPos = ent:LocalToWorld( ply:GetNWVector( "glee_RappelSourceOffset" ) )
    ply:SetNWFloat( "glee_RappelRopeLength", ply:GetPos():Distance( anchorPos ) + 100 )

end )

-- only the hold-use below gets anyone out, ExitVehicle bypasses this
hook.Add( "CanExitVehicle", "glee_vehicles_holdtoexit", function( vehicle )
    if not vehicle.glee_SeatHost then return end
    return false

end )

hook.Add( "PlayerEnteredVehicle", "glee_vehicles_resetexit", function( ply, vehicle )
    if not vehicle.glee_SeatHost then return end
    ply.glee_vehicleExitArmed = nil
    ply.glee_vehicleExitHolding = nil

end )

hook.Add( "VehicleMove", "glee_vehicles_holdtoexit", function( ply, vehicle, mv )
    local host = vehicle.glee_SeatHost
    if not IsValid( host ) then return end

    if not mv:KeyDown( IN_USE ) then
        ply.glee_vehicleExitArmed = true
        if ply.glee_vehicleExitHolding then
            ply.glee_vehicleExitHolding = nil
            generic_KillProgressBar( ply, exitBarId )

        end
        return

    end
    -- still holding the use that boarded
    if not ply.glee_vehicleExitArmed then return end

    ply.glee_vehicleExitHolding = true
    local progress = generic_WaitForProgressBar( ply, exitBarId, 0.1, 7, { progInfo = host.glee_Vehicle.cfg.exitText } )
    if progress < 100 then return end

    generic_KillProgressBar( ply, exitBarId )
    ply.glee_vehicleExitHolding = nil
    ply:ExitVehicle()

end )

hook.Add( "PlayerLeaveVehicle", "glee_vehicles_exit", function( ply, vehicle )
    local host = vehicle.glee_SeatHost
    if not IsValid( host ) then return end

    ply.glee_nextVehicleSeatInteract = CurTime() + 1
    local exitOffset = host.glee_Vehicle.cfg.exitOffset

    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        -- escaping kills them in their seat
        if not ply:Alive() then return end
        if not IsValid( vehicle ) then return end
        if not ply.TeleportTo then return end

        ply:TeleportTo( vehicle:GetPos() + exitOffset )

    end )
end )
