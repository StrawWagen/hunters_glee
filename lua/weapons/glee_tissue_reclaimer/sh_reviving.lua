-- The Medical Tissue Reclaimer's reviving, included by shared.lua
-- holding primary on a dead player's projection brings them back, Think in shared.lua carries the hold through
-- then the medic's shoves

local reclaimer = SWEP.Reclaimer
local CLASS = reclaimer.CLASS
local ReviveSound = reclaimer.ReviveSound
local ReviveDenySound = reclaimer.ReviveDenySound
local DryFireSound = reclaimer.DryFireSound
local reviveReach = reclaimer.reviveReach
local boneSnapFrac = reclaimer.boneSnapFrac
local playServerSound = reclaimer.playServerSound
local playServerOneShot = reclaimer.playServerOneShot
local notifyFromServer = reclaimer.notifyFromServer
local notifyDryFire = reclaimer.notifyDryFire
local clearFailedNotifies = reclaimer.clearFailedNotifies
local isLiving = reclaimer.isLiving
local isOrganic = reclaimer.isOrganic

-- Reviving ------------------------------------------------------------------

-- where each player died, see the gamemode's modules/deadpositions
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

-- the dead player whose position is nearest where we're aiming, within reach, reviveReach if not given
function SWEP:FindRevivable( aimTrace, reach )
    local center = aimTrace.HitPos
    local nearest, nearestPos
    reach = reach or reviveReach
    local nearestDistSqr = reach^2

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

local nearMissReach = reviveReach * 4

-- why primary found nothing to heal or revive
local function notifyNothingToReclaim( wep, aimTrace )
    local aimed = aimTrace.Entity
    local notice = {
        text = "NO TISSUE FOUND",
        description = "Aim at someone hurt, or a death location.",
    }

    local living = isLiving( aimed )
    if living and not isOrganic( aimed ) then
        notice.text = "NO TISSUE DETECTED"
        notice.description = "That's a machine."

    elseif living and aimed:GetBloodColor() == DONT_BLEED then -- like floor turrets, still healable
        notice.text = "TISSUE UNCLEAR"
        notice.description = "Healable, but at full health."

    elseif living then
        notice.text = "TISSUE INTACT"
        if aimed:IsPlayer() then
            notice.description = "They're at full health."

        else
            notice.description = "It's at full health."

        end

    -- players aim at the corpse and think they have to drag it back, it's the death location that revives
    elseif IsValid( wep:FindRevivable( aimTrace, nearMissReach ) ) then
        notice.text = "DEATH LOCATION DESYNCED"
        notice.description = "Reclaimer must be aligned with death location."

    elseif IsValid( aimed ) then
        notice.text = "INCOMPATIBLE TISSUE"
        notice.description = "That can't be reclaimed."

    end

    notifyDryFire( wep, IN_ATTACK, notice )

end

-- the server judges what was clicked, and says why it failed. The client can't judge who's healable, see PrimaryHealTarget
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

    -- healing's held, see HealThink. The client goes by the server's last check, a round trip late
    local aimTrace
    if SERVER then
        local healTarget
        healTarget, aimTrace = self:TraceHealTarget()
        if healTarget then return end

    else
        if self:GetAimedHealable() then return end
        aimTrace = self:TraceAim()

    end

    local toRevive, resurrectPos = self:FindRevivable( aimTrace )
    if not IsValid( toRevive ) or not owner:IsPlayer() then
        if SERVER then
            playServerOneShot( self, DryFireSound )
            self:PlayViewModelOnce( "fire" )
            notifyNothingToReclaim( self, aimTrace )

        end
        self:SetNextPrimaryFire( CurTime() + 0.1 )
        return

    end

    if not self:CanAffordRevive() then
        if SERVER then
            playServerSound( self, ReviveDenySound, 75, 80 )
            notifyFromServer( self, {
                text = "INSUFFICIENT RECLAMATION JUICE",
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

hook.Add( "PlayerSwitchWeapon", "glee_reclaimer_blockswitchwhilereviving", function( ply, _, _ )
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) then return end
    if wep:GetClass() ~= CLASS then return end
    if wep.resurrecting then return true end

end )

function SWEP:StartResurrect( ent, resurrectPos )
    if not self:CanResurrect( ent ) then return end

    local owner = self:GetOwner()

    self.resurrecting = true
    self.toResurrect = ent
    self.toResurrectPos = resurrectPos

    -- a re-press on the same dead player resumes, the progress bar's kept per dead player, see Think
    if ent ~= self.lastResurrectTarget then
        self:SetRevivingProgress( 0 )

    end
    self.lastResurrectTarget = ent
    self:SetRevivingTarget( ent )

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

    -- if they have a ragdoll entity, remove it
    SafeRemoveEntity( ply:GetRagdollEntity() )

    self:SendReviveJolt( ply )
    self:PlayViewModelOnce( "fire" )
    ply:Resurrect( self.toResurrectPos )
    return true

end


-- Shoving the medic ---------------------------------------------------------
-- the medic gets shoved around by the bones going in, down and away from the death pos
-- the server can't see the clients' corpses, so it shoves on the same schedule, for a typical one
local shoveBoneCount = 15 -- a player ragdoll's physics objects
local shoveFromFrac = 0.8 -- the bones before this are spread out enough to go in without a shove
local shoveDown = 120
local shoveAway = 60 -- keep it gentle, moving reviveReach from where the revive started cancels it
local shoveSpread = 60 -- degrees either side of straight away from the death pos
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
