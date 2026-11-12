AddCSLuaFile()

--[[------------------------------------
    Tissue Reclaimer: heals the living, revives the dead, both out of one pool of juice.

    Primary on a hurt player heals them, primary near a dead player's marker holds to revive.
    Secondary heals yourself.
    Juice comes from buying another, and from health pickups found while already at full health.

    Read top to bottom: setup, healing, reviving, the hud, then where dead players' positions come from.
--]]-------------------------------------

SWEP.PrintName = "Tissue Reclaimer"
SWEP.Author = "StrawWagen, robotboy655 & MaxOfS2D"
SWEP.Purpose = "Heal the living with your primary attack, yourself with the secondary. Hold primary on the dead to revive them."
SWEP.Category = "Hunter's Glee"

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = true

SWEP.ViewModel = Model( "models/weapons/c_medkit.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_medkit.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.HoldType = "slam"

-- juice is the owner's GLEE_JUICE ammo, no clip
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = 200 -- also what each shop resupply adds
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "GLEE_JUICE"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.OwnerHealAmount = 8
SWEP.HealAmount = 20 -- healing others costs and gives double this
SWEP.ReviveCost = 100

local CLASS = "termhunt_tissue_reclaimer"

local HealSound = Sound( "HealthKit.Touch" )
local DenySound = Sound( "WallHealth.Deny" )
local ReviveSound = Sound( "items/medshot4.wav" )
local ReviveDenySound = Sound( "items/medshotno1.wav" )

local reviveReach = 75 -- from where you aim to a dead player's position, and how far you can move mid-revive
local markerRange = 1000


-- Setup ---------------------------------------------------------------------

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )

end

function SWEP:CanAffordRevive()
    return self:Ammo1() >= self.ReviveCost

end

function SWEP:CustomAmmoDisplay()
    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Ammo1()

    return self.AmmoDisplay

end

function SWEP:AttackAnim()
    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

    -- Even though the viewmodel has looping IDLE anim at all times, we need this to make fire animation work in multiplayer
    timer.Create( "weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function() if ( IsValid( self ) ) then self:SendWeaponAnim( ACT_VM_IDLE ) end end )

end

function SWEP:Deploy()
    if SERVER and GAMEMODE.SendDeadPlayersToClients then
        GAMEMODE:SendDeadPlayersToClients()

    end
    return true

end

function SWEP:ShutDown()
    if self.resurrectingLoop then
        self.resurrectingLoop:Stop()

    end
    local owner = self:GetOwner()
    if IsValid( owner ) then
        owner.glee_reclaimerBlocksSwitching = nil

    end
    timer.Stop( "weapon_idle" .. self:EntIndex() )

end

function SWEP:OnRemove()
    self:ShutDown()

end

function SWEP:Holster()
    self:ShutDown()
    return true

end

function SWEP:OwnerChanged()
    self:ShutDown()

end

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, CLASS, "materials/vgui/hud/" .. CLASS .. ".png" )
    language.Add( "GLEE_JUICE_ammo", "Juice" )

end


-- Healing -------------------------------------------------------------------

-- the hurt player or npc in reach, if primary should heal instead of revive
function SWEP:GetHealTarget()
    local owner = self:GetOwner()
    if owner:IsPlayer() then
        owner:LagCompensation( true )

    end

    local tr = util.TraceLine( {
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 64,
        filter = owner
    } )

    if owner:IsPlayer() then
        owner:LagCompensation( false )

    end

    local ent = tr.Entity
    if not IsValid( ent ) then return nil, tr end
    if not ( ent:IsPlayer() or ent:IsNPC() ) then return nil, tr end
    if ent:Health() <= 0 then return nil, tr end
    if ent:Health() >= ent:GetMaxHealth() then return nil, tr end

    return ent, tr

end

function SWEP:HealOther( ent )
    local owner = self:GetOwner()

    local need = self.HealAmount * 2 -- healing other players is super efficient
    need = math.min( ent:GetMaxHealth() - ent:Health(), need )

    if self:Ammo1() < need then
        owner:EmitSound( DenySound )
        self:SetNextPrimaryFire( CurTime() + 0.1 )
        return

    end

    self:TakePrimaryAmmo( need )

    ent:SetHealth( math.min( ent:GetMaxHealth(), ent:Health() + need ) )
    ent.glee_LastSetHealthReason = "glee_reclaimer_heal"
    ent:EmitSound( HealSound )

    self:AttackAnim()
    self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.5 )

    if owner.GivePlayerScore and ent:IsPlayer() then
        owner:GivePlayerScore( 8 )

    end

    owner:SetNW2Bool( "gleereclaimer_healedother", true )

end

function SWEP:SecondaryAttack()
    if CLIENT then return end
    if self.resurrecting then return end -- would spend the juice the revive is about to cost

    local ent = self:GetOwner()

    local need = self.OwnerHealAmount
    if IsValid( ent ) then need = math.min( ent:GetMaxHealth() - ent:Health(), self.OwnerHealAmount ) end

    if IsValid( ent ) and self:Ammo1() >= need and ent:Health() < ent:GetMaxHealth() then
        ent:SetNW2Bool( "gleereclaimer_healedself", true )

        self:TakePrimaryAmmo( need )

        ent:SetHealth( math.min( ent:GetMaxHealth(), ent:Health() + need ) )
        ent.glee_LastSetHealthReason = "glee_reclaimer_healself"
        ent:EmitSound( HealSound )

        self:AttackAnim()
        self:SetNextSecondaryFire( CurTime() + self:SequenceDuration() + 0.5 )

    else
        ent:EmitSound( DenySound )
        self:SetNextSecondaryFire( CurTime() + 1 )

    end
end

local juiceToGive = {
    item_healthkit = 25,
    item_healthvial = 10,

}

hook.Add( "PlayerCanPickupItem", "glee_reclaimer_absorbsitems", function( ply, item )
    local itemsClass = item:GetClass()
    local toGive = juiceToGive[itemsClass]
    if not toGive then return end

    if not ply:HasWeapon( CLASS ) then return end

    if ply:Health() < ply:GetMaxHealth() then return end

    if item.glee_AbsorbedByPly then return end
    item.glee_AbsorbedByPly = true

    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        ply:GiveAmmo( toGive, "GLEE_JUICE" )
        local pit = 100 + ( 200 / toGive )
        ply:EmitSound( "items/medshot4.wav", 55, pit, 1, CHAN_BODY )
        SafeRemoveEntity( item )

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

-- the dead player whose position is near where we're aiming
function SWEP:FindRevivable( aimTrace )
    local center = aimTrace.HitPos

    for _, data in pairs( self:GetGamemodeDeadPlayerData() ) do
        if not IsValid( data.ply ) then continue end
        if not self:CanResurrect( data.ply ) then continue end
        if data.pos:DistToSqr( center ) < reviveReach^2 then
            return data.ply, data.pos

        end
    end
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    if owner:IsPlayer() and owner:HasWeapon( "termhunt_divine_chosen" ) then
        owner:ChatPrint( "Disgusting. Why would I help such a worthless being?" )
        owner:DropWeaponKeepAmmo( self )
        return

    end

    local healTarget, aimTrace = self:GetHealTarget()
    if healTarget then
        self:HealOther( healTarget )
        return

    end

    local toRevive, resurrectPos = self:FindRevivable( aimTrace )
    if not IsValid( toRevive ) or not owner:IsPlayer() then
        owner:EmitSound( DenySound )
        self:SetNextPrimaryFire( CurTime() + 0.1 )
        return

    end

    if not self:CanAffordRevive() then
        owner:EmitSound( ReviveDenySound, 75, 80 )
        self:SetNextPrimaryFire( CurTime() + 0.5 )
        return

    end

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

    self:SetNWBool( "RevivingPly", true )

    self.resurrectStartPos = owner:GetPos()

    self:AttackAnim()

    owner:EmitSound( ReviveSound, 100, 70, 1, CHAN_STATIC, SND_NOFLAGS, 10 )

    local recip = RecipientFilter( false )
    recip:AddAllPlayers()

    self.resurrectingLoop = CreateSound( owner, "items/medcharge4.wav", recip )
    self.resurrectingLoop:Play()

    huntersGlee_Announce( { self.toResurrect }, 5, 5, "You are being revived by " .. owner:Nick() )

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
        -- dont give as much score if owner killed who they reviving
        if ply:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then
            reward = 150
            if not owner.glee_InfernalReviveHint then
                owner.glee_InfernalReviveHint = true
                huntersGlee_Notify( { owner }, {
                    text = "REVIVAL PAYOUT HALVED",
                    description = "Patient is bound by an infernal contract.",
                    time = 6,
                } )

            end
        elseif GAMEMODE:HasSlighted( owner, ply ) >= 50 then
            reward = 150
            if not owner.glee_HomicideReviveHint then
                owner.glee_HomicideReviveHint = true
                huntersGlee_Notify( { owner }, {
                    text = "REVIVAL PAYOUT HALVED",
                    description = "You killed this patient.",
                    time = 6,
                } )

            end
        elseif not owner.glee_revivemoneyhint then
            owner.glee_revivemoneyhint = true
            huntersGlee_Notify( { owner }, {
                text = "+" .. tostring( reward ) .. " score!",
                kind = "good", time = 6
            } )

        end

        ply.glee_resurrectDecreasingScore = ply.glee_resurrectDecreasingScore or 0

        -- dont just resuurect the same person over and over!
        local rewardBite = ply.glee_resurrectDecreasingScore - CurTime()
        if rewardBite < 0 then
            rewardBite = 0

        end

        reward = math.Clamp( reward + -rewardBite, 0, 300 )
        owner:GivePlayerScore( reward )

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

    ply:Resurrect( self.toResurrectPos )
    return true

end

function SWEP:GetViewModelPosition( pos, ang )
    local offset = Vector( 0 )
    if self:GetNWBool( "RevivingPly", false ) then
        offset = Vector( 0, 0, -10 )

    end
    return pos + offset, ang

end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    -- spawnable outside glee, where there's nobody to revive
    if SERVER and GAMEMODE.SendDeadPlayersToClients then
        local nextRefresh = self.nextRefresh or 0
        if nextRefresh < CurTime() then
            self.nextRefresh = CurTime() + 4
            GAMEMODE:SendDeadPlayersToClients()

        end
    end

    if self.resurrecting and IsValid( self.toResurrect ) then
        local ent = self.toResurrect
        local tooFar = self.resurrectStartPos:DistToSqr( owner:GetPos() ) > reviveReach^2
        local keyDown = owner:KeyDown( IN_ATTACK )
        local cancel = tooFar or not keyDown or ent:Health() > 0 or not self:CanAffordRevive()
        local done = false
        if cancel then
            done = true
            owner:EmitSound( ReviveDenySound, 75, 80 )

        else
            local progress = generic_WaitForProgressBar( owner, "glee_resurrector", 0.1, 2, nil )
            if progress >= 100 then
                generic_KillProgressBar( owner, "glee_resurrector" )
                self:ResurrectPly( ent )
                done = true

            end
        end
        if done == true then
            self.resurrectingLoop:Stop()
            self.toResurrectPos = nil
            self.resurrecting = nil
            self.toResurrect = nil
            self.resurrectStartPos = nil
            self:SetNWBool( "RevivingPly", false )

        end
    end
    if not ( self.resurrecting and IsValid( self.toResurrect ) ) then
        owner.glee_reclaimerBlocksSwitching = nil

    end
end


-- Hud -----------------------------------------------------------------------

if CLIENT then
    -- the nearest dead player we could revive, nil for none
    function SWEP:NearestRevivable()
        local ownerPos = self:GetOwner():GetPos()
        local deads = self:GetGamemodeDeadPlayerData()
        table.sort( deads, function( a, b )
            return ownerPos:DistToSqr( a.pos ) < ownerPos:DistToSqr( b.pos )

        end )
        for _, data in ipairs( deads ) do
            if not IsValid( data.ply ) then continue end
            if not data.pos then continue end
            if not self:CanResurrect( data.ply ) then continue end
            return data

        end
    end

    function SWEP:HintPostStack()
        local owner = self:GetOwner()

        if self:Ammo1() <= 0 then
            local msg = "NO JUICE LEFT\nBuy another Tissue Reclaimer in the shop..."
            if owner:Health() >= owner:GetMaxHealth() then
                msg = msg .. "\nOr pick up some Health off the ground..."

            end
            return true, msg

        end

        if not owner:GetNW2Bool( "gleereclaimer_resurrected", false ) and self:CanAffordRevive() and self:NearestRevivable() then
            return true, "Hold primary attack on a dead player's marker to revive them!"

        end

        if not owner:GetNW2Bool( "gleereclaimer_healedself", false ) and owner:Health() < owner:GetMaxHealth() then return true, "Secondary attack to heal yourself!" end
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
                return true, "Primary attack to heal others!\nIt's much faster than healing yourself."

            end
        end
    end

    local markerUp = Vector( 0, 0, 16 ) -- dead positions are on the floor
    local markerColor = Color( 0, 0, 0, 0 )
    local brokeLabel = "NEED " .. SWEP.ReviveCost .. " JUICE"
    local reviveLabel = "REVIVE"

    -- corner brackets around the nearest dead player, in the style's alert colour when we can pay
    -- for the revive, its disabled colour when we can't
    function SWEP:PaintReviveMarker( data )
        local screen = ( data.pos + markerUp ):ToScreen()
        if not screen.visible then return end

        local style = terminator_Extras.glee_Style( "generic" )
        local canAfford = self:CanAffordRevive()
        local roleColor = style:Color( canAfford and "alert" or "disabled" )

        local dist = data.pos:Distance( LocalPlayer():GetPos() )
        local closeness = 1 - math.Clamp( ( dist - 200 ) / ( markerRange - 200 ), 0, 1 )

        markerColor.r, markerColor.g, markerColor.b = roleColor.r, roleColor.g, roleColor.b
        markerColor.a = Lerp( closeness, 120, 255 )

        local half = math.Round( style:Scaled( Lerp( closeness, 28, 50 ) ) )
        local arm = math.Round( half * 0.45 )
        local thick = math.max( 2, style:Scaled( 4 ) )
        local x, y = math.Round( screen.x ), math.Round( screen.y )
        local left, right, top, bottom = x - half, x + half, y - half, y + half

        surface.SetDrawColor( markerColor )
        surface.DrawRect( left, top, arm, thick )
        surface.DrawRect( left, top, thick, arm )
        surface.DrawRect( right - arm, top, arm, thick )
        surface.DrawRect( right - thick, top, thick, arm )
        surface.DrawRect( left, bottom - thick, arm, thick )
        surface.DrawRect( left, bottom - arm, thick, arm )
        surface.DrawRect( right - arm, bottom - thick, arm, thick )
        surface.DrawRect( right - thick, bottom - arm, thick, arm )

        style:Draw( canAfford and reviveLabel or brokeLabel, "small", x, bottom + style:Metric( "laneSpacing" ), markerColor )

    end

    function SWEP:DrawHUD()
        if self:GetNWBool( "RevivingPly", false ) then return end

        local owner = self:GetOwner()
        if not IsValid( owner ) then return end

        local nearest = self:NearestRevivable()
        if nearest then
            self:PaintReviveMarker( nearest )

        end

        local deads = self:GetGamemodeDeadPlayerData()
        local nextPlayersCheck = self.nextPlayersCheck or 0
        if nextPlayersCheck < CurTime() then
            self.nextPlayersCheck = CurTime() + 1
            self.validDeads = {}

            for _, data in ipairs( deads ) do
                if not IsValid( data.ply ) then continue end
                if data.ply == LocalPlayer() then continue end
                if data.ply:Health() > 0 then continue end
                self.validDeads[data.ply] = data

            end
        end

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

            local deadDat = self.validDeads[ent]

            if not deadDat then return end
            if not self:CanResurrect( deadDat.ply ) then return end
            if deadDat.pos:DistToSqr( currentOwner:GetPos() ) > markerRange^2 then return end

            return deadDat.pos, true, true -- pos override, draw at any distance, and draw even if dead

        end )
    end
end


-- Dead player positions -----------------------------------------------------
-- The server keeps where each player died, and drips them out to every client while anyone holds one of these

if CLIENT then
    potentialResurrectionData = {}
    local nextResurrectRecieve = 0

    net.Receive( "glee_storeresurrectpos", function()
        if nextResurrectRecieve > CurTime() then return end
        nextResurrectRecieve = CurTime() + 0.01
        local ply = net.ReadEntity()
        local pos = net.ReadVector()
        local data = { ply = ply, pos = pos }
        for ind, overlapData in ipairs( potentialResurrectionData ) do -- remove old resurrect pos
            if overlapData.ply ~= ply then continue end
            table.remove( potentialResurrectionData, ind )

        end
        table.insert( potentialResurrectionData, data )

    end )
end

if not SERVER then return end

if not GAMEMODE.IsReallyHuntersGlee then return end

util.AddNetworkString( "glee_storeresurrectpos" )

local nextSendAttempt = 0

function GAMEMODE:SendDeadPlayersToClients()
    if nextSendAttempt > CurTime() then return end
    local count = table.Count( GAMEMODE.deadPlayers )
    nextSendAttempt = CurTime() + 0.05 + count * 0.05

    count = 0

    for _, currentDeadPlayerData in pairs( GAMEMODE.deadPlayers ) do
        count = count + 1
        timer.Simple( count * 0.05, function()
            local ply = currentDeadPlayerData.ply
            local pos = currentDeadPlayerData.pos
            net.Start( "glee_storeresurrectpos" )
            net.WriteEntity( ply )
            net.WriteVector( pos )
            net.Broadcast()
        end )
    end
end

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
    GAMEMODE:SendDeadPlayersToClients()

end )
