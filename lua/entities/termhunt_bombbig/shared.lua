AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.Category    = "Other"
ENT.PrintName   = "Big Bomb Gland Bomb"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Explodes"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/gibs/antlion_gib_large_3.mdl"

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
        phys:SetMass( phys:GetMass() * 50 )

    end

    -- Start the motion controller
    self:StartMotionController()

    self.MaxHealth = 30
end

function ENT:PhysicsCollide( data, _ )
    if data.Speed < 40 then return end
    util.ScreenShake( self:GetPos(), data.Speed / 40, 20, 0.5, 800 )
    self:EmitSound( "Flesh.ImpactHard" )

end

function ENT:OnTakeDamage( dmg )
    self.fakeHealth = self.fakeHealth or self.MaxHealth
    if dmg:GetDamage() > 2 then
        self:Fire( "IgniteLifetime", 10 )

    end

    if dmg:IsExplosionDamage() and self.fakeHealth + -dmg:GetDamage() < self.fakeHealth then
        dmg:SetDamage( 0 )
        self.fakeHealth = math.Rand( 0.5, 1.5 )

    end

    self.fakeHealth = math.Clamp( self.fakeHealth + -dmg:GetDamage(), 0, self.MaxHealth )

    if ( self.nextDamageSound or 0 ) < CurTime() then
        self.nextDamageSound = CurTime() + self.fakeHealth * 0.05
        local pit = math.random( 15, 25 ) + ( math.abs( self.fakeHealth - self.MaxHealth ) * 4 )
        self:EmitSound( "npc/headcrab_poison/ph_wallhit2.wav", 80, pit )
        self:EmitSound( "physics/flesh/flesh_squishy_impact_hard4.wav", 80, pit + 20 )

        local obj = self:GetPhysicsObject()
        obj:ApplyForceCenter( VectorRand() * obj:GetMass() * 200 )

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

    for _ = 1, 8 do
        self:EmitSound( "npc/antlion_grub/squashed.wav", 100, math.random( 50, 150 ), 1, CHAN_STATIC )

    end

    self:EmitSound( "ambient/machines/thumper_hit.wav", 100, 120, 1, CHAN_STATIC )

    util.ScreenShake( self:GetPos(), 30, 40, 1, 800 )
    util.ScreenShake( self:GetPos(), 5, 20, 3, 3000 )

    local explode = ents.Create( "env_explosion" )
    explode:SetPos( Vector( worldSpaceC.x, worldSpaceC.y, worldSpaceC.z ) )
    explode:SetOwner( self:GetCreator() or self )
    explode:Spawn()
    explode:SetKeyValue( "iMagnitude", 4 * 115 )
    explode:Fire( "Explode", 0, 0 )

    for _ = 1, 8 do
        local grossSplat = EffectData()
        grossSplat:SetOrigin( self:GetPos() )
        grossSplat:SetScale( 3.5 )
        grossSplat:SetMagnitude( 20 )
        grossSplat:SetNormal( VectorRand() )

        util.Effect( "StriderBlood", grossSplat )

    end

    local BloodPlaster = self.BloodPlaster

    timer.Simple( 0, function()
        BloodPlaster( self, worldSpaceC, 50 )

    end )

end

function ENT:UpdateTransmitState()
    return TRANSMIT_PVS

end

function ENT:PhysicsSimulate( _, _ )
    return SIM_NOTHING
end