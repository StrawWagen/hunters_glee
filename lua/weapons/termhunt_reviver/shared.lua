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
    if ply.blockSwitchingWeaponsReviver then return true end
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

        self:SetNextPrimaryFire( CurTime() + self:SequenceDuration() + 0.5 )

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

function SWEP:ResurrectPly( ent )
    if not IsValid( ent ) then return end
    if not IsValid( self ) then return end
    if self:GetOwner():Health() <= 0 then return end

    self:TakePrimaryAmmo( 1 )

    ent.unstuckOrigin = self.toResurrectPos

    self:GetOwner():EmitSound( HealSound, 100, 90, 1, CHAN_STATIC )
    self:GetOwner():EmitSound( "ambient/levels/labs/electric_explosion1.wav", 100, 120, 1, CHAN_STATIC, SND_NOFLAGS, 10 )

    if self:GetOwner().GivePlayerScore then
        self:GetOwner():GivePlayerScore( 200 )

    end

    if ent.Resurrect then
        ent:Resurrect()

        return true
    end

    ent:Spawn()
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        ent:SetPos( ent.unstuckOrigin )
        ent.unstuckOrigin = nil
    end )

    self:AttackAnim()
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
    if resurrecting then
        local ent = self.toResurrect
        local tooFar = self.resurrectStartPos:DistToSqr( self:GetOwner():GetPos() ) > 75^2
        local keyDown = self:GetOwner():KeyDown( IN_ATTACK )
        local cancel = tooFar or not keyDown or self.toResurrect:Health() > 0
        local done = false
        if cancel then
            done = true
            self:GetOwner():EmitSound( DenySound, 75, 80 )
        elseif self.resurrectEnd < CurTime() then
            self:ResurrectPly( ent )
            done = true
        else
            local nextSound = self.nextResurrectSound or 0
            local InvertedDone = math.abs( ( self.resurrectEnd - CurTime() ) - self.ResTime )

            if nextSound < CurTime() then
                self.nextResurrectSound = CurTime() + math.Rand( 0.5, 0.8 )
                local ampUp = math.abs( InvertedDone * self.ResTime )
                local pitch = ampUp + math.random( 80, 90 )
                self:GetOwner():EmitSound( "Flesh.ImpactSoft", 75, pitch )

            end
            local PercentDone = InvertedDone / self.ResTime
            PercentDone = math.Round( PercentDone * 100 )

            self:SetNWInt( "RevivingPercent", PercentDone )
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
        self:GetOwner().blockSwitchingWeaponsReviver = nil
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


local resurrectBar = Color( 240, 240, 240, 200 )
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
    alpha = math.Clamp( alpha, 100, 255 )
    local newFadedRed = ColorAlpha( fadedRed, alpha )
    surface.SetDrawColor( newFadedRed )
    surface.DrawOutlinedRect( x, y, 100, 100, 10 )

end

local function PaintProgressBar( percent )
    local PosX = ScrW() / 2
    local PosY = ScrH() / 2

    local x = PosX + -200
    local y = PosY + 110

    surface.SetDrawColor( resurrectBar )
    surface.DrawRect( x, y, percent * 4, 50 )

end

function SWEP:Deploy()
    if SERVER and GAMEMODE.SendDeadPlayersToClients then
        GAMEMODE:SendDeadPlayersToClients()
    end
end

local paintDeadOverride = Color( 100,250,250 )

function SWEP:DrawHUD()

    local doingReviving = self:GetNWBool( "RevivingPly", false )
    if doingReviving then
        local revivePercent = self:GetNWInt( "RevivingPercent", -1 )
        PaintProgressBar( revivePercent )
    else
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
            for _, deadDat in ipairs( self.validDeads ) do
                huntersGlee_PaintPlayer( deadDat.ply, deadDat.pos )

            end
        end
    end
end
