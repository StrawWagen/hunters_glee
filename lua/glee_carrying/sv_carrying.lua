
local glee_Carrying = terminator_Extras.glee_Carrying

util.AddNetworkString( "glee_carrying_wheelpick" )
util.AddNetworkString( "glee_carrying_wheelopened" )


-- Carrying -------------------------------------------------------------------

local hintCooldown = 3

-- Once every hintCooldown at most, a switch blocked by the hands-full rule can try every tick
function glee_Carrying.HintHandsFull( ply )
    if ( ply.glee_NextHandsFullHint or 0 ) > CurTime() then return end
    ply.glee_NextHandsFullHint = CurTime() + hintCooldown

    huntersGlee_Announce( { ply }, 5, hintCooldown, "You already have something on your back.\nPress Reload to set this down." )
    ply:EmitSound( "common/wpn_denyselect.wav", 65, math.random( 95, 105 ) )

end

-- For those whose carry rules give them no back, same cooldown as HintHandsFull
function glee_Carrying.HintCantBackpack( ply )
    if ( ply.glee_NextHandsFullHint or 0 ) > CurTime() then return end
    ply.glee_NextHandsFullHint = CurTime() + hintCooldown

    huntersGlee_Announce( { ply }, 5, hintCooldown, "You can't fit this on your back!\nPress Reload to set it down." )

end

-- The gamemode's strips, eg being grabbed, drop what they carry first, as the camera and flashlight do,
-- rather than removing the weapons out from under it. Outside the gamemode the hook never runs
hook.Add( "glee_PreStripWeapons", "glee_carrying_dropbeforestrip", function( ply )
    if not ply.DropWeaponKeepAmmo then return end

    for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( ply ) ) do
        ply:DropWeaponKeepAmmo( wep )

    end
end )

-- What's on their back leaves with them, the escape kills them right after, and their weapons with it,
-- which would leave it where they escaped. What's in their hands is left behind. Outside the gamemode
-- the hook never runs. glee_carrying_escapedwith( ply, ent ), first, is for whatever wants to reward it
hook.Add( "glee_ply_escaped", "glee_carrying_escapewithback", function( ply )
    for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( ply ) ) do
        local ent = wep:GetCarriedEnt()
        if not wep:GetOnBack() or not IsValid( ent ) then continue end

        hook.Run( "glee_carrying_escapedwith", ply, ent )
        -- now, not next tick, or the kill releases it first and it springs back to life for a tick
        ent:Remove() -- takes its weapon with it

    end
end )

-- Gives them weaponClass, or its twin, carrying a brand new entity it makes itself, eg from a shop.
-- The one way to, a weapon given any other way with nothing to carry removes itself. False if there's no room
function glee_Carrying.GiveNewCarryable( ply, weaponClass )
    if not glee_Carrying.HasRoomFor( ply, weaponClass ) then return false end

    local wep = ents.Create( glee_Carrying.GetFreeWeaponClass( ply, weaponClass ) )
    if not IsValid( wep ) then return false end

    wep:SetMakesOwnCarryEnt( true )
    wep:SetPos( ply:GetShootPos() )
    wep:Spawn()

    if not ply:PickupWeapon( wep ) then
        SafeRemoveEntity( wep )
        return false

    end

    ply:SelectWeapon( wep:GetClass() )

    return true

end

-- Gives them its weapon, which grabs ent, and switches to it. False and CanCarry's reason if they can't
function glee_Carrying.Carry( ply, ent )
    local canCarry, reason = glee_Carrying.CanCarry( ply, ent )
    if not canCarry then return false, reason end

    local wep = ents.Create( glee_Carrying.GetFreeWeaponClass( ply, glee_Carrying.GetCarryWeaponClass( ent ) ) )
    if not IsValid( wep ) then return false end

    wep.glee_CarryOnEquip = ent
    wep:SetPos( ply:GetShootPos() )
    wep:Spawn()

    if not ply:PickupWeapon( wep ) then
        SafeRemoveEntity( wep )
        return false

    end

    ply:SelectWeapon( wep:GetClass() )

    return true

end


-- The use wheel --------------------------------------------------------------

-- the client can't see everything that refuses an action, constraints for one, so it's told
local function announceRefusal( ply, reason )
    if not reason then return end
    huntersGlee_Announce( { ply }, 5, 2, reason )

end

local pickCooldown = 0.2

net.Receive( "glee_carrying_wheelpick", function( _, ply )
    if ( ply.glee_NextUseWheelPick or 0 ) > CurTime() then return end
    ply.glee_NextUseWheelPick = CurTime() + pickCooldown

    local ent = net.ReadEntity()
    local key = net.ReadString()

    if not IsValid( ent ) then return end

    -- only what it offers right now, a key the wheel showed may be gone since
    local offered = false
    for _, action in ipairs( glee_Carrying.GetUseActions( ent ) or {} ) do
        if action.key == key then
            offered = true
            break

        end
    end
    if not offered then return end
    if not glee_Carrying.InUseRange( ply, ent, glee_Carrying.UseRangeSlack ) then return end

    local canPick, reason = glee_Carrying.CanPick( ply, ent, key )
    if not canPick then
        announceRefusal( ply, reason )
        return

    end

    -- a held use already went through as a +use, which may have lifted what it's now picking from
    if glee_Carrying.GetPhysicsHeld( ply ) == ent then
        ply:DropObject()

    end

    glee_Carrying.RunAction( ply, ent, key )

end )

-- a held use already lifted whatever its first tick landed on, the wheel's taking over from that
net.Receive( "glee_carrying_wheelopened", function( _, ply )
    ply:DropObject()

end )

-- see CanLift, wheel-only ones open their wheel straight away, lifting them too would fight it
hook.Add( "AllowPlayerPickup", "glee_carrying_wheelonly", function( _, ent )
    if not glee_Carrying.CanLift( ent ) then return false end

end )

-- The engine's +use can land on what they carry. Swapped for what they're aiming at past it
hook.Add( "FindUseEntity", "glee_carrying_notowncarried", function( ply, defaultEnt )
    if not IsValid( defaultEnt ) or not glee_Carrying.IsCarriedBy( defaultEnt, ply ) then return end

    local shootPos = ply:GetShootPos()
    local tr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + ply:GetAimVector() * glee_Carrying.UseRange,
        filter = glee_Carrying.GetCarrierTraceFilter( ply ),
    } )

    -- NULL isn't an answer to the engine, it keeps its own pick, so the PlayerUse below refuses that
    if IsValid( tr.Entity ) then return tr.Entity end

end )

hook.Add( "PlayerUse", "glee_carrying_notowncarried", function( ply, used )
    if glee_Carrying.IsCarriedBy( used, ply ) then return false end

end )


-- Lifted with use, reload stashes it ----------------------------------------

hook.Add( "OnPlayerPhysicsPickup", "glee_carrying_trackheld", function( ply, ent )
    ply:SetNW2Entity( "glee_PhysicsHeld", ent )

end )

hook.Add( "OnPlayerPhysicsDrop", "glee_carrying_trackheld", function( ply )
    ply:SetNW2Entity( "glee_PhysicsHeld", NULL )

end )

hook.Add( "PlayerDeath", "glee_carrying_trackheld", function( ply )
    ply:SetNW2Entity( "glee_PhysicsHeld", NULL )

end )

hook.Add( "KeyPress", "glee_carrying_heldaction", function( ply, key )
    if key ~= IN_RELOAD then return end

    local ent, action, canPick, reason = glee_Carrying.GetHeldPickUp( ply )
    if not ent then return end

    if not canPick then
        announceRefusal( ply, reason )
        return

    end

    ply:DropObject()
    local worked = glee_Carrying.RunAction( ply, ent, action.key )

    -- lessons are the gamemode's, outside it there's no hint to grow out of
    if worked and action.lesson and GAMEMODE.LearnLesson then
        GAMEMODE:LearnLesson( ply, action.lesson )

    end
end )
