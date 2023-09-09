--AeroMatix || https://www.youtube.com/channel/UCzA_5QTwZxQarMzwZFBJIAw || http://steamcommunity.com/profiles/76561198176907257

SWEP.Author             = "AeroMatix" -- + edited by straw w wagen

SWEP.Spawnable          = true
SWEP.PrintName          = "Flare Gun"
SWEP.Category           = "Hunter's Glee"
SWEP.InventoryIcon      = "flaregun_hud"

SWEP.HoldType           = "pistol"
SWEP.Weight             = 3
SWEP.Range              = 2000
SWEP.Slot               = 1
SWEP.SlotPos            = 3

SWEP.AutoSwitchFrom     = true
SWEP.DrawAmmo           = true
SWEP.ViewModelFlip      = false
SWEP.BounceWeaponIcon   = false

SWEP.ViewModel          = "models/weapons/v_flaregun.mdl"
SWEP.WorldModel         = "models/weapons/w_357.mdl"

if CLIENT then
    language.Add( "GLEE_FLAREGUN_PLAYER_ammo", "Flare" )

end

game.AddAmmoType( {
    name = "GLEE_FLAREGUN_PLAYER", -- Note that whenever picked up, the localization string will be '#BULLET_PLAYER_556MM_ammo'
    dmgtype = DMG_BURN,
    tracer = TRACER_NONE,
    plydmg = 0, -- This can either be a number or a ConVar name.
    npcdmg = 0, -- Ditto.
    force = 0,
    maxcarry = 10, -- Ditto.
    minsplash = 0,
    maxsplash = 0
} )

SWEP.Primary.Sound = Sound( "weapons/flaregun/fire.wav" )
SWEP.Primary.Ammo            = "GLEE_FLAREGUN_PLAYER"
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize =  1
SWEP.Primary.DefaultClip =  2
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1

SWEP.Secondary.Sound = nil
SWEP.Secondary.Ammo = ""
SWEP.Secondary.NumShots = 1
SWEP.Secondary.ClipSize            = 0
SWEP.Secondary.DefaultClip        = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1

function SWEP:GetProjectileOffset()
    local owner = self:GetOwner()
    local aimVec = owner:GetAimVector()
    return owner:GetShootPos() + aimVec * 25, aimVec

end

function SWEP:CanPrimaryAttack()
    local owner = self:GetOwner()
    if owner:IsPlayer() then return true end
    if not terminator_Extras.PosCanSeeComplex( owner:GetShootPos(), self:GetProjectileOffset(), self, MASK_SOLID ) then return end

    if not owner.NothingOrBreakableBetweenEnemy then return end

    return CurTime() >= self:GetNextPrimaryFire() and self:Clip1() > 0

end

function SWEP:PrimaryAttack()
    if not self:CanPrimaryAttack() then return end
    if self:Clip1() <= 0 then
        if IsFirstTimePredicted() then
            self:EmitSound( "Weapon_Pistol.Empty" )

        end
        return

    end
    self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
    self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay )
    self:ShootFlare()
    self:SetClip1( self:Clip1() -1 )
    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )

    if self:Clip1() == 0 then
        self:DefaultReload( ACT_VM_RELOAD )
    end
end

function SWEP:ShootFlare()
    if not SERVER then return end
    local owner = self:GetOwner()

    local flare = ents.Create( "termhunt_flare" )
    if not IsValid( flare ) then return end

    owner:ViewPunch( Angle( -10,0,0 ) )

    local offsettedPos, dirToShoot = self:GetProjectileOffset()

    flare:SetAngles( dirToShoot:Angle() )
    flare:Spawn()

    flare:SetPos( offsettedPos )
    local obj = flare:GetPhysicsObject()
    if IsValid( obj ) then
        obj:SetVelocity( dirToShoot * 32000 )

    end

    owner:EmitSound( "Weapon_FlareGun.Single", 90, 100, 1, CHAN_STATIC  )

    -- ECHO echo echo ehco
    local filter = RecipientFilter()
    filter:AddAllPlayers()

    local flareSound = CreateSound( self, "Weapon_FlareGun.Single", filter )
    flareSound:SetDSP( 22 )
    flareSound:SetSoundLevel( 140 )
    flareSound:PlayEx( 0.8, 60 )

    sound.EmitHint( SOUND_COMBAT, owner:GetShootPos(), 6000, 1, owner )

end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    if CLIENT then
        local oldpath = "vgui/hud/name"
        local newpath = string.gsub( oldpath, "name", self.InventoryIcon )
        self.WepSelectIcon = surface.GetTextureID( newpath )
    end
end

function SWEP:Equip()
end

function SWEP:OwnerChanged()
end

function SWEP:OnDrop()
end

function SWEP:CanBePickedUpByNPCs()
    return true
end

function SWEP:GetNPCBulletSpread( _ )
    return 0
end

function SWEP:GetNPCBurstSettings()
    return 1,1,0.001
end

function SWEP:GetNPCRestTimes()
    return 2,4
end

function SWEP:GetCapabilities()
    return CAP_WEAPON_RANGE_ATTACK1
end

function SWEP:DrawWorldModel()
end


if not CLIENT then return end
local red = Color( 255, 50, 50, 255 )

function SWEP:DrawWorldModel()
    self:SetColor( red )
    self:DrawModel()

end