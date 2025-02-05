SWEP.PrintName = "Reviver"
SWEP.Author = "StrawWagen & the people who worked on the medkit"
SWEP.Purpose = "Resurrect the fallen"

SWEP.Slot = 5
SWEP.SlotPos = 3

SWEP.Spawnable = false
SWEP.Category = "Hunter's Glee"

SWEP.ViewModel = Model( "models/weapons/c_medkit.mdl" )
SWEP.WorldModel = Model( "models/weapons/w_medkit.mdl" )
SWEP.ViewModelFOV = 54
SWEP.UseHands = true

SWEP.Primary.ClipSize = math.huge
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.MaxAmmo = math.huge -- Maxumum ammo
SWEP.ResTime = 2.5

SWEP.ViewOffset = Vector( 0 )

local HealSound = Sound( "items/medshot4.wav" )
local DenySound = Sound( "items/medshotno1.wav" )

function SWEP:Initialize()

    self:SetHoldType( "slam" )

    self:SetClip1( self.Primary.DefaultClip )
    self:UpdateColor()

end

function SWEP:UpdateColor()
    local resurrects = self:Clip1()
    if resurrects > 0 then
        color = Color( 255,255,255 )
    else
        color = Color( 160,160,160 )
    end
    self:SetColor( color )

end

hook.Add( "PlayerDeath", "reviverfallbackremoveblockswitch", function( victim )
    victim.blockSwitchingWeaponsReviver = nil

end )

hook.Add( "PlayerSwitchWeapon", "blockswitchingfromreviver", function( ply, _, _ )
    if not ply.blockSwitchingWeaponsReviver then return end
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) then return end
    if wep:GetClass() ~= "termhunt_reviver" then return end
    if wep.resurrecting then return true end

end )

function SWEP:GetGamemodeDeadPlayerData()
    if GAMEMODE.deadPlayers then return GAMEMODE.deadPlayers end
    if not CLIENT then return {} end
    return potentialResurrectionData or {}

end

function SWEP:OnEmpty()
    self:GetOwner():EmitSound( DenySound, 75, 80 )
    self:SetNextPrimaryFire( CurTime() + 0.5 )
end

function SWEP:PrimaryAttack()

    if CLIENT then return end

    if self:Clip1() <= 0 then self:OnEmpty() return end

    if self:GetOwner():IsPlayer() then
        self:GetOwner():LagCompensation( true )
    end

    local tr = util.TraceLine( {
        start = self:GetOwner():GetShootPos(),
        endpos = self:GetOwner():GetShootPos() + self:GetOwner():GetAimVector() * 64,
        filter = self:GetOwner()
    } )

    local ent = nil
    local center = tr.HitPos

    local plys = self:GetGamemodeDeadPlayerData()
    local resurrectPos = nil
    for _, data in pairs( plys ) do
        if not IsValid( data.ply ) then continue end
        --print( data.ply, data.pos )
        if data.ply:Health() > 0 then continue end
        if data.pos:DistToSqr( center ) < 75^2 then
            ent = data.ply
            resurrectPos = data.pos
            break
        end
    end

    if self:GetOwner():IsPlayer() then
        self:GetOwner():LagCompensation( false )
    end


    if IsValid( ent ) then
        self:StartResurrect( ent, resurrectPos )

        self:SetNextPrimaryFire( CurTime() + 0.5 )

    else
        self:GetOwner():EmitSound( DenySound, 75, 80 )
        self:SetNextPrimaryFire( CurTime() + 0.5 )

    end

    self:UpdateColor()

end

function SWEP:StartResurrect( ent, resurrectPos )
    self:GetOwner().blockSwitchingWeaponsReviver = true
    self.resurrecting = true
    self.toResurrect = ent
    self.toResurrectPos = resurrectPos

    self:SetNWBool( "RevivingPly", true )

    self.resurrectStartPos = self:GetOwner():GetPos()
    self.resurrectEnd = CurTime() + self.ResTime

    self:AttackAnim()

    self:GetOwner():EmitSound( HealSound, 100, 70, 1, CHAN_STATIC, SND_NOFLAGS, 10 )

    local recip = RecipientFilter( false )
    recip:AddAllPlayers()

    self.resurrectingLoop = CreateSound( self:GetOwner(), "items/medcharge4.wav", recip )
    self.resurrectingLoop:Play()

    huntersGlee_Announce( { self.toResurrect }, 5, 5, "You are being revived by " .. self:GetOwner():Name() )

end

function SWEP:ResurrectPly( ply )
    if not IsValid( ply ) then return end
    if not IsValid( self ) then return end
    local owner = self:GetOwner()
    if owner:Health() <= 0 then return end

    self:TakePrimaryAmmo( 1 )

    ply.unstuckOrigin = self.toResurrectPos

    timer.Simple( 0.1, function()
        if not IsValid( ply ) then return end
        local filterAllPlayers = RecipientFilter()
        filterAllPlayers:AddAllPlayers()
        ply:EmitSound( HealSound, 100, 90, 1, CHAN_STATIC, nil, nil, filterAllPlayers )
        ply:EmitSound( "ambient/levels/labs/electric_explosion1.wav", 100, 120, 1, CHAN_STATIC, nil, 10, filterAllPlayers )

    end )

    if owner.GivePlayerScore then
        local reward = 300
        -- dont give as much score if owner killed who they reviving
        if GAMEMODE:HasHomicided( owner, ply ) then
            reward = 150
            if not owner.glee_HomicideReviveHint then
                owner.glee_HomicideReviveHint = true
                huntersGlee_Announce( { owner }, 5, 8, "Half score for reviving, since you killed this person earlier." )

            end
        elseif not owner.glee_revivemoneyhint then
            owner.glee_revivemoneyhint = true
            huntersGlee_Announce( { owner }, 4, 8, "+" .. tostring( reward ) .. " score!" )

        end

        ply.glee_resurrectDecreasingScore = ply.glee_resurrectDecreasingScore or 0

        -- dont just resuurect the same person over and over!
        local rewardBite = ply.glee_resurrectDecreasingScore - CurTime()
        if rewardBite < 0 then
            rewardBite = 0

        end

        reward = math.Clamp( reward + -rewardBite, 0, 300 )
        owner:GivePlayerScore( reward )

        ply.glee_resurrectDecreasingScore = math.max( CurTime() + 60, ply.glee_resurrectDecreasingScore + 60 )

    end

    ply:Resurrect()
    return true

end

function SWEP:GetViewModelPosition( pos, ang )
    local offset = Vector( 0 )
    if self:Clip1() <= 0 then
        offset = Vector( 0,0,-10 )
    elseif self:GetNWBool( "RevivingPly", false ) then
        offset = Vector( 0,0,-10 )
    end
    return pos + offset, ang
end

function SWEP:Think()
    if SERVER then
        local nextRefresh = self.nextRefresh or 0
        if nextRefresh < CurTime() then
            self.nextRefresh = CurTime() + 4
            GAMEMODE:SendDeadPlayersToClients()
        end
    end

    local resurrecting = self.resurrecting and IsValid( self.toResurrect )
    local owner = self:GetOwner()

    if resurrecting then
        local ent = self.toResurrect
        local tooFar = self.resurrectStartPos:DistToSqr( owner:GetPos() ) > 75^2
        local keyDown = owner:KeyDown( IN_ATTACK )
        local cancel = tooFar or not keyDown or self.toResurrect:Health() > 0
        local done = false
        if cancel then
            done = true
            owner:EmitSound( DenySound, 75, 80 )

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
            self.resurrectEnd = nil
            self:SetNWBool( "RevivingPly", false )
        end
    end
    if not ( self.resurrecting and IsValid( self.toResurrect ) ) then
        owner.blockSwitchingWeaponsReviver = nil
    end
end

function SWEP:AttackAnim()
    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )

    -- Even though the viewmodel has looping IDLE anim at all times, we need this to make fire animation work in multiplayer
    timer.Create( "weapon_idle" .. self:EntIndex(), self:SequenceDuration(), 1, function() if ( IsValid( self ) ) then self:SendWeaponAnim( ACT_VM_IDLE ) end end )
end

function SWEP:SecondaryAttack()
    return
end

function SWEP:ShutDown()
    if self.resurrectingLoop then
        self.resurrectingLoop:Stop()
    end
    local owner = self:GetOwner()
    if IsValid( owner ) then
        owner.blockSwitchingWeaponsReviver = nil

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

function SWEP:CustomAmmoDisplay()

    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay

end

function SWEP:AddResurrect()
    self:SetClip1( self:Clip1() + 1 )
    self:UpdateColor()

end


local fadedRed = Color( 255, 25, 25 )

local function PaintBoxOnPlayer( data )
    local pos = data.pos
    if not pos then return end

    local OnScreenDat = data.pos:ToScreen()
    if not OnScreenDat.visible then return end

    local PosX = OnScreenDat.x
    local PosY = OnScreenDat.y

    local x = PosX + -50
    local y = PosY + -50

    local max = 1000
    local alpha = math.abs( math.Clamp( data.pos:Distance( LocalPlayer():GetPos() ), 400, max ) - max ) * 0.8
    alpha = math.Clamp( alpha, 120, 255 )
    local newFadedRed = ColorAlpha( fadedRed, alpha )
    surface.SetDrawColor( newFadedRed )
    surface.DrawOutlinedRect( x, y, 100, 100, 10 )

end

function SWEP:Deploy()
    if SERVER and GAMEMODE.SendDeadPlayersToClients then
        GAMEMODE:SendDeadPlayersToClients()

    end
end
if CLIENT then
    function SWEP:DrawHUD()
        local doingReviving = self:GetNWBool( "RevivingPly", false )

        if doingReviving then return end
        local ownerPos = self:GetOwner():GetPos()
        local nearestDeadPly = nil
        local deads = self:GetGamemodeDeadPlayerData()
        table.sort( deads, function( a, b )
            local dist1 = ownerPos:DistToSqr( a.pos )
            local dist2 = ownerPos:DistToSqr( b.pos )
            return dist1 < dist2
        end )
        for _, data in ipairs( deads ) do
            if not IsValid( data.ply ) then continue end
            if data.ply:Health() > 0 then continue end
            if not data.pos then continue end
            nearestDeadPly = data
            break

        end
        if nearestDeadPly then
            PaintBoxOnPlayer( nearestDeadPly )

        end

        if not huntersGlee_PaintPlayer then return end
        local nextPlayersCheck = self.nextPlayersCheck or 0
        if nextPlayersCheck < CurTime() then
            self.nextPlayersCheck = CurTime() + 1
            self.validDeads = {}

            for _, data in ipairs( deads ) do
                if not IsValid( data.ply ) then continue end
                if data.ply == LocalPlayer() then continue end
                if data.ply:Health() > 0 then continue end
                table.insert( self.validDeads, data )

            end
        end
        if self.validDeads then
            local bail = nil
            for _, deadDat in ipairs( self.validDeads ) do
                if bail then break end
                -- draw one person far away
                if deadDat.pos:DistToSqr( ownerPos ) > 1000^2 then bail = true end
                huntersGlee_PaintPlayer( deadDat.ply, deadDat.pos )

            end
        end
    end

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

if not GAMEMODE.ISHUNTERSGLEE then return end

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
    GAMEMODE.deadPlayers[victim:GetCreationID()] = { ply = victim, pos = victim:GetPos() }
    GAMEMODE:SendDeadPlayersToClients()

end )