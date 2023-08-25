if CLIENT then
    SWEP.DrawCrosshair   = false
    SWEP.Slot      = 4
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
    function SWEP:GetViewModelPosition( pos, ang )
        return pos + ang:Forward() * 5, ang
    end
end

if SERVER then

    resource.AddFile( "materials/VGUI/ttt/icon_beartrap.vmt" )
    resource.AddFile( "materials/VGUI/ttt/icon_beartrap.vtf" )

    resource.AddFile( "materials/models/freeman/beartrap_diffuse.vtf" )
    resource.AddFile( "materials/models/freeman/beartrap_specular.vtf" )
    resource.AddFile( "materials/models/freeman/trap_dif.vmt" )

    resource.AddFile( "sound/beartrap.wav" )

    resource.AddFile( "models/stiffy360/BearTrap.dx80.vtx" )
    resource.AddFile( "models/stiffy360/BearTrap.dx90.vtx" )
    resource.AddFile( "models/stiffy360/beartrap.mdl" )
    resource.AddFile( "models/stiffy360/BearTrap.phy" )
    resource.AddFile( "models/stiffy360/BearTrap.sw.vtx" )
    resource.AddFile( "models/stiffy360/beartrap.vvd" )
    resource.AddFile( "models/stiffy360/BearTrap.xbox.vtx" )

    resource.AddFile( "models/stiffy360/C_BearTrap.dx80.vtx" )
    resource.AddFile( "models/stiffy360/C_BearTrap.dx90.vtx" )
    resource.AddFile( "models/stiffy360/c_beartrap.mdl" )
    resource.AddFile( "models/stiffy360/C_BearTrap.sw.vtx" )
    resource.AddFile( "models/stiffy360/c_beartrap.vvd" )
    resource.AddFile( "models/stiffy360/C_BearTrap.xbox.vtx" )

    resource.AddFile( "materials/entities/termhunt_weapon_beartrap.png" )

end

function SWEP:Initialize()
    self.huntersglee_allowpickup = true

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

function SWEP:ValidPlace()
    local owner = self:GetOwner()
    local traceStruct = {
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 150,
        filter = owner
    }
    local tr = util.TraceLine( traceStruct )
    if not tr.HitWorld then return end

    local dot = vector_up:Dot( tr.HitNormal )
    if not ( dot > 0.55 and dot <= 1 ) then return end

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

function SWEP:PrimaryAttack()
end

util.PrecacheModel( "models/stiffy360/beartrap.mdl" )

function SWEP:DoGhost()
    self.beartrapGhost = ClientsideModel( "models/stiffy360/beartrap.mdl", RENDERGROUP_BOTH )
    self.beartrapGhost:Spawn()

end

function SWEP:Think()
    if CLIENT then
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

        local step = 20
        local progBarStatus = generic_WaitForProgressBar( self:GetOwner(), "termhunt_weapon_beartrap_place", 0.25, step )

        if isnumber( progBarStatus ) and progBarStatus <= step and progBarStatus ~= self.oldplaceStatus then
            self:GetOwner():EmitSound( "physics/metal/metal_box_strain2.wav", 65, 130 )

        end
        self.oldplaceStatus = progBarStatus

        if progBarStatus < 100 then return end

        self:SetNextPrimaryFire( CurTime() + 0.5 )

        local owner = self:GetOwner()
        local ent = ents.Create( "termhunt_bear_trap" )
        ent:SetPos( tr.HitPos + tr.HitNormal )
        local ang = tr.HitNormal:Angle()
        ang:RotateAroundAxis( ang:Right(), -90 )
        ent:SetAngles( ang )
        ent:SetCreator( owner )
        ent:Spawn()

        ent:EmitSound( "physics/metal/metal_solid_impact_hard5.wav", 65, 80 )

        self:SetClip1( self:Clip1() + -1 )

        if self:Clip1() > 0 then return end

        self:GetOwner():SwitchToDefaultWeapon()
        self:GetOwner():StripWeapon( self:GetClass() )
    end
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
    self:DeGhost()
end