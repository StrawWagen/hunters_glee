
local glee_Carrying = terminator_Extras.glee_Carrying


-- Carrying -------------------------------------------------------------------

-- in first person, the carrier sees right through what they carry
-- it rides their bones, so it'd sit right in front of the camera
local function isHiddenFromView( ent )
    local wep = glee_Carrying.GetCarrierWeapon( ent )
    if not IsValid( wep ) then return false end

    local carrier = wep:GetOwner()
    if carrier ~= LocalPlayer() then return false end

    return not carrier:ShouldDrawLocalPlayer()

end

-- draws it the way it would've drawn anyway, unless it's hidden
-- stays on after it's put down, that's fine, it only hides while carried
function glee_Carrying.DrawUnlessHidden( ent, flags )
    if isHiddenFromView( ent ) then return end

    local underneath = ent.glee_PreCarryRenderOverride
    if underneath then
        underneath( ent, flags )

    -- RenderOverride stands in for both Draw and DrawTranslucent, each pass gets the one it'd have run
    elseif bit.band( flags, STUDIO_TRANSPARENCY ) ~= 0 and ent.DrawTranslucent then
        ent:DrawTranslucent( flags )

    elseif ent.Draw then
        ent:Draw( flags )

    else
        ent:DrawModel( flags )

    end
end

-- clientside models stuck onto carried things, see terminator_cl_extramodels.lua in the terminator addon
hook.Add( "ShouldDrawMyExtraModels", "glee_carrying_hidefromcarrier", function( ent )
    if isHiddenFromView( ent ) then return false end

end )

-- kept on the table, so it's the same function after an autorefresh
-- a new one would look like something else replaced it, and get wrapped in itself
-- looks DrawUnlessHidden up by name each call, so an autorefresh still reaches it
glee_Carrying.CarriedRenderOverride = glee_Carrying.CarriedRenderOverride or function( ent, flags )
    glee_Carrying.DrawUnlessHidden( ent, flags )

end

-- what this client has turned ShouldCollide on for, and what it was before
-- the server sets that flag on what it carries, but the wiki never says it's networked
-- kept on the table, or an autorefresh would take our own true as what it was before
glee_Carrying.ClientCollisionChecked = glee_Carrying.ClientCollisionChecked or setmetatable( {}, { __mode = "k" } )
local collisionChecked = glee_Carrying.ClientCollisionChecked

-- what the local player carries this frame, reused so Think makes no garbage
local carriedNow = {}

local function startCollisionCheck( ent )
    collisionChecked[ent] = ent:GetCustomCollisionCheck()
    ent:SetCustomCollisionCheck( true )
    ent:CollisionRulesChanged()

end

local function stopCollisionCheck( ent )
    ent:SetCustomCollisionCheck( collisionChecked[ent] )
    ent:CollisionRulesChanged()
    collisionChecked[ent] = nil

end

-- wraps each carried thing's RenderOverride, so it can hide
-- per entity, so it reaches props and engine entities too, they've no ENT table to put it on
-- polled, the weapon can reach this client after the thing it carries does
-- and until then the carrier reads as nobody, so collision rules are worked out here too
hook.Add( "Think", "glee_carrying_hidefromcarrier", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end -- joining, there's no local player yet

    local carried = carriedNow
    table.Empty( carried )

    for _, wep in ipairs( ply:GetWeapons() ) do
        if not wep.IsGleeBackpackable then continue end

        local ent = wep:GetCarriedEnt()
        if not IsValid( ent ) then continue end

        carried[ent] = true

        -- again whenever something else swaps it out, eg the ent setting its own
        local wrapper = glee_Carrying.CarriedRenderOverride
        if ent.RenderOverride ~= wrapper then
            ent.glee_PreCarryRenderOverride = ent.RenderOverride
            ent.RenderOverride = wrapper

        end
    end

    -- only their own projectiles are predicted, so only what they carry needs the client's answer
    -- hooked before the rules change, so ShouldCollide's there to be asked
    if next( carried ) then glee_Carrying.SetOwnProjectilesHooked( true ) end

    for ent in pairs( carried ) do
        if collisionChecked[ent] == nil then startCollisionCheck( ent ) end

    end

    for ent in pairs( collisionChecked ) do
        if carried[ent] then continue end

        if IsValid( ent ) then
            stopCollisionCheck( ent )

        else
            collisionChecked[ent] = nil

        end
    end

    if not next( carried ) then glee_Carrying.SetOwnProjectilesHooked( false ) end

end )


-- sh_carrying's ShouldCollide reads the carrier, so a new carrier changes its answer
-- the server calls CollisionRulesChanged itself as it picks up and puts down
-- the client finds out when the carrier var arrives
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

-- what they're aiming at in use range, if it has actions
-- never what they carry, the trace skips it
local function findTarget( ply )
    local shootPos = ply:EyePos()
    local tr = util.TraceLine( {
        start = shootPos,
        endpos = shootPos + ply:GetAimVector() * glee_Carrying.UseRange,
        filter = glee_Carrying.GetCarrierTraceFilter( ply ),
    } )

    local ent = tr.Entity
    if not IsValid( ent ) or not glee_Carrying.GetUseActions( ent ) then return end

    return ent

end

-- asks the server to run one of ent's actions, it checks everything again
-- sent by key, not wheel slot, the actions can change in between
-- eg someone else picks it up
local function sendPick( ent, key )
    net.Start( "glee_carrying_wheelpick" )
        net.WriteEntity( ent )
        net.WriteString( key )
    net.SendToServer()

end

-- the mouse aims it while use stays held, letting go of use picks
-- replaces any wheel already open
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

-- what using ent does, decided here and nowhere else
-- one action just runs, several open the wheel
-- a lone PickUpAction is left to use, which lifts it, then reload carries it
-- wheel-only ents can't be lifted, so theirs just runs
local function useOn( ply, ent )
    local actions = glee_Carrying.GetUseActions( ent )
    if not actions then return end

    if glee_Carrying.IsLiftThenReload( actions ) and not glee_Carrying.IsUseWheelOnly( ent ) then return end

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

        -- GleeUseWheelOnly, a plain +use does nothing on these, so there's nothing to wait out
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

-- tells them what reload would do with what they're lifting
-- the hint stack is the gamemode's, so GAMEMODE's lessons are always there when this runs
hook.Add( "huntersglee_cl_displayhint_poststack", "glee_carrying_heldactionhint", function( ply )
    local ent, action, canPick, reason = glee_Carrying.GetHeldPickUp( ply )
    if not ent then return end

    -- why the press would be refused, or nothing when there's no reason worth saying
    if not canPick then
        if reason then return true, reason end
        return

    end

    local valid, reloadKey = GAMEMODE:TranslatedBind( "+reload" )
    if not valid then return GAMEMODE:UnboundHint( "+reload", "You can't pick this up...", true ) end

    local learned = action.lesson and GAMEMODE:HasLearnedLesson( ply, action.lesson )
    local hint = learned and action.shortHint or action.hint

    return true, string.format( hint, string.upper( reloadKey ) )

end )
