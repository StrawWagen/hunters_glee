--[[
    Carrying big things, and the use wheel that picks them up. All of it's on terminator_Extras.glee_Carrying,
    glee_Carrying below.

    Carrying: a carried entity stays itself, a glee_backpackable_base is the handle to it.
    One rides in the hands, and as many on the back as their carry rules allow, see GetCarryRules.
    The one in the hands can't be put away while the back's full.
    A scripted entity's shared file calls glee_Carrying.MakeCarryable( ENT, weaponClass ), and lists
    glee_Carrying.PickUpAction in its GleeUseActions to be picked up with use.
    Anything without an ENT table, an engine class or a prop, calls
        glee_Carrying.RegisterCarryable( class, weaponClass, matches, extras )
    which does both. GleeTooHeavyToLift = true, on either, stops use lifting it physically, so it's picked
    up by holding use on it instead, see CanLift.
    A weapon only ever makes its own entity when GiveNewCarryable hands it out, eg from a shop.

    The use wheel: hold use on an entity that has GleeUseActions, flick toward one, let go.
    A quick press is still a plain +use, only a held one opens the wheel. GleeUseWheelOnly = true, for
    what a plain +use is no use on, opens it the moment use's pressed, or runs its one action if that's
    all it has, and stops use lifting it.

        ENT.GleeUseActions = {
            { key = "carry", label = "Pick up" },
            { key = "tune", label = "Tune", icon = Material( "..." ) },
        }
        function ENT:CanUseAction( ply, key ) end -- shared, optional. False, and a reason, greys it out and refuses it
        function ENT:OnUseAction( ply, key ) end -- server

    PickUpAction's never handed to those two, CanCarry and Carry answer it.
    Anything without an ENT table registers the same fields, shared, with
        glee_Carrying.RegisterUseActions( class, id, { GleeUseActions = ..., CanUseAction = ..., OnUseAction = ..., GleeCarryWeapon = ..., Matches = ... } )
    each function taking the entity first. Matches( ent ), optional, narrows it within the class,
    and beats one without.

    With only one action there's nothing to pick, so there's no wheel, it's just run. Except a lone
    PickUpAction on what use can lift, see IsLiftThenReload: a tap of use lifts it like anything else.
    Anything lifted with use that offers PickUpAction, alongside other actions or not, is stashed by
    reload while it's held, see GetHeldPickUp. PickUpAction carries its own hints for that,
        { key = ..., label = ..., hint = "first time", shortHint = "once they've done it", lesson = "..." }
    the gamemode lesson learned once a reload stash goes through. Picking it from the wheel doesn't teach it.
]]

terminator_Extras = terminator_Extras or {}
terminator_Extras.glee_Carrying = terminator_Extras.glee_Carrying or {}

local glee_Carrying = terminator_Extras.glee_Carrying


-- The use wheel --------------------------------------------------------------

glee_Carrying.UseRange = 90
-- of UseRange. The client lets a wheel stay open this far off, and the server takes a pick from it.
-- One number, or a wheel the client still shows could get its picks refused
glee_Carrying.UseRangeSlack = 1.5

-- by class, lists of defs. Kept on the table, so an autorefresh of this file doesn't forget what other
-- files registered, they don't run again to put it back
glee_Carrying.ClassUseDefs = glee_Carrying.ClassUseDefs or {}
local classDefs = glee_Carrying.ClassUseDefs

-- id names this registration, so registering it again, as an autorefresh does, replaces it
function glee_Carrying.RegisterUseActions( class, id, def )
    def.Id = id

    local defs = classDefs[class] or {}
    classDefs[class] = defs

    for index, existing in ipairs( defs ) do
        if existing.Id == id then
            defs[index] = def
            return

        end
    end

    table.insert( defs, def )

end

-- What an entity's wheel is made of, its own or its class's. Nil fields where it has none.
-- One with a Matches beats a catch-all, whatever order they were registered in
local function getDef( ent )
    if ent.GleeUseActions then return ent end

    local defs = classDefs[ent:GetClass()]
    if not defs then return end

    local catchAll
    for _, def in ipairs( defs ) do
        if not def.Matches then
            catchAll = catchAll or def

        elseif def.Matches( ent ) then
            return def

        end
    end

    return catchAll

end

-- GleeUseWheelOnly, for what a plain +use does nothing useful on: use opens the wheel the moment
-- it's pressed, and can't lift it
function glee_Carrying.IsUseWheelOnly( ent )
    local def = getDef( ent )

    return def and def.GleeUseWheelOnly or false

end

-- Whether use can lift it physically. Not wheel-only ones, nor GleeTooHeavyToLift ones, whose use is
-- still held like anything else's, just never a lift
function glee_Carrying.CanLift( ent )
    local def = getDef( ent )
    if not def then return true end

    return not def.GleeUseWheelOnly and not def.GleeTooHeavyToLift

end

-- by actions table, the same without PickUpAction, built once each
local withoutPickUp = setmetatable( {}, { __mode = "k" } )

local function getWithoutPickUp( actions )
    local filtered = withoutPickUp[actions]
    if filtered then return filtered end

    filtered = {}
    for _, action in ipairs( actions ) do
        if action.key ~= glee_Carrying.PickUpAction.key then
            filtered[#filtered + 1] = action

        end
    end

    withoutPickUp[actions] = filtered

    return filtered

end

-- Nil when it has no wheel. While it's carried there's no picking it up, so PickUpAction's left out,
-- and nil if that leaves nothing. Don't edit what it returns, it can be a shared cached table
function glee_Carrying.GetUseActions( ent )
    local def = getDef( ent )
    if not def then return end

    local actions = def.GleeUseActions
    if not actions or not glee_Carrying.IsCarried( ent ) then return actions end

    local filtered = getWithoutPickUp( actions )
    if #filtered == 0 then return end

    return filtered

end

-- From their eyes to ent's nearest point. slack multiplies the range, optional
function glee_Carrying.InUseRange( ply, ent, slack )
    local eyePos = ply:EyePos()
    local range = glee_Carrying.UseRange * ( slack or 1 )

    return eyePos:DistToSqr( ent:NearestPoint( eyePos ) ) <= range ^ 2

end

-- Alive, and the action's CanUseAction allows it. Without a CanUseAction, every action's allowed.
-- A refusal passes on CanUseAction's reason, when it gives one. PickUpAction's always CanCarry's
function glee_Carrying.CanPick( ply, ent, key )
    if not ply:Alive() then return false end
    if key == glee_Carrying.PickUpAction.key then return glee_Carrying.CanCarry( ply, ent ) end

    local def = getDef( ent )
    if not def or not def.CanUseAction then return true end

    local canPick, reason = def.CanUseAction( ent, ply, key )
    return canPick, reason

end

-- NULL when they're not lifting anything with use
function glee_Carrying.GetPhysicsHeld( ply )
    return ply:GetNW2Entity( "glee_PhysicsHeld" )

end

-- Offers nothing but PickUpAction, which is picked by lifting it with use then pressing reload, not by
-- holding use, so a tap of use stays a plain lift. Only for what use can lift, see CanLift, the rest run it
function glee_Carrying.IsLiftThenReload( actions )
    return #actions == 1 and actions[1].key == glee_Carrying.PickUpAction.key

end

-- What they're lifting with use, PickUpAction, whether they can carry it, and the reason if not.
-- Whatever else it offers, a lift's already chosen it, reload stashes it. Nil when they're lifting
-- nothing, or it can't be picked up
function glee_Carrying.GetHeldPickUp( ply )
    local ent = glee_Carrying.GetPhysicsHeld( ply )
    if not IsValid( ent ) then return end

    local pickUpAction = glee_Carrying.PickUpAction
    local offered = false
    for _, action in ipairs( glee_Carrying.GetUseActions( ent ) or {} ) do
        if action.key == pickUpAction.key then
            offered = true
            break

        end
    end
    if not offered then return end

    local canPick, reason = glee_Carrying.CanPick( ply, ent, pickUpAction.key )

    return ent, pickUpAction, canPick, reason

end

if SERVER then
    -- Whatever OnUseAction returns, true when it went through. PickUpAction's always Carry
    function glee_Carrying.RunAction( ply, ent, key )
        if key == glee_Carrying.PickUpAction.key then return glee_Carrying.Carry( ply, ent ) end

        local def = getDef( ent )
        if not def or not def.OnUseAction then return end

        return def.OnUseAction( ent, ply, key )

    end
end


-- Carrying -------------------------------------------------------------------

local MAX_CARRIED = 2 -- hands and back

-- NULL when nobody's carrying it
function glee_Carrying.GetCarrierWeapon( ent )
    return ent:GetNW2Entity( "glee_CarrierWeapon" )

end

function glee_Carrying.IsCarried( ent )
    return IsValid( glee_Carrying.GetCarrierWeapon( ent ) )

end

-- Whoever's carrying it, NULL if nobody is. From networked values, so it's the same both sides
local function getCarrier( ent )
    local wep = glee_Carrying.GetCarrierWeapon( ent )
    if not IsValid( wep ) then return NULL end

    return wep:GetOwner()

end

-- owned by ply, or by something they own, like a projectile some SWEPs give to themselves
local function isOwnedBy( ent, ply )
    local owner = ent:GetOwner()
    if owner == ply then return true end

    return IsValid( owner ) and owner:GetOwner() == ply

end

-- A carried thing's owned by its carrier, which keeps their traces off it, but not their projectiles,
-- which they own too, and owned things do nothing for each other. A bolt is big enough to spawn inside
-- what's on their back. Shared, so prediction agrees. Nil otherwise, so an item's own ShouldCollide
-- still decides the rest
local function ownProjectilesShouldCollide( ent1, ent2 )
    local carrier = getCarrier( ent1 )
    if IsValid( carrier ) and isOwnedBy( ent2, carrier ) then return false end

    carrier = getCarrier( ent2 )
    if IsValid( carrier ) and isOwnedBy( ent1, carrier ) then return false end

end

-- an autorefresh starts this over at false, so the hook's dropped to match
local ownProjectilesHooked = false
hook.Remove( "ShouldCollide", "glee_carrying_ownprojectiles" )

-- Asked about every pair where either has a custom collision check, so it's only hooked while there's
-- something carried for it to answer about
function glee_Carrying.SetOwnProjectilesHooked( hooked )
    if hooked == ownProjectilesHooked then return end
    ownProjectilesHooked = hooked

    if hooked then
        hook.Add( "ShouldCollide", "glee_carrying_ownprojectiles", ownProjectilesShouldCollide )

    else
        hook.Remove( "ShouldCollide", "glee_carrying_ownprojectiles" )

    end
end

if SERVER then
    -- kept on the table, so an autorefresh doesn't forget what's carried
    glee_Carrying.CarriedEnts = glee_Carrying.CarriedEnts or {}
    local carriedEnts = glee_Carrying.CarriedEnts

    function glee_Carrying.SetCarriedTracked( ent, carried )
        carriedEnts[ent] = carried or nil
        glee_Carrying.SetOwnProjectilesHooked( next( carriedEnts ) ~= nil )

    end

    glee_Carrying.SetOwnProjectilesHooked( next( carriedEnts ) ~= nil )

end

-- Every backpackable they hold, in their hands and on their back. A new table each call
function glee_Carrying.GetCarriedWeapons( ply )
    local carried = {}
    for _, wep in ipairs( ply:GetWeapons() ) do
        if wep.IsGleeBackpackable then
            carried[#carried + 1] = wep

        end
    end

    return carried

end

-- Nil when it can't be carried. Its own, as MakeCarryable sets, or its class's, as RegisterCarryable does
function glee_Carrying.GetCarryWeaponClass( ent )
    if ent.GleeCarryWeapon then return ent.GleeCarryWeapon end

    local def = getDef( ent )
    if not def then return end

    return def.GleeCarryWeapon

end

-- Shared, so the wheel and hints grey out the same as the server refuses. A refusal can come with a
-- reason to show them. The server also refuses anything constrained, which clients can't see,
-- so a client can say yes to what the server then won't
function glee_Carrying.CanCarry( ply, ent )
    if not ply:Alive() then return false end
    if glee_Carrying.IsCarried( ent ) then return false end
    if ent:GetNW2Bool( "glee_Nailed", false ) then return false, "It's nailed down." end -- see termhunt_weapon_hammer
    if SERVER and constraint.HasConstraints( ent ) then return false, "It's attached to something." end

    local class = glee_Carrying.GetCarryWeaponClass( ent )
    if not class then return false end

    return glee_Carrying.HasRoomFor( ply, class )

end

-- A player holds one weapon of a class, so each carry weapon gets a twin, its class with this on the
-- end, and two of the same thing are carried as one of each. Two's all MAX_CARRIED ever needs
local TWIN_SUFFIX = "_twin"

-- The twin inherits everything, so an autorefresh of weaponClass reaches it. Registered again by
-- whatever registered it, as an autorefresh of that file does, it's just replaced
local function registerTwin( weaponClass )
    local twinClass = weaponClass .. TWIN_SUFFIX
    weapons.Register( { Base = weaponClass, Spawnable = false, IsGleeCarryTwin = true }, twinClass )

    if CLIENT then
        killicon.AddAlias( twinClass, weaponClass )

    end
end

-- Which of weaponClass and its twin they don't hold yet, nil if they hold both
function glee_Carrying.GetFreeWeaponClass( ply, weaponClass )
    if not ply:HasWeapon( weaponClass ) then return weaponClass end

    local twinClass = weaponClass .. TWIN_SUFFIX
    if not ply:HasWeapon( twinClass ) then return twinClass end

end

-- What a player can carry, the one place that decides it. backSlots is how many ride their back, on top
-- of the one in their hands. handsSpeedMul times a weapon's SpeedModifier slows them while it's in
-- their hands, on the back it's always just SpeedModifier
local normalCarryRules = { backSlots = MAX_CARRIED - 1, handsSpeedMul = 1 }
local weakCarryRules = { backSlots = 0, handsSpeedMul = 2 }

local weakBaseHealth = 50 -- the playermodel's base health under this, too small to put anything on their back

-- Shared, the switch block and the greying out run clientside too. Outside the gamemode glee_BaseHealth is
-- never set, so everyone's normal
function glee_Carrying.GetCarryRules( ply )
    local baseHealth = ply:GetNW2Int( "glee_BaseHealth", 0 ) -- see sv_modelscale
    if baseHealth > 0 and baseHealth < weakBaseHealth then return weakCarryRules end

    return normalCarryRules

end

-- Whether they could take on one more carried as weaponClass, eg from a shop. False, and why, if not
function glee_Carrying.HasRoomFor( ply, weaponClass )
    local canHold = 1 + glee_Carrying.GetCarryRules( ply ).backSlots
    if #glee_Carrying.GetCarriedWeapons( ply ) >= canHold then return false, "Your hands are full." end
    if not glee_Carrying.GetFreeWeaponClass( ply, weaponClass ) then return false, "You can't carry any more of these." end

    return true

end

-- Only which weapon carries it. For use to pick it up, list PickUpAction in its GleeUseActions too
function glee_Carrying.MakeCarryable( ENT, weaponClass )
    ENT.GleeCarryWeapon = weaponClass
    registerTwin( weaponClass )

end

-- Filled in place, not replaced. Entities and registrations hold this very table, so an autorefresh
-- of this file reaches them too
local pickUpAction = glee_Carrying.PickUpAction or {}
glee_Carrying.PickUpAction = pickUpAction

pickUpAction.key = "carry"
pickUpAction.label = "Pick up"
pickUpAction.hint = "This is holdable\nPress R to hold it in your hands"
pickUpAction.shortHint = "Holdable, press R"
pickUpAction.lesson = "PutAwayAHoldable"

-- Shared. matches( ent ), optional, narrows it within the class, like prop_physics down to gas cans.
-- It gets a use wheel of just PickUpAction. Registering it again, as an autorefresh does, replaces it.
-- extras, optional, more fields for its def, eg { GleeTooHeavyToLift = true }
function glee_Carrying.RegisterCarryable( class, weaponClass, matches, extras )
    local def = {
        Matches = matches,
        GleeCarryWeapon = weaponClass,
        GleeUseActions = { glee_Carrying.PickUpAction },
    }
    for key, value in pairs( extras or {} ) do
        def[key] = value

    end

    glee_Carrying.RegisterUseActions( class, weaponClass, def )
    registerTwin( weaponClass )

end

-- SWEP Construction Kit's element offsets, as bone local ones. Its pos is along forward, right, up,
-- and its angle turns yaw, then pitch, then roll, each around the axes the last turn left
function glee_Carrying.SCKToLocal( pos, ang )
    local localAng = Angle( 0, 0, 0 )
    localAng:RotateAroundAxis( localAng:Up(), ang.y )
    localAng:RotateAroundAxis( localAng:Right(), ang.p )
    localAng:RotateAroundAxis( localAng:Forward(), ang.r )

    return Vector( pos.x, -pos.y, pos.z ), localAng

end

-- The dual elites' viewmodel, posed into holding one thing out front, guns shrunk away.
-- armsInward swings the upper arms in towards each other, negative's inward; yaw would swing them up
-- and down, so it's pitch. The hand rolls turn the palms, 0 leaves the elites' grip, palms facing in
function glee_Carrying.ElitesBoneMods( armsInward, leftHandRoll, rightHandRoll )
    return {
        ["ValveBiped.Bip01_R_UpperArm"] = { scale = Vector( 1, 1, 1 ), pos = Vector( -3.385, -1.29, 0.507 ), angle = Angle( armsInward, 0, 0 ) },
        ["v_weapon.elite_right"] = { scale = Vector( 0.009, 0.009, 0.009 ), pos = Vector( 0, 0, 0 ), angle = Angle( 0, 0, 0 ) },
        ["ValveBiped.Bip01_L_UpperArm"] = { scale = Vector( 1, 1, 1 ), pos = Vector( -1.254, -0.774, 0 ), angle = Angle( -armsInward, 0, 0 ) },
        ["ValveBiped.Bip01_L_Hand"] = { scale = Vector( 1, 1, 1 ), pos = Vector( 0, 0, 0 ), angle = Angle( 0, 0, leftHandRoll ) },
        ["v_weapon.elite_left"] = { scale = Vector( 0.009, 0.009, 0.009 ), pos = Vector( 0, 0, -30 ), angle = Angle( 0, 0, 0 ) },
        ["ValveBiped.Bip01_R_Hand"] = { scale = Vector( 1, 1, 1 ), pos = Vector( 0, 0, 0 ), angle = Angle( 0, 0, rightHandRoll ) },
    }
end

-- What's in their hands can't be switched away from, onto their back, when their back's full or their
-- carry rules give them none. Shared, so prediction agrees
hook.Add( "PlayerSwitchWeapon", "glee_carrying_handsfull", function( ply, oldWep, newWep )
    if not IsValid( oldWep ) or not oldWep.IsGleeBackpackable then return end
    if not IsValid( oldWep:GetCarriedEnt() ) then return end

    -- nothing goes on their back at all, what's in their hands stays there till it's put down
    if glee_Carrying.GetCarryRules( ply ).backSlots <= 0 then
        if SERVER then glee_Carrying.HintCantBackpack( ply ) end
        return true

    end

    for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( ply ) ) do
        -- switching to what's on the back swaps the two, that's fine
        if wep ~= oldWep and wep ~= newWep then
            if SERVER then glee_Carrying.HintHandsFull( ply ) end
            return true

        end
    end
end )
