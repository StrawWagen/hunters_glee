--AeroMatix || https://www.youtube.com/channel/UCzA_5QTwZxQarMzwZFBJIAw || http://steamcommunity.com/profiles/76561198176907257

SWEP.Author = "AeroMatix" -- + edited by straw w wagen
SWEP.Contact = ""
SWEP.Gun = "flaregun_hud"

SWEP.Weight                = 5
SWEP.AutoSwitchTo        = true
SWEP.AutoSwitchFrom        = false
SWEP.HoldType            = "pistol"
SWEP.Category             = "Hunter's Glee"
SWEP.PrintName             = "Flare Gun"

SWEP.Slot = 1
SWEP.SlotPos = 3
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true
SWEP.ViewModelFOV = 65
SWEP.ViewModelFlip = false
SWEP.Spawnable = true
SWEP.AdminSpawnable = false
SWEP.BounceWeaponIcon       = false

SWEP.ViewModel = "models/weapons/v_flaregun.mdl"
SWEP.WorldModel = "models/weapons/w_357.mdl"

terminator_Extras.SetupAnalogWeight( SWEP )

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

SWEP.Range = 2000

function SWEP:PrimaryAttack()
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

    -- echo
    local filter = RecipientFilter()
    filter:AddAllPlayers()
    local owner = self:GetOwner()

    if not IsValid( owner ) then SafeRemoveEntity( self ) return end

    owner:EmitSound( "Weapon_FlareGun.Single", 90, 100, 1, CHAN_STATIC  )

    local flareSound = CreateSound( self, "Weapon_FlareGun.Single", filter )
    flareSound:SetDSP( 22 )
    flareSound:SetSoundLevel( 140 )
    flareSound:PlayEx( 0.8, 60 )

    SafeRemoveEntityDelayed( Flare1, 12 )

    sound.EmitHint( SOUND_COMBAT, owner:GetShootPos(), 6000, 1, owner )

    local flare = ents.Create( "termhunt_flare" )
    if not IsValid( flare ) then return end

    flare:SetAngles( owner:GetAimVector():Angle() )
    flare:Spawn()

    flare:SetPos( owner:GetShootPos() )
    local obj = flare:GetPhysicsObject()
    if IsValid( obj ) then
        obj:SetVelocity( self:GetForward() * 32000 )

    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    if CLIENT then
        local oldpath = "vgui/hud/name"
        local newpath = string.gsub( oldpath, "name", self.Gun )
        self.WepSelectIcon = surface.GetTextureID( newpath )
    end
end

function SWEP:Equip()
    self:SetHoldType( self.HoldType )

end

function SWEP:OwnerChanged()
end

function SWEP:OnDrop()
end

function SWEP:CanBePickedUpByNPCs()
    return true
end

function SWEP:GetNPCBulletSpread(prof)
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