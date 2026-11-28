AddCSLuaFile()

--[[------------------------------------
    Medical Tissue Reclaimer: heals the living, revives the dead, both out of one pool of reclamation juice.

    Hold primary on a hurt player to heal them, or on a dead player's projection to revive them.
    Hold secondary to heal yourself.
    Reclamation juice comes from buying another, and from health pickups found while already at full health.

    Read top to bottom: setup, telling the owner no, other addons' entities, the viewmodel, who's healable, healing,
    picking up material, then Think, which runs it all every tick.

    The rest is in the files included at the bottom, each read top to bottom too:
    sh_reviving.lua, reviving, and the medic's shoves
    cl_beams.lua, the hud, the kit's look, where its beams leave it, recoil, and drawing one beam
    cl_projection.lua, projecting the dead, and pulling their corpse into the projection as they're revived
    cl_draw.lua, the healing's beams, the sounds, and SWEP:DrawBeams, which draws it all
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
SWEP.GleeFlashlightInHand = true -- no barrel to mount the flashlight on, it's held in the off hand

-- reclamation juice is the owner's GLEE_RECLAMATION_MATERIAL ammo, no clip
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
    -- the server's, every client reclaims their copy of the corpse off these
    -- datatable vars arrive in one snapshot, so a client never sees a new target with the last one's progress
    self:NetworkVar( "Entity", "RevivingTarget" )
    self:NetworkVar( "Float", "RevivingProgress" ) -- 0 to 1

end

function SWEP:CanAffordRevive()
    return self:Ammo1() >= self.ReviveCost

end

-- networked, unlike self.resurrecting, so every client knows too
function SWEP:IsReviving()
    return IsValid( self:GetRevivingTarget() )

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
    language.Add( "GLEE_RECLAMATION_MATERIAL_ammo", "Reclamation Juice" )

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

local outOfMaterialText = "NO RECLAMATION JUICE LEFT" -- the notify's, and the hint's, see HintPostStack

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


-- Who's healable ------------------------------------------------------------
-- the server's to judge, the client only gets where the owner's aiming, see TraceAim

-- npc classes that are all machine, see https://wiki.facepunch.com/gmod/Enums/CLASS
-- CLASS_COMBINE isn't, it's soldiers and turrets both
local machineClasses
if SERVER then -- the enums don't exist on the client
    machineClasses = {
        [CLASS_COMBINE_GUNSHIP] = true,
        [CLASS_MANHACK] = true,
        [CLASS_MILITARY] = true,
        [CLASS_SCANNER] = true,
        [CLASS_MISSILE] = true,
        [CLASS_HACKED_ROLLERMINE] = true,
        [CLASS_MACHINE] = true,
        [CLASS_PORTAL_TURRET] = true,
    }
end

-- machines have no tissue to reclaim
-- server only, none of what says so is right on the client, see PrimaryHealTarget
local function isOrganic( ent )
    if ent.DoMetallicDamage then return false end
    if ent.GetNPCClass and machineClasses[ent:GetNPCClass()] then return false end
    return ent:GetBloodColor() ~= BLOOD_COLOR_MECH

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

local function aimTraceData( owner )
    local shootPos = owner:GetShootPos()
    return {
        start = shootPos,
        endpos = shootPos + owner:GetAimVector() * healReach,
        filter = owner,
    }

end

-- where the owner's aiming, out to heal reach, see FindRevivable
function SWEP:TraceAim()
    return util.TraceLine( aimTraceData( self:GetOwner() ) )

end

if SERVER then
    -- the hurt player or npc being aimed at, nil if there's none, and the aim's trace, see TraceAim
    -- a precise line first, then a fat hull for a near miss, like the shove's
    function SWEP:TraceHealTarget()
        local owner = self:GetOwner()

        local lagCompensate = owner:IsPlayer()
        if lagCompensate then
            owner:LagCompensation( true )

        end

        local aimTrace = self:TraceAim()
        local target = aimTrace.Entity
        if not isHealable( target ) then
            local trace = aimTraceData( owner )
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
end


-- Healing -------------------------------------------------------------------
-- a hold, primary on someone else, secondary on yourself, a few health a tick
-- healing yourself turns the kit onto its medic first. To the left, the viewmodel has no right side to show
-- it stays turned a moment after letting go, so a quick re-press doesn't wait on the turn again
-- healing someone else or reviving turns it back quicker
-- predicted, run from Think, so the beams, their sound and the turn start without waiting on the server
-- who primary heals is the server's, see PrimaryHealTarget

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
        text = "INSUFFICIENT RECLAMATION JUICE",
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

-- Other addons' entities ----------------------------------------------------
-- The kit's left click is free on most things, since healing is the hold. A classname in
-- SpecialInteractions gets the click instead, so another mod's entities are handled here, apart
-- from the healing. The mod they come from need not be installed: a key is only a classname,
-- nothing here loads the other addon, and every handler checks the fields it uses first.

local FEED_COST = 10 -- reclamation material per body
local FEED_DELAY = 1 -- seconds the click is held off after a body goes in

SWEP.SpecialInteractions = {
    ["evil_fungus"] = {
        -- the strand has no solid body, so the aim trace lands on the world under it. The patch is
        -- found by its mat instead: the one with a node nearest where the aim lands
        find = function( tr )
            local best, bestDist
            for _, ent in ipairs( ents.FindByClass( "evil_fungus" ) ) do
                local mat = ent.Mat
                if mat and mat.Nearest and not ent.Absorbed then
                    local node, dist = mat:Nearest( tr.HitPos, 48 )
                    if node and ( not bestDist or dist < bestDist ) then
                        best, bestDist = ent, dist

                    end
                end
            end
            return best

        end,

        -- FEED_COST buys the strand one body, at the node nearest the click
        -- the fungus's own food goes in the same way, see its Digest
        -- FEED_DELAY makes a held trigger pay once per body, not once per frame
        primaryAttack = function( wep, ent, tr )
            local mat = ent.Mat
            if not mat or not mat.SetMass or not ent.Closest then return end

            local node = ent:Closest( tr.HitPos )
            if not node or node.dead then return end

            if wep:Ammo1() < FEED_COST then
                playServerDeny( wep )
                return

            end

            wep:TakePrimaryAmmo( FEED_COST )
            mat:SetMass( node, ( node.m or 0 ) + 1 )
            playServerOneShot( wep, AbsorbSound )
            wep:SetNextPrimaryFire( CurTime() + FEED_DELAY )

        end,
    },
}

-- the interaction for what a click landed on, by classname. A registered class may have no solid
-- body, so a click on the world also offers itself to each entry's find, which reads where the aim
-- landed instead of what it hit. Nil when nothing of another addon's is there
function SWEP:SpecialInteractionAt( tr )
    local ent = IsValid( tr.Entity ) and tr.Entity
    if ent then
        local direct = self.SpecialInteractions[ent:GetClass()]
        if direct then return direct, ent end

    end

    if not tr.HitWorld then return end

    for _, candidate in pairs( self.SpecialInteractions ) do
        if candidate.find then
            local found = candidate.find( tr )
            if IsValid( found ) then return candidate, found end

        end
    end
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

-- who primary heals, the server's to pick. The client can't see everything that decides it, eg terminators' IsNPC, see isOrganic
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
        ply:GiveAmmo( toGive, "GLEE_RECLAMATION_MATERIAL", true ) -- has its own notice, below
        local pit = 100 + ( 200 / toGive )
        ply:EmitSound( AbsorbSound, 55, pit, 1, CHAN_BODY )
        SafeRemoveEntity( item )

        huntersGlee_Notify( { ply }, {
            text = "Reclamation Juice +{num}",
            iconWeapon = CLASS, -- one icon for kits and vials alike, so they add to the same total
            addNum = toGive,
            kind = "good",
        } )

    end )
end )


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
            -- tooFar is the medic walking off, "tissue out of range" had players dragging the body to the projection
            local why = tooFar and "Desynced with death location." or cantAfford and "Insufficient reclamation juice."
            if why then
                huntersGlee_Notify( { owner }, {
                    text = "REVIVAL INTERRUPTED",
                    description = why,
                    kind = "bad",
                    replaceKey = "glee_reclaimer_interrupted",
                } )

            end

        else
            local barId = "glee_resurrector" .. ent:GetCreationID() -- each dead player's own, so someone new starts at 0
            local progress = generic_WaitForProgressBar( owner, barId, reviveBarSpeed, reviveBarChunk, nil )
            self:SetRevivingProgress( progress / 100 )
            self:ReclaimShoves( progress / 100 )
            if progress >= 100 then
                generic_KillProgressBar( owner, barId )
                self:SetRevivingProgress( 0 ) -- they're up, reviving them again starts over
                self:ResurrectPly( ent )
                done = true

            end
        end
        if done == true then
            self.toResurrectPos = nil
            self.resurrecting = nil
            self.toResurrect = nil
            self.resurrectStartPos = nil
            self:SetRevivingTarget( NULL )

        end
    end
end


-- The other files -----------------------------------------------------------
-- what they share with this file and each other goes through SWEP.Reclaimer
-- each takes what it needs at its top, and adds what the files after it need at its bottom
-- only at load, every weapon gets its own deep copy of this table, so self.Reclaimer shares nothing

SWEP.Reclaimer = {
    CLASS = CLASS,
    ReviveSound = ReviveSound,
    ReviveDenySound = ReviveDenySound,
    DryFireSound = DryFireSound,
    reviveReach = reviveReach,
    pointOutRange = pointOutRange,
    boneSnapFrac = boneSnapFrac,
    playServerSound = playServerSound,
    playServerOneShot = playServerOneShot,
    outOfMaterialText = outOfMaterialText,
    notifyFromServer = notifyFromServer,
    notifyDryFire = notifyDryFire,
    clearFailedNotifies = clearFailedNotifies,
    isLiving = isLiving,
    isOrganic = isOrganic,
}

if SERVER then
    AddCSLuaFile( "sh_reviving.lua" )
    AddCSLuaFile( "cl_beams.lua" )
    AddCSLuaFile( "cl_projection.lua" )
    AddCSLuaFile( "cl_draw.lua" )

end

include( "sh_reviving.lua" )

if CLIENT then
    include( "cl_beams.lua" )
    include( "cl_projection.lua" )
    include( "cl_draw.lua" )

end
