AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

ENT.Category    = "Hunter's Glee"
ENT.PrintName   = "Flare"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Flares"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/plates/plate.mdl"

local invis = Color( 255, 255, 255, 0 )

local lifetime = 20

function ENT:Initialize()
    self:SetModel( self.Model )

    if not SERVER then return end

    self:SetColor( invis )
    self:SetRenderMode( RENDERMODE_TRANSTEXTURE )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_NONE )

    SafeRemoveEntityDelayed( self, lifetime )

    -- Wake up our physics object so we don't start asleep
    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
        timer.Simple( 1, function()
            if not phys or not phys:IsValid() then return end
            phys:EnableDrag( true )
            phys:SetDragCoefficient( 48 )

        end )

    end

    local flareReal = ents.Create( "env_flare" )
    if not IsValid( flareReal ) then return false end

    flareReal:SetKeyValue( "spawnflags", 0 )
    flareReal:SetKeyValue( "scale", "20" )
    flareReal:Spawn()
    flareReal:Activate()
    flareReal:SetParent( self )
    flareReal:Fire( "Start", tostring( lifetime ), 0.0 )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self.BurnSound = CreateSound( self, "weapons/flaregun/burn.wav" )
        self.BurnSound:Play()
        self.BurnSound:ChangePitch( 80, lifetime )

    end )

end

function ENT:PhysicsCollide( colData, collider )
    colData.HitEntity:Ignite( 5 )

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

end

function ENT:OnRemove()
    if self.BurnSound then
        self.BurnSound:Stop()

    end
end