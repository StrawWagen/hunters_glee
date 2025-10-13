SWEP.PrintName = "Emplacement Gun"
SWEP.Author = "Boomeritaintaters + gaming98"
SWEP.Instructions = "I want revenge. I want them to know that death is coming - John Rambo" 
SWEP.Category = "Hunter's Glee"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = 400
SWEP.Primary.DefaultClip = 400
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "ar2"

SWEP.Secondary.Ammo = "none"

SWEP.Weight = 10
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 2
SWEP.SlotPos = 3
SWEP.DrawAmmo = true
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/tfa_mmod/c_ar3.mdl"
SWEP.WorldModel = "models/weapons/tfa_mmod/w_ar3.mdl"

SWEP.UseHands = true

SWEP.ShootSound = ("weapons/ar1/ar1_dist1.wav")

function SWEP:Deploy()
    self.Weapon:EmitSound("weapons/ar3/ar3_deploy.wav")
    self.deploying = true
    self.deployTime = CurTime() + 1.0
    return true
end

function SWEP:PrimaryAttack()
    local ply = self:GetOwner()
    
    if self:Clip1() <= 0 then
        self:EmitSound("Weapon_Pistol.Empty")
        self:SetNextPrimaryFire(CurTime() + 0.2)
        return
    end

    self:SetNextPrimaryFire(CurTime() + 0.0615)
    self:ShootBullet(math.random(15, 25), 1, 0.03)
    self:EmitSound(self.ShootSound)
    self:TakePrimaryAmmo(1)
    
    if IsValid(ply) then
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
    self:SetHoldType("physgun")
end

function SWEP:Think()
    self:NextThink(CurTime())
    return true
end

function SWEP:DoImpactEffect(tr, nDamageType)
    if tr.HitSky then return true end
    
    local effectdata = EffectData()
    effectdata:SetOrigin(tr.HitPos)
    effectdata:SetNormal(tr.HitNormal)
    util.Effect("AR2Impact", effectdata)
    
    return true
end

function SWEP:Reload()
    if self:Clip1() >= self.Primary.ClipSize then return end
    if self:GetOwner():GetAmmoCount(self.Primary.Ammo) <= 0 then return end
    if self.Reloading then return end
    
    self.Reloading = true
    
    
    local vm = self:GetOwner():GetViewModel()
    if IsValid(vm) then
        vm:SendViewModelMatchingSequence(11)
    end
    
    self:SetNextPrimaryFire(CurTime() + 3.1)
    
    timer.Create("fart" .. self:EntIndex(), 1.3, 1, function()
        if not IsValid(self) then return end
        
        self:EmitSound("weapons/shotgun/shotgun_cock.wav")
        
        local ammo = math.min(self.Primary.ClipSize - self:Clip1(), self:GetOwner():GetAmmoCount(self.Primary.Ammo))
        self:SetClip1(self:Clip1() + ammo)
        self:GetOwner():RemoveAmmo(ammo, self.Primary.Ammo)
        
        self.Reloading = false
    end)
end

function SWEP:ShootBullet(damage, numBullets, aimcone)
    local ply = self:GetOwner()
    
    local bullet = {}
    bullet.Num = numBullets
    bullet.Src = ply:GetShootPos()
    bullet.Dir = ply:GetAimVector()
    bullet.Spread = Vector(aimcone, aimcone, 0)
    bullet.Tracer = 1
    bullet.TracerName = "AR2Tracer"
    bullet.Force = 5
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo
    bullet.Callback = function(attacker, tr, dmginfo)
    end
    
    ply:FireBullets(bullet)
    
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    ply:SetAnimation(PLAYER_ATTACK1)
end