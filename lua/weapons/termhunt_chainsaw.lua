-- model is from this https://steamcommunity.com/sharedfiles/filedetails/?id=2849966415&searchtext=chainsaw melle pack 
-- GIVE THEM LOVE AND AWARD THEM YAYAYAYAYA 
-- billions must award anubiques





SWEP.Base = "weapon_base"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.PrintName = "Chainsaw"
SWEP.Author = "Boomertaters"
SWEP.Purpose = "AHHHH... FRESH MEAT"

SWEP.ViewModel = "models/weapons/chainsaw/v_me_chainsaw.mdl"
SWEP.WorldModel = "models/weapons/chainsaw/w_me_chainsaw.mdl" -- why you gotta be like this :(
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
    self.IsReadyToAttack = false
    self.IsTurningOn = false
    self.IsTurningOff = false
    self.IsAttacking = false
end

function SWEP:Reload()
    if self.IsTurningOn or self.IsTurningOff then return end

    if self.IsReadyToAttack then
        self:TurnOff()
    else
        self:TurnOn()
    end
end

function SWEP:TurnOn()
    self.IsTurningOn = true

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "TurnOn" ) )

    timer.Simple( 2.2, function()
        if not IsValid( self ) then return end

        self:StopSound( "Weapon_Chainsaw.IdleLoop" )
        self:EmitSound( "Weapon_Chainsaw.IdleLoop", 60, 100 )
        self.IsReadyToAttack = true
        self.IsTurningOn = false
    end )

    self:SetNextPrimaryFire( CurTime() + 1.5 )
end

function SWEP:TurnOff()
    self.IsTurningOff = true
    self.IsAttacking = false

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "TurnOff" ) )

    self:StopSound( "Weapon_Chainsaw.IdleLoop" )
    self:StopSound( "Weapon_Chainsaw.SawLoop" )

    timer.Simple( 1.0, function()
        if not IsValid( self ) then return end

        self.IsReadyToAttack = false
        self.IsTurningOff = false
    end )

    self:SetNextPrimaryFire( CurTime() + 1.0 )
end

function SWEP:PrimaryAttack()
    if self.IsTurningOn or self.IsTurningOff then return end

    if not self.IsReadyToAttack then
        self:TurnOn()
        return
    end

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence( vm:LookupSequence( "Attack_On" ) )

    if not self.IsAttacking then
        self:StopSound( "Weapon_Chainsaw.IdleLoop" )
        self:StopSound( "Weapon_Chainsaw.SawLoop" )
        self:EmitSound( "Weapon_Chainsaw.SawLoop", 65, 100 )
        self.IsAttacking = true

        vm:SendViewModelMatchingSequence( 11 ) 
    end

    self:DealDamage()

    self:SetNextPrimaryFire( CurTime() + 0.1 )

	self:GetOwner():SetAnimation( PLAYER_ATTACK1 )
end

function SWEP:Think()
    if self.IsReadyToAttack and not self:GetOwner():KeyDown( IN_ATTACK ) and self.IsAttacking then
        self.IsAttacking = false
        self:StopSound( "Weapon_Chainsaw.SawLoop" )
        self:StopSound( "Weapon_Chainsaw.IdleLoop" )
        self:EmitSound( "Weapon_Chainsaw.IdleLoop", 60, 100 )

        local vm = self:GetOwner():GetViewModel()
        vm:SendViewModelMatchingSequence( 10 ) 
    end
end

function SWEP:DealDamage()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end

    local tr = util.TraceLine({
        start = owner:GetShootPos(),
        endpos = owner:GetShootPos() + owner:GetAimVector() * 65,
        filter = owner
    })

    if tr.Hit and tr.HitPos:Distance( owner:GetShootPos() ) <= 65 then
        local ent = tr.Entity

            local bullet = {
                Num = 1,
                Src = owner:GetShootPos(),
                Dir = owner:GetAimVector(),
                Spread = Vector( 0, 0, 0 ),
                Tracer = 0,
                Force = 3,
                Damage = math.random( 32, 64 ),
                Distance = 65
            }

            owner:FireBullets( bullet )

            if IsValid( ent ) and ( ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() ) then

            sound.Play( "physics/body/body_medium_break"..math.random( 2, 4 )..".wav", tr.HitPos, 75, math.random( 75, 155 ), 1 )
            sound.Play( "npc/antlion_guard/antlion_guard_shellcrack"..math.random( 1, 2 )..".wav", tr.HitPos, 75, math.random( 75, 155 ), 1 )
            sound.Play( "ambient/machines/slicer"..math.random( 1, 4 )..".wav", tr.HitPos, 75, math.random( 75, 155 ), 1 )

            local ed = EffectData()
            ed:SetOrigin( tr.HitPos )
            ed:SetNormal( tr.HitNormal )
            ed:SetScale( 6 )
            ed:SetFlags( 3 )
            util.Effect( "bloodspray", ed, true, true )
        end
    end
end


function SWEP:Holster()
    if self.IsReadyToAttack then
        self:TurnOff()
    end

    self:StopSound( "Weapon_Chainsaw.IdleLoop" )
    self:StopSound( "Weapon_Chainsaw.SawLoop" )

    return true
end

function SWEP:OnRemove()
    self:StopSound( "Weapon_Chainsaw.IdleLoop" )
    self:StopSound( "Weapon_Chainsaw.SawLoop" )
end

