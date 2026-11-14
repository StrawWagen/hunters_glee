AddCSLuaFile()

--[[------------------------------------
    Medical Tissue Reclaimer: heals the living, revives the dead, both out of one pool of reclamation material.

    Hold primary on a hurt player to heal them, or on a dead player's projection to revive them.
    Hold secondary to heal yourself.
    Reclamation material comes from buying another, and from health pickups found while already at full health.

    Read top to bottom: setup, telling the owner no, the viewmodel, healing, picking up material, reviving,
    then Think, which runs it all every tick.
    After that the hud, the client's half, beams, projection, corpse and sounds, tied together in SWEP:DrawBeams at its bottom,
    and last, where dead players' positions come from.
--]]-------------------------------------

SWEP.PrintName = "Medical Tissue Reclaimer"
SWEP.Author = "StrawWagen"
SWEP.Purpose = "Hold primary to heal the living, secondary to heal yourself. Hold primary on the dead to revive them."
SWEP.Category = "Hunter's Glee"

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_superphyscannon.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_physics.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.HoldType = "physgun"

-- reclamation material is the owner's GLEE_RECLAMATION_MATERIAL ammo, no clip
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 200 -- also what each shop resupply adds
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "GLEE_RECLAMATION_MATERIAL"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

-- healing is a hold, a few health at a time, see HealTick
SWEP.HealTickAmount = 2 -- a whole one at ReclamationPerHealth, less would round up to costing more
SWEP.HealInterval = 0.1 -- seconds between ticks healing others, 20 hp a second
SWEP.SelfHealInterval = 0.4 -- healing yourself, 5 hp a second
SWEP.ReclamationPerHealth = 0.5 -- rounded up, it's whole ammo
SWEP.ReviveCost = 100

local CLASS = "glee_tissue_reclaimer"

local DenySound = Sound( "WallHealth.Deny" ) -- out of reclamation material
local ReviveSound = Sound( "items/medshot4.wav" )
local ReviveDenySound = Sound( "items/medshotno1.wav" )
local AbsorbSound = Sound( "items/medshot4.wav" ) -- a health pickup going into the kit

-- the gravity gun's own, pitched up for a smaller, fussier machine, see playOneShot
local DryFireSound = Sound( "weapons/physcannon/physcannon_dryfire.wav" ) -- nothing to heal or revive
local HealStartSound = Sound( "weapons/physcannon/physcannon_pickup.wav" )
local HealStopSound = Sound( "weapons/physcannon/physcannon_drop.wav" )
local oneShotPitch = 130
local oneShotLevel = 70
local oneShotVol = 0.2

local healReach = 120 -- how far the aim trace goes, for healing and for finding who to revive
local healHull = Vector( 10, 10, 10 ) -- the forgiving second try at who to heal, like the shove's, see TraceHealTarget
local reviveReach = 75 -- from where that trace ends to a dead player's position, and how far you can move mid-revive
local pointOutRange = 1000 -- dead players within this each get a nameplate and a beam. Past it, only the nearest gets a beam

-- the revive's progress bar, see generic_WaitForProgressBar
-- it keeps its progress through a quick let go and re-press, so the corpse's reclaiming does too
local reviveBarSpeed = 0.1 -- seconds per step
local reviveBarChunk = 2 -- percent per step

-- the corpse goes into the projection a bone at a time, slow at first, then faster and faster
-- nearly every bone going in right at the end of the revive
local reclaimRampup = 0.6 -- each bone's wait is this times the last
local reclaimFinishFrac = 0.95 -- of the way through the revive, the last bone goes in, just before they stand

-- 0 to 1 of the way through the revive, when this bone of boneCount goes in
local function boneSnapFrac( boneIndex, boneCount )
    return reclaimFinishFrac * ( 1 - reclaimRampup ^ ( boneIndex + 1 ) ) / ( 1 - reclaimRampup ^ boneCount )

end


-- Setup ---------------------------------------------------------------------

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

function SWEP:SetupDataTables()
    -- all predicted, see HealThink
    self:NetworkVar( "Entity", "HealTarget" ) -- who it's healing right now, its owner when healing themselves. Every client's beams and sounds go off this
    self:NetworkVar( "Float", "NextHealTick" )
    -- healing yourself turns the kit onto its medic
    self:NetworkVar( "Float", "SelfAim" ) -- 0 to 1, how far it's turned onto them
    self:NetworkVar( "Float", "SelfAimUntil" ) -- stays turned onto them until then
    self:NetworkVar( "Float", "ViewModelBusyUntil" ) -- a one-shot sequence is playing until then, see PlayViewModelOnce
    -- the server's, other clients don't know its owner's ammo
    self:NetworkVar( "Bool", "OutOfMaterial" ) -- can't afford a heal tick, its glow goes out
    -- the server's, the client can't see everything that decides it, see PrimaryHealTarget
    self:NetworkVar( "Bool", "AimedHealable" ) -- aimed at someone primary would heal, the prongs part for it

end

function SWEP:CanAffordRevive()
    return self:Ammo1() >= self.ReviveCost

end

-- networked, unlike self.resurrecting, so every client knows too
function SWEP:IsReviving()
    return IsValid( self:GetNWEntity( "RevivingTarget", NULL ) )

end

-- can't heal even 1 health, it's spent
-- only the owner's client knows their ammo, everyone else reads the server's answer, see OutOfMaterial
function SWEP:IsOutOfMaterial()
    return self:Ammo1() < self:HealCost( 1 )

end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Ammo1()

    return self.AmmoDisplay

end

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, CLASS, "materials/vgui/hud/" .. CLASS .. ".png" )
    language.Add( "GLEE_RECLAMATION_MATERIAL_ammo", "Reclamation Material" )

end


-- Telling the owner no ------------------------------------------------------
-- the sounds and notifies for a click or a hold that did nothing

-- from predicted code, the owner's client plays its own, and the server's reaches everyone else
local function playOneShot( wep, snd )
    if not IsFirstTimePredicted() then return end
    wep:GetOwner():EmitSound( snd, oneShotLevel, oneShotPitch, oneShotVol )

end

-- for what only the server can judge, like who's healable, the server's IsNPC counts terminators, the client's doesn't
-- prediction keeps the server's sounds from the owner, so it's lifted to reach them too
local function playServerSound( wep, snd, level, pitch, vol )
    if CLIENT then return end
    local owner = wep:GetOwner()

    SuppressHostEvents( NULL )
    owner:EmitSound( snd, level, pitch, vol )
    if owner:IsPlayer() then
        SuppressHostEvents( owner )

    end
end

local function playServerOneShot( wep, snd )
    playServerSound( wep, snd, oneShotLevel, oneShotPitch, oneShotVol )

end

local outOfMaterialText = "NO RECLAMATION MATERIAL LEFT" -- the notify's, and the hint's, see HintPostStack

-- out of material, nothing else it says matters, so it's said over every other failure
-- one replaceKey from both realms, see notifyFailed and notifyFromServer
local function overOutOfMaterial( wep, data )
    if not wep:IsOutOfMaterial() then return end

    data.text = outOfMaterialText
    data.description = "Buy another, or pick up health while at full health."
    data.replaceKey = "glee_reclaimer_reclamation"

end

-- why it failed, in the owner's notice feed
-- from predicted code, so only the owner's client sends it, the server's would show it twice
-- each reason shares a replaceKey, holding on flashes the one already up instead of stacking more
local function notifyFailed( wep, data )
    if SERVER or not IsFirstTimePredicted() then return end

    data.kind = "bad"
    overOutOfMaterial( wep, data )
    huntersGlee_Notify( nil, data )

end

-- every failure notify's key, see clearFailedNotifies
local failedNotifyKeys = {
    "glee_reclaimer_dryfire",
    "glee_reclaimer_reclamation",
    "glee_reclaimer_interrupted",
}

-- once it heals or revives, whatever went wrong before is stale
local function clearFailedNotifies( wep )
    if CLIENT then return end
    local owner = wep:GetOwner()
    if not owner:IsPlayer() then return end

    for _, key in ipairs( failedNotifyKeys ) do
        huntersGlee_CancelNotify( { owner }, key )

    end
end

-- why it failed, from the server, for what the client can't judge, eg who's an npc
local function notifyFromServer( wep, data )
    if CLIENT then return end
    local owner = wep:GetOwner()
    if not owner:IsPlayer() then return end

    data.kind = "bad"
    overOutOfMaterial( wep, data )
    huntersGlee_Notify( { owner }, data )

end

-- why a click did nothing
-- only on the press, holding on after a heal fills someone up isn't a failed click
local function notifyDryFire( wep, key, data )
    if CLIENT then return end
    local owner = wep:GetOwner()
    if not owner:IsPlayer() or not owner:KeyPressed( key ) then return end

    data.replaceKey = "glee_reclaimer_dryfire"
    notifyFromServer( wep, data )

end


-- The viewmodel's sequences -------------------------------------------------
-- the gravity gun's own. Shaking while it heals or revives, like it does holding a prop, see UpdateViewModel
-- still otherwise. The model's idle sways, it reads as a wobble, so it never plays
-- instead every one-shot, the deploy's draw too, stops on its last frame, where the gun rests
-- shared and predicted, like the fists'

local busySequence = "hold_idle"
local settleSequence = "altfire" -- out of the shake, back to resting
local drawSequence = "draw" -- the engine plays it on deploy

-- the owner's viewmodel, nil for npcs
function SWEP:OwnersViewModel()
    local owner = self:GetOwner()
    if not IsValid( owner ) or not owner:IsPlayer() then return end

    local vm = owner:GetViewModel()
    if not IsValid( vm ) then return end

    return vm

end

-- the shake waits until it's done
function SWEP:PlayViewModelOnce( name )
    local vm = self:OwnersViewModel()
    if not vm then return end

    local seq = vm:LookupSequence( name )
    if seq < 0 then return end

    vm:SendViewModelMatchingSequence( seq )
    self:SetViewModelBusyUntil( CurTime() + vm:SequenceDuration( seq ) )

end

function SWEP:UpdateViewModel()
    if CurTime() < self:GetViewModelBusyUntil() then return end

    local vm = self:OwnersViewModel()
    if not vm then return end

    local busySeq = vm:LookupSequence( busySequence )
    local shaking = vm:GetSequence() == busySeq

    if self:IsReviving() or IsValid( self:GetHealTarget() ) then
        -- only on a change, sending it again restarts it
        if not shaking then
            vm:SendViewModelMatchingSequence( busySeq )

        end
    elseif shaking then
        self:PlayViewModelOnce( settleSequence )

    end
end

-- the gravity gun's pull, on the viewmodel and the owner's body
function SWEP:AttackAnim()
    self:PlayViewModelOnce( "altfire" )
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

end

function SWEP:Deploy()
    local vm = self:OwnersViewModel()
    if vm then
        self:SetViewModelBusyUntil( CurTime() + vm:SequenceDuration( vm:LookupSequence( drawSequence ) ) )

    end
    return true

end

function SWEP:ShutDown()
    local owner = self:GetOwner()
    if IsValid( owner ) then
        owner.glee_reclaimerBlocksSwitching = nil

    end
    self:SetViewModelBusyUntil( 0 )
    self:SetHealTarget( NULL )
    self:SetAimedHealable( false )
    self:SetSelfAimUntil( 0 )
    self:SetSelfAim( 0 )
    self.glee_selfAimShown = 0
    if CLIENT then
        self:StopLoopSounds()
        self:StopHologramHum()

    end
end

function SWEP:OnRemove()
    self:ShutDown()
    if CLIENT then
        SafeRemoveEntity( self.glee_hologram )

    end
end

function SWEP:Holster()
    self:ShutDown()
    return true

end

function SWEP:OwnerChanged()
    self:ShutDown()

end


-- Healing -------------------------------------------------------------------
-- a hold, primary on someone else, secondary on yourself, a few health a tick
-- healing yourself turns the kit onto its medic first. To the left, the viewmodel has no right side to show
-- it stays turned a moment after letting go, so a quick re-press doesn't wait on the turn again
-- healing someone else or reviving turns it back quicker
-- all predicted, run from Think, so the beams, their sound and the turn start without waiting on the server

local selfAimLinger = 0.5 -- seconds it stays turned onto the medic after letting go
local selfAimCutTo = 0.1 -- seconds left turned, once it's cut short
local selfAimInTime = 0.35 -- seconds turning all the way onto the medic
local selfAimOutTime = 0.4 -- seconds turning back
local selfHealYaw = 35 -- degrees the viewmodel turns left, tune in game
local selfHealPitch = 8 -- degrees it tips down toward the chest, tune in game
local selfHealShift = 16 -- units it slides right, so turning left doesn't swing it across the view
local healScorePerHealth = 0.2 -- healing other players, 8 for 40 health
local denyRepeat = 1 -- seconds between deny sounds, holding on with none left
local aimCheckInterval = 0.1 -- seconds between the server's checks for AimedHealable

-- npc classes that are all machine, see https://wiki.facepunch.com/gmod/Enums/CLASS
-- CLASS_COMBINE isn't, it's soldiers and turrets both
local machineClasses = {
    [CLASS_COMBINE_GUNSHIP] = true,
    [CLASS_MANHACK] = true,
    [CLASS_MILITARY] = true,
    [CLASS_SCANNER] = true,
    [CLASS_MISSILE] = true,
    [CLASS_HACKED_ROLLERMINE] = true,
    [CLASS_MACHINE] = true,
    [CLASS_PORTAL_TURRET] = true,
}

-- machines have no tissue to reclaim
local function isOrganic( ent )
    if ent.DoMetallicDamage then return false end
    if ent.GetNPCClass and machineClasses[ent:GetNPCClass()] then return false end -- server only
    if ent.GetBloodColor and ent:GetBloodColor() == BLOOD_COLOR_MECH then return false end -- GetBloodColor may be server only
    return true

end

-- a player or npc that's alive, organic or not
local function isLiving( ent )
    if not IsValid( ent ) then return false end
    if not ( ent:IsPlayer() or ent:IsNPC() ) then return false end
    return ent:Health() > 0

end

local function isHealable( ent )
    if not isLiving( ent ) then return false end
    if not isOrganic( ent ) then return false end

    return ent:Health() < ent:GetMaxHealth()

end

-- the hurt player or npc being aimed at, nil if there's none, and the aim's trace, see FindRevivable
-- a precise line first, then a fat hull for a near miss, like the shove's
function SWEP:TraceHealTarget()
    local owner = self:GetOwner()
    local shootPos = owner:GetShootPos()
    local trace = {
        start = shootPos,
        endpos = shootPos + owner:GetAimVector() * healReach,
        filter = owner,
    }

    -- only the server rewinds, the client already sees everyone where they were
    local lagCompensate = SERVER and owner:IsPlayer()
    if lagCompensate then
        owner:LagCompensation( true )

    end

    local aimTrace = util.TraceLine( trace )
    local target = aimTrace.Entity
    if not isHealable( target ) then
        trace.mins = -healHull
        trace.maxs = healHull
        target = util.TraceHull( trace ).Entity

    end

    if lagCompensate then
        owner:LagCompensation( false )

    end

    if not isHealable( target ) then return nil, aimTrace end
    return target, aimTrace

end

function SWEP:HealCost( health )
    return math.ceil( health * self.ReclamationPerHealth )

end

-- how much a tick would heal them, and what it'd cost
function SWEP:TickHealAndCost( healTarget )
    -- never below 0, the client's idea of someone else's health can be off, and a negative cost gives material
    local heal = math.Clamp( healTarget:GetMaxHealth() - healTarget:Health(), 0, self.HealTickAmount )
    return heal, self:HealCost( heal )

end

function SWEP:CanSelfHeal()
    local owner = self:GetOwner()
    if owner:Health() >= owner:GetMaxHealth() then return false end

    local _, cost = self:TickHealAndCost( owner )
    return self:Ammo1() >= cost

end

local function insufficientNotice()
    return {
        text = "INSUFFICIENT RECLAMATION MATERIAL",
        description = "Reclamation halted.",
        replaceKey = "glee_reclaimer_reclamation",
    }
end

-- too little left to heal yourself, predicted
local function playDeny( wep )
    wep:PlayViewModelOnce( "fire" )
    if not IsFirstTimePredicted() then return end
    wep:GetOwner():EmitSound( DenySound )
    notifyFailed( wep, insufficientNotice() )

end

-- too little left to heal someone else, from the server, it's the one that picks who, see PrimaryHealTarget
local function playServerDeny( wep )
    if CLIENT then return end
    wep:PlayViewModelOnce( "fire" )
    playServerSound( wep, DenySound )
    notifyFromServer( wep, insufficientNotice() )

end

-- only the deny, holding it down is up to HealThink
function SWEP:SecondaryAttack()
    if not IsValid( self:GetOwner() ) then return end
    if self:IsReviving() then return end -- would spend the material the revive is about to cost
    if self:CanSelfHeal() then return end

    local owner = self:GetOwner()
    if owner:Health() >= owner:GetMaxHealth() then
        playOneShot( self, DryFireSound )
        self:PlayViewModelOnce( "fire" )
        notifyDryFire( self, IN_ATTACK2, {
            text = "TISSUE INTACT",
            description = "You're at full health.",
        } )

    else
        playDeny( self )

    end
    self:SetNextSecondaryFire( CurTime() + denyRepeat )

end

function SWEP:IsSelfAiming()
    return CurTime() < self:GetSelfAimUntil()

end

-- turns it back off its medic sooner
function SWEP:CutSelfAim()
    self:SetSelfAimUntil( math.min( self:GetSelfAimUntil(), CurTime() + selfAimCutTo ) )

end

-- steps self aim from where it is toward 1 while self aiming, 0 when not
local function stepSelfAim( aim, turning, dt )
    if turning then
        return math.min( aim + dt / selfAimInTime, 1 )

    end
    return math.max( aim - dt / selfAimOutTime, 0 )

end

-- heals them a tick's worth, they have to be hurt and it has to be affordable
function SWEP:HealTick( healTarget )
    local owner = self:GetOwner()
    local isSelf = healTarget == owner
    local heal, cost = self:TickHealAndCost( healTarget )

    self:SetNextHealTick( CurTime() + ( isSelf and self.SelfHealInterval or self.HealInterval ) )
    self:TakePrimaryAmmo( cost )

    if not SERVER then return end

    healTarget:SetHealth( math.min( healTarget:GetMaxHealth(), healTarget:Health() + heal ) )

    if isSelf then
        healTarget.glee_LastSetHealthReason = "glee_reclaimer_healself"
        owner:SetNW2Bool( "gleereclaimer_healedself", true )
        return

    end

    healTarget.glee_LastSetHealthReason = "glee_reclaimer_heal"
    owner:SetNW2Bool( "gleereclaimer_healedother", true )

    if owner.GivePlayerScore and healTarget:IsPlayer() then
        -- score is whole, the fractions carry over to the next tick
        local score = ( self.glee_healScore or 0 ) + heal * healScorePerHealth
        local whole = math.floor( score )
        self.glee_healScore = score - whole
        if whole > 0 then
            owner:GivePlayerScore( whole )

        end
    end
end

-- who primary heals, the server's to pick. The client can't see everything that decides it, eg terminators' IsNPC, DoMetallicDamage
-- so the client keeps whoever the server last picked, a round trip late
function SWEP:PrimaryHealTarget()
    if SERVER then
        return ( self:TraceHealTarget() ) -- not its trace

    end

    local healTarget = self:GetHealTarget()
    if IsValid( healTarget ) and healTarget ~= self:GetOwner() then return healTarget end

end

-- every tick, for a player holding it. Picks who the held buttons heal, primary on someone else wins
function SWEP:HealThink()
    local owner = self:GetOwner()
    local canHeal = owner:Health() > 0 and not self:IsReviving()

    local healTarget = canHeal and owner:KeyDown( IN_ATTACK ) and self:PrimaryHealTarget()
    local healingSelf = canHeal and not healTarget and owner:KeyDown( IN_ATTACK2 ) and self:CanSelfHeal()

    if healingSelf then
        self:SetSelfAimUntil( CurTime() + selfAimLinger )

    elseif healTarget or self:IsReviving() then
        self:CutSelfAim()

    end

    self:SetSelfAim( stepSelfAim( self:GetSelfAim(), self:IsSelfAiming(), FrameTime() ) )

    -- not until it's all the way round
    if healingSelf and self:GetSelfAim() >= 1 then
        healTarget = owner

    end

    local tickDue = CurTime() >= self:GetNextHealTick()
    if healTarget then
        local _, cost = self:TickHealAndCost( healTarget )
        if self:Ammo1() < cost then
            -- only someone else, CanSelfHeal already turned away a self heal it can't afford
            if SERVER and tickDue then
                playServerDeny( self )
                self:SetNextHealTick( CurTime() + denyRepeat )

            end
            healTarget = nil

        elseif tickDue then
            self:HealTick( healTarget )

        end
    end

    healTarget = healTarget or NULL
    local wasHealing = IsValid( self:GetHealTarget() )
    if IsValid( healTarget ) and not wasHealing then
        self:AttackAnim()
        playServerOneShot( self, HealStartSound )
        clearFailedNotifies( self )

    elseif wasHealing and not IsValid( healTarget ) then
        playServerOneShot( self, HealStopSound )

    end
    self:SetHealTarget( healTarget )

end


-- Picking up material -------------------------------------------------------
-- health pickups found at full health go into the kit instead

local reclamationToGive = {
    item_healthkit = 25,
    item_healthvial = 10,

}
local absorbedNames = {
    item_healthkit = "a health kit",
    item_healthvial = "a health vial",

}

hook.Add( "PlayerCanPickupItem", "glee_reclaimer_absorbsitems", function( ply, item )
    local itemsClass = item:GetClass()
    local toGive = reclamationToGive[itemsClass]
    if not toGive then return end

    if not ply:HasWeapon( CLASS ) then return end

    if ply:Health() < ply:GetMaxHealth() then return end

    if item.glee_AbsorbedByPly then return end
    item.glee_AbsorbedByPly = true

    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        ply:GiveAmmo( toGive, "GLEE_RECLAMATION_MATERIAL" )
        local pit = 100 + ( 200 / toGive )
        ply:EmitSound( AbsorbSound, 55, pit, 1, CHAN_BODY )
        SafeRemoveEntity( item )

        huntersGlee_Notify( { ply }, {
            text = "MATERIAL RECLAIMED",
            description = "+" .. toGive .. " Reclamation Material, from " .. absorbedNames[itemsClass] .. ".",
            kind = "good",
            replaceKey = "glee_reclaimer_absorbed",
        } )

    end )
end )


-- Reviving ------------------------------------------------------------------

function SWEP:GetGamemodeDeadPlayerData()
    if GAMEMODE.deadPlayers then return GAMEMODE.deadPlayers end
    if not CLIENT then return {} end
    return potentialResurrectionData or {}

end

function SWEP:CanResurrect( ply )
    if not IsValid( ply ) then return false end
    if not ply:IsPlayer() then return false end
    if ply:Health() > 0 then return false end
    if ply:HasEscaped() then return false end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return false end
    if owner:Health() <= 0 then return false end

    return true

end

-- the dead player whose position is nearest where we're aiming, within reviveReach
function SWEP:FindRevivable( aimTrace )
    local center = aimTrace.HitPos
    local nearest, nearestPos
    local nearestDistSqr = reviveReach^2

    for _, data in pairs( self:GetGamemodeDeadPlayerData() ) do
        if not IsValid( data.ply ) then continue end
        if not self:CanResurrect( data.ply ) then continue end

        local distSqr = data.pos:DistToSqr( center )
        if distSqr < nearestDistSqr then
            nearest, nearestPos, nearestDistSqr = data.ply, data.pos, distSqr

        end
    end

    return nearest, nearestPos

end

-- why primary found nothing to heal or revive, aimed is what the aim's line hit
local function notifyNothingToReclaim( wep, aimed )
    local notice = {
        text = "NO TISSUE FOUND",
        description = "Aim at someone hurt, or a death location.",
    }

    local living = isLiving( aimed )
    if living and not isOrganic( aimed ) then
        notice.text = "NO TISSUE DETECTED"
        notice.description = "That's a machine."

    elseif living and aimed.GetBloodColor and aimed:GetBloodColor() == DONT_BLEED then -- like floor turrets, still healable
        notice.text = "TISSUE UNCLEAR"
        notice.description = "Whatever it's made of, it's at full health."

    elseif living then
        notice.text = "TISSUE INTACT"
        if aimed:IsPlayer() then
            notice.description = "They're at full health."

        else
            notice.description = "It's at full health."

        end

    elseif IsValid( aimed ) then
        notice.text = "INCOMPATIBLE TISSUE"
        notice.description = "That can't be reclaimed."

    end

    notifyDryFire( wep, IN_ATTACK, notice )

end

-- the server judges what was clicked, and says why it failed. The client can disagree on who's healable, see PrimaryHealTarget
function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    if owner:IsPlayer() and owner:HasWeapon( "termhunt_divine_chosen" ) then
        if SERVER then
            huntersGlee_Notify( { owner }, {
                text = "Disgusting. Why would I help such a worthless being?",
                kind = "bad",
            } )
            owner:DropWeaponKeepAmmo( self )

        end
        return

    end

    local healTarget, aimTrace = self:TraceHealTarget()
    if healTarget then return end -- healing's held, see HealThink

    local toRevive, resurrectPos = self:FindRevivable( aimTrace )
    if not IsValid( toRevive ) or not owner:IsPlayer() then
        -- the server's call, it can heal what the client thinks it can't, see PrimaryHealTarget
        if SERVER then
            playServerOneShot( self, DryFireSound )
            self:PlayViewModelOnce( "fire" )
            notifyNothingToReclaim( self, aimTrace.Entity )

        end
        self:SetNextPrimaryFire( CurTime() + 0.1 )
        return

    end

    if not self:CanAffordRevive() then
        if SERVER then
            playServerSound( self, ReviveDenySound, 75, 80 )
            notifyFromServer( self, {
                text = "INSUFFICIENT RECLAMATION MATERIAL",
                description = "Complete Reclamation needs " .. self.ReviveCost .. ", " .. self:Ammo1() .. " remaining.",
                replaceKey = "glee_reclaimer_reclamation",
            } )

        end
        self:SetNextPrimaryFire( CurTime() + 0.5 )
        return

    end

    if CLIENT then return end

    self:StartResurrect( toRevive, resurrectPos )
    self:SetNextPrimaryFire( CurTime() + 0.5 )

end

hook.Add( "PlayerDeath", "glee_reclaimer_fallbackunblockswitch", function( victim )
    victim.glee_reclaimerBlocksSwitching = nil

end )

hook.Add( "PlayerSwitchWeapon", "glee_reclaimer_blockswitchwhilereviving", function( ply, _, _ )
    if not ply.glee_reclaimerBlocksSwitching then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) then return end
    if wep:GetClass() ~= CLASS then return end
    if wep.resurrecting then return true end

end )

function SWEP:StartResurrect( ent, resurrectPos )
    if not self:CanResurrect( ent ) then return end

    local owner = self:GetOwner()

    owner.glee_reclaimerBlocksSwitching = true
    self.resurrecting = true
    self.toResurrect = ent
    self.toResurrectPos = resurrectPos

    self:SetNWEntity( "RevivingTarget", ent ) -- for every client to reclaim their copy of the corpse

    self.resurrectStartPos = owner:GetPos()

    self:AttackAnim()
    clearFailedNotifies( self )

    owner:EmitSound( ReviveSound, 100, 70, 1, CHAN_STATIC, SND_NOFLAGS, 10 )

    huntersGlee_Announce( { self.toResurrect }, 5, 5, "You are being Reclaimed by " .. owner:Nick() )

end

-- a jolt of arcs on every nearby client as the revived stand up, see StartReviveJolt
-- a net message, not util.Effect, the revive's run from predicted Think, where effects skip the predicting owner
if SERVER then
    util.AddNetworkString( "glee_reclaimer_revivejolt" )

end

function SWEP:SendReviveJolt( revived )
    if not SERVER then return end

    local recipients = RecipientFilter()
    recipients:AddPVS( self:GetPos() )

    net.Start( "glee_reclaimer_revivejolt" )
        net.WriteEntity( self )
        net.WriteEntity( revived )
    net.Send( recipients )

end

function SWEP:ResurrectPly( ply )
    if not self:CanResurrect( ply ) then return end
    if not self:CanAffordRevive() then return end

    local owner = self:GetOwner()
    self:TakePrimaryAmmo( self.ReviveCost )

    owner:SetNW2Bool( "gleereclaimer_resurrected", true )

    timer.Simple( 0.1, function()
        if not IsValid( ply ) then return end
        local filterAllPlayers = RecipientFilter()
        filterAllPlayers:AddAllPlayers()
        ply:EmitSound( ReviveSound, 100, 90, 1, CHAN_STATIC, nil, nil, filterAllPlayers )
        ply:EmitSound( "ambient/levels/labs/electric_explosion1.wav", 100, 120, 1, CHAN_STATIC, nil, 10, filterAllPlayers )

    end )

    if owner.GivePlayerScore then
        local fullReward = 300
        local reward = fullReward
        local hintReward = false
        -- dont give as much score if owner killed who they reviving
        if ply:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then
            reward = 150
            if not owner.glee_InfernalReviveHint then
                owner.glee_InfernalReviveHint = true
                huntersGlee_Notify( { owner }, {
                    text = "REVIVAL PAYOUT HALVED",
                    description = "They're bound by an infernal contract.",
                    time = 6,
                } )

            end
        elseif GAMEMODE:HasSlighted( owner, ply ) >= 50 then
            reward = 150
            if not owner.glee_HomicideReviveHint then
                owner.glee_HomicideReviveHint = true
                huntersGlee_Notify( { owner }, {
                    text = "REVIVAL PAYOUT HALVED",
                    description = "You killed them.",
                    time = 6,
                } )

            end
        elseif not owner.glee_revivemoneyhint then
            owner.glee_revivemoneyhint = true
            hintReward = true -- once the repeat revive bite below is taken off

        end

        ply.glee_resurrectDecreasingScore = ply.glee_resurrectDecreasingScore or 0

        -- dont just resuurect the same person over and over!
        local rewardBite = ply.glee_resurrectDecreasingScore - CurTime()
        if rewardBite < 0 then
            rewardBite = 0

        end

        reward = math.Clamp( reward + -rewardBite, 0, 300 )
        owner:GivePlayerScore( reward )
        if hintReward then
            huntersGlee_Notify( { owner }, {
                text = "+" .. tostring( reward ) .. " score!",
                kind = "good", time = 6
            } )

        end

        -- this forgiveness cant be too high, because we dont know HOW the player died
        GAMEMODE:AddMischievousness( owner, -1, "revived a player" )

        GAMEMODE.roundExtraData.hasRevivedTbl = GAMEMODE.roundExtraData.hasRevivedTbl or {}
        if reward == fullReward and GAMEMODE:GetStoredPersistentGuilt( owner ) > 0 and not GAMEMODE.roundExtraData.hasRevivedTbl[ply] then
            GAMEMODE.roundExtraData.hasRevivedTbl[ply] = true
            GAMEMODE:IncrementPersistentGuilt( owner, -0.15, "You brought someone back.\nYour guilt barely lifts..." )

        end

        ply.glee_resurrectDecreasingScore = math.max( CurTime() + 60, ply.glee_resurrectDecreasingScore + 60 )

    end

    GAMEMODE:ForgiveKillByRevive( owner, ply )

    -- their corpse went into them. Spawning leaves a player's death ragdoll lying around otherwise
    SafeRemoveEntity( ply:GetRagdollEntity() )

    self:SendReviveJolt( ply )
    self:PlayViewModelOnce( "fire" )
    ply:Resurrect( self.toResurrectPos )
    return true

end


-- Shoving the medic ---------------------------------------------------------
-- the medic gets shoved around by the bones going in, down and away from the body
-- the server can't see the clients' corpses, so it shoves on the same schedule, for a typical one
local shoveBoneCount = 15 -- a player ragdoll's physics objects
local shoveFromFrac = 0.8 -- the bones before this are spread out enough to go in without a shove
local shoveDown = 120
local shoveAway = 60 -- keep it gentle, moving reviveReach from where the revive started cancels it
local shoveSpread = 60 -- degrees either side of straight away from the body
local shoveSounds = {
    Sound( "weapons/physcannon/superphys_small_zap1.wav" ),
    Sound( "weapons/physcannon/superphys_small_zap2.wav" ),
    Sound( "weapons/physcannon/superphys_small_zap3.wav" ),
    Sound( "weapons/physcannon/superphys_small_zap4.wav" ),
}
local shoveShakeAmp = 4
local shoveShakeRadius = 400

function SWEP:ReclaimShoves( reviveFrac )
    local dueCount = 0
    while dueCount < shoveBoneCount and boneSnapFrac( dueCount, shoveBoneCount ) <= reviveFrac do
        dueCount = dueCount + 1

    end

    -- like the corpse's cracks, bones already shoved for stay quiet through a let go and re-press
    -- less due than that, the progress bar ran out and this is a new revive
    local shoved = self.reclaimShoved or 0
    if dueCount < shoved then
        shoved = dueCount

    end

    local newShoves = 0
    for bone = shoved, dueCount - 1 do
        if boneSnapFrac( bone, shoveBoneCount ) >= shoveFromFrac then
            newShoves = newShoves + 1

        end
    end
    self.reclaimShoved = dueCount

    -- the bar moves in steps, so near the end one step can bring several bones. One shove a step
    if newShoves <= 0 then return end

    local owner = self:GetOwner()
    local away = owner:GetPos() - self.toResurrectPos
    away.z = 0
    if away:IsZero() then
        away = VectorRand()
        away.z = 0

    end
    away:Normalize()
    away:Rotate( Angle( 0, math.Rand( -shoveSpread, shoveSpread ), 0 ) )

    owner:SetVelocity( away * shoveAway + Vector( 0, 0, -shoveDown ) ) -- adds to a player's velocity
    owner:EmitSound( shoveSounds[math.random( #shoveSounds )], 75, math.random( 95, 105 ) )
    util.ScreenShake( owner:GetPos(), shoveShakeAmp, 20, 0.3, shoveShakeRadius, true )

end


-- Every tick ----------------------------------------------------------------
-- Think runs the healing and the revive, GetViewModelPosition places the viewmodel every frame

-- 0 to 1, how far the viewmodel's turned onto its medic, see GetViewModelPosition
-- its own, stepped every frame the same way, SelfAim only moves a tick at a time
function SWEP:ShownSelfAim()
    local frame = FrameNumber()
    if self.glee_selfAimFrame ~= frame then
        self.glee_selfAimFrame = frame
        self.glee_selfAimShown = stepSelfAim( self.glee_selfAimShown or 0, self:IsSelfAiming(), FrameTime() )

    end
    return math.ease.InOutSine( self.glee_selfAimShown )

end

local offsetNormal = Vector( 0, -2, 0 )
local offsetReviving = Vector( 0, -3, -1 )

function SWEP:GetViewModelPosition( pos, ang )
    local offset = offsetNormal
    if self:IsReviving() then
        offset = offsetReviving

    end
    pos = pos + offset

    local turn = self:ShownSelfAim()
    if turn > 0 then
        pos = pos + ang:Right() * selfHealShift * turn
        ang:RotateAroundAxis( ang:Up(), selfHealYaw * turn )
        ang:RotateAroundAxis( ang:Right(), -selfHealPitch * turn )

    end

    if CLIENT then
        pos, ang = self:ApplyJostle( pos, ang )

    end
    return pos, ang

end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    if owner:IsPlayer() then
        self:HealThink()
        self:UpdateViewModel()

        if SERVER then
            self:SetOutOfMaterial( self:IsOutOfMaterial() )

            -- a lag compensated trace, not every tick, it's only the prongs
            if ( self.glee_nextAimCheck or 0 ) < CurTime() then
                self.glee_nextAimCheck = CurTime() + aimCheckInterval
                self:SetAimedHealable( self:TraceHealTarget() ~= nil )

            end
        end
    end

    if self.resurrecting and IsValid( self.toResurrect ) then
        local ent = self.toResurrect
        local tooFar = self.resurrectStartPos:DistToSqr( owner:GetPos() ) > reviveReach^2
        local keyDown = owner:KeyDown( IN_ATTACK )
        local cantAfford = not self:CanAffordRevive()
        local cancel = tooFar or not keyDown or ent:Health() > 0 or cantAfford
        local done = false
        if cancel then
            done = true
            owner:EmitSound( ReviveDenySound, 75, 80 )

            -- letting go is on purpose, and getting up shows for itself
            local why = tooFar and "Tissue out of range." or cantAfford and "Insufficient reclamation material."
            if why then
                huntersGlee_Notify( { owner }, {
                    text = "REVIVAL INTERRUPTED",
                    description = why,
                    kind = "bad",
                    replaceKey = "glee_reclaimer_interrupted",
                } )

            end

        else
            local progress = generic_WaitForProgressBar( owner, "glee_resurrector", reviveBarSpeed, reviveBarChunk, nil )
            self:SetNWFloat( "RevivingProgress", progress / 100 ) -- clients reclaim the corpse off this
            self:ReclaimShoves( progress / 100 )
            if progress >= 100 then
                generic_KillProgressBar( owner, "glee_resurrector" )
                self:ResurrectPly( ent )
                done = true

            end
        end
        if done == true then
            self.toResurrectPos = nil
            self.resurrecting = nil
            self.toResurrect = nil
            self.resurrectStartPos = nil
            self:SetNWEntity( "RevivingTarget", NULL )

        end
    end
    if not ( self.resurrecting and IsValid( self.toResurrect ) ) then
        owner.glee_reclaimerBlocksSwitching = nil

    end
end


-- Hud -----------------------------------------------------------------------

if CLIENT then
    -- every dead player we could revive, nearest first
    function SWEP:RevivablesByDistance()
        local ownerPos = self:GetOwner():GetPos()
        local revivables = {}
        for _, data in ipairs( self:GetGamemodeDeadPlayerData() ) do
            if not IsValid( data.ply ) then continue end
            if not data.pos then continue end
            if not self:CanResurrect( data.ply ) then continue end
            table.insert( revivables, data )

        end

        table.sort( revivables, function( a, b )
            return ownerPos:DistToSqr( a.pos ) < ownerPos:DistToSqr( b.pos )

        end )
        return revivables

    end

    -- where ply will be revived, nil if we can't revive them
    function SWEP:RevivableData( ply )
        if not self:CanResurrect( ply ) then return end

        for _, data in ipairs( self:GetGamemodeDeadPlayerData() ) do
            if data.ply == ply and data.pos then return data end

        end
    end

    function SWEP:HintPostStack()
        local owner = self:GetOwner()

        if self:IsOutOfMaterial() then
            local msg = outOfMaterialText .. "\nBuy another Medical Tissue Reclaimer in the shop..."
            if owner:Health() >= owner:GetMaxHealth() then
                msg = msg .. "\nOr pick up some Health off the ground..."

            end
            return true, msg

        end

        -- until their first revive, a step at a time. Close enough, the beam's become a projection, see UpdateProjected
        if not owner:GetNW2Bool( "gleereclaimer_resurrected", false ) and self:CanAffordRevive() and self:RevivablesByDistance()[1] then
            if self.glee_projectedDead then
                return true, "Hold primary attack on their projection to reclaim them."

            end
            return true, "The beam leads you to a Death Location."

        end

        if not owner:GetNW2Bool( "gleereclaimer_healedself", false ) and owner:Health() < owner:GetMaxHealth() then return true, "Hold secondary attack to heal yourself!" end
        if not owner:GetNW2Bool( "gleereclaimer_healedother", false ) and #player.GetAll() > 1 then
            local players = player.GetAll()
            local canHeal
            for _, ply in ipairs( players ) do
                if ply == owner then continue end
                local theirHp = ply:Health()
                if theirHp <= 0 then continue end
                if theirHp >= ply:GetMaxHealth() then continue end
                if ply:GetPos():DistToSqr( owner:GetPos() ) > 300^2 then continue end

                canHeal = true

            end
            if canHeal then
                return true, "Hold primary attack to heal others!\nIt's much faster than healing yourself."

            end
        end
    end

    function SWEP:DrawHUD()
        if self:IsReviving() then return end

        local owner = self:GetOwner()
        if not IsValid( owner ) then return end

        if self.PaintPlyHooking then return end
        self.PaintPlyHooking = true

        local ownerWhenHookCreated = owner

        -- nameplates over every revivable dead player in range
        hook.Add( "glee_cl_shouldpaintply_whilealive", self, function( _self, ent )
            local currentOwner = self:GetOwner()
            if currentOwner ~= ownerWhenHookCreated then
                self.PaintPlyHooking = nil
                hook.Remove( "glee_cl_shouldpaintply_whilealive", self )
                return

            end
            local ownersActiveWeapon = currentOwner:GetActiveWeapon()
            if ownersActiveWeapon ~= self then
                self.PaintPlyHooking = nil
                hook.Remove( "glee_cl_shouldpaintply_whilealive", self )
                return

            end

            if ent == LocalPlayer() then return end -- spectating whoever holds it

            local deadDat = self:RevivableData( ent )
            if not deadDat then return end
            if deadDat.pos:DistToSqr( currentOwner:GetPos() ) > pointOutRange^2 then return end

            return deadDat.pos, true, true -- pos override, draw at any distance, and draw even if dead

        end )
    end
end


-- The client's half ---------------------------------------------------------
-- The kit projects the dead back up, standing where they'll be revived, built from the feet up as you close in.
-- Further away, it only points them out.
-- While someone's revived, their corpse is pulled into the projection, bone by bone.
-- Drawn for everyone who can see it held, from the viewmodel in first person, the world model otherwise.
-- Its sounds are here too, the loops and the projection's.
-- SWEP:DrawBeams, at the bottom, ties it all together.

if CLIENT then
    local beamMat = Material( "sprites/bluelaser1" )
    local glowMat = Material( "sprites/light_glow02_add" )
    local hologramMat = Material( "models/alyx/emptool_glow" ) -- additive, tinted by colour modulation, like the infernal skeleton's glow
    local reclamationColor = Color( 120, 255, 60 ) -- the canister's green
    local brokeColor = Color( 120, 120, 120 ) -- can't afford a revive
    local drawColor = Color( 0, 0, 0 )


    -- The kit's look --------------------------------------------------------
    -- a gravity gun with a health kit strapped on, see MyExtraModels in the terminator addon's readme
    -- pos and ang are local to the attachment, tune them in game, autorefresh works

    local vmKitExtras = {
        {
            model = "models/items/healthkit.mdl",
            bone = "Base", -- drawn in the viewmodel's own fov, where its attachments, moved into the world's, would be off
            pos = Vector( 0, -1, -7 ),
            ang = Angle( 120, 90, 0 ),
            scale = 0.75,
        },
        {
            model = "models/healthvial.mdl",
            bone = "Base",
            pos = Vector( 0, 0, 0 ),
            ang = Angle( 0, 0, 0 ),
            scale = 1.5,
        }
    }
    local wmKitExtras = {
        {
            model = "models/items/healthkit.mdl",
            attachment = "core",
            pos = Vector( -14, 2, 0 ),
            ang = Angle( 180, 30, -90 ),
            scale = 0.6,
        },
        {
            model = "models/healthvial.mdl",
            attachment = "core",
            pos = Vector( -12, 3, 0 ),
            ang = Angle( 90, 0, 0 ),
            scale = 0.9,
        }
    }

    -- the prongs part while there's a body to project, then spread wide as it's revived
    -- they part a little aimed at someone to heal, or turning onto the medic, and spread while healing
    -- of the way open, the "active" pose param on both models
    local prongOpenAimedHealable = 0.25
    local prongOpenProjecting = 0.35
    local prongOpenSelfAimed = 0.5
    local prongOpenHealingSelf = 0.75
    local prongOpenHealingOther = 1
    local prongOpenSpeed = 3 -- of the way open per second
    local prongShutSpeed = 1.5

    -- slams them shut, eg as the revived stand up
    function SWEP:ShutProngs()
        self.glee_prongOpen = 0

    end

    -- eases the prongs toward open or shut, once a frame, see DrawBeams
    -- reviveFrac, 0 to 1 of the way through reviving who's projected, nil when nobody is being
    function SWEP:UpdateProngs( projecting, reviveFrac, aimedHealable )
        local frame = FrameNumber()
        if self.glee_prongFrame == frame then return end
        self.glee_prongFrame = frame

        local target = 0
        if projecting then
            target = Lerp( reviveFrac or 0, prongOpenProjecting, 1 )

        end
        if aimedHealable then
            target = math.max( target, prongOpenAimedHealable )

        end
        target = math.max( target, self:ShownSelfAim() * prongOpenSelfAimed )

        local healTarget = self:GetHealTarget()
        if IsValid( healTarget ) then
            target = math.max( target, healTarget == self:GetOwner() and prongOpenHealingSelf or prongOpenHealingOther )

        end

        local open = self.glee_prongOpen or 0
        local speed = target > open and prongOpenSpeed or prongShutSpeed
        self.glee_prongOpen = math.Approach( open, target, speed * FrameTime() )

    end

    -- gmod's physgun is these same models, glowing in its owner's weapon colour
    -- so the kit draws with its own copies of their materials, glowing reclamation green, see materials/tissue_reclaimer
    -- overridden only for the draw, the viewmodel is shared with every other weapon
    -- the unlit copies are for when it's out of material
    local vmGlowMat = Material( "tissue_reclaimer/v_reclaimer_sheet" )
    local wmGlowMat = Material( "tissue_reclaimer/w_reclaimer_sheet" )
    local vmUnlitMat = Material( "tissue_reclaimer/v_reclaimer_sheet_unlit" )
    local wmUnlitMat = Material( "tissue_reclaimer/w_reclaimer_sheet_unlit" )
    local wmGlowSlots = { 0, 1 } -- w_physics's material slots that use w_physics_sheet2, on its glowing skin

    -- dropped, nobody's ammo is in it, so it glows
    function SWEP:IsGlowing()
        return not ( IsValid( self:GetOwner() ) and self:GetOutOfMaterial() )

    end

    function SWEP:DrawWorldModel( flags )
        self:SetPoseParameter( "active", self.glee_prongOpen or 0 )
        self:InvalidateBoneCache() -- the beams may have read its attachments already this frame

        local mat = self:IsGlowing() and wmGlowMat or wmUnlitMat
        for _, slot in ipairs( wmGlowSlots ) do
            render.MaterialOverrideByIndex( slot, mat )

        end
        self:DrawModel( flags )
        for _, slot in ipairs( wmGlowSlots ) do
            render.MaterialOverrideByIndex( slot, nil )

        end

        terminator_Extras.DrawMyExtraModels( self, wmKitExtras, flags )

    end

    function SWEP:PreDrawViewModel( vm )
        vm:SetPoseParameter( "active", self.glee_prongOpen or 0 )
        vm:InvalidateBoneCache() -- the beams read its attachments already this frame
        render.MaterialOverrideByIndex( 0, self:IsGlowing() and vmGlowMat or vmUnlitMat )

    end

    function SWEP:PostDrawViewModel( vm )
        render.MaterialOverrideByIndex( 0, nil )
        terminator_Extras.DrawMyExtraModels( vm, vmKitExtras )

    end


    -- Where the beams leave the kit -----------------------------------------
    -- the main beams from the barrel, the rays from the prongs' tips
    -- like the flashlight module, see cl_flashlight.lua

    local vmBeamAttachment = "muzzle"
    local wmBeamAttachment = "core"
    local vmProngTips = { "fork1t", "fork2t" }
    local wmProngTips = { "fork1t", "fork2t", "fork3t" }

    -- seeing through owner's eyes, with their viewmodel, ours or a spectated player's
    local function isSeenInFirstPerson( owner )
        local me = LocalPlayer()
        if owner == me then
            return not me:ShouldDrawLocalPlayer() and me:GetObserverMode() == OBS_MODE_NONE

        end
        return me:GetObserverMode() == OBS_MODE_IN_EYE and me:GetObserverTarget() == owner

    end

    -- the viewmodel we're seeing the kit as, nil when it's the world model
    function SWEP:SeenViewModel()
        if not isSeenInFirstPerson( self:GetOwner() ) then return end

        local vm = LocalPlayer():GetViewModel()
        if IsValid( vm ) then return vm end

    end

    -- where one of the kit's attachments is this frame, on vm, or on the world model without one
    -- a viewmodel's attachments come out already moved into the world's fov, unlike its bones
    -- only good while rendering, the viewmodel's placed for this frame by then, offsets from GetViewModelPosition and all
    -- unlike cl_flashlight.lua, which runs before that, and has to carry it to this frame's eyes
    local function getKitAttachment( wep, vm, name )
        local ent = vm or wep
        local attach = ent:GetAttachment( ent:LookupAttachment( name ) )
        if not attach then return end

        return attach.Pos, attach.Ang

    end

    -- where the beams leave the kit, and the kit's angles, for holding beams relative to it
    function SWEP:BeamStart()
        local vm = self:SeenViewModel()
        if vm then
            local pos, ang = getKitAttachment( self, vm, vmBeamAttachment )
            if pos then return pos, ang end

        end

        return getKitAttachment( self, nil, wmBeamAttachment )

    end

    -- reused by every call, only good until the next
    local prongTipPositions = {}

    -- where the rays leave, empty if none of the tips could be found
    function SWEP:ProngTips()
        local vm = self:SeenViewModel()
        local names = vm and vmProngTips or wmProngTips

        local count = 0
        for _, name in ipairs( names ) do
            local pos = getKitAttachment( self, vm, name )
            if pos then
                count = count + 1
                prongTipPositions[count] = pos

            end
        end
        for index = #prongTipPositions, count + 1, -1 do
            prongTipPositions[index] = nil

        end

        return prongTipPositions

    end


    -- Spots on a body -------------------------------------------------------
    -- a bone's position is its joint, the shoulder for an upper arm
    -- so rays and blood land somewhere inside the bone instead, in its hitbox

    -- per model, its hitboxes in list, and by the bone they're on in byBone
    -- each { bone, mins, maxs }, in the bone's own space
    local hitboxesCache = {}

    local function getHitboxes( ent )
        local mdl = ent:GetModel()
        local hitboxes = hitboxesCache[mdl]
        if hitboxes then return hitboxes end

        hitboxes = { list = {}, byBone = {} }
        local hitboxSet = 0
        for hitbox = 0, ( ent:GetHitBoxCount( hitboxSet ) or 0 ) - 1 do
            local mins, maxs = ent:GetHitBoxBounds( hitbox, hitboxSet )
            if mins then
                local box = { bone = ent:GetHitBoxBone( hitbox, hitboxSet ), mins = mins, maxs = maxs }
                table.insert( hitboxes.list, box )
                hitboxes.byBone[box.bone] = box

            end
        end

        hitboxesCache[mdl] = hitboxes
        return hitboxes

    end

    local function randomInBox( box )
        local mins, maxs = box.mins, box.maxs
        return Vector( math.Rand( mins.x, maxs.x ), math.Rand( mins.y, maxs.y ), math.Rand( mins.z, maxs.z ) )

    end

    -- somewhere inside bone, see spotPos. Its joint when it has no hitbox
    local function randomSpotOnBone( ent, bone )
        local box = getHitboxes( ent ).byBone[bone]
        return { bone = bone, offset = box and randomInBox( box ) or vector_origin }

    end

    -- somewhere inside any of ent's bones, nil if it has none
    local function randomSpot( ent )
        local list = getHitboxes( ent ).list
        if #list > 0 then
            local box = list[math.random( #list )]
            return { bone = box.bone, offset = randomInBox( box ) }

        end

        local boneCount = ent:GetBoneCount()
        if boneCount <= 0 then return end
        return { bone = math.random( 0, boneCount - 1 ), offset = vector_origin }

    end

    -- where spot is on ent right now, it moves with its bone. nil if the bone isn't set up
    local function spotPos( ent, spot )
        local matrix = ent:GetBoneMatrix( spot.bone )
        if not matrix then return end

        return LocalToWorld( spot.offset, angle_zero, matrix:GetTranslation(), matrix:GetAngles() )

    end


    -- Holding the aim to the kit --------------------------------------------
    -- each beam re-aims every few frames, and in between is held where it was, relative to the kit
    -- a still kit stays on target, a swung one throws its projection off course until it re-aims

    local reaimFrames = { 1, 3 }
    local rayCount = 5 -- the rays besides the main beam, to random spots every re-aim

    -- how far off true each aim lands, and how much the middle of a beam shakes every frame
    local jitterMin, jitterMax = 1, 2

    local function jitter()
        return VectorRand():GetNormalized() * math.Rand( jitterMin, jitterMax )

    end

    -- where dead's beams start, where their projection stands and faces, the way the beams leave the kit,
    -- and the spots on body the rays go to, see spotPos, nil without a body
    -- takes the goal, a little off, when it's time to re-aim, otherwise moves the last aim along with the kit
    function SWEP:HeldProjection( dead, kitPos, kitAng, goalPos, goalAng, goalDir, body )
        self.glee_heldProjections = self.glee_heldProjections or {}

        local held = self.glee_heldProjections[dead]
        if not held then
            held = {}
            self.glee_heldProjections[dead] = held

        end

        local frame = FrameNumber()
        if not held.start or held.nextFrame <= frame then
            held.start = jitter()
            held.pos, held.ang = WorldToLocal( goalPos + jitter(), goalAng, kitPos, kitAng )
            held.dir = WorldToLocal( goalDir, angle_zero, vector_origin, kitAng )
            held.nextFrame = frame + math.random( reaimFrames[1], reaimFrames[2] )

            held.raySpots = nil
            if body then
                held.raySpots = {}
                for ray = 1, rayCount do
                    held.raySpots[ray] = randomSpot( body ) -- nil without any bones, and the list stays empty

                end
            end
        end

        local heldStart = LocalToWorld( held.start, angle_zero, kitPos, kitAng )
        local heldPos, heldAng = LocalToWorld( held.pos, held.ang, kitPos, kitAng )
        local heldDir = LocalToWorld( held.dir, angle_zero, vector_origin, kitAng )
        return heldStart, heldPos, heldAng, heldDir, held.raySpots

    end


    -- Drawing one beam ------------------------------------------------------

    local beamSegments = 12
    local beamWidth = 3
    local rayWidth = 1.5
    local diffuseWidth = 16 --the main beam's last segment flares out to this, diffusing into the projection

    -- beams stop at the world, traced every this many segments. The curve between is checked as a straight line
    local wallCheckSegments = 2
    local splashSize = 8 -- per unit of beam width
    local wallTraceResult = {}
    local wallTrace = { mask = MASK_SOLID_BRUSHONLY, output = wallTraceResult }

    -- the clean curve, before jitter, so a beam grazing a corner doesn't flicker between cut and not
    -- reused by every beam, only the first beamPointCount are this beam's
    local beamPoints = {}
    local beamFracs = {}

    -- where a beam meets a wall, fade 0 to 1 is how faded out the beam is there, it shrinks with it
    local function drawSplash( pos, normal, color, fade, width )
        local size = width * splashSize * fade * math.Rand( 0.8, 1.2 )
        if size <= 0 then return end

        drawColor.r, drawColor.g, drawColor.b = color.r, color.g, color.b
        drawColor.a = 255 * fade
        render.SetMaterial( glowMat )
        render.DrawQuadEasy( pos + normal * 0.5, normal, size, size, drawColor, math.Rand( 0, 360 ) )
        render.DrawSprite( pos + normal * 0.75, size * 0.5, size * 0.5, drawColor )

    end

    -- leaves the kit along the aim, then bends toward endPos, or stops at a wall. Fades toward the tip, tipAlpha 1 is solid all the way
    -- tipWidth, if given, its last segment flares out to this, then tapers away into whatever's at endPos. Not at a wall
    -- bend, how far it carries on along startDir before turning, times its length. Defaults to 0.5
    -- returns whether it made it to endPos
    local function drawBeam( startPos, startDir, endPos, color, tipAlpha, alpha, width, tipWidth, bend )
        local length = startPos:Distance( endPos )
        local control = startPos + startDir * length * ( bend or 0.5 )
        local scroll = CurTime() * 2 -- material flowing out of the kit

        local beamPointCount = 0
        local hitWall = false
        local checkedPos, checkedFrac = startPos, 0
        for segment = 0, beamSegments do
            local frac = segment / beamSegments
            local point = math.QuadraticBezier( frac, startPos, control, endPos )
            beamPointCount = beamPointCount + 1
            beamPoints[beamPointCount] = point
            beamFracs[beamPointCount] = frac

            local checkHere = segment > 0 and ( segment % wallCheckSegments == 0 or segment == beamSegments )
            if checkHere then
                wallTrace.start = checkedPos
                wallTrace.endpos = point
                util.TraceLine( wallTrace )

                -- starting solid is the kit pushed into a wall, let the beam out rather than cut it at the kit
                if wallTraceResult.Hit and not wallTraceResult.StartSolid then
                    -- the trace spans more than one segment, drop the points already past the wall
                    local cutFrac = Lerp( wallTraceResult.Fraction, checkedFrac, frac )
                    while beamPointCount > 1 and beamFracs[beamPointCount] >= cutFrac do -- the kit's point always stays
                        beamPointCount = beamPointCount - 1

                    end

                    beamPointCount = beamPointCount + 1
                    beamPoints[beamPointCount] = wallTraceResult.HitPos
                    beamFracs[beamPointCount] = cutFrac
                    hitWall = true
                    break

                end
                checkedPos, checkedFrac = point, frac

            end
        end

        -- the flared last segment is its own beam. Widening one point of a beam twists it into a ribbon
        local flaring = tipWidth and not hitWall and beamPointCount > 2
        local thinCount = flaring and beamPointCount - 1 or beamPointCount

        drawColor.r, drawColor.g, drawColor.b = color.r, color.g, color.b
        render.SetMaterial( beamMat )
        render.StartBeam( thinCount )
        local point, frac
        for index = 1, thinCount do
            point = beamPoints[index]
            frac = beamFracs[index]
            if index > 1 and index < beamPointCount then
                point = point + jitter() -- the ends stay put, on the kit and on the body or wall

            end

            drawColor.a = 255 * alpha * ( 1 - frac * ( 1 - tipAlpha ) )
            render.AddBeam( point, width, frac * length / 32 - scroll, drawColor )

        end
        render.EndBeam()

        if flaring then
            local tipFrac = beamFracs[beamPointCount]
            render.StartBeam( 2 )
            render.AddBeam( point, tipWidth, frac * length / 32 - scroll, drawColor )
            drawColor.a = 255 * alpha * ( 1 - tipFrac * ( 1 - tipAlpha ) )
            render.AddBeam( beamPoints[beamPointCount], 0, tipFrac * length / 32 - scroll, drawColor ) -- tapering away into it
            render.EndBeam()

        end

        if hitWall then
            drawSplash( beamPoints[beamPointCount], wallTraceResult.HitNormal, color, drawColor.a / 255, width )

        end
        return not hitWall

    end


    -- Arcs ------------------------------------------------------------------
    -- material jolting out of the kit, where the tissue goes back in hard. See eff_term_goodarc in the terminator addon

    local arcColor = Angle( reclamationColor.r, reclamationColor.g, reclamationColor.b )

    local ARC_NO_LIGHT = 1
    local ARC_NO_SOUND = 16
    local ARC_PASS_WORLD = 32
    local ARC_NO_DECAL = 128

    -- leaves along startDir, then turns onto endPos
    -- flags, eff_term_goodarc's. The kit's own sounds and lights are usually enough, so most arcs pass ARC_NO_SOUND and ARC_NO_LIGHT
    local function reclamationArc( startPos, startDir, endPos, scale, flags )
        -- every setting set, see eff_term_goodarc
        local fx = EffectData()
            fx:SetOrigin( startPos )
            fx:SetStart( endPos )
            fx:SetNormal( startDir )
            fx:SetScale( scale )
            fx:SetMagnitude( 8 ) -- segments
            fx:SetRadius( 6 * scale ) -- jitter
            fx:SetAngles( arcColor )
            fx:SetDamageType( 2 ) -- branches
            fx:SetEntity( NULL )
            fx:SetFlags( flags )
        util.Effect( "eff_term_goodarc", fx )

    end


    -- The projection --------------------------------------------------------

    local beamUp = Vector( 0, 0, 24 ) -- dead positions are on the floor, pointers aim this far above them
    local reachingDist = 300 -- closer than this, the nearest is projected
    local pointerLength = 80 -- pointers shorten toward this as they get further. Past pointOutRange, only the nearest gets one
    local unprojectSlack = 50 -- once projected, stays so until this much past reachingDist, so the edge doesn't restart the build
    local buildTime = 0.8 -- seconds the projection takes to build from the feet up, once it starts

    -- cowering, they were just hunted down. By activity, custom player models name their sequences all sorts
    local hologramAct = ACT_HL2MP_IDLE_SCARED
    local hologramFallbackPose = "idle_all_01"
    local centerBone = "ValveBiped.Bip01_Spine2" -- the main beam lands here

    -- who this kit projects, since when, for the build, and which way they cower. Its nearest, once they're within reachingDist
    -- a new nearest, or walking out and back in, starts the build over
    function SWEP:UpdateProjected( nearest, ownerPos )
        local projectDist = reachingDist
        if nearest and nearest.ply == self.glee_projectedDead then
            projectDist = reachingDist + unprojectSlack

        end

        if not nearest or ownerPos:Distance( nearest.pos ) > projectDist then
            self.glee_projectedDead = nil
            return

        end

        if self.glee_projectedDead ~= nearest.ply then
            self.glee_projectedDead = nearest.ply
            self.glee_projectStart = CurTime()
            self.glee_projectAng = Angle( 0, math.Rand( 0, 360 ), 0 )

        end
    end

    -- each kit only projects its nearest, so it keeps one model, made over into whoever that is
    -- removed in OnRemove
    function SWEP:GetHologram( dead )
        local holo = self.glee_hologram
        if not IsValid( holo ) then
            holo = ClientsideModel( dead:GetModel(), RENDERGROUP_TRANSLUCENT )
            if not IsValid( holo ) then return end

            holo:SetNoDraw( true )
            self.glee_hologram = holo

        end

        local mdl = dead:GetModel()
        if holo.glee_dead == dead and holo:GetModel() == mdl then return holo end

        holo.glee_dead = dead
        holo:SetModel( mdl )
        holo:SetSkin( dead:GetSkin() )
        for _, bodyGroup in pairs( dead:GetBodyGroups() ) do
            holo:SetBodygroup( bodyGroup.id, dead:GetBodygroup( bodyGroup.id ) )

        end

        local pose = holo:SelectWeightedSequence( hologramAct )
        if pose < 0 then
            pose = holo:LookupSequence( hologramFallbackPose )

        end
        if pose >= 0 then
            holo:ResetSequence( pose )

        end

        local _, maxs = holo:GetModelBounds()
        holo.glee_height = maxs.z

        return holo

    end

    -- before reading its bones or drawing it
    local function poseHologram( holo, pos, ang )
        holo:SetPos( pos )
        holo:SetAngles( ang )
        holo:FrameAdvance() -- by the time since it last advanced, so drawing it in more than one view a frame doesn't speed it up
        holo:SetupBones() -- bones are stale after moving it

    end

    local function getBonePos( holo, boneId )
        if not boneId then return end

        local matrix = holo:GetBoneMatrix( boneId )
        if not matrix then return end

        return matrix:GetTranslation()

    end

    -- posed at pos and ang by poseHologram
    -- built 0 to 1, how far up from the feet it's been built, a line glows across the build
    -- returns how high it's built
    local function drawHologram( holo, pos, ang, color, built, bright )
        local up = ang:Up()
        local builtHeight = holo.glee_height * built

        local building = built < 1
        local oldClipping
        if building then
            -- keeps what's below the build line
            oldClipping = render.EnableClipping( true )
            local normal = -up
            render.PushCustomClipPlane( normal, normal:Dot( pos + up * builtHeight ) )

        end

        render.MaterialOverride( hologramMat )
        render.SetColorModulation( color.r / 255 * bright, color.g / 255 * bright, color.b / 255 * bright )
        holo:DrawModel()
        render.SetColorModulation( 1, 1, 1 )
        render.MaterialOverride( nil )

        if building then
            render.PopCustomClipPlane()
            render.EnableClipping( oldClipping )

            local scanPos = pos + up * builtHeight
            drawColor.r, drawColor.g, drawColor.b = color.r, color.g, color.b
            drawColor.a = 255 * bright
            render.SetMaterial( glowMat )
            -- quads are one sided, so one facing each way
            render.DrawQuadEasy( scanPos, up, 48, 48, drawColor )
            render.DrawQuadEasy( scanPos, -up, 48, 48, drawColor )

        end

        return builtHeight

    end


    -- Recoil ----------------------------------------------------------------
    -- the kit twitches in the medic's hands every time a bone goes in, a touch on top of the server's shoves
    -- only the viewmodel twitches, see GetViewModelPosition

    local jostleDecay = 8 -- how fast a kick settles, per second
    local jostleKickPos = 0.4 -- units, along the viewmodel's own axes
    local jostleKickAng = 1.5 -- degrees

    -- what's left of every kick so far, nil before the first
    function SWEP:CurrentJostle()
        local jostlePos = self.glee_jostlePos
        if not jostlePos then return end

        local left = math.exp( -( CurTime() - self.glee_jostleTime ) * jostleDecay )
        return jostlePos * left, self.glee_jostleAng * left

    end

    function SWEP:Jostle()
        local jostlePos, jostleAng = self:CurrentJostle()
        jostlePos = jostlePos or Vector( 0, 0, 0 )
        jostleAng = jostleAng or Angle( 0, 0, 0 )

        local kickAng = Angle( math.Rand( -1, 1 ), math.Rand( -1, 1 ), math.Rand( -1, 1 ) ) * jostleKickAng
        self.glee_jostlePos = jostlePos + VectorRand() * jostleKickPos
        self.glee_jostleAng = jostleAng + kickAng
        self.glee_jostleTime = CurTime()

    end

    function SWEP:ApplyJostle( pos, ang )
        local jostlePos, jostleAng = self:CurrentJostle()
        if not jostlePos then return pos, ang end

        return LocalToWorld( jostlePos, jostleAng, pos, ang )

    end


    -- Reclaiming the corpse -------------------------------------------------
    -- while being revived, the corpse is pulled into the projection a bone at a time, each frozen there with a crack, see boneSnapFrac
    -- like cl_souls, ragdoll bones are moved through their physics objects
    -- every client reclaims its own copy of the corpse, so a corpse's progress is kept on it, shared by every kit reviving it

    local boneBreakSounds = {
        Sound( "physics/body/body_medium_break2.wav" ),
        Sound( "physics/body/body_medium_break3.wav" ),
        Sound( "physics/body/body_medium_break4.wav" ),
    }
    local fleshSounds = {
        Sound( "physics/flesh/flesh_squishy_impact_hard1.wav" ),
        Sound( "physics/flesh/flesh_squishy_impact_hard2.wav" ),
        Sound( "physics/flesh/flesh_squishy_impact_hard3.wav" ),
        Sound( "physics/flesh/flesh_squishy_impact_hard4.wav" ),
    }

    -- with no kit reviving it for this long, the corpse is let go. Covers a cancelled revive, and a kit we stopped seeing
    local reclaimHoldTime = 0.25
    local reclaimedRagdolls = setmetatable( {}, { __mode = "k" } )
    local fakeCorpses = setmetatable( {}, { __mode = "k" } ) -- to the dead player each stands in for

    -- freezes one of the corpse's physics objects onto the hologram's matching bone, returns whether it could
    local function moveBoneToHologram( rag, holo, boneIndex )
        local ragsObj = rag:GetPhysicsObjectNum( boneIndex )
        if not IsValid( ragsObj ) then return false end

        local matrix = holo:GetBoneMatrix( rag:TranslatePhysBoneToBone( boneIndex ) )
        if not matrix then return false end

        ragsObj:EnableMotion( false )
        ragsObj:SetPos( matrix:GetTranslation() )
        ragsObj:SetAngles( matrix:GetAngles() )
        return true

    end


    -- Fake corpses ----------------------------------------------------------
    -- a fake corpse's bones grow back in groups, one per physics object, with the bones that ride on it, eg fingers
    -- physics object index -> the bones in its group, per model
    local growGroupsCache = {}

    local function getGrowGroups( fake )
        local mdl = fake:GetModel()
        local groups = growGroupsCache[mdl]
        if groups then return groups end

        groups = {}
        for bone = 0, fake:GetBoneCount() - 1 do
            local physIndex = math.max( fake:TranslateBoneToPhysBone( bone ), 0 ) -- bones on no physics object grow with the root
            groups[physIndex] = groups[physIndex] or {}
            table.insert( groups[physIndex], bone )

        end

        growGroupsCache[mdl] = groups
        return groups

    end

    -- grown 0 to 1, of the scale the dead player has that bone at, their own model so the bones line up
    local function scaleGrowGroup( fake, physIndex, grown )
        local group = getGrowGroups( fake )[physIndex]
        if not group then return end

        local dead = fake:GetOwner()
        if not IsValid( dead ) then return end

        for _, bone in ipairs( group ) do
            fake:ManipulateBoneScale( bone, dead:GetManipulateBoneScale( bone ) * grown )

        end
    end

    -- eases each group in from when it started growing, see fakeCorpseGrowTime
    local fakeCorpseGrowTime = 0.15

    local function growFakeCorpse( fake, finishNow )
        local growStarts = fake.glee_growStarts
        if not growStarts then return end

        local now = CurTime()
        for physIndex, started in pairs( growStarts ) do
            local grown = finishNow and 1 or math.Clamp( ( now - started ) / fakeCorpseGrowTime, 0, 1 )
            scaleGrowGroup( fake, physIndex, grown )
            if grown >= 1 then
                growStarts[physIndex] = nil

            end
        end
    end

    -- for players with nothing left to reclaim, dissolved, gibbed, or just gone, a stand in that's grown back instead
    -- set up like cl_souls' souls, kept on the dead player so every kit shares it
    local function getFakeCorpse( dead, holo )
        local mdl = dead:GetModel()
        local fake = dead.glee_reclaimerFakeCorpse
        if IsValid( fake ) and fake:GetModel() == mdl then
            -- an autorefresh empties fakeCorpses but leaves the fake on the player, and unlisted it'd be treated as a real corpse
            fakeCorpses[fake] = dead
            return fake

        end

        SafeRemoveEntity( fake )

        fake = ClientsideRagdoll( mdl, RENDERGROUP_OPAQUE )
        if not IsValid( fake ) then return end

        fake:SetOwner( dead )
        fake:SetSkin( dead:GetSkin() )
        for _, bodyGroup in pairs( dead:GetBodyGroups() ) do
            fake:SetBodygroup( bodyGroup.id, dead:GetBodygroup( bodyGroup.id ) )

        end

        function fake.GetPlayerColor( self )
            local owner = self:GetOwner()
            if not IsValid( owner ) then return vector_origin end

            return owner:GetPlayerColor()

        end

        -- nothing there until it's grown, frozen on the projection to grow from
        for physIndex in pairs( getGrowGroups( fake ) ) do
            scaleGrowGroup( fake, physIndex, 0 )

        end
        for boneIndex = 0, fake:GetPhysicsObjectCount() - 1 do
            moveBoneToHologram( fake, holo, boneIndex )

        end

        fake:SetNoDraw( false )

        fake.glee_grown = {} -- physics object indexes whose groups have been grown
        fakeCorpses[fake] = dead
        dead.glee_reclaimerFakeCorpse = fake
        dead:CallOnRemove( "glee_reclaimerfakecorpse", function( ent )
            SafeRemoveEntity( ent.glee_reclaimerFakeCorpse )

        end )

        return fake

    end

    -- what's left of them to reclaim, or a fake corpse to grow when nothing is
    -- nil when there's a ragdoll that won't line up with the projection
    local function getCorpse( dead, holo )
        local rag = dead:GetRagdollEntity()
        if IsValid( rag ) then
            if rag:GetModel() ~= holo:GetModel() then return end
            return rag

        end

        return getFakeCorpse( dead, holo )

    end


    -- The order bones go in -------------------------------------------------
    -- see newReclaimOrder
    -- each physics object's parent, the one it hangs off, -1 for the root. Per model
    local physParentsCache = {}

    local function getPhysParents( rag )
        local mdl = rag:GetModel()
        local parents = physParentsCache[mdl]
        if parents then return parents end

        parents = {}
        for physIndex = 0, rag:GetPhysicsObjectCount() - 1 do
            parents[physIndex] = -1

            -- up the skeleton, past bones with no physics object of their own, eg a clavicle
            local bone = rag:GetBoneParent( rag:TranslatePhysBoneToBone( physIndex ) )
            while bone >= 0 do
                local parentPhys = rag:TranslateBoneToPhysBone( bone )
                if parentPhys >= 0 and parentPhys ~= physIndex then
                    parents[physIndex] = parentPhys
                    break

                end
                bone = rag:GetBoneParent( bone )

            end
        end

        physParentsCache[mdl] = parents
        return parents

    end

    -- the physics objects, starting from startIndex and spreading out along the skeleton, a random way each time
    -- a list, the first to go in first
    local function spreadingOrder( rag, startIndex )
        local parents = getPhysParents( rag )
        local count = rag:GetPhysicsObjectCount()
        local order = {}
        local ordered = {}
        local frontier = { startIndex }

        while #frontier > 0 do
            local physIndex = table.remove( frontier, math.random( #frontier ) )
            if not ordered[physIndex] then
                ordered[physIndex] = true
                table.insert( order, physIndex )

                for other = 0, count - 1 do
                    local touching = parents[other] == physIndex or parents[physIndex] == other
                    if touching and not ordered[other] then
                        table.insert( frontier, other )

                    end
                end
            end
        end

        -- any the skeleton didn't join up
        for physIndex = 0, count - 1 do
            if not ordered[physIndex] then
                table.insert( order, physIndex )

            end
        end

        return order

    end

    -- a real corpse starts anywhere, a hand, a foot, its head. A fake one grows out from the torso
    local function newReclaimOrder( rag )
        if fakeCorpses[rag] then
            return spreadingOrder( rag, 0 )

        end
        return spreadingOrder( rag, math.random( 0, rag:GetPhysicsObjectCount() - 1 ) )

    end


    -- Letting go ------------------------------------------------------------
    -- frozen physics objects are stubborn, they need waking as well as unfreezing, like cl_souls does
    local function releaseRagdoll( rag )
        -- a fake corpse's ungrown bones are frozen from the start, and would hold up the grown ones
        local releasing = {}
        if fakeCorpses[rag] then
            for physIndex = 0, rag:GetPhysicsObjectCount() - 1 do
                table.insert( releasing, physIndex )

            end
            growFakeCorpse( rag, true ) -- nobody's growing it now

        else
            local order = rag.glee_reclaimOrder or {}
            for pos = 1, rag.glee_reclaimNextBone or 0 do
                table.insert( releasing, order[pos] )

            end
        end

        for _, physIndex in ipairs( releasing ) do
            local ragsObj = rag:GetPhysicsObjectNum( physIndex )
            if IsValid( ragsObj ) then
                ragsObj:EnableMotion( true )
                ragsObj:Wake()

            end
        end

        rag.glee_reclaimNextBone = nil

    end

    hook.Add( "Think", "glee_reclaimer_releasecorpses", function()
        -- fake corpses go once who they stood in for is up again
        for fake, dead in pairs( fakeCorpses ) do
            if not IsValid( fake ) then
                fakeCorpses[fake] = nil

            elseif not IsValid( dead ) or dead:Health() > 0 then
                fake:Remove()
                fakeCorpses[fake] = nil

            end
        end

        if not next( reclaimedRagdolls ) then return end

        local now = CurTime()
        for rag in pairs( reclaimedRagdolls ) do
            if not IsValid( rag ) then
                reclaimedRagdolls[rag] = nil

            elseif rag.glee_reclaimHeldUntil < now then
                releaseRagdoll( rag )
                reclaimedRagdolls[rag] = nil

            end
        end
    end )


    -- Tendrils --------------------------------------------------------------
    -- the kit reaches for the next few bones due with tendrils, and drags them in, see drawTendrils
    -- a visual flourish, the server knows nothing of them
    local tendrilCount = 3
    local tendrilWindow = 0.25 -- of the revive, before its bone goes in, a tendril tightens from faint to taut
    local tendrilFaintest = 0.15 -- alpha, the furthest from going in
    local tendrilWidth = 1
    local tendrilWrithe = 6 -- how fast they writhe

    -- whether the bone at pos in rag's reclaim order has a tendril on it
    -- a fake corpse has none, only grown bones an interrupted revive left loose get dragged back
    local function hasTendril( rag, pos, reclaimedCount )
        if pos <= reclaimedCount or pos > reclaimedCount + tendrilCount then return false end
        if not fakeCorpses[rag] then return true end

        return rag.glee_grown[rag.glee_reclaimOrder[pos]] == true

    end

    -- the bones not in yet drift toward their spots on the projection, harder the further the revive's got
    -- the ones with tendrils on are dragged, the rest barely move
    local pullRate = 3 -- at the end of the revive, the share of the way to its spot a loose bone is sent per second
    local tendrilPull = 3 -- times pullRate, a bone with a tendril on
    local looseBonePull = 0.3 -- times pullRate, the rest
    local pullSteer = 8 -- how quickly a loose bone's velocity turns toward that, per second

    -- the bones in rag's reclaim order after reclaimedCount
    local function pullLooseBones( rag, holo, reclaimedCount, reviveFrac )
        local frame = FrameNumber()
        if rag.glee_reclaimPullFrame == frame then return end -- drawn in more than one view, don't pull twice
        rag.glee_reclaimPullFrame = frame

        local steer = math.min( pullSteer * FrameTime(), 1 )
        local order = rag.glee_reclaimOrder
        for pos = reclaimedCount + 1, #order do
            local physIndex = order[pos]
            local ragsObj = rag:GetPhysicsObjectNum( physIndex )
            local matrix = IsValid( ragsObj ) and holo:GetBoneMatrix( rag:TranslatePhysBoneToBone( physIndex ) )
            if matrix then
                local pull = hasTendril( rag, pos, reclaimedCount ) and tendrilPull or looseBonePull
                local wanted = ( matrix:GetTranslation() - ragsObj:GetPos() ) * pullRate * pull * reviveFrac
                ragsObj:Wake()
                ragsObj:SetVelocity( LerpVector( steer, ragsObj:GetVelocity(), wanted ) )

            end
        end
    end

    -- from the prongs to the bones with tendrils on, see hasTendril. Stopped by walls like the beams
    local function drawTendrils( wep, rag, reclaimedCount, reviveFrac )
        local startPos, kitAng = wep:BeamStart()
        if not startPos then return end

        local startDir = kitAng:Forward()
        local tips = wep:ProngTips()
        local order = rag.glee_reclaimOrder
        local boneCount = #order
        rag.glee_tendrilSpots = rag.glee_tendrilSpots or {} -- where on each bone its tendril grabs, kept so it doesn't jump

        for pos = reclaimedCount + 1, math.min( reclaimedCount + tendrilCount, boneCount ) do
            if not hasTendril( rag, pos, reclaimedCount ) then continue end

            local physIndex = order[pos]
            local spot = rag.glee_tendrilSpots[physIndex]
            if not spot then
                spot = randomSpotOnBone( rag, rag:TranslatePhysBoneToBone( physIndex ) )
                rag.glee_tendrilSpots[physIndex] = spot

            end

            local endPos = spotPos( rag, spot )
            if endPos then
                local untilIn = boneSnapFrac( pos - 1, boneCount ) - reviveFrac
                local taut = math.Clamp( 1 - untilIn / tendrilWindow, tendrilFaintest, 1 )
                local bend = 0.35 + 0.25 * math.sin( CurTime() * tendrilWrithe + pos )
                local tip = tips[( pos - 1 ) % math.max( #tips, 1 ) + 1] or startPos
                drawBeam( tip, startDir, endPos, reclamationColor, 1, taut, tendrilWidth * ( 0.5 + taut ), nil, bend )

            end
        end
    end


    -- Bones going in --------------------------------------------------------
    -- the last stretch of bones go in with an arc from the prongs, building up to the jolt when they stand, see StartReviveJolt
    local snapArcFrac = 0.85 -- of the way through the revive, bones going in after this arc

    -- a bone of boneCount going in at bonePos, bleeds, kicks the kit, and arcs to it if it's late enough
    local function boneGoesIn( wep, bonePos, boneIndex, boneCount )
        local blood = EffectData()
        blood:SetOrigin( bonePos )
        blood:SetColor( BLOOD_COLOR_RED )
        blood:SetNormal( VectorRand() )
        util.Effect( "BloodImpact", blood )

        wep:Jostle()
        if boneSnapFrac( boneIndex, boneCount ) < snapArcFrac then return end

        local tips = wep:ProngTips()
        local tip = tips[math.random( math.max( #tips, 1 ) )]
        if not tip then return end

        reclamationArc( tip, ( bonePos - tip ):GetNormalized(), bonePos, 0.4, ARC_NO_SOUND + ARC_NO_LIGHT + ARC_NO_DECAL + ARC_PASS_WORLD )

    end

    -- call every frame the revive goes on, even once every bone's in, or the corpse is let go
    -- reviveFrac is 0 to 1 of the way through the revive, every bone due by then goes in, jostling wep
    local function reclaimBones( wep, dead, holo, reviveFrac )
        local rag = getCorpse( dead, holo )
        if not rag then return end -- the revive carries on without one

        local isFake = fakeCorpses[rag] ~= nil
        if isFake then
            growFakeCorpse( rag )

        end

        rag.glee_reclaimHeldUntil = CurTime() + reclaimHoldTime
        reclaimedRagdolls[rag] = true

        local reclaimedCount = rag.glee_reclaimNextBone or 0
        local boneCount = rag:GetPhysicsObjectCount()
        local dueCount = 0
        while dueCount < boneCount and boneSnapFrac( dueCount, boneCount ) <= reviveFrac do
            dueCount = dueCount + 1

        end

        -- bones already cracked once this revive go back in quietly, after a let go and re-press
        -- less due than that, the progress bar ran out and this is a new revive
        local crackedCount = rag.glee_reclaimCracked or 0
        if dueCount < crackedCount then
            crackedCount = 0

        end

        -- a new revive picks a new start, as its first bone goes in. A re-press keeps the one it had
        local startsOver = reclaimedCount == 0 and crackedCount == 0 and dueCount > 0
        if startsOver or not rag.glee_reclaimOrder then
            rag.glee_reclaimOrder = newReclaimOrder( rag )

        end
        local order = rag.glee_reclaimOrder

        -- the projection swings with the kit, so the bones already in follow it, not where it was when they went in
        for pos = 1, reclaimedCount do
            moveBoneToHologram( rag, holo, order[pos] )

        end

        -- near the end, a frame can be late for more than one
        while reclaimedCount < dueCount do
            local physIndex = order[reclaimedCount + 1]
            local bonePos -- somewhere inside the bone, where it cracks and bleeds
            if moveBoneToHologram( rag, holo, physIndex ) then
                local bone = rag:TranslatePhysBoneToBone( physIndex )
                bonePos = spotPos( holo, randomSpotOnBone( holo, bone ) )

            end

            -- a fake's groups grow the first time they go in, and stay grown, even through a whole new revive
            local growsNow = bonePos and isFake and not rag.glee_grown[physIndex]
            if growsNow then
                rag.glee_grown[physIndex] = true
                rag.glee_growStarts = rag.glee_growStarts or {}
                rag.glee_growStarts[physIndex] = CurTime()
                sound.Play( fleshSounds[math.random( #fleshSounds )], bonePos, 70, math.random( 90, 110 ) )
                boneGoesIn( wep, bonePos, reclaimedCount, boneCount )

            elseif bonePos and reclaimedCount >= crackedCount then
                sound.Play( boneBreakSounds[math.random( #boneBreakSounds )], bonePos, 70, math.random( 90, 110 ) )
                boneGoesIn( wep, bonePos, reclaimedCount, boneCount )

            end
            reclaimedCount = reclaimedCount + 1

        end

        rag.glee_reclaimNextBone = reclaimedCount
        rag.glee_reclaimCracked = math.max( crackedCount, reclaimedCount )

        pullLooseBones( rag, holo, reclaimedCount, reviveFrac )
        drawTendrils( wep, rag, reclaimedCount, reviveFrac )

    end


    -- The revive's jolt -----------------------------------------------------
    -- arcs into the projection's chest as the revived stand up, see SendReviveJolt

    -- the projection's chest, where they're about to stand. nil if this kit wasn't projecting them
    function SWEP:ProjectedChest( dead )
        local holo = self.glee_hologram
        if not IsValid( holo ) or holo.glee_dead ~= dead then return end

        return getBonePos( holo, holo:LookupBone( centerBone ) )

    end

    function SWEP:StartReviveJolt( revived )
        self:ShutProngs() -- spread wide all revive, they slam shut as the jolt goes in

        local startPos, kitAng = self:BeamStart()
        if not startPos then return end

        local chest = self:ProjectedChest( revived )
        if not chest then return end

        -- one arc carries the sound and light, the rest would only stack them
        local barrelDir = kitAng:Forward()
        reclamationArc( startPos, barrelDir, chest, 1.5, ARC_PASS_WORLD + ARC_NO_DECAL )
        for _, tip in ipairs( self:ProngTips() ) do
            reclamationArc( tip, barrelDir, chest, 1, ARC_NO_SOUND + ARC_NO_LIGHT + ARC_PASS_WORLD + ARC_NO_DECAL )

        end
    end

    net.Receive( "glee_reclaimer_revivejolt", function()
        local wep = net.ReadEntity()
        local revived = net.ReadEntity()
        if not IsValid( wep ) or not IsValid( revived ) then return end
        if not wep.StartReviveJolt then return end -- not a kit, the index went to something else on our end

        wep:StartReviveJolt( revived )

    end )


    -- The healing's beams ---------------------------------------------------
    -- held on whoever the kit's healing, see HealTarget
    -- healing others is clean, every ray lands on them
    -- healing yourself isn't, the kit has to turn its beams back on its own medic, and most of the material splashes on the floor

    local healFadeIn = 0.1 -- seconds
    local healFadeOut = 0.25
    local healReaimInterval = 0.12 -- seconds between picking new bones and spill points for the rays
    local healRayCount = 4
    local healOtherStrength = 2.5 -- times the beams' usual widths, healing someone else pours far more material
    local healSelfBend = 1 -- see drawBeam, the kit isn't built to point at its own medic
    local spillCount = 4 -- a self heal's rays that miss, onto the floor around them
    local spillRadiusMin, spillRadiusMax = 24, 64
    local spillTraceUp = Vector( 0, 0, 32 )
    local spillTraceDown = Vector( 0, 0, -96 )

    -- somewhere on the floor around pos, just under it, so a beam to it splashes there. nil when there's no floor
    local function spillPoint( pos )
        local offset = VectorRand()
        offset.z = 0
        offset:Normalize()

        local from = pos + offset * math.Rand( spillRadiusMin, spillRadiusMax ) + spillTraceUp
        local tr = util.TraceLine( { start = from, endpos = from + spillTraceDown, mask = MASK_SOLID_BRUSHONLY } )
        if not tr.Hit or tr.StartSolid then return end

        return tr.HitPos - tr.HitNormal * 2

    end

    -- new spots for the rays healing others, new spill points healing yourself
    local function reaimHealing( healing, isSelf )
        healing.nextReaim = CurTime() + healReaimInterval
        healing.raySpots = {}
        healing.spills = {}

        local healTarget = healing.healTarget
        if isSelf then
            for _ = 1, spillCount do
                local spill = spillPoint( healTarget:GetPos() )
                if spill then
                    table.insert( healing.spills, spill )

                end
            end
            return

        end

        for ray = 1, healRayCount do
            healing.raySpots[ray] = randomSpot( healTarget ) -- nil without any bones, and the list stays empty

        end
    end

    -- from DrawBeams, fades in on someone new, and out for a moment after the healing stops
    -- barrelDir, the way the beams leave the muzzle
    function SWEP:DrawHealing( startPos, barrelDir )
        local healTarget = self:GetHealTarget()
        local healing = self.glee_healing

        if IsValid( healTarget ) then
            if not healing or healing.healTarget ~= healTarget then
                healing = { healTarget = healTarget, alpha = 0, nextReaim = 0 }
                self.glee_healing = healing

            end
            healing.alpha = math.min( healing.alpha + FrameTime() / healFadeIn, 1 )

        elseif healing then
            healing.alpha = healing.alpha - FrameTime() / healFadeOut

        end

        if not healing then return end
        healTarget = healing.healTarget
        if healing.alpha <= 0 or not IsValid( healTarget ) then
            self.glee_healing = nil
            return

        end

        local isSelf = healTarget == self:GetOwner()
        if healing.nextReaim <= CurTime() then
            reaimHealing( healing, isSelf )

        end

        local alpha = healing.alpha
        local tips = self:ProngTips()
        local tipCount = math.max( #tips, 1 )
        local chest = healTarget:WorldSpaceCenter()

        if not isSelf then
            drawBeam( startPos, barrelDir, chest, reclamationColor, 1, alpha, beamWidth * healOtherStrength, diffuseWidth * healOtherStrength )
            for ray, spot in ipairs( healing.raySpots ) do
                local rayEnd = spotPos( healTarget, spot )
                if rayEnd then
                    drawBeam( tips[( ray - 1 ) % tipCount + 1] or startPos, barrelDir, rayEnd, reclamationColor, 1, alpha, rayWidth * healOtherStrength )

                end
            end
            return

        end

        -- out of the barrel, turned onto the medic, then hooking back onto them, the rest spill
        drawBeam( startPos, barrelDir, chest, reclamationColor, 1, alpha, beamWidth, nil, healSelfBend )
        for spill, spillPos in ipairs( healing.spills ) do
            drawBeam( tips[( spill - 1 ) % tipCount + 1] or startPos, barrelDir, spillPos, reclamationColor, 1, 0.5 * alpha, rayWidth, nil, healSelfBend )

        end
    end


    -- The loops -------------------------------------------------------------
    -- while the kit's reviving, or healing, off the networked RevivingTarget and HealTarget
    -- clientside like the heavy turret's, a serverside loop only reaches whoever was in earshot when it started
    -- a loop nobody stops plays forever, so every way a kit can go quiet stops them:
    -- nothing to do, going dormant, put away, its holder gone, removed. See the sweep below, ShutDown and OnRemove

    local reviveLoops = {
        { path = "items/medcharge4.wav", level = 75, volume = 1 },
    }
    local healLoops = {
        { path = "items/medcharge4.wav", level = 70, volume = 0.7 },
        { path = "weapons/physcannon/hold_loop.wav", level = 70, volume = 0.6 },
    }
    local loopPitch = 100
    local healSelfLoopPitch = 85 -- the kit straining, turned back on its medic
    local loopPitchTime = 0.2 -- seconds sliding between pitches
    local loopCheckInterval = 0.1

    function SWEP:StopLoopSounds()
        if not self.glee_loopSounds then return end

        for _, loop in ipairs( self.glee_loopSounds ) do
            loop:Stop()

        end
        self.glee_loopSounds = nil
        self.glee_loopSet = nil
        self.glee_loopPitch = nil

    end

    -- which loops should be going, and at what pitch. nil when none should
    function SWEP:WantedLoops()
        if self:IsDormant() then return end
        if self:IsReviving() then return reviveLoops, loopPitch end

        local healTarget = self:GetHealTarget()
        if not IsValid( healTarget ) then return end

        return healLoops, healTarget == self:GetOwner() and healSelfLoopPitch or loopPitch

    end

    -- restarted whenever one's not playing, the engine drops loops out from under us, stopsound and the like
    function SWEP:UpdateLoopSounds()
        local loopSet, pitch = self:WantedLoops()
        if not loopSet then
            self:StopLoopSounds()
            return

        end

        local sounds = self.glee_loopSounds
        local playing = sounds ~= nil and self.glee_loopSet == loopSet
        for _, loop in ipairs( sounds or {} ) do
            if not loop:IsPlaying() then
                playing = false

            end
        end

        if playing then
            -- only on a change, each call starts the slide over
            if self.glee_loopPitch ~= pitch then
                self.glee_loopPitch = pitch
                for _, loop in ipairs( sounds ) do
                    loop:ChangePitch( pitch, loopPitchTime )

                end
            end
            return

        end

        self:StopLoopSounds()

        sounds = {}
        for index, loopData in ipairs( loopSet ) do
            local loop = CreateSound( self, loopData.path )
            loop:SetSoundLevel( loopData.level )
            loop:PlayEx( loopData.volume, pitch )
            sounds[index] = loop

        end
        self.glee_loopSounds = sounds
        self.glee_loopSet = loopSet
        self.glee_loopPitch = pitch

    end


    -- The hologram's sounds -------------------------------------------------
    -- from the projection, so the hum follows it around. Only a kit's projected one sounds, see UpdateProjected
    -- driven by DrawBeams, a kit nobody's drawing has its hum stopped by the sweep below

    local holoBuildSound = "buttons/combine_button5.wav" -- once, as it starts building from the feet
    local holoUnprojectSound = "buttons/combine_button2.wav" -- once, as it goes, walked away from or swapped for someone nearer
    local holoAimedSound = "buttons/combine_button1.wav" -- once, as it brightens, aimed close enough to revive
    local holoHum = { path = "ambient/machines/combine_shield_loop3.wav", level = 60 } -- looped while it's projected and the beam reaches it
    local holoOneShotLevel = 65
    local humVolume = 0.3
    local humVolumeAimed = 1 -- aimed close enough to revive, or being revived
    local humPitch = 150
    local humPitchRevived = 200 -- it climbs here from humPitch over the revive
    local humStaleTime = 0.25 -- seconds without DrawBeams before the hum's stopped

    local function playHoloSound( path, holo )
        if not IsValid( holo ) then return end
        sound.Play( path, holo:GetPos(), holoOneShotLevel )

    end

    function SWEP:StopHologramHum()
        if self.glee_holoHum then
            self.glee_holoHum:Stop()

        end
        self.glee_holoHum = nil

    end

    -- from DrawBeams, once a frame
    -- holo is the projection when the beam reaches it, nil otherwise. aimed when it's bright, reviveFrac 0 to 1 while it's revived
    function SWEP:UpdateHologramSounds( holo, aimed, reviveFrac )
        local frame = FrameNumber()
        if self.glee_holoSoundFrame == frame then return end -- drawn in more than one view
        self.glee_holoSoundFrame = frame
        self.glee_holoSoundTime = CurTime()

        -- off who's projected, not whether the beam reaches, so a wall flickering in the way doesn't restart them
        local projected = self.glee_projectedDead
        if projected ~= self.glee_holoSoundDead then
            if self.glee_holoSoundDead then
                playHoloSound( holoUnprojectSound, self.glee_hologram )

            end
            if projected then
                playHoloSound( holoBuildSound, self.glee_hologram )

            end
            self.glee_holoSoundDead = projected
            self.glee_holoSoundAimed = nil

        end

        if not holo then
            self:StopHologramHum()
            return

        end

        if aimed and not self.glee_holoSoundAimed then
            playHoloSound( holoAimedSound, holo )

        end
        self.glee_holoSoundAimed = aimed

        -- restarted whenever it's not playing, like the loops
        local hum = self.glee_holoHum
        if not hum or not hum:IsPlaying() then
            self:StopHologramHum()
            hum = CreateSound( holo, holoHum.path )
            hum:SetSoundLevel( holoHum.level )
            hum:PlayEx( 0, humPitch )
            self.glee_holoHum = hum

        end
        hum:ChangeVolume( aimed and humVolumeAimed or humVolume )
        hum:ChangePitch( Lerp( reviveFrac or 0, humPitch, humPitchRevived ) )

    end

    function SWEP:HologramHumStale()
        return CurTime() - ( self.glee_holoSoundTime or 0 ) > humStaleTime

    end


    -- kits with their loops going. An autorefresh empties it, they're back in on their next check
    local soundingKits = {}
    local checkedKits = {}
    local nextLoopCheck = 0

    -- only held kits get checked, so any that stop being held are stopped here, nobody else would
    hook.Add( "Think", "glee_reclaimer_loopsounds", function()
        if nextLoopCheck > CurTime() then return end
        nextLoopCheck = CurTime() + loopCheckInterval

        table.Empty( checkedKits )
        for _, ply in player.Iterator() do
            local wep = ply:GetActiveWeapon()
            if not IsValid( wep ) or wep:GetClass() ~= CLASS then continue end

            wep:UpdateLoopSounds()
            if wep:HologramHumStale() then
                wep:StopHologramHum()

            end
            checkedKits[wep] = true
            soundingKits[wep] = ( wep.glee_loopSounds or wep.glee_holoHum ) and true or nil

        end

        for wep in pairs( soundingKits ) do
            if checkedKits[wep] then continue end

            soundingKits[wep] = nil
            if IsValid( wep ) then
                wep:StopLoopSounds()
                wep:StopHologramHum()

            end
        end
    end )


    -- Drawing it all --------------------------------------------------------

    -- every frame, for a kit held where we can see it
    -- points out the dead, projects the nearest, and reclaims their corpse while it's revived
    function SWEP:DrawBeams()
        local owner = self:GetOwner()
        local isMine = owner == LocalPlayer()

        -- other players' ammo isn't networked to us, so their beams are always full
        local color = reclamationColor
        if isMine and not self:CanAffordRevive() then
            color = brokeColor

        end

        -- the same trace PrimaryAttack revives from
        local aimPos
        if isMine then
            local _, aimTrace = self:TraceHealTarget()
            aimPos = aimTrace.HitPos

        end
        local aimedHealable = self:GetAimedHealable()

        local startPos, kitAng = self:BeamStart()
        if not startPos then return end

        local barrelDir = kitAng:Forward() -- the beams leave the muzzle along it
        local ownerPos = owner:GetPos()
        local revivables = self:RevivablesByDistance()
        self:UpdateProjected( revivables[1], ownerPos )

        local projecting = false
        local reviveFrac
        local soundingHolo, holoAimed -- the projection, once the beam's reached it, see UpdateHologramSounds
        for index, data in ipairs( revivables ) do
            local dist = ownerPos:Distance( data.pos )
            if index > 1 and dist > pointOutRange then break end

            local holo = data.ply == self.glee_projectedDead and self:GetHologram( data.ply )
            local goalAng = holo and self.glee_projectAng or angle_zero
            local beamStart, standPos, standAng, startDir, raySpots = self:HeldProjection( data.ply, startPos, kitAng, data.pos, goalAng, barrelDir, holo )

            if not holo then
                -- not who we're projecting, point them out
                local further = math.Clamp( ( dist - reachingDist ) / ( pointOutRange - reachingDist ), 0, 1 )
                local length = Lerp( further, reachingDist, pointerLength )
                local tipPos = beamStart + ( standPos + beamUp - beamStart ):GetNormalized() * length
                drawBeam( beamStart, startDir, tipPos, color, 0, 1, beamWidth )
                continue

            end

            -- brightens when aimed close enough to revive, see FindRevivable, and while they're revived, for everyone watching
            local revivingThem = self:GetNWEntity( "RevivingTarget", NULL ) == data.ply
            local aimedAt = aimPos and aimPos:DistToSqr( data.pos ) < reviveReach^2
            local bright = ( aimedAt or revivingThem ) and 1 or 0.45
            local beamStrength = revivingThem and 2 or 1
            local built = math.Clamp( ( CurTime() - self.glee_projectStart ) / buildTime, 0, 1 )

            poseHologram( holo, standPos, standAng )
            local centerPos = getBonePos( holo, holo:LookupBone( centerBone ) ) or standPos + beamUp

            -- a wall in the way, nothing gets through to project
            local reached = drawBeam( beamStart, startDir, centerPos, color, built, 1, beamWidth * beamStrength, diffuseWidth * beamStrength )
            if not reached then continue end

            projecting = true
            soundingHolo, holoAimed = holo, aimedAt or revivingThem
            local builtHeight = drawHologram( holo, standPos, standAng, color, built, bright )

            if revivingThem then
                reviveFrac = self:GetNWFloat( "RevivingProgress", 0 )
                reclaimBones( self, data.ply, holo, reviveFrac )

            end

            -- picked on the last re-aim, none until the first since projecting started
            if not raySpots then continue end

            -- from the prongs' tips, taking turns. Each lights up once the build reaches it
            local tips = self:ProngTips()
            local up = standAng:Up()
            for rayIndex, spot in ipairs( raySpots ) do
                local rayEnd = spotPos( holo, spot )
                if rayEnd and up:Dot( rayEnd - standPos ) <= builtHeight then
                    local rayStart = tips[( rayIndex - 1 ) % math.max( #tips, 1 ) + 1] or beamStart
                    drawBeam( rayStart, startDir, rayEnd, color, 1, 0.5 * bright, rayWidth * beamStrength )

                end
            end
        end

        self:DrawHealing( startPos, barrelDir )
        self:UpdateProngs( projecting, reviveFrac, aimedHealable )
        self:UpdateHologramSounds( soundingHolo, holoAimed, reviveFrac )

    end

    hook.Add( "PostDrawTranslucentRenderables", "glee_reclaimer_drawbeams", function( drawingDepth, drawingSkybox )
        if drawingDepth or drawingSkybox then return end

        for _, ply in player.Iterator() do
            if ply:IsDormant() then continue end
            if ply:Health() <= 0 then continue end

            local wep = ply:GetActiveWeapon()
            if not IsValid( wep ) then continue end
            if wep:GetClass() ~= CLASS then continue end

            wep:DrawBeams()

        end
    end )
end


-- Dead player positions -----------------------------------------------------
-- The server keeps where each player died, and sends every client the whole list whenever it changes
-- each send replaces the client's list, so the respawned drop off it too

if CLIENT then
    potentialResurrectionData = {}

    net.Receive( "glee_deadplayerpositions", function()
        local list = {}
        for _ = 1, net.ReadUInt( 8 ) do
            local ply = net.ReadEntity()
            local pos = net.ReadVector()
            table.insert( list, { ply = ply, pos = pos } )

        end
        potentialResurrectionData = list

    end )
end

if not SERVER then return end

if not GAMEMODE.IsReallyHuntersGlee then return end

util.AddNetworkString( "glee_deadplayerpositions" )

local syncQueued = false
local nextSync = 0
local syncInterval = 0.1 -- deaths in a burst go out together

-- sent on the next Think, however many queue it up before then
function GAMEMODE:QueueDeadPlayersSync()
    syncQueued = true

end

local function sendDeadPlayers()
    local list = {}
    for _, data in pairs( GAMEMODE.deadPlayers ) do
        if IsValid( data.ply ) then
            table.insert( list, data )

        end
    end

    net.Start( "glee_deadplayerpositions" )
    net.WriteUInt( #list, 8 )
    for _, data in ipairs( list ) do
        net.WriteEntity( data.ply )
        net.WriteVector( data.pos )

    end
    net.Broadcast()

end

hook.Add( "Think", "glee_reclaimer_syncdeadplayers", function()
    if not syncQueued then return end
    if nextSync > CurTime() then return end

    syncQueued = false
    nextSync = CurTime() + syncInterval
    sendDeadPlayers()

end )

-- GM:PlayerSpawn takes them off the list after the hooks, it's gone by the time the sync goes out
hook.Add( "PlayerSpawn", "glee_reclaimer_syncrespawned", function()
    GAMEMODE:QueueDeadPlayersSync()

end )

-- joining mid round, they've missed every sync so far
hook.Add( "glee_full_load", "glee_reclaimer_syncjoined", function()
    GAMEMODE:QueueDeadPlayersSync()

end )

hook.Add( "PlayerDeath", "saveResurrectPos", function( victim )
    -- Manually trace down first so the ground check can have a larger distance than the nav snap.
    local pos = victim:GetPos()
    local tr = util.TraceHull( {
        start = pos,
        endpos = pos + Vector( 0, 0, -5000 ),
        mins = victim:OBBMins() * Vector( 0, 0, 0.01 ),
        maxs = victim:OBBMaxs() * Vector( 0, 0, 0.01 ),
        mask = MASK_PLAYERSOLID_BRUSHONLY,
    } )

    local area = navmesh.GetNearestNavArea( tr.HitPos, false, 500, false, true )

    if IsValid( area ) then
        pos = area:GetClosestPointOnArea( pos )

    end

    GAMEMODE.deadPlayers[victim:GetCreationID()] = { ply = victim, pos = pos }
    GAMEMODE:QueueDeadPlayersSync()

end )
