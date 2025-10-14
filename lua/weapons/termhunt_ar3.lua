SWEP.PrintName = "Emplacement Gun"
SWEP.Author = "Boomeritaintaters + gaming98"
SWEP.Instructions = "I want revenge. I want them to know that death is coming - John Rambo"
SWEP.Category = "Hunter's Glee"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = 500
SWEP.Primary.DefaultClip = 500
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

SWEP.ShootSound = "Weapon_FuncTank.Single"
SWEP.ConsecutiveShotsDecay = 1

SWEP.HeatDecay = 0.004
SWEP.HeatPerShot = 0.004
SWEP.UnbearableHeat = 0.25

SWEP.LastAttack = 0

function SWEP:SetupDataTables()
    self:NetworkVar( "Int", "ConsecutiveShots" )
    self:NetworkVar( "Float", "Heat" )

end

function SWEP:Deploy()
    self:EmitSound( "weapons/ar3/ar3_deploy.wav" )
    self.deploying = true
    self.deployTime = CurTime() + 1

    if CLIENT then return end

    local owner = self:GetOwner()
    if IsValid( owner ) and owner:IsPlayer() and owner.doSpeedClamp then
        owner:doSpeedClamp( "glee_ar3_deployed", -75 ) -- apply speed debuff when equipped

        local timerName = "glee_ar3_deploy_timer" .. self:GetCreationID()

        local function stopDebuff()
            timer.Remove( timerName )
            owner:doSpeedClamp( "glee_ar3_deployed", nil )

        end
        timer.Create( timerName, 0.45, 0, function() -- cleanup debuff when no longer active weapon
            if not IsValid( owner ) then timer.Remove( timerName ) return end -- owner gone

            if not IsValid( self ) then stopDebuff() return end -- swep gone
            if owner:GetActiveWeapon() ~= self then stopDebuff() return end -- not active weapon

        end )
    end

    return true

end

function SWEP:PrimaryAttack()
    if self:Clip1() <= 0 then
        self:EmitSound( "Weapon_Pistol.Empty" )
        self:SetNextPrimaryFire( CurTime() + 0.2 )
        return

    end

    local add = 0.1
    add = math.max( 0.035, add - ( self:GetConsecutiveShots() * 0.0008 ) )

    self:SetNextPrimaryFire( CurTime() + add )
    self:ShootBullet( math.random( 15, 25 ), 1, 0.03 )
    self:EmitSound( self.ShootSound )
    self:TakePrimaryAmmo( 1 )

    if not SERVER then return end

    self:SetConsecutiveShots( self:GetConsecutiveShots() + 1 )
    self:SetHeat( self:GetHeat() + self.HeatPerShot )

    self.LastAttack = CurTime()

end

function SWEP:SecondaryAttack()
end

function SWEP:Initialize()
    self:SetHoldType( "physgun" )
    if not SERVER then return end

    local timerName = "glee_ar3_heatthinktimer" .. self:GetCreationID()
    timer.Create( timerName, 0.05, 0, function()
        if not IsValid( self ) then timer.Remove( timerName ) return end

        local owner = self:GetOwner()
        if self.LastAttack + 0.1 < CurTime() then
            local shots = self:GetConsecutiveShots()
            if shots > 0 then
                self:SetConsecutiveShots( math.max( 0, shots - self.ConsecutiveShotsDecay ) )

            end
            local heat = self:GetHeat()
            if heat > 0 then
                self:SetHeat( math.max( 0, heat - self.HeatDecay ) )

            end
        elseif IsValid( owner ) then
            local heat = self:GetHeat()
            local thresh = self.UnbearableHeat
            local overThresh = math.max( heat - thresh, 0 )

            if overThresh > 0 then
                if overThresh > 1 and math.Rand( 0, 1 ) < overThresh then
                    owner:Ignite( overThresh * 2 )
                    if GAMEMODE.GivePanic then
                        GAMEMODE:GivePanic( owner, overThresh * 4 )

                    end
                elseif GAMEMODE.GivePanic then
                    GAMEMODE:GivePanic( owner, overThresh * 2 )

                end
            end
        end
    end )
end

function SWEP:DoImpactEffect( tr, _nDamageType )
    if tr.HitSky then return true end

    local effectdata = EffectData()
    effectdata:SetOrigin( tr.HitPos )
    effectdata:SetNormal( tr.HitNormal )
    util.Effect( "AR2Impact", effectdata )

    return true

end

function SWEP:InspectAnim()
    if not SERVER then return end

    local nextInspect = self.nextInspect or 0
    if nextInspect > CurTime() then return end

    self.nextInspect = CurTime() + 2

    self:SendWeaponAnim( ACT_VM_FIDGET )

end

function SWEP:Reload()
    if self:Clip1() >= self.Primary.ClipSize then self:InspectAnim() return end
    if self:GetOwner():GetAmmoCount( self.Primary.Ammo ) <= 0 then return end
    if self.Reloading then return end

    self.Reloading = true

    local vm = self:GetOwner():GetViewModel()
    if IsValid( vm ) then
        vm:SendViewModelMatchingSequence( 11 )

    end

    self:SetNextPrimaryFire( CurTime() + 3.1 )

    local timerName = "glee_ar3ReloadFinishTimer" .. self:GetCreationID()

    timer.Create( timerName, 1.3, 1, function()
        if not IsValid( self ) then return end

        self:EmitSound( "weapons/shotgun/shotgun_cock.wav" )

        local ammo = math.min( self.Primary.ClipSize - self:Clip1(), self:GetOwner():GetAmmoCount( self.Primary.Ammo ) )
        self:SetClip1( self:Clip1() + ammo )
        self:GetOwner():RemoveAmmo( ammo, self.Primary.Ammo )

        self.Reloading = false

    end )
end

function SWEP:ShootBullet( damage, numBullets, aimcone )
    local ply = self:GetOwner()

    local bullet = {}
    bullet.Num = numBullets
    bullet.Src = ply:GetShootPos()
    bullet.Dir = ply:GetAimVector()
    bullet.Spread = Vector( aimcone, aimcone, 0 )
    bullet.Tracer = 1
    bullet.TracerName = "AR2Tracer"
    bullet.Force = 5
    bullet.Damage = damage
    bullet.AmmoType = self.Primary.Ammo

    ply:FireBullets( bullet )

    self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
    ply:SetAnimation( PLAYER_ATTACK1 )

end

if not CLIENT then return end


local glee_overlaydrawing = false

-- frankensteined cfc emplacement heat effect
local function startHeatDrawing( ent )
    if not IsValid( ent ) then return end
    if glee_overlaydrawing then return end -- reentrancy guard

    local heat = ent:GetHeat()
    if heat <= 0 then return end

    glee_overlaydrawing = true

    local colorMul = ( 0.25 + heat ) * 15
    render.SetBlend( heat ^ 3 * 0.5 )
    render.SetColorModulation( 1 * colorMul, 0.25 * colorMul, 0 )

end

local function stopHeatDrawing()
    if not glee_overlaydrawing then return end
    -- reset render state
    render.SetColorModulation( 1, 1, 1 )
    render.SetBlend( 1 )

    glee_overlaydrawing = nil

end

-- Overlay the viewmodel with a heat tint
function SWEP:PreDrawViewModel( vm )
    if glee_overlaydrawing then return end
    local heat = self:GetHeat()
    if heat <= 0 then return end

    glee_overlaydrawing = true
    vm:DrawModel()
    glee_overlaydrawing = nil

    if not IsValid( vm ) then return end
    startHeatDrawing( self, vm )

end

function SWEP:ViewModelDrawn( vm )
    if not IsValid( vm ) then return end
    stopHeatDrawing( self, vm )

end

-- Overlay the worldmodel with the same heat tint
function SWEP:DrawWorldModel()
    -- Draw base pass normally
    self:DrawModel()
    startHeatDrawing( self, self )
    self:DrawModel()
    stopHeatDrawing( self, self )

end