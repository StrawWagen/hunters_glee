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

function ENT:SetupDataTables()
    self:NetworkVar( "Float", 0, "DeathTime" )

end

--sandbox support
function ENT:SpawnFunction( ply, tr )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 20

    local ent = ents.Create( "termhunt_flare" )
    ent:Spawn()
    ent:SetPos( SpawnPos )
    ent:SetOwner( ply )

    return ent

end

function ENT:Initialize()
    self:SetModel( self.Model )

    if not SERVER then return end

    self:SetColor( invis )
    self:SetRenderMode( RENDERMODE_TRANSTEXTURE )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )

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

    flareReal.terminatorIgnoreEnt = true
    flareReal:SetKeyValue( "spawnflags", 0 )
    flareReal:SetKeyValue( "scale", "8" )
    flareReal:SetParent( self )
    flareReal:Spawn()
    flareReal:Activate()
    flareReal:Fire( "Start", tostring( lifetime ), 0.1 )

    self:DeleteOnRemove( flareReal )

    self:SetDeathTime( CurTime() + lifetime )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self.BurnSound = CreateSound( self, "weapons/flaregun/burn.wav" )
        self.BurnSound:Play()
        self.BurnSound:ChangePitch( 80, lifetime )


    end )

end

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS

end

function ENT:PhysicsCollide( colData, _ )

    local hitEnt = colData.HitEntity
    if not IsValid( hitEnt ) then return end

    local nextDealBurnDamage = hitEnt.glee_Flaregun_NextDealBurnDamage or 0
    if nextDealBurnDamage > CurTime() then return end
    hitEnt.glee_Flaregun_NextDealBurnDamage = CurTime() + 0.1

    local impactDamage = colData.Speed / 30
    impactDamage = math.Clamp( impactDamage, 0, 25 )

    if impactDamage >= 5 then
        local dmgInfo = DamageInfo()
        dmgInfo:SetDamage( impactDamage )
        dmgInfo:SetDamageType( DMG_BURN )
        hitEnt:TakeDamageInfo( dmgInfo )

    end

    local igniteTime = impactDamage / 2.5
    if hitEnt:IsPlayer() then
        igniteTime = math.Clamp( igniteTime, 0, 5 )

    end

    hitEnt:Ignite( igniteTime )

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )

end

function ENT:OnRemove()
    if self.BurnSound then
        self.BurnSound:Stop()

    end
end

function ENT:Think()
    local myPos = self:GetPos()
    local contents = util.PointContents( myPos )
    if bit.band( contents, CONTENTS_WATER ) == CONTENTS_WATER then
        sound.Play( "hl1/fvox/hiss.wav", myPos, 80, 150 )
        sound.Play( "ambient/water/water_splash1.wav", myPos, 80, 120 )
        SafeRemoveEntity( self )

    end
end

if not CLIENT then return end

local flaresThatPierceFog = {}

local flareMatId = surface.GetTextureID( "effects/redflare" )
local flareColor = Color( 255, 255, 255 )
local slowSpeed = 10^2

hook.Add( "RenderScreenspaceEffects", "glee_predraw_fogpiercing_flares", function()

    local me = LocalPlayer()
    local myShootPos = me:GetShootPos()

    for _, flare in pairs( flaresThatPierceFog ) do

        local flaresRealPos = flare:WorldSpaceCenter()
        local pos2d = flaresRealPos:ToScreen()

        if not pos2d.visible then continue end
        if flare:GetVelocity():LengthSqr() < slowSpeed then continue end

        local distanceToIt = myShootPos:Distance( flaresRealPos )
        if distanceToIt < 1000 then continue end

        local canSee = terminator_Extras.PosCanSeeComplex( myShootPos, flaresRealPos, me )
        if not canSee then continue end

        local distScalar = math.log( distanceToIt, 4 ) * 5
        local timeToDeath = math.abs( flare:GetDeathTime() - CurTime() )
        local size = math.Clamp( ( timeToDeath / lifetime ) + 1, 0, 1 )
        size = size * 75

        local width = size + -distScalar
        local height = size + -distScalar

        local jitter = width * 0.05

        local jitterx = math.Rand( -jitter, jitter )
        local jittery = math.Rand( -jitter, jitter )

        local halfWidth = width / 2
        local halfHeight = height / 2

        local texturedQuadStructure = {
            texture = flareMatId,
            color   = flareColor,
            x 	= pos2d.x + -halfWidth + jitterx,
            y 	= pos2d.y + -halfHeight + jittery,
            w 	= width,
            h 	= height
        }

        draw.TexturedQuad( texturedQuadStructure )

    end
end )

function ENT:Think()
    local myId = self:GetCreationID()

    if not flaresThatPierceFog[myId] then
        flaresThatPierceFog[myId] = self

    end
end

function ENT:OnRemove()
    flaresThatPierceFog[self:GetCreationID()] = nil

end