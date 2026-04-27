-- Thank you to the developers of https://steamcommunity.com/sharedfiles/filedetails/?id=1682679491&searchtext=li%27l+annabelle for the annabelle weapon model and sounds!!
-- Give 'em awards and follows!

SWEP.PrintName    = "Annabelle"
SWEP.Author       = "Boomertaters"
SWEP.Category     = "Hunter's Glee"
SWEP.Instructions = "Hitting targets increases damage and fire rate. Missing decreases them."

SWEP.Spawnable    = true
SWEP.AdminOnly    = false
SWEP.UseHands     = true

SWEP.Primary.ClipSize    = 6
SWEP.Primary.DefaultClip = 6
SWEP.Primary.Automatic   = false
SWEP.Primary.Ammo        = "357"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = false
SWEP.Secondary.Ammo        = "none"

SWEP.Weight         = 5
SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = false
SWEP.Slot           = 2
SWEP.SlotPos        = 1
SWEP.DrawAmmo       = true
SWEP.DrawCrosshair  = true

SWEP.ViewModel = "models/weapons/annabelle/v_win92.mdl"
SWEP.WorldModel = "models/weapons/annabelle/w_win92.mdl"


function SWEP:SetupDataTables()
    self:NetworkVar( "Bool",  0, "Reloading" )
    self:NetworkVar( "Bool",  1, "Firing" )
    self:NetworkVar( "Float", 0, "DamageMult" )
    self:NetworkVar( "Float", 1, "SpeedMult" )
end

function SWEP:ResetStats()
    self:SetDamageMult( 1 )
    self:SetSpeedMult( 1 )
end

function SWEP:AdjustStats( hitLiving )
    if hitLiving then
        self:SetDamageMult( math.min( self:GetDamageMult() + 0.50, 4.0 ) )
        self:SetSpeedMult( math.min( self:GetSpeedMult() + 0.10, 1.6 ) )
    else
        self:SetDamageMult( math.max( self:GetDamageMult() - 0.60, 0.50 ) )
        self:SetSpeedMult( math.max( self:GetSpeedMult() - 0.12, 0.50 ) )
    end
end


function SWEP:Initialize()
    self:SetHoldType( "shotgun" )

    if SERVER then
        self:ResetStats()
        self:SetReloading( false )
        self:SetFiring( false )
    end
end

function SWEP:Deploy()
    self:SendWeaponAnim( ACT_VM_DRAW )

    if SERVER then
        self:ResetStats()
        self:SetReloading( false )
        self:SetFiring( false )
    end

    return true
end

function SWEP:Holster()
    if SERVER then
        self:SetReloading( false )
        self:SetFiring( false )
    end

    return true
end


function SWEP:PrimaryAttack()
    if self:GetReloading() then return end
    if self:GetFiring() then return end
    if not self:CanPrimaryAttack() then return end
    if not IsFirstTimePredicted() then return end

    local owner     = self:GetOwner()
    local speedMult = self:GetSpeedMult()

    self:SetNextPrimaryFire( CurTime() + 0.85 / speedMult )
    self:TakePrimaryAmmo( 1 )
    self:ShootBullet( owner )

    if SERVER then
        self:SetFiring( true )

        timer.Create( "glee_annabelle_pump" .. self:GetCreationID(), 0.40 / speedMult, 1, function()
            if not IsValid( self ) then return end

            self:EmitSound( "hunters_glee/annabelle/rifle_pump.wav", 82, 100 * self:GetSpeedMult() )
            self:SetFiring( false )
        end )
    end
end

function SWEP:SecondaryAttack()
end

function SWEP:ShootBullet( owner )
    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    owner:MuzzleFlash()
    owner:SetAnimation( PLAYER_ATTACK1 )

    local vm = owner:GetViewModel()

    if IsValid( vm ) then
        vm:SetPlaybackRate( self:GetSpeedMult() )
    end

    owner:EmitSound( "hunters_glee/annabelle/rifle_fire.wav", 88, 100 * self:GetSpeedMult() )

    owner:FireBullets( {
        Num      = 1,
        Src      = owner:GetShootPos(),
        Dir      = owner:GetAimVector(),
        Spread   = Vector( 0.001, 0.001, 0 ),
        Tracer   = 1,
        Force    = 30,
        Damage   = 90 * self:GetDamageMult(),
        AmmoType = "357",
        Callback = function( _, trace, _ )
            if not SERVER then return end

            local ent = trace.Entity
            local hit = IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() )

            self:AdjustStats( hit )
        end
    } )
end


function SWEP:Reload()
    if self:GetReloading() then return end
    if self:GetFiring() then return end
    if self:Clip1() >= 6 then return end
    if not IsFirstTimePredicted() then return end

    local owner = self:GetOwner()

    if owner:GetAmmoCount( self.Primary.Ammo ) <= 0 then return end

    self:SendWeaponAnim( ACT_SHOTGUN_RELOAD_START )
    owner:SetAnimation( PLAYER_RELOAD )

    if SERVER then
        self:SetReloading( true )
        self:ResetStats()
        self:SetNextPrimaryFire( CurTime() + 2 )

        timer.Simple( 0.45, function()
            if IsValid( self ) then self:ReloadLoop() end
        end )
    end
end

function SWEP:ReloadLoop()
    if not self:GetReloading() then return end

    local owner = self:GetOwner()

    if self:Clip1() >= 6 or owner:GetAmmoCount( self.Primary.Ammo ) <= 0 then
        self:FinishReload()

        return
    end

    self:EmitSound( "hunters_glee/annabelle/insert.wav", 75, 100 )
    self:SendWeaponAnim( ACT_VM_RELOAD )
    self:SetNextPrimaryFire( CurTime() + 2 )
    owner:RemoveAmmo( 1, self.Primary.Ammo )
    self:SetClip1( self:Clip1() + 1 )

    timer.Create( "glee_annabelle_reloadloop" .. self:GetCreationID(), 0.60, 1, function()
        if IsValid( self ) then self:ReloadLoop() end
    end )
end

function SWEP:FinishReload()
    if not self:GetReloading() then return end

    self:SetReloading( false )
    self:SetNextPrimaryFire( CurTime() + 0.5 )
    self:SendWeaponAnim( ACT_SHOTGUN_RELOAD_FINISH )

    timer.Create( "glee_annabelle_finishanim" .. self:GetCreationID(), 0.5, 1, function()
        if not IsValid( self ) then return end
        if self:GetReloading() then return end

        self:SendWeaponAnim( ACT_VM_IDLE )
    end )
end

