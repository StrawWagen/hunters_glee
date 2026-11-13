-- https://steamcommunity.com/sharedfiles/filedetails/?id=158421055 at 12/11/2026 DD/MM/YYYY -dedactedlife

if ( SERVER ) then

	AddCSLuaFile( "shared.lua" )
	
	SWEP.HoldType			= "pistol"
	
end

if ( CLIENT ) then

	SWEP.PrintName			= "Sexyness"
	SWEP.Author			= "2-bit, glee'd by dedactedlife"

	SWEP.Slot			= 1
	SWEP.SlotPos			= 1
	SWEP.iconletter			= "f"
	
	local Color_Icon = Color( 255, 80, 0, 128 )

end

SWEP.Base			= "weapon_base"

SWEP.Spawnable			= true
SWEP.AdminSpawnable		= true
SWEP.AdminOnly = true

SWEP.ViewModel			= "models/glee/weapons/sexyness/v_pist_weagon.mdl"
SWEP.WorldModel			= "models/glee/weapons/sexyness/w_pist_weagon.mdl"
SWEP.ViewModelFlip 		= true

SWEP.Weight			= 5
SWEP.AutoSwitchTo		= false
SWEP.AutoSwitchFrom		= false

SWEP.HoldType = "Pistol" -- How the swep is hold Pistol smg greanade melee 
 
SWEP.FiresUnderwater = true -- Does your swep fire under water ? 
 
SWEP.Weight = 5 -- Chose the weight of the Swep 
 
SWEP.DrawCrosshair = true -- Do you want it to have a crosshair ? 
 
SWEP.Category = "Hunter's Glee"
 
SWEP.DrawAmmo = true -- Does the ammo show up when you are using it ? True / False 
 
SWEP.ReloadSound = "sound/weapons/alyxgun/alyx_gun_reload.wav" -- Reload sound, you can use the default ones, or you can use your one; Example; "sound/myswepreload.waw" 
 
SWEP.base = "weapon_base" 

SWEP.Primary.Sound = "weapons/automag/deagle-1.wav"
SWEP.Primary.Damage = 99999999999 -- How much damage the swep is doing 
SWEP.Primary.TakeAmmo = 1 -- How much ammo does it take for each shot ? 
SWEP.Primary.ClipSize = 9999999 -- The clipsize 
SWEP.Primary.Ammo = "Pistol" -- ammmo type pistol/ smg1 
SWEP.Primary.DefaultClip = 9999999 -- How much ammo does the swep come with `? 
SWEP.Primary.Spread = 0.25 -- Does the bullets spread all over, if you want it fire exactly where you are aiming leave it 0.1 
SWEP.Primary.NumberofShots = 75 -- How many bullets you are firing each shot. 
SWEP.Primary.Automatic = true -- Is the swep automatic ? 
SWEP.Primary.Recoil = 0 -- How much we should punch the view 
SWEP.Primary.Delay = 0.05 -- How long time before you can fire again 
SWEP.Primary.Force = 1000000 -- The force of the shot 

SWEP.Secondary.Sound = "weapons/automag/deagle-1.wav"
SWEP.Secondary.Damage = 9999999 -- How much damage the swep is doing 
SWEP.Secondary.TakeAmmo = 1 -- How much ammo does it take for each shot ? 
SWEP.Secondary.ClipSize = 9999999 -- The clipsize 
SWEP.Secondary.Ammo = "Pistol" -- ammmo type pistol/ smg1 
SWEP.Secondary.DefaultClip = 9999999 -- How much ammo does the swep come with `? 
SWEP.Secondary.Spread = 0.1 -- Does the bullets spread all over, if you want it fire exactly where you are aiming leave it 0.1 
SWEP.Secondary.NumberofShots = 1 -- How many bullets you are firing each shot. 
SWEP.Secondary.Automatic = true -- Is the swep automatic ? 
SWEP.Secondary.Recoil = 0.0 -- How much we should punch the view 
SWEP.Secondary.Delay = 0.05 -- How long time before you can fire again 
SWEP.Secondary.Force = 1000000 -- The force of the shot 

function SWEP:Initialize() 
	util.PrecacheSound(self.Primary.Sound) 
	util.PrecacheSound(self.Secondary.Sound) 
        self:SetWeaponHoldType( self.HoldType )
end 

function SWEP:PrimaryAttack() 
	if ( !self:CanPrimaryAttack() ) then return end 
 
	local bullet = {} 
		bullet.Num = self.Primary.NumberofShots 
		bullet.Src = self.Owner:GetShootPos() 
		bullet.Dir = self.Owner:GetAimVector() 
		bullet.Spread = Vector( self.Primary.Spread * 0.1 , self.Primary.Spread * 0.1, 0) 
		bullet.Tracer = 0 
		bullet.Force = self.Primary.Force 
		bullet.Damage = self.Primary.Damage 
		bullet.AmmoType = self.Primary.Ammo 
 
	local rnda = self.Primary.Recoil * -1 
	local rndb = self.Primary.Recoil * math.random(-1, 1) 
 
	self:ShootEffects() 
 
	self.Owner:FireBullets( bullet ) 
	self:EmitSound(Sound(self.Primary.Sound)) 
	self.Owner:ViewPunch( Angle( rnda,rndb,rnda ) ) 
	self:TakePrimaryAmmo(self.Primary.TakeAmmo) 
 
	self:SetNextPrimaryFire( CurTime() + self.Primary.Delay )
	self:SetNextSecondaryFire( CurTime() + self.Primary.Delay ) 
end 

function SWEP:SecondaryAttack() 
	if ( !self:CanSecondaryAttack() ) then return end 
 
	local rnda = -self.Secondary.Recoil 
	local rndb = self.Secondary.Recoil * math.random(-1, 1) 
 
	self.Owner:ViewPunch( Angle( rnda,rndb,rnda ) ) 
	local eyetrace = self.Owner:GetEyeTrace() 
	self:EmitSound ( self.Secondary.Sound ) 
	self:ShootEffects() 
	if SERVER then
		local ent =  ents.Create ("env_explosion")
			ent:SetPos( eyetrace.HitPos ) 
			ent:SetOwner( self.Owner ) 
			ent:Spawn() 
			ent:SetKeyValue("iMagnitude","175") 
			ent:Fire("Explode", 0, 0 ) 
			ent:EmitSound("weapon_AWP.Single", 400, 400 ) 
	 
		self:SetNextPrimaryFire( CurTime() + self.Secondary.Delay ) 
		self:SetNextSecondaryFire( CurTime() + self.Secondary.Delay ) 
		self:TakePrimaryAmmo(self.Secondary.TakeAmmo) 
	end
end 
