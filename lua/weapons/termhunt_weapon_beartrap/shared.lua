if CLIENT then
    SWEP.DrawCrosshair   = false
    SWEP.Slot      = 2
    SWEP.ViewModelFlip        = false
    SWEP.ViewModelFOV        = 54

end

SWEP.Base = "weapon_base"

SWEP.HoldType = "normal"
SWEP.PrintName = "Beartrap"
SWEP.Purpose = "Snap!"
SWEP.ViewModel  = "models/stiffy360/c_beartrap.mdl"
SWEP.WorldModel  = "models/stiffy360/beartrap.mdl"
SWEP.UseHands    = true

SWEP.AutoSwitchTo    = false
SWEP.AutoSwitchFrom    = true

SWEP.Weight         = terminator_Extras.GoodWeight
SWEP.Spawnable        = true
SWEP.AdminSpawnable    = false
SWEP.Category = "Hunter's Glee"

SWEP.Primary.ClipSize = 100
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "termhunt_weapon_beartrap", "materials/vgui/hud/killicon/termhunt_bear_trap.png" )
    function SWEP:GetViewModelPosition( pos, ang )
        return pos + ang:Forward() * 5, ang
    end
end

if SERVER then
    resource.AddFile( "materials/VGUI/ttt/icon_beartrap.vmt" )

    resource.AddFile( "materials/models/freeman/beartrap_diffuse.vtf" )
    resource.AddFile( "materials/models/freeman/beartrap_specular.vtf" )
    resource.AddFile( "materials/models/freeman/trap_dif.vmt" )

    resource.AddFile( "sound/beartrap.wav" )

    resource.AddFile( "models/stiffy360/beartrap.mdl" )

    resource.AddFile( "models/stiffy360/c_beartrap.mdl" )

    resource.AddFile( "materials/entities/termhunt_weapon_beartrap.png" )

end

function SWEP:Initialize()
    self.huntersglee_allowpickup = true
    self:SetHoldType( self.HoldType )

end

function SWEP:Deploy()
    if not CLIENT then return true end
    self:DrawWorldModel( false )

end

function SWEP:Equip()
    self:SetClip1( 0 )
    self:Charge()

end

if SERVER then
    AddCSLuaFile()

end

SWEP.termPlace_PlacingRange = 150

function SWEP:ValidPlace()
    local owner = self:GetOwner()
    local traceStruct = {
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.termPlace_PlacingRange,
        filter = owner
    }
    local tr = util.TraceLine( traceStruct )
    if not tr.Hit then return end

    return true, tr

end

function SWEP:CustomAmmoDisplay()

    self.AmmoDisplay = self.AmmoDisplay or {}
    self.AmmoDisplay.Draw = true
    self.AmmoDisplay.PrimaryClip = self:Clip1()

    return self.AmmoDisplay

end

function SWEP:Charge()
    self:SetClip1( self:Clip1() + 1 )

end

local gunCock = Sound( "items/ammo_pickup.wav" )

function SWEP:EquipAmmo( newOwner )
    local theirWeap = newOwner:GetWeapon( self:GetClass() )
    theirWeap:SetClip1( theirWeap:Clip1() + 1 )
    newOwner:EmitSound( gunCock, 60, math.random( 90, 110 ) )

end

function SWEP:CanPrimaryAttack()
    return self:GetNextPrimaryFire() < CurTime()

end

util.PrecacheModel( "models/stiffy360/beartrap.mdl" )

function SWEP:DoGhost()
    self.beartrapGhost = ClientsideModel( "models/stiffy360/beartrap.mdl", RENDERGROUP_BOTH )
    self.beartrapGhost:Spawn()

end

function SWEP:Think()
    if self:Clip1() <= 0 then return end
    if CLIENT then
        local owner = self:GetOwner()
        if owner ~= LocalPlayer() then return end
        if self:Clip1() <= 0 then
            self:DeGhost()
            return

        end
        if not IsValid( self.beartrapGhost ) then
            self:DoGhost()

        else
            local canPlace, tr = self:ValidPlace()
            if not canPlace then return end
            local ang = tr.HitNormal:Angle()
            ang:RotateAroundAxis( ang:Right(), -90 )

            self.beartrapGhost:SetPos( tr.HitPos )
            self.beartrapGhost:SetAngles( ang )
        end
    elseif SERVER and self:GetOwner():KeyDown( IN_ATTACK ) then
        if not self:CanPrimaryAttack() then return end

        local canPlace, tr = self:ValidPlace()

        if canPlace ~= true then
            self:SetNextPrimaryFire( CurTime() + 0.5 )
            return

        end

        local step = 18
        local progBarStatus = generic_WaitForProgressBar( self:GetOwner(), "termhunt_weapon_beartrap_place", 0.25, step )

        if isnumber( progBarStatus ) and progBarStatus <= step and progBarStatus ~= self.oldplaceStatus then
            self:GetOwner():EmitSound( "physics/metal/metal_box_strain2.wav", 65, 130 )

        end
        self.oldplaceStatus = progBarStatus

        if progBarStatus < 100 then return end

        generic_KillProgressBar( self:GetOwner(), "termhunt_weapon_beartrap_place" )
        self:Place( tr )

    end
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    if not owner:IsNextBot() then return end
    local canPlace, tr = self:ValidPlace()
    if not canPlace then return end
    self:SetClip1( 1 )
    local placed = self:Place( tr )
    placed.usedByTerm = true

end

function SWEP:Place( tr )
    self:SetNextPrimaryFire( CurTime() + 0.5 )

    local owner = self:GetOwner()
    local beartrap = GAMEMODE:SpawnABearTrap( tr.HitPos, tr )
    beartrap:SetCreator( owner )
    beartrap:Spawn()

    beartrap:EmitSound( "physics/metal/metal_solid_impact_hard5.wav", 65, 80 )

    self:SetClip1( self:Clip1() + -1 )

    if self:Clip1() > 0 then return beartrap end

    timer.Simple( 0.5, function()
        if not IsValid( self ) then return end
        if not IsValid( self:GetOwner() ) then return end
        --- AAAAAHH
        if not self:GetOwner().SwitchToDefaultWeapon then return end
        self:GetOwner():SwitchToDefaultWeapon()
        if not self:GetOwner().StripWeapon then return end
        self:GetOwner():StripWeapon( self:GetClass() )

    end )
    return beartrap

end

function SWEP:SecondaryAttack()
end

function SWEP:Reload()
end

function SWEP:DeGhost()
    SafeRemoveEntity( self.beartrapGhost )

end

function SWEP:Holster()
    if CLIENT then
        self:DeGhost()
    end
    return true
end

function SWEP:OnRemove()
    if CLIENT then
        self:DeGhost()

    end
end


local vec_up = Vector( 0, 0, 1 )
SWEP.termPlace_MaxAreaSize = 100

local nookDirections2dDirs = {
    Vector( 1, 0, 0 ),
    Vector( 0.5, 0.5, 0 ),
    Vector( 0, 1, 0 ),
    Vector( -0.5, 0.5, 0 ),
    Vector( -1, 0, 0 ),
    Vector( -0.5, -0.5, 0 ),
    Vector( 0, -1, 0 ),
    Vector( 0.5, -0.5, 0 ),
}

function SWEP:termPlace_ScoringFunc( owner, checkPos )
    local nookScore = terminator_Extras.GetNookScore( checkPos, 100, nookDirections2dDirs )
    local score = nookScore
    score = score + math.Rand( -0.2, 0.2 )
    if checkPos:DistToSqr( owner:GetPos() ) < 350^ 2 then
        score = score + -1

    end
    --debugoverlay.Text( checkPos, tostring( score ), 5, false )
    return score

end

local nookDirectionsPlace = {
    Vector( 1, 0, -0.5 ),
    Vector( 0.5, 0.5, -0.5 ),
    Vector( 0, 1, -0.5 ),
    Vector( -0.5, 0.5, -0.5 ),
    Vector( -1, 0, -0.5 ),
    Vector( -0.5, -0.5, -0.5 ),
    Vector( 0, -1, -0.5 ),
    Vector( 0.5, -0.5, -0.5 ),
    Vector( 1, 0, -0.75 ),
    Vector( 0.5, 0.5, -0.75 ),
    Vector( 0, 1, -0.75 ),
    Vector( -0.5, 0.5, -0.75 ),
    Vector( -1, 0, -0.75 ),
    Vector( -0.5, -0.5, -0.75 ),
    Vector( 0, -1, -0.75 ),
    Vector( 0.5, -0.5, -0.75 ),
}

function SWEP:termPlace_PlacingFunc( owner )
    local _, hits = terminator_Extras.GetNookScore( owner:GetShootPos(), 500, nookDirectionsPlace )
    local shortestIndex = 1
    for fraction, tr in pairs( hits ) do
        local dot = vec_up:Dot( tr.HitNormal )
        if not ( dot > 0.55 and dot <= 1 ) then continue end

        local foundArea = navmesh.GetNavArea( tr.HitPos, 250 )
        if not foundArea then continue end
        if math.max( foundArea:GetSizeX(), foundArea:GetSizeY() ) > self.termPlace_MaxAreaSize then continue end

        -- find shortest tr
        if fraction <= shortestIndex then shortestIndex = fraction end

    end
    if shortestIndex >= 1 then return owner:GetPos() + owner:GetAimVector() * 100 end
    return hits[shortestIndex].HitPos

end


if not CLIENT then return end

local posOffset = Vector( 0, 0, 0 )
local angOffset = Angle( 0, -90, -90 )

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    if IsValid( owner ) then
        local attachId = owner:LookupAttachment( "anim_attachment_RH" )
        if attachId <= 0 then return end
        local attachTbl = owner:GetAttachment( attachId )
        local posOffsetW, angOffsetW = LocalToWorld( posOffset, angOffset, attachTbl.Pos, attachTbl.Ang )
        self:SetPos( posOffsetW )
        self:SetAngles( angOffsetW )

    else
        self:SetSequence( "ClosedIdle" )

    end
    self:DrawModel()

end