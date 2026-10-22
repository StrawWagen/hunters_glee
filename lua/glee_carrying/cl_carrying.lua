
local glee_Carrying = terminator_Extras.glee_Carrying


-- Carrying -------------------------------------------------------------------

-- The carrier sees through what they carry in first person, it rides their bones, right in front of the camera
local function isHiddenFromView( ent )
    local wep = glee_Carrying.GetCarrierWeapon( ent )
    if not IsValid( wep ) then return false end

    local carrier = wep:GetOwner()
    if carrier ~= LocalPlayer() then return false end

    return not carrier:ShouldDrawLocalPlayer()

end

-- Draws as it would've, unless it's hidden. Left on once it's put down, it only ever hides while carried
function glee_Carrying.DrawUnlessHidden( ent, flags )
    if isHiddenFromView( ent ) then return end

    local underneath = ent.glee_PreCarryRenderOverride
    if underneath then
        underneath( ent, flags )

    elseif ent.Draw then
        ent:Draw( flags )

    else
        ent:DrawModel( flags )

    end
end

-- By name each call, so an autorefresh reaches entities wrapped before it
local function carriedRenderOverride( ent, flags )
    glee_Carrying.DrawUnlessHidden( ent, flags )

end

-- Per entity, so it reaches props and engine entities too, which have no ENT table to put it on.
-- Polled, the weapon a carried thing points at can reach this client after the carried thing does.
-- Wrapped once ever, a flag not a function compare, or a refresh would wrap the old wrapper in the new
hook.Add( "Think", "glee_carrying_hidefromcarrier", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end -- joining, there's no local player yet

    local carrying = false
    for _, wep in ipairs( ply:GetWeapons() ) do
        if not wep.IsGleeBackpackable then continue end

        local ent = wep:GetCarriedEnt()
        if not IsValid( ent ) then continue end

        carrying = true
        if not ent.glee_HidesFromCarrier then
            ent.glee_HidesFromCarrier = true
            ent.glee_PreCarryRenderOverride = ent.RenderOverride
            ent.RenderOverride = carriedRenderOverride

        end
    end

    -- only their own projectiles are predicted, so only what they carry needs the client's answer
    glee_Carrying.SetOwnProjectilesHooked( carrying )

end )


-- sh_carrying's ShouldCollide reads the carrier, so a change of carrier changes its answer. The server
-- calls this itself as it picks up and puts down, the client's told by the carrier arriving
hook.Add( "EntityNetworkedVarChanged", "glee_carrying_collisionrules", function( ent, name )
    if name ~= "glee_CarrierWeapon" then return end

    -- a tick late, the var's not set till after this hook
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        ent:CollisionRulesChanged()

    end )
end )


-- The use wheel --------------------------------------------------------------

local OUTER_RADIUS_1080P = 300
local WHEEL_OPEN_DELAY = 0.25 -- use held this long opens the wheel, let go sooner and it was just a +use

-- on the table, so an autorefresh while one's open can still release it, its hooks hold the mouse
local function getCurrentWheel()
    return glee_Carrying.CurrentWheel

end

local useWasDown = false

-- what the current press of use landed on, and when, until it opens a wheel or is let go
local pressedEnt
local pressedAt

-- What they're aiming at in use range, if it has actions
local function findTarget( ply )
    -- cached for the frame, but it runs on as far as it can, so it's cut to use range here
    local tr = ply:GetEyeTrace()
    if tr.StartPos:DistToSqr( tr.HitPos ) > glee_Carrying.UseRange ^ 2 then return end

    local ent = tr.Entity
    if not IsValid( ent ) or not glee_Carrying.GetUseActions( ent ) then return end

    return ent

end

-- Asks the server to run one of ent's actions, which checks it all again.
-- The key, not a wheel slot, the actions can change in between, eg it's picked up by someone else
local function sendPick( ent, key )
    net.Start( "glee_carrying_wheelpick" )
        net.WriteEntity( ent )
        net.WriteString( key )
    net.SendToServer()

end

-- Aimed by the mouse while use stays held, letting go of use picks. Replaces any wheel already open
local function openWheel( ply, ent )
    local oldWheel = getCurrentWheel()
    if IsValid( oldWheel ) then oldWheel:Remove() end

    local wheel = vgui.Create( "glee_wheel" )
    local outer = wheel:Style():Scaled( OUTER_RADIUS_1080P )

    wheel:SetSize( outer * 2, outer * 2 )
    wheel:SetItems( glee_Carrying.GetUseActions( ent ) )
    wheel:Center()

    function wheel:GetItemStatus( item )
        if not IsValid( ent ) then return false end

        -- just the yes or no, glee_wheel reads a second return as a cooldown
        local canPick = glee_Carrying.CanPick( ply, ent, item.key )
        return canPick

    end

    function wheel:OnItemSelected( item )
        sendPick( ent, item.key )
        self:Close()

    end

    hook.Add( "Think", wheel, function( self )
        if IsValid( ent ) and ply:Alive() and glee_Carrying.InUseRange( ply, ent, glee_Carrying.UseRangeSlack ) then return end

        self:Close()

    end )

    wheel:HoldAim()
    ply:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    -- the press already went through as a +use, which may have lifted it
    net.Start( "glee_carrying_wheelopened" )
    net.SendToServer()

    glee_Carrying.CurrentWheel = wheel

end

-- What using ent does, the one place that decides. Nothing with no actions, the wheel with several, and
-- one action's just run. Except a lone PickUpAction on what use can lift, that's lift-then-reload,
-- so a tap of use stays a plain lift
local function useOn( ply, ent )
    local actions = glee_Carrying.GetUseActions( ent )
    if not actions then return end

    if glee_Carrying.IsLiftThenReload( actions ) and glee_Carrying.CanLift( ent ) then return end

    if #actions == 1 then
        sendPick( ent, actions[1].key )
        return

    end

    openWheel( ply, ent )

end

-- CreateMove, not KeyPress, KeyPress never runs clientside in singleplayer
hook.Add( "CreateMove", "glee_carrying_holduse", function( cmd )
    local useDown = cmd:KeyDown( IN_USE )
    local ply = LocalPlayer()

    if useDown ~= useWasDown then
        useWasDown = useDown
        pressedEnt = nil

        if not useDown then
            local wheel = getCurrentWheel()
            if IsValid( wheel ) then wheel:Release() end
            return

        end

        if not ply:Alive() or ply:InVehicle() then return end

        local target = findTarget( ply )

        -- a plain +use does nothing on these, so there's nothing to wait out
        if target and glee_Carrying.IsUseWheelOnly( target ) then
            useOn( ply, target )
            return

        end

        pressedEnt = target
        pressedAt = RealTime()
        return

    end

    if not pressedEnt or RealTime() - pressedAt < WHEEL_OPEN_DELAY then return end

    local ent = pressedEnt
    pressedEnt = nil

    if not IsValid( ent ) or not ply:Alive() then return end
    if not glee_Carrying.InUseRange( ply, ent, glee_Carrying.UseRangeSlack ) then return end

    useOn( ply, ent )

end )

-- the gamemode's hint stack, so its lessons are always there
hook.Add( "huntersglee_cl_displayhint_poststack", "glee_carrying_heldactionhint", function( ply )
    local ent, action, canPick, reason = glee_Carrying.GetHeldPickUp( ply )
    if not ent then return end

    -- why the press would be refused, or nothing when there's no reason worth saying
    if not canPick then
        if reason then return true, reason end
        return

    end

    local learned = action.lesson and GAMEMODE:HasLearnedLesson( ply, action.lesson )
    if learned and action.shortHint then return true, action.shortHint end
    if action.hint then return true, action.hint end

    local reloadKey = input.LookupBinding( "+reload" ) or "+reload"
    return true, string.upper( reloadKey ) .. " to " .. string.lower( action.label )

end )
