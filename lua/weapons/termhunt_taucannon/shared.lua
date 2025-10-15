
local GAMEMODE = GAMEMODE or GM

-- CREDIT https://steamcommunity.com/sharedfiles/filedetails/?id=2885673816
-- had to completely cleanup the code, what a mess

SWEP.Base                		= "weapon_base"
SWEP.Category            		= "Hunter's Glee"
SWEP.Spawnable           		= true
SWEP.AdminOnly 					= false
SWEP.UseHands 					= true

SWEP.ViewModel 					= "models/weapons/TauMmod/c_gauss.mdl"
SWEP.WorldModel 				= "models/weapons/TauMmod/w_gauss.mdl"

SWEP.Primary.Sound 				= "weapons/gauss/fire1.wav"
SWEP.Primary.ClipSize    		= -1
SWEP.Primary.DefaultClip 		= 100
SWEP.Primary.Automatic   		= true
SWEP.Primary.Ammo               = "Uranium_235"

SWEP.Secondary.ClipSize  		= -1
SWEP.Secondary.Delay            = 3
SWEP.Secondary.DefaultClip 		= -1
SWEP.Secondary.Automatic        = true
SWEP.Secondary.Ammo             = ""


SWEP.PrintName    	= "TAU CANNON"
SWEP.Author       	= "Dnjido + StrawWagen"
SWEP.Instructions 	= "Charge up for massive damage! But don't let it overcharge!"
SWEP.ViewModelFOV 	= 58
SWEP.Slot         	= 4

SWEP.HoldType       = "ar2"


SWEP.DrawCrosshair = true

SWEP.Weight = 25

SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "termhunt_taucannon", "materials/entities/termhunt_taucannon.png" )

    function SWEP:CustomAmmoDisplay()
        local owner = self:GetOwner()
        if not IsValid( owner ) then return end
        local ammo = owner:GetAmmoCount( self:GetPrimaryAmmoType() )
        return {
            Draw = true,
            PrimaryClip = ammo
        }
    end
end

local max_Charge = 20
local charge_SlowdownThresh = 10
local gauss_Dmg = 75
local gauss_Hull = Vector( 2, 2, 2 )

function SWEP:SetupDataTables()
    self:NetworkVar( "Int", 0, "ChargeLevel" )

end

function SWEP:Deploy()
    self:EmitSound( "hunters_glee/weapons/gauss/gauss_deploy.wav" )

end

function SWEP:Holster()
    self:KillSound()
    return true

end

function SWEP:Initialize()
    self.nextSprintTime = 0
    self:SetChargeLevel( 0 )
    self:SetHoldType( self.HoldType )

end

function SWEP:DumpCharge()
    local owner = self:GetOwner()
    local chargeLevel = self:GetChargeLevel()
    if chargeLevel <= 0 then return end

    self:KillSound()
    local lvl = 75 + chargeLevel * 0.5

    self:EmitSound( self.Primary.Sound, lvl, 100 + -chargeLevel )
    self:SendWeaponAnim( ACT_VM_SECONDARYATTACK )

    local bullet = {}

    local needsSplode
    if SERVER and chargeLevel >= charge_SlowdownThresh then
        needsSplode = true

    end

    bullet.Callback = function( _attacker, trace, dmginfo )
        if needsSplode then
            isFirstBullet = nil
            local attacker = IsValid( owner ) and owner or self
            terminator_Extras.GleeFancySplode( trace.HitPos + trace.HitNormal * 5, 10 * chargeLevel, 8 * chargeLevel, attacker, self )

        end

        dmginfo:SetDamageType( bit.bor( DMG_AIRBOAT,DMG_BLAST ) )
        if chargeLevel == max_Charge and trace.Entity:GetClass() ~= "prop_vehicle_apc" then
            trace.Entity:SetHealth( 0 )

        end
        local effectdata = EffectData()
        for _ = 0, max_Charge, chargeLevel * max_Charge do
            effectdata:SetNormal( trace.HitNormal )
            effectdata:SetOrigin( trace.HitPos )
            util.Effect( "StunstickImpact", effectdata )
        end
    end

    local validOwner = IsValid( owner )

    local hullSizeMul = 1
    hullSizeMul = hullSizeMul + chargeLevel / 2

    local num = 1 + chargeLevel / 4
    local dmg = gauss_Dmg * chargeLevel
    local dir = validOwner and owner:GetAimVector() or self:GetForward()
    local start = validOwner and owner:GetShootPos() or ( self:GetPos() + dir * 25 )

    bullet.Num      = num
    bullet.Dir      = dir
    bullet.Src      = start
    bullet.Force    = 500 + chargeLevel * 5
    bullet.Spread   = 0 + chargeLevel * 0.1
    bullet.HullSize = 1
    bullet.Damage   = dmg
    bullet.Tracer	= 1
    bullet.TracerName = "HL1GaussBeam_GMOD"
    bullet.Attacker = owner
    bullet.HullSize = gauss_Hull
    self:FireBullets( bullet )

    if validOwner then
        local forceDir = -dir
        if owner:OnGround() then
            if owner:Crouching() then
                forceDir = forceDir + Vector( 0, 0, -1 )

            else
                forceDir = forceDir + Vector( 0, 0, 0.01 )

            end
            forceDir:Normalize()

        end

        local force
        if chargeLevel >= charge_SlowdownThresh then
            force = 250 + chargeLevel * 100

        else
            force = chargeLevel * 100

        end
        owner:SetVelocity( forceDir * force )

        if GAMEMODE.GivePanic then
            local panic = chargeLevel
            if not owner:OnGround() then
                panic = panic * 4

            end
            GAMEMODE:GivePanic( owner, panic )

        end
    else
        self:GetPhysicsObject():ApplyForceCenter( -dir * chargeLevel * 1000 )

    end

    self:SetChargeLevel( 0 )

end

function SWEP:KillSound() -- you NEED to call this in all the places where it's called. DO NOT TRUST LOOPING SOUNDS!
    if self.chargeSound and self.chargeSound:IsPlaying() then
        self.chargeSound:Stop()

    end
    if self.overchargeSound and self.overchargeSound:IsPlaying() then
        self.overchargeSound:Stop()

    end
end

function SWEP:Think()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local chargeLevel = self:GetChargeLevel()

    local vel = owner:GetVelocity():Length()
    local crouchspeed = owner:GetWalkSpeed() * owner:GetCrouchedWalkSpeed()
    local CHARGING = owner:KeyDown( IN_ATTACK2 )
    if not owner:KeyDown( IN_ATTACK ) and not CHARGING then
        local STARTING_SPRINTING = owner:KeyDown( IN_SPEED ) and vel >= crouchspeed and owner:OnGround() and CurTime() > self.nextSprintTime
        if STARTING_SPRINTING then
            self:SendWeaponAnim( ACT_VM_SPRINT_IDLE )
            self.nextSprintTime = CurTime() + 1
            self.nextInspect = CurTime() + 1

        end
        local DONE_SPRINTING = owner:KeyReleased( IN_SPEED ) or ( owner:KeyDown( IN_SPEED ) and vel < crouchspeed ) or ( owner:KeyDown( IN_SPEED ) and not owner:OnGround() )
        if DONE_SPRINTING then
            self.nextInspect = CurTime() + 0.25
            self:SendWeaponAnim( ACT_VM_IDLE )

        end
    end

    if owner:IsPlayer() and CHARGING then
        if not self.chargeSound then -- first think, create the sound
            local chargeSound = CreateSound( owner, "hunters_glee/weapons/gauss/chargeloop.wav" )
            self.chargeSound = chargeSound
            self:CallOnRemove( "gleetau_chargeSound", function() -- ALWAYS KILL THE SOUND WHEN GUN GOES AWAY
                if chargeSound and chargeSound:IsPlaying() then
                    chargeSound:Stop()

                end
            end )

        else -- ok next think, chargesound is created
            if not self.chargeSound:IsPlaying() then -- otherwise stopsound would break the sound, small one tho since the sound is cleaned up when charging stops
                self.chargeSound:Play()

            end
            if chargeLevel < max_Charge then -- and manage pitch
                local pitch = 100 + 15 * chargeLevel
                if chargeLevel > charge_SlowdownThresh then
                    local remainder = chargeLevel - charge_SlowdownThresh
                    pitch = pitch + -30 * remainder

                end
                self.chargeSound:ChangePitch( pitch, 0 )

            end
        end
        if not self.overchargeSound then -- overcharging warning sound
            local overchargeSound = CreateSound( owner, "ambient/levels/labs/teleport_malfunctioning.wav" )
            self.overchargeSound = overchargeSound
            self:CallOnRemove( "gleetau_overchargeSound", function() -- ALWAYS MAKE SURE LOOPING SOUNDS WILL BE KILLED
                if overchargeSound and overchargeSound:IsPlaying() then
                    overchargeSound:Stop()

                end
            end )

        elseif chargeLevel > charge_SlowdownThresh then -- decrease the pitch the more it overcharges
            if not self.overchargeSound:IsPlaying() then -- stopsound WILL be called somehow
                self.overchargeSound:Play()

            end
            local pitch = 100 + 15 * ( chargeLevel - charge_SlowdownThresh ) -- high pitch to low
            local volume = 0.5 + ( chargeLevel - charge_SlowdownThresh ) * 0.05 -- low volume to high
            self.overchargeSound:ChangePitch( pitch, 0 )
            self.overchargeSound:ChangeVolume( volume, 0 )

            if SERVER then -- just makes bots react to scary weapon
                local eyeTr = owner:GetEyeTrace()
                sound.EmitHint( SOUND_DANGER, eyeTr.HitPos, 50 + chargeLevel * 25, 1 )
                local aimEnt = eyeTr.Entity
                if IsValid( aimEnt ) and aimEnt.ReallyAnger then
                    aimEnt:ReallyAnger( chargeLevel * 0.5 )

                end
            end
        end
    end
    if SERVER and self.chargeSound and chargeLevel == 0 then
        self:KillSound()

    end

    if owner:IsPlayer() and owner:KeyReleased( IN_ATTACK2 ) and chargeLevel ~= 0 and IsFirstTimePredicted() then
        self:DumpCharge()

    end
end

function SWEP:Reload()
    local nextInspect = self.nextInspect or 0
    if nextInspect > CurTime() then return end

    self.nextInspect = CurTime() + 1

    self:DefaultReload( ACT_VM_RELOAD )
    local owner = self:GetOwner()
    if owner:KeyPressed( IN_RELOAD ) then
        self:SendWeaponAnim( ACT_VM_IDLE_DEPLOYED_1 )
        timer.Create( "ts", 0.5, 1, function()
            if not IsValid( self ) then return end
            self:EmitSound( "hunters_glee/weapons/gauss/gauss_fidget.wav" )

        end )
    end
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()

    self:SetNextPrimaryFire( CurTime() + 0.2 )
    self:SetNextSecondaryFire( CurTime() + 1 )
    self.nextInspect = CurTime() + 1

    if not owner:IsPlayer() or owner:GetAmmoCount( self.Primary.Ammo ) > 0 then

        self:EmitSound( self.Primary.Sound )
        self:SendWeaponAnim( ACT_VM_PRIMARYATTACK )
        owner:SetAnimation( PLAYER_ATTACK1 )
        if owner.RemoveAmmo then
            owner:RemoveAmmo( 1, self.Primary.Ammo )

        end

        local bullet = {}

        bullet.Callback = function( _, trace, dmginfo )
            dmginfo:SetDamageType( bit.bor( DMG_AIRBOAT,DMG_BLAST ) )

            if trace.Normal:Dot( trace.HitNormal ) < 0.5 then
                timer.Simple( 0, function()
                    if not IsValid( self ) then return end
                    local newOwner = self:GetOwner()
                    if not IsValid( self ) or not IsValid( owner ) or newOwner ~= owner then return end
                    local effectdata = EffectData()
                    effectdata:SetNormal( trace.HitNormal )
                    effectdata:SetOrigin( trace.HitPos )
                    util.Effect( "StunstickImpact", effectdata )

                    bullet = {}

                    bullet.Callback = function( _, _, dmgInfo2 )
                        dmgInfo2:SetDamageType( bit.bor( DMG_AIRBOAT,DMG_BLAST ) )

                    end

                    bullet.Num = 1
                    bullet.Dir = owner:GetAimVector() -2 * ( owner:GetAimVector():Dot( trace.HitNormal ) ) * trace.HitNormal
                    bullet.Src = trace.HitPos
                    bullet.Force = 100
                    bullet.Spread = 0
                    bullet.HullSize = 1
                    bullet.Damage = gauss_Dmg
                    bullet.Tracer		= 0
                    bullet.Attacker = owner
                    bullet.HullSize = gauss_Hull
                    self:FireBullets( bullet )

                end )

            else
                local effectdata = EffectData()
                effectdata:SetNormal( trace.HitNormal )
                effectdata:SetOrigin( trace.HitPos )
                util.Effect( "StunstickImpact", effectdata )

            end
        end

        bullet.Num = 1
        bullet.Dir = owner:GetAimVector()
        bullet.Src = owner:GetShootPos()
        bullet.Force = 100 + self:GetChargeLevel()
        bullet.Spread = 0
        bullet.HullSize = 1
        bullet.Damage = 20
        bullet.Tracer		= 1
        bullet.TracerName		= "HL1GaussBeam_GMOD"
        bullet.Attacker = owner
        self:FireBullets( bullet )

    end
end

-- always drop tau cannon and trigger DumpCharge on death
hook.Add( "DoPlayerDeath", "glee_taucannon_drop", function( ply )
    if ply.DropWeaponKeepAmmo then return end -- let glee weapon dropper do its thing

    local weapon = ply:GetActiveWeapon()

    if not IsValid( weapon ) or weapon:GetClass() ~= "termhunt_taucannon" then return end

    if weapon:GetChargeLevel() <= 0 then return end

    ply:DropWeapon( weapon )
    timer.Simple( 30, function()
        if not IsValid( weapon ) then return end
        local newOwner = weapon:GetOwner()
        if IsValid( newOwner ) then return end
        SafeRemoveEntity( weapon )

    end )
end )

function SWEP:OnDrop()
    if self:GetChargeLevel() > 0 then
        self:DumpCharge()

    end
    self:KillSound()
    self:SetChargeLevel( 0 )

end

function SWEP:OwnerChanged()
    self:KillSound()

end

function SWEP:OnRemove()
    self:KillSound()

end

function SWEP:DoImpactEffect()
    return true

end

function SWEP:FireAnimationEvent()
    return true

end

function SWEP:Explode() -- YOU LET IT OVERCHARGE!
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    self:KillSound()
    self:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 90, 80, 1, CHAN_STATIC )
    self:EmitSound( "ambient/levels/labs/electric_explosion4.wav", 90, 120, 1, CHAN_STATIC )
    self:SendWeaponAnim( ACT_VM_SECONDARYATTACK )

    local effectdata = EffectData()
    effectdata:SetOrigin( owner:GetPos() )
    effectdata:SetScale( 1 )
    util.Effect( "Explosion", effectdata )

    if not SERVER then return end

    util.BlastDamage( self, owner, owner:WorldSpaceCenter(), 500, 1000 )

    local dmginfo = DamageInfo()
    dmginfo:SetDamage( 1000 )
    dmginfo:SetAttacker( owner )
    dmginfo:SetInflictor( self )
    dmginfo:SetDamageType( bit.bor( DMG_BLAST,DMG_AIRBOAT ) )
    owner:TakeDamageInfo( dmginfo )

    if owner.DropWeaponKeepAmmo then
        owner:DropWeaponKeepAmmo( self )

    else
        owner:DropWeapon( self )

    end
end

function SWEP:SecondaryAttack()
    if not IsFirstTimePredicted() then return end
    self.nextInspect = CurTime() + 1
    local owner = self:GetOwner()
    if owner.RemoveAmmo and self:Ammo1() ~= 0 then
        local chargeLevel = self:GetChargeLevel()
        if chargeLevel < max_Charge then
            chargeLevel = chargeLevel + 1
            self:SetChargeLevel( chargeLevel )
            if SERVER and owner.RemoveAmmo then
                owner:RemoveAmmo( 1, self.Primary.Ammo )

            end
        else
            if SERVER then
                self:DumpCharge()
                self:Explode()

            end
            return

        end
        local add = 0.2
        if chargeLevel > charge_SlowdownThresh then
            local overThresh = ( chargeLevel - charge_SlowdownThresh )
            if GAMEMODE.GivePanic then
                GAMEMODE:GivePanic( owner, overThresh^1.5 )

            end
            add = add + overThresh * 0.1

        end
        self:SetNextSecondaryFire( CurTime() + add )
        self:SetNextPrimaryFire( CurTime() + add + 0.5 )
        if SERVER then
            self:SendWeaponAnim( ACT_VM_PULLBACK )
            local amp = chargeLevel
            local fre = max_Charge - chargeLevel
            local dur = add * 2
            local rad = 100 + chargeLevel * 50
            util.ScreenShake( owner:WorldSpaceCenter(), amp, fre, dur, rad, true )

        end
    end
end

if not SERVER then return end
if not GAMEMODE.RandomlySpawnEnt then return end

GAMEMODE:RandomlySpawnEnt( "termhunt_taucannon", 1, math.Rand( 0, 1 ), nil, math.random( 1000, 10000 ) )
