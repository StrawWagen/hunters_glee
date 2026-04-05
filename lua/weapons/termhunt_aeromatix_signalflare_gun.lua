--AeroMatix || https://www.youtube.com/channel/UCzA_5QTwZxQarMzwZFBJIAw || http://steamcommunity.com/profiles/76561198176907257

SWEP.Base               = "termhunt_aeromatix_flare_gun"
SWEP.Author             = "Straw W Wagen"

SWEP.Spawnable          = true
SWEP.PrintName          = "Escape Signal Flare"
SWEP.Category           = "Hunter's Glee"

SWEP.HoldType           = "pistol"
SWEP.Weight             = 6
SWEP.Range              = 2000
SWEP.Slot               = 2
SWEP.SlotPos            = 3

SWEP.Purpose = "Shoot into the sky to call for... help?"

SWEP.AutoSwitchFrom     = false
SWEP.AutoSwitchTo       = true
SWEP.DrawAmmo           = true
SWEP.ViewModelFlip      = false
SWEP.BounceWeaponIcon   = true

SWEP.ViewModel          = "models/weapons/v_flaregun.mdl"
SWEP.WorldModel         = "models/weapons/w_dkflaregun.mdl" -- https://steamcommunity.com/sharedfiles/filedetails/?id=1623971250

local className = "termhunt_aeromatix_signalflare_gun"
if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, className, "materials/vgui/hud/killicon/" .. className .. ".png" )
    language.Add( "GLEE_SIGNALFLAREGUN_PLAYER_ammo", "Escape Signal Flare" )

end

SWEP.Primary.Sound = Sound( "weapons/flaregun/fire.wav" )
SWEP.Primary.Ammo            = "GLEE_SIGNALFLAREGUN_PLAYER"
SWEP.Primary.NumShots = 1
SWEP.Primary.ClipSize =  1
SWEP.Primary.DefaultClip =  1
SWEP.Primary.Automatic = false
SWEP.Primary.Delay = 1

SWEP.Secondary.Sound = nil
SWEP.Secondary.Ammo = ""
SWEP.Secondary.NumShots = 1
SWEP.Secondary.ClipSize            = 0
SWEP.Secondary.DefaultClip        = 0
SWEP.Secondary.Automatic = false
SWEP.Secondary.Delay = 1

function SWEP:ShootFlare()
    if not SERVER then return end
    local owner = self:GetOwner()

    local flare = ents.Create( "termhunt_signalflare" )
    if not IsValid( flare ) then return end

    owner:ViewPunch( Angle( -10, 0, 0 ) )

    local offsettedPos, dirToShoot = self:GetProjectileOffset()

    flare:SetAngles( dirToShoot:Angle() )
    flare:Spawn()

    flare.MyOwner = owner

    flare:SetPos( offsettedPos )
    local obj = flare:GetPhysicsObject()
    if IsValid( obj ) then
        obj:SetVelocity( dirToShoot * 48000 )

    end

    owner:EmitSound( "Weapon_FlareGun.Single", 80, 100, 1, CHAN_STATIC  )

    -- ECHO echo echo ehco
    local filter = RecipientFilter()
    filter:AddAllPlayers()

    local flareSound = CreateSound( self, "Weapon_FlareGun.Single", filter )
    flareSound:SetDSP( 22 )
    flareSound:SetSoundLevel( 150 )
    flareSound:PlayEx( 1, 40 )

    local flareSourcePos = owner:GetShootPos()

    local hintTimerName = "glee_signalflare_hint_" .. owner:GetCreationID()
    timer.Create( hintTimerName, 2, 10, function()
        sound.EmitHint( SOUND_COMBAT, flareSourcePos, 6000, 1, owner )

    end )

    hook.Run( "glee_signalflare_shoot", owner, self, flare )

end

function SWEP:CanBePickedUpByNPCs()
    return true

end

if not CLIENT then return end

local blueFlaregunWMat = Material( "models/weapons/dk_flaregun/signal_gm.vmt" )

local posOffset = Vector( 4, 0, 3 )
local angOffset = Angle( 0, 180, -90 )

function SWEP:DrawWorldModel()
    local owner = self:GetOwner()
    if IsValid( owner ) and owner:GetActiveWeapon() == self then
        local attachId = owner:LookupAttachment( "anim_attachment_RH" )
        if attachId <= 0 then return end
        local attachTbl = owner:GetAttachment( attachId )
        local posOffsetW, angOffsetW = LocalToWorld( posOffset, angOffset, attachTbl.Pos, attachTbl.Ang )
        self:SetPos( posOffsetW )
        self:SetAngles( angOffsetW )

        self:SetupBones()

    end
    render.MaterialOverrideByIndex( 0, blueFlaregunWMat )
    self:DrawModel()

end

local blueFlaregunVMat = Material( "models/weapons/v_flaregun/signal_flaregun_sheet.vmt" )

function SWEP:PreDrawViewModel()
    render.MaterialOverrideByIndex( 1, blueFlaregunVMat )

end