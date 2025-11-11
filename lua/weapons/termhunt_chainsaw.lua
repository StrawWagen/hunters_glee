-- model is from this https://steamcommunity.com/sharedfiles/filedetails/?id=2841514992&searchtext=no+more+room+in+helli melle pack 
-- GIVE THEM LOVE AND AWARD THEM YAYAYAYAYA 
-- billions must award YLW

SWEP.Base = "weapon_base"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.PrintName = "Chainsaw"
SWEP.Author = "Boomertaters"
SWEP.Purpose = "AHHHH... FRESH MEAT"

SWEP.ViewModel = "models/weapons/tfa_nmrih/v_me_chainsaw.mdl"
SWEP.WorldModel = "models/weapons/tfa_nmrih/w_me_chainsaw.mdl" -- why you gotta be like this :(
SWEP.ViewModelFOV = 80
SWEP.UseHands = true
SWEP.HoldType = "physgun"
SWEP.ViewModelFlip = true

SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    self.IsRevvedUp = false
    self.IsTurningOn = false
    self.IsTurningOff = false
    self.IsAttacking = false
end

function SWEP:Reload()
    if self.IsTurningOn or self.IsTurningOff then return end

    if self.IsRevvedUp then
        self:TurnOff()
    else
        self:TurnOn()
    end
end

function SWEP:TurnOn()
    self.IsTurningOn = true

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "TurnOn" ) )

        timer.Simple( 0.7, function()
        if not IsValid( self ) then return end
        self:EmitSound( "chainsaw/chainsaw_failedstart.wav" )
    end )


        timer.Simple( 1.5, function()
        if not IsValid( self ) then return end
        self:EmitSound( "chainsaw/chainsaw_successstart.wav" )
    end )


    timer.Simple( 2.8, function()
        if not IsValid( self ) then return end

        self:StopSound( "chainsaw/chainsaw_sawloop.wav" )
        self:StopSound( "chainsaw/chainsaw_idleloop.wav" )
        self:EmitSound( "chainsaw/chainsaw_idleloop.wav" )
        self.IsRevvedUp = true
        self.IsTurningOn = false

        local vm2 = self:GetOwner():GetViewModel()
        vm2:SendViewModelMatchingSequence( vm2:LookupSequence( "IdleOn" ) )

    end )

    self:SetNextPrimaryFire( CurTime() + 0.6 )
end

function SWEP:TurnOff()
    self.IsTurningOff = true
    self.IsAttacking = false

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "TurnOff" ) )

    self:EmitSound( "chainsaw/chainsaw_turnoff.wav" )

    self:StopSound( "chainsaw/chainsaw_idleloop.wav" )
    self:StopSound( "chainsaw/chainsaw_sawloop.wav" )

    timer.Simple( 1.0, function()
        if not IsValid( self ) then return end

        self.IsRevvedUp = false
        self.IsTurningOff = false
    end )

    self:SetNextPrimaryFire( CurTime() + 1.0 )
end

function SWEP:PrimaryAttack()
    if not IsFirstTimePredicted() then return end
    if self.IsTurningOn or self.IsTurningOff then return end

    if not self.IsRevvedUp then
        self:TurnOn()
        return
    end

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "Attack_On" ) )

    if not self.IsAttacking then
        self:StopSound( "chainsaw/chainsaw_idleloop.wav" )
        self:StopSound( "chainsaw/chainsaw_sawloop.wav" )
        self:EmitSound( "chainsaw/chainsaw_sawloop.wav" )
        self.IsAttacking = true

        vm:SendViewModelMatchingSequence( 11 )
    end

    self:DealDamage()

    self:SetNextPrimaryFire( CurTime() + 0.2 )

    self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:Think()
    local shutDownAttacking = self.IsAttacking and self.IsRevvedUp and not self:GetOwner():KeyDown( IN_ATTACK )
    if shutDownAttacking then
        self.IsAttacking = false
        self:StopSound( "chainsaw/chainsaw_sawloop.wav" )
        self:StopSound( "chainsaw/chainsaw_idleloop.wav" )
        self:EmitSound( "chainsaw/chainsaw_idleloop.wav" )

        local vm = self:GetOwner():GetViewModel()
        vm:SendViewModelMatchingSequence( vm:LookupSequence( "IdleOn" ) )
    end

    local doIdleAnim = self.IsRevvedUp and not self.IsAttacking and not self.IsTurningOn and not self.IsTurningOff
    if doIdleAnim then
        local vm = self:GetOwner():GetViewModel()
        if vm:GetSequence() != vm:LookupSequence( "IdleOn" ) then
            vm:SendViewModelMatchingSequence( vm:LookupSequence( "IdleOn" ) )
        end
    end
end

function SWEP:DealDamage()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 90,
        filter = owner
    })

    if tr.Hit and tr.HitPos:Distance( owner:GetShootPos() ) <= 90 then
        local ent = tr.Entity

        local bullet = {
            Num = 1,
            Src = owner:GetShootPos(),
            Dir = owner:GetAimVector(),
            Spread = Vector( 0, 0, 0 ),
            Tracer = 0,
            Force = 3,
            Damage = math.random( 26, 62 ),
            Distance = 90
        }

        owner:FireBullets( bullet )

        if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then

            sound.Play( "physics/body/body_medium_break"..math.random( 2, 4 )..".wav", tr.HitPos, 75, math.random( 100, 155 ), 1 )
            sound.Play( "npc/antlion_guard/antlion_guard_shellcrack"..math.random( 1, 2 )..".wav", tr.HitPos, 75, math.random( 100, 155 ), 1 )
            sound.Play( "ambient/machines/slicer"..math.random( 1, 4 )..".wav", tr.HitPos, 75, math.random( 100, 155 ), 1 )

            local ed = EffectData()
            ed:SetOrigin( tr.HitPos )
            ed:SetNormal( tr.HitNormal )
            ed:SetScale( 8 )
            ed:SetFlags( 3 )
            util.Effect( "bloodspray", ed, true, true )
        end
    end
end


function SWEP:Holster()
    if self.IsRevvedUp then
        self:TurnOff()
    end

    self:StopSound( "chainsaw/chainsaw_idleloop.wav" )
    self:StopSound( "chainsaw/chainsaw_sawloop.wav" )

    return true
end

function SWEP:OnRemove()
    self:StopSound( "chainsaw/chainsaw_idleloop.wav" )
    self:StopSound( "chainsaw/chainsaw_sawloop.wav" )
end