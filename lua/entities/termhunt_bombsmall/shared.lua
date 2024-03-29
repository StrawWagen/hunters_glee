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

function ENT:Initialize()
    self:SetModel( self.Model )

    if not SERVER then return end

    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

    -- Wake up our physics object so we don't start asleep
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()

    end

    -- Start the motion controller
    self:StartMotionController()

    self.MaxHealth = 10
end

function ENT:OnTakeDamage( dmg )
    self.fakeHealth = self.fakeHealth or self.MaxHealth
    if dmg:GetDamage() > 2 then
        self:Fire( "IgniteLifetime", 10 )

    end

    if dmg:IsExplosionDamage() then
        dmg:ScaleDamage( 0.005 )

    end

    self.fakeHealth = math.Clamp( self.fakeHealth + -dmg:GetDamage(), 0, self.MaxHealth )

    if ( self.nextDamageSound or 0 ) < CurTime() then
        self.nextDamageSound = CurTime() + self.fakeHealth * 0.05
        local pit = math.random( 15, 25 ) + ( math.abs( self.fakeHealth - self.MaxHealth ) * 4 )
        self:EmitSound( "npc/headcrab_poison/ph_wallhit2.wav", 80, pit + 40 )
        self:EmitSound( "physics/flesh/flesh_squishy_impact_hard4.wav", 80, pit + 60 )

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

    local explode = ents.Create( "env_explosion" )
    explode:SetPos( Vector( worldSpaceC.x, worldSpaceC.y, worldSpaceC.z ) )
    explode:SetOwner( self:GetCreator() or self )
    explode:Spawn()
    explode:SetKeyValue( "iMagnitude", 1 * 115 )
    explode:Fire( "Explode", 0, 0 )

    local BloodPlaster = self.BloodPlaster

    timer.Simple( 0, function()
        BloodPlaster( self, worldSpaceC, 50 )

    end )

end