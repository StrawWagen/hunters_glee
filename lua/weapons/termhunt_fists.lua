AddCSLuaFile()

SWEP.PrintName    = "Hands & Fists"
SWEP.Author       = "Boomertaters + Kilburn, robotboy655, MaxOfS2D & Tenrys"
SWEP.Category     = "Hunter's Glee"
SWEP.Instructions = [[Chain punches to build up damage.
Be sure to raise your guard, guards reduce more damage the harder you're hit.]]

SWEP.Spawnable      = true
SWEP.AdminOnly      = false
SWEP.UseHands       = true

SWEP.ViewModel    = Model( "models/weapons/c_arms.mdl" )
SWEP.WorldModel   = ""
SWEP.ViewModelFOV = 54

SWEP.Primary.ClipSize    = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic   = true
SWEP.Primary.Ammo        = "none"

SWEP.Secondary.ClipSize    = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic   = true
SWEP.Secondary.Ammo        = "none"

SWEP.Weight         = 1
SWEP.AutoSwitchTo   = false
SWEP.AutoSwitchFrom = true
SWEP.Slot           = 0
SWEP.SlotPos        = 4
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair  = true
SWEP.DrawWeaponInfoBox = false

SWEP.HitDistance     = 68
SWEP.BaseDamage      = 18
SWEP.DamageAddedAfterHit = 6


SWEP.IronSightsPos = Vector( 0, -3.594, -0.801 )
SWEP.IronSightsAng = Vector( 27.564, 0, 0 )

SWEP.ViewModelBoneMods = {
    ["ValveBiped.Bip01_L_UpperArm"] = { scale = Vector( 1, 1, 1 ), pos = Vector( -1.487, -1.842, 0 ), angle = Angle( 0, 0, 0 ) },
    ["ValveBiped.Bip01_R_UpperArm"] = { scale = Vector( 1, 1, 1 ), pos = Vector( -0.852, 0, 0 ), angle = Angle( 0, 0, 0 ) }
}

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "termhunt_fists", "materials/vgui/hud/killicon/termhunt_fists.png" )
end

local SwingSound = Sound( "WeaponFrag.Throw" )
local HitSound = Sound( "Flesh.ImpactHard" )
local HitSound2 = Sound( "Flesh.Break" )

local allBones
local hasGarryFixedBoneScalingYet = false
local viewModelMul = 0

function SWEP:SetupDataTables()
    self:NetworkVar( "Float", 0, "NextMeleeAttack" )
    self:NetworkVar( "Float", 1, "NextIdle" )
    self:NetworkVar( "Float", 2, "NextBlock" )
    self:NetworkVar( "Float", 3, "NextLower" )
    self:NetworkVar( "Int",   2, "Combo" )
    self:NetworkVar( "Bool",  1, "Lower" )
    self:NetworkVar( "Bool",  2, "Block" )
end

function SWEP:Initialize()
    self:SetHoldType( "fist" )
    self:SetLower( false )
    self:SetBlock( false )
end

function SWEP:UpdateNextIdle()
    local vm = self.Owner:GetViewModel()
    self:SetNextIdle( CurTime() + vm:SequenceDuration() / vm:GetPlaybackRate() )
end

function SWEP:DoDrawCrosshair()
    if self:GetLower() or self:GetBlock() then
        return true
    end
end

function SWEP:PrimaryAttack()
    if self:GetLower() or self:GetBlock() then return end

    self.Owner:SetAnimation( PLAYER_ATTACK1 )

    local isLeft = util.SharedRandom( self:GetClass(), 0, 1, 0 ) > 0.5
    local vm = self.Owner:GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( isLeft and "fists_left" or "fists_right" ) )

    self:EmitSound( SwingSound )
    self:UpdateNextIdle()
    self:SetNextMeleeAttack( CurTime() + 0.2 )
    self:SetNextPrimaryFire( CurTime() + 0.65 )
end

function SWEP:DealDamage()
    local owner = self.Owner

    owner:LagCompensation( true )

    local traceData = {
        start  = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * self.HitDistance,
        filter = owner,
        mask   = MASK_SHOT_HULL
    }

    local tr = util.TraceLine( traceData )

    if not IsValid( tr.Entity ) then
        traceData.mins = Vector( -10, -10, -8 )
        traceData.maxs = Vector( 10, 10, 8 )
        tr = util.TraceHull( traceData )
    end

    if tr.Hit then
        self:EmitSound( HitSound )
		self:EmitSound( HitSound2 )
    end

    local hit = false

    if SERVER and IsValid( tr.Entity ) and ( tr.Entity:IsNPC() or tr.Entity:IsPlayer() or tr.Entity:Health() > 0 ) then
        local combo = self:GetCombo()
        local damage = self.BaseDamage + ( combo * self.DamageAddedAfterHit )
        local forceMultiplier = 1 + ( combo * 0.5 )

        local dmginfo = DamageInfo()
        dmginfo:SetAttacker( IsValid( owner ) and owner or self )
        dmginfo:SetInflictor( self )
        dmginfo:SetDamage( damage )
        dmginfo:SetDamageForce( owner:GetForward() * 10000 * forceMultiplier )

        SuppressHostEvents( NULL )
        tr.Entity:TakeDamageInfo( dmginfo )
        SuppressHostEvents( owner )

        hit = true
    end

    if IsValid( tr.Entity ) then
        local phys = tr.Entity:GetPhysicsObject()
        if IsValid( phys ) then
            phys:ApplyForceOffset( owner:GetAimVector() * 80 * phys:GetMass(), tr.HitPos )
        end
    end

    if SERVER then
        self:SetCombo( hit and self:GetCombo() + 1 or 0 )
    end

    owner:LagCompensation( false )
end

function SWEP:GetViewModelPosition( eyePos, eyeAng )
    local targetMul = self:GetBlock() and 1 or ( self:GetLower() and -1 or 0 )
    viewModelMul = math.Approach( viewModelMul, targetMul, FrameTime() * 6 )

    if self.IronSightsAng then
        eyeAng:RotateAroundAxis( eyeAng:Right(),   self.IronSightsAng.x * viewModelMul )
        eyeAng:RotateAroundAxis( eyeAng:Up(),       self.IronSightsAng.y * viewModelMul )
        eyeAng:RotateAroundAxis( eyeAng:Forward(),  self.IronSightsAng.z * viewModelMul )
    end

    local offset = self.IronSightsPos
    eyePos = eyePos + offset.x * eyeAng:Right() * viewModelMul
    eyePos = eyePos + offset.y * eyeAng:Forward() * viewModelMul
    eyePos = eyePos + offset.z * eyeAng:Up() * viewModelMul

    return eyePos, eyeAng
end

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:Deploy()
    self:SetNextLower( CurTime() + 0.25 )
    self:SetNextBlock( CurTime() + 0.25 )

    local vm = self.Owner:GetViewModel()

    if self:GetLower() then
        vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_holster" ) )
        self:SetHoldType( "normal" )

        return
    end

    vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_draw" ) )
    self:SetNextPrimaryFire( CurTime() + vm:SequenceDuration() )
    self:UpdateNextIdle()
    self:SetHoldType( "fist" )

    if SERVER then
        self:SetCombo( 0 )
    end

    return true
end

function SWEP:Holster()
    self:SetBlock( false )
    self:SetNextMeleeAttack( 0 )

    if CLIENT and IsValid( self.Owner ) then
        local vm = self.Owner:GetViewModel()
        if IsValid( vm ) then
            self:ResetBonePositions( vm )
        end
    end

    return true
end

function SWEP:Lower()
    self:SetHoldType( "normal" )
    self:SetNextBlock( CurTime() + 0.25 )
    self:SetNextMeleeAttack( 0 )
    self:SetBlock( false )

    return true
end

function SWEP:Block()
    self:SetHoldType( "camera" )
    self:SetNextMeleeAttack( 0 )
    self:SetLower( false )
    self:SetNextIdle( CurTime() )

    return true
end

function SWEP:UnBlock()
    self:SetHoldType( "fist" )

    return true
end

function SWEP:Reload()
    if self:GetNextLower() > CurTime() then return end

    if self:GetBlock() then
        self:SetNextBlock( CurTime() + 0.25 )
        self:SetBlock( false )
        self:UnBlock()

        return
    end

    if not self.Owner:KeyPressed( IN_RELOAD ) then return end

    self:SetNextLower( CurTime() + 0.25 )

    local lower = self:GetLower()
    self:SetLower( not lower )

    if not lower then
        self:Lower()
    else
        self:Deploy()
    end
end

function SWEP:SecondaryAttack()
    if self:GetNextBlock() > CurTime() then return end
    if not self.Owner:KeyPressed( IN_ATTACK2 ) then return end
    if self:GetLower() then return end

    self:SetNextBlock( CurTime() + 0.25 )

    local block = self:GetBlock()
    self:SetBlock( not block )

    if not block then
        self:Block()
    else
        self:UnBlock()
    end
end

function SWEP:Think()
    local vm = self.Owner:GetViewModel()
    local idleTime = self:GetNextIdle()

    if idleTime > 0 and CurTime() > idleTime then
        local bl = util.SharedRandom( self:GetClass(), 0, 1, 0 ) > 0.5
        vm:SendViewModelMatchingSequence( vm:LookupSequence( "fists_idle_0" .. ( bl and 2 or 1 ) ) )
        self:UpdateNextIdle()
    end

    local block = self:GetBlock()
    if block and self:GetNextBlock() < CurTime() and not self.Owner:KeyDown( IN_ATTACK2 ) then
        self:SetNextBlock( CurTime() + 0.25 )
        self:SetBlock( false )
        self:UnBlock()
    end

    if self:GetLower() or block then return end

    local meleeTime = self:GetNextMeleeAttack()
    if meleeTime > 0 and CurTime() > meleeTime then
        self:DealDamage()
        self:SetNextMeleeAttack( 0 )
    end

    if SERVER and CurTime() > self:GetNextPrimaryFire() + 0.5 then
        self:SetCombo( 0 )
    end
end

function SWEP:ResetBonePositions( vm )
    if not vm:GetBoneCount() then return end

    for i = 0, vm:GetBoneCount() do
        vm:ManipulateBoneScale( i, Vector( 1, 1, 1 ) )
        vm:ManipulateBoneAngles( i, Angle( 0, 0, 0 ) )
        vm:ManipulateBonePosition( i, Vector( 0, 0, 0 ) )
    end
end

function SWEP:UpdateBonePositions( vm )
    if not self.ViewModelBoneMods then
        self:ResetBonePositions( vm )

        return
    end

    if not vm:GetBoneCount() then return end

    local loopthrough = self.ViewModelBoneMods
    if not hasGarryFixedBoneScalingYet then
        allBones = {}
        for i = 0, vm:GetBoneCount() do
            local boneName = vm:GetBoneName( i )
            allBones[boneName] = self.ViewModelBoneMods[boneName] or {
                scale = Vector( 1, 1, 1 ),
                pos = Vector( 0, 0, 0 ),
                angle = Angle( 0, 0, 0 )
            }
        end

        loopthrough = allBones
    end

    for boneName, boneData in pairs( loopthrough ) do
        local bone = vm:LookupBone( boneName )
        if not bone then continue end

        local position = Vector( boneData.pos.x, boneData.pos.y, boneData.pos.z ) * viewModelMul

        if not hasGarryFixedBoneScalingYet then
            local ms = Vector( 1, 1, 1 )
            local cur = vm:GetBoneParent( bone )
            while cur >= 0 do
                ms = ms * loopthrough[vm:GetBoneName( cur )].scale
                cur = vm:GetBoneParent( cur )
            end
        end

        if vm:GetManipulateBoneAngles( bone ) ~= boneData.angle then
            vm:ManipulateBoneAngles( bone, boneData.angle )
        end

        if vm:GetManipulateBonePosition( bone ) ~= position then
            vm:ManipulateBonePosition( bone, position )
        end
    end
end

function SWEP:ViewModelDrawn()
    local vm = self.Owner:GetViewModel()
    if not IsValid( vm ) then return end
    self:UpdateBonePositions( vm )
end