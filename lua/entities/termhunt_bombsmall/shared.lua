AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.Category    = "Other"
ENT.PrintName   = "Small Bomb Gland Bomb"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Explodes"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/weapons/w_bugbait.mdl"

local className = "termhunt_bombsmall"
if CLIENT then
    language.Add( className, ENT.PrintName )
    killicon.Add( className, "vgui/hud/killicon/" .. className .. ".vmt", color_white )

else
    resource.AddFile( "materials/vgui/hud/killicon/" .. className .. ".vmt" )

end

function ENT:Initialize()
    self:SetModel( self.Model )

    if not SERVER then return end

    self:SetUseType( SIMPLE_USE )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

    terminator_Extras.SmartSleepEntity( self, 20 )

    -- Wake up our physics object so we don't start asleep
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
        phys:SetMaterial( "Watermelon" )

    end

    -- Start the motion controller
    self:StartMotionController()

    self.MaxHealth = 10

end

function ENT:OnTakeDamage( dmg )
    local attacker = dmg:GetAttacker()
    if IsValid( attacker ) and ( attacker:IsPlayer() or attacker:IsNPC() ) then
        self.glee_detonator = attacker

    end
    self.fakeHealth = self.fakeHealth or self.MaxHealth
    if dmg:GetDamage() > 2 then
        self:Fire( "IgniteLifetime", 10 )

    end

    -- dont chain explode in one tick!
    if dmg:IsExplosionDamage() then
        dmg:ScaleDamage( 0.005 )

    end

    self.fakeHealth = math.Clamp( self.fakeHealth + -dmg:GetDamage(), 0, self.MaxHealth )

    if ( self.nextDamageSound or 0 ) < CurTime() then
        self.nextDamageSound = CurTime() + self.fakeHealth * 0.05
        local pit = math.random( 15, 25 ) + ( math.abs( self.fakeHealth - self.MaxHealth ) * 4 )
        self:EmitSound( "npc/headcrab_poison/ph_wallhit2.wav", 80, pit + 40 )
        self:EmitSound( "physics/flesh/flesh_squishy_impact_hard4.wav", 80, pit + 60 )

        sound.EmitHint( SOUND_DANGER, self:GetPos(), 400, 3, self )

    end

    if self.fakeHealth <= 0 then
        SafeRemoveEntity( self )

    end
end

function ENT:BloodPlaster( pos, count )
    for _ = 1, count do
        util.Decal( "Blood", pos, pos + ( VectorRand() * math.random( 100, 1000 ) ), nil )

    end
end

function ENT:OnRemove()

    if not SERVER then return end

    if ( self.fakeHealth or self.MaxHealth or 1 ) > 0 then return end

    local worldSpaceC = self:WorldSpaceCenter()

    for _ = 1, 2 do
        self:EmitSound( "npc/antlion_grub/squashed.wav", 100, math.random( 100, 200 ), 1, CHAN_STATIC )

    end

    local attacker = self.glee_detonator
    if not IsValid( attacker ) then
        attacker = self:GetCreator()

    end
    if not IsValid( attacker ) then
        attacker = self:GetOwner()

    end
    if not IsValid( attacker ) then
        attacker = self

    end

    terminator_Extras.GleeFancySplode( worldSpaceC, 115, 115 + 100, attacker, self )

    local BloodPlaster = self.BloodPlaster

    timer.Simple( 0, function()
        BloodPlaster( self, worldSpaceC, 50 )

    end )
end

function ENT:Use( user )
    if not user:IsPlayer() then return end
    if user:Health() <= 0 then return end
    if user:IsPlayerHolding() then
        DropObject( self )

    else
        user:PickupObject( self )

    end
end