--[[
    Carrying big things, and the use wheel that picks them up. All on terminator_Extras.glee_Carrying.

    CARRYING
        Carried ents have 2 parts
        The actual ent.
        And a swep created to manage it being in your hands.
        One in the hands, more on the back, see GetCarryRules.

        If you want to make a SENT carryable,
        Call these on the actual ENT tbl:
            glee_Carrying.MakeCarryable( ENT, weaponClass ) -- registers it to the carrying system

            -- and its USE actions, mandatory, nothing can pick it up without these
            -- if the tbl's count is 1, ( should be just glee_Carrying.PickUpAction ),
            -- physics picking it up, and pressing R will trigger the action
            ENT.GleeUseActions = { glee_Carrying.PickUpAction } -- USE wheel actions, see below

        If you want to make an engine class carryable:
            glee_Carrying.RegisterCarryable( class, weaponClass, matches, extras )

        Lifted with use, reload carries it, see GetHeldPickUp.

    USE WHEEL
        defaults to having the USE wheel take a moment to open, so ENT:Use can run.
        set .GleeUseWheelOnly to have it open instantly.

        -- these are all your actions
        -- you'll want to include glee_Carrying.PickUpAction, it's the "Pick Up" action.
        ENT.GleeUseActions = {
            glee_Carrying.PickUpAction, -- built in "Pick up", carries the ent. key "carry", skips the two below
            { key = "tune", label = "Tune", icon = Material( "..." ) },
        }
        -- and some stubs
        function ENT:CanUseAction( ply, key ) end -- shared, can this action be ran? return true  allows, return false, reason  greys it out
        function ENT:OnUseAction( ply, key ) end  -- server
        function ENT:CanPickUp( ply ) end         -- shared, optional. CanUseAction, for PickUpAction

        engine class? see RegisterUseActions.
]]

terminator_Extras = terminator_Extras or {}
terminator_Extras.glee_Carrying = terminator_Extras.glee_Carrying or {}

local glee_Carrying = terminator_Extras.glee_Carrying

-- a default action, makes you pick up an ent
local pickUpAction = {
    key = "carry",
    label = "Pick up",
    -- %s is their reload key, see cl_carrying's held action hint
    hint = "This is holdable\nPress %s to hold it in your hands",
    shortHint = "Holdable, press %s",
    lesson = "PutAwayAHoldable",
}

--[[
-- so,
ENT.GleeUseActions = {
    glee_Carrying.PickUpAction, -- this is pickUpAction
}
--]]

do
    -- autorefresh bs
    local existing = glee_Carrying.PickUpAction
    if existing then
        table.Empty( existing )
        for field, value in pairs( pickUpAction ) do
            existing[field] = value

        end

        pickUpAction = existing

    end
end
glee_Carrying.PickUpAction = pickUpAction

-- The use wheel --------------------------------------------------------------

glee_Carrying.UseRange = 90
-- times UseRange, how far off an open wheel can still be picked from
-- client and server share it, so a wheel that's still showing never gets its pick refused
glee_Carrying.UseRangeSlack = 1.5

-- RegisterUseActions defs, by class
-- kept on the table, other files registered these, an autorefresh of this file won't run them again
glee_Carrying.ClassUseDefs = glee_Carrying.ClassUseDefs or {}
local classDefs = glee_Carrying.ClassUseDefs

-- shared, gives an engine class a use wheel
-- def takes the same fields as an ENT, see the top of this file
-- its functions take the ent first, eg def.CanUseAction( ent, ply, key )
-- def.Matches( ent ), optional, narrows it down within the class
-- registering the same id again replaces it, so autorefresh is fine
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

-- where an ent's wheel is defined, the ent itself, or a def registered for its class
-- nil when it has neither
-- a def with Matches beats a catch-all, whatever order they were registered in
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

-- GleeUseWheelOnly, for ents where a plain +use does nothing useful
-- use opens the wheel the moment it's pressed, and can't lift the ent
function glee_Carrying.IsUseWheelOnly( ent )
    local def = getDef( ent )

    return def and def.GleeUseWheelOnly or false

end

-- each actions table, minus PickUpAction, built once per table
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

-- nil when it has no wheel
-- PickUpAction's left out while it's carried, nil if that leaves nothing
-- don't edit what it returns, it can be a shared cached table
function glee_Carrying.GetUseActions( ent )
    local def = getDef( ent )
    if not def then return end

    local actions = def.GleeUseActions
    if not actions or not glee_Carrying.IsCarried( ent ) then return actions end

    local filtered = getWithoutPickUp( actions )
    if #filtered == 0 then return end

    return filtered

end

-- from their eyes, to the ent's nearest point
-- slack multiplies the range, optional
function glee_Carrying.InUseRange( ply, ent, slack )
    local eyePos = ply:EyePos()
    local range = glee_Carrying.UseRange * ( slack or 1 )

    return eyePos:DistToSqr( ent:NearestPoint( eyePos ) ) <= range ^ 2

end

-- can ply pick this action off ent's wheel?
-- never when they're dead, or carrying it
-- otherwise it's the ent's CanUseAction, and its reason if it gives one
-- no CanUseAction allows everything
-- PickUpAction asks CanCarry instead
function glee_Carrying.CanPick( ply, ent, key )
    if not ply:Alive() then return false end
    if glee_Carrying.IsCarriedBy( ent, ply ) then return false end
    if key == glee_Carrying.PickUpAction.key then return glee_Carrying.CanCarry( ply, ent ) end

    local def = getDef( ent )
    if not def or not def.CanUseAction then return true end

    local canPick, reason = def.CanUseAction( ent, ply, key )
    return canPick, reason

end

-- what they're lifting with use, NULL if nothing
function glee_Carrying.GetPhysicsHeld( ply )
    return ply:GetNW2Entity( "glee_PhysicsHeld" )

end

-- just PickUpAction, nothing else
-- these don't open a wheel, they're lifted with use, then reload carries them
-- so a tap of use stays a plain lift
-- wheel-only ents can't be lifted, they just run PickUpAction, check IsUseWheelOnly too
function glee_Carrying.IsLiftThenReload( actions )
    return #actions == 1 and actions[1].key == glee_Carrying.PickUpAction.key

end

-- does its wheel have PickUpAction right now?
-- not whether this player can carry it, that's CanCarry
function glee_Carrying.OffersPickUp( ent )
    for _, action in ipairs( glee_Carrying.GetUseActions( ent ) or {} ) do
        if action.key == glee_Carrying.PickUpAction.key then return true end

    end

    return false

end

-- what reload would carry right now
-- returns the ent they're lifting, PickUpAction, whether they can carry it, and why not
-- even if its wheel has other actions, lifting it already chose this one
-- nil when they're lifting nothing, or nothing that can be picked up
function glee_Carrying.GetHeldPickUp( ply )
    local ent = glee_Carrying.GetPhysicsHeld( ply )
    if not IsValid( ent ) then return end
    if not glee_Carrying.OffersPickUp( ent ) then return end

    local pickUpAction = glee_Carrying.PickUpAction
    local canPick, reason = glee_Carrying.CanPick( ply, ent, pickUpAction.key )

    return ent, pickUpAction, canPick, reason

end

if SERVER then
    -- runs the ent's OnUseAction, true when it went through
    -- PickUpAction runs Carry instead
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

-- whoever's carrying it, NULL if nobody
-- networked, so both sides agree
local function getCarrier( ent )
    local wep = glee_Carrying.GetCarrierWeapon( ent )
    if not IsValid( wep ) then return NULL end

    return wep:GetOwner()

end

function glee_Carrying.IsCarriedBy( ent, ply )
    return getCarrier( ent ) == ply

end

-- owned by ply, or by something they own, like a projectile some SWEPs give to themselves
local function isOwnedBy( ent, ply )
    local owner = ent:GetOwner()
    if owner == ply then return true end

    return IsValid( owner ) and owner:GetOwner() == ply

end

-- stops their own projectiles hitting what they carry
-- a crossbow bolt is big enough to spawn inside what's on their back
-- carried ents are owned by the carrier, but sharing an owner doesn't stop two things colliding
-- shared, so prediction agrees
-- returns nil otherwise, so the item's own ShouldCollide still gets a say
local function ownProjectilesShouldCollide( ent1, ent2 )
    local carrier = getCarrier( ent1 )
    if IsValid( carrier ) and isOwnedBy( ent2, carrier ) then return false end

    carrier = getCarrier( ent2 )
    if IsValid( carrier ) and isOwnedBy( ent1, carrier ) then return false end

end

-- autorefresh resets this to false, so drop the hook to match
local ownProjectilesHooked = false
hook.Remove( "ShouldCollide", "glee_carrying_ownprojectiles" )

-- ShouldCollide runs for every pair where either has a custom collision check, that's a lot
-- so it's only hooked while something's carried
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

-- every backpackable they hold, hands and back
-- a new table each call
function glee_Carrying.GetCarriedWeapons( ply )
    local carried = {}
    for _, wep in ipairs( ply:GetWeapons() ) do
        if wep.IsGleeBackpackable then
            carried[#carried + 1] = wep

        end
    end

    return carried

end

-- a trace filter of them, and everything they carry
-- a new table each call
-- filtering just them won't do, a filter table doesn't skip what they own, and clientside nothing does
function glee_Carrying.GetCarrierTraceFilter( ply )
    local filter = { ply }
    for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( ply ) ) do
        local carried = wep:GetCarriedEnt()
        if IsValid( carried ) then
            filter[#filter + 1] = carried

        end
    end

    return filter

end

-- the weapon that carries it, nil if it can't be carried
-- MakeCarryable sets it on the ent, RegisterCarryable on its class
function glee_Carrying.GetCarryWeaponClass( ent )
    if ent.GleeCarryWeapon then return ent.GleeCarryWeapon end

    local def = getDef( ent )
    if not def then return end

    return def.GleeCarryWeapon

end

-- can ply carry ent? false, reason if not, the reason's shown to them
-- shared, so the wheel and hints grey out when the server would refuse
-- except constraints, clients can't see those, so the server can still say no
function glee_Carrying.CanCarry( ply, ent )
    if not ply:Alive() then return false end
    if glee_Carrying.IsCarried( ent ) then return false end
    if ent:GetNW2Bool( "glee_Nailed", false ) then return false, "It's nailed down." end -- see termhunt_weapon_hammer

    local def = getDef( ent )
    if def and def.CanPickUp then
        local canPickUp, reason = def.CanPickUp( ent, ply )
        if not canPickUp then return false, reason end

    end

    if SERVER and constraint.HasConstraints( ent ) then return false, "It's attached to something." end

    local class = glee_Carrying.GetCarryWeaponClass( ent )
    if not class then return false end

    return glee_Carrying.HasRoomFor( ply, class )

end

-- a player can only hold one weapon of each class
-- so each carry weapon gets a twin, its class plus this
-- two of the same thing are carried as one of each
-- one twin is enough while MAX_CARRIED is 2
local TWIN_SUFFIX = "_twin"

-- the twin inherits everything, so an autorefresh of weaponClass reaches it too
-- registering it again just replaces it
-- never Spawnable, or it'd be in the spawnmenu twice
-- GleeTwinOf is the class it twins, read Spawnable off that instead
local function registerTwin( weaponClass )
    local twinClass = weaponClass .. TWIN_SUFFIX
    weapons.Register( { Base = weaponClass, Spawnable = false, GleeTwinOf = weaponClass }, twinClass )

    if CLIENT then
        killicon.AddAlias( twinClass, weaponClass )

    end
end

-- whichever of weaponClass and its twin they don't hold yet
-- nil if they hold both
function glee_Carrying.GetFreeWeaponClass( ply, weaponClass )
    if not ply:HasWeapon( weaponClass ) then return weaponClass end

    local twinClass = weaponClass .. TWIN_SUFFIX
    if not ply:HasWeapon( twinClass ) then return twinClass end

end

-- what a player can carry, decided here and nowhere else
-- backSlots, how many ride on their back, on top of the one in their hands
-- handsSpeedMul, scales the weapon's SpeedModifier while it's in their hands
-- on the back it's always just SpeedModifier
local normalCarryRules = { backSlots = MAX_CARRIED - 1, handsSpeedMul = 1 }
local weakCarryRules = { backSlots = 0, handsSpeedMul = 2 }

local weakBaseHealth = 50 -- the playermodel's base health under this, too small to put anything on their back

-- shared, the switch block and greying out run clientside too
-- outside the gamemode glee_BaseHealth is never set, so everyone gets normal rules
function glee_Carrying.GetCarryRules( ply )
    local baseHealth = ply:GetNW2Int( "glee_BaseHealth", 0 ) -- see sv_modelscale
    if baseHealth > 0 and baseHealth < weakBaseHealth then return weakCarryRules end

    return normalCarryRules

end

-- could they take one more carried as weaponClass? eg buying one from the shop
-- false, reason if not
function glee_Carrying.HasRoomFor( ply, weaponClass )
    local canHold = 1 + glee_Carrying.GetCarryRules( ply ).backSlots
    if #glee_Carrying.GetCarriedWeapons( ply ) >= canHold then return false, "Your hands are full." end
    if not glee_Carrying.GetFreeWeaponClass( ply, weaponClass ) then return false, "You can't carry any more of these." end

    return true

end

-- only sets which weapon carries it
-- use can't pick it up until PickUpAction's in its GleeUseActions too
function glee_Carrying.MakeCarryable( ENT, weaponClass )
    ENT.GleeCarryWeapon = weaponClass
    registerTwin( weaponClass )

end

-- shared, makes an engine class carryable, with a use wheel of just PickUpAction
-- matches( ent ), optional, narrows it down within the class, like prop_physics down to gas cans
-- extras, optional, more fields for its def, eg { GleeUseWheelOnly = true }
-- registering it again replaces it, so autorefresh is fine
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

-- converts SWEP Construction Kit offsets to bone local ones
-- SCK's pos is forward, right, up
-- its angle turns yaw, then pitch, then roll, each around the axes the last turn left
function glee_Carrying.SCKToLocal( pos, ang )
    local localAng = Angle( 0, 0, 0 )
    localAng:RotateAroundAxis( localAng:Up(), ang.y )
    localAng:RotateAroundAxis( localAng:Right(), ang.p )
    localAng:RotateAroundAxis( localAng:Forward(), ang.r )

    return Vector( pos.x, -pos.y, pos.z ), localAng

end

-- the dual elites viewmodel, posed to hold one thing out front, guns shrunk away
-- armsInward swings the upper arms towards each other, negative's inward
-- it's pitch, yaw would swing them up and down
-- the hand rolls turn the palms, 0 keeps the elites grip, palms facing in
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

-- can inHands go on their back as they switch to newWep?
-- newWep can be NULL, holstered with nothing to switch to
-- false, "noback" when their carry rules give them no back slots
-- false, "backfull" when something's already there
-- shared, so prediction agrees
function glee_Carrying.CanPutAway( ply, inHands, newWep )
    if glee_Carrying.GetCarryRules( ply ).backSlots <= 0 then return false, "noback" end

    for _, wep in ipairs( glee_Carrying.GetCarriedWeapons( ply ) ) do
        -- switching to what's on the back swaps the two, that's fine
        if wep ~= inHands and wep ~= newWep then return false, "backfull" end

    end

    return true

end
