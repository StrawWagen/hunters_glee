AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category = "Hunter's Glee"
ENT.PrintName = "Skull Cache"
ENT.Author = "StrawWagen"
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()

ENT.Model = "models/crunchy/props/contagion_props/ammo_crate_b.mdl"
ENT.SkullCount = 10
ENT.SkullOffsetMaxs = Vector( 8, 12, 15 )
ENT.SkullOffsetMins = Vector( -8, -12, 15 )

local IsValid = IsValid

function ENT:Initialize()
    self:SetModel( self.Model )

    if SERVER then
        self.DoNotDuplicate = true

        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetSolid( SOLID_VPHYSICS )
        self:SetUseType( SIMPLE_USE )

        self:SpawnSkulls()

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:SetMass( 100 )
            phys:Wake()

        end
    end
end

if not SERVER then return end

--sandbox support
function ENT:SpawnFunction( ply, tr, ClassName )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 32

    local ent = ents.Create( ClassName )
    ent:SetPos( SpawnPos )
    ent:SetAngles( Angle( 0, -ply:EyeAngles().y, 0 ) ) -- set to player's angle
    ent:Spawn()

    return ent

end

function ENT:SpawnSkulls()
    self.cachedSkulls = {}

    for _ = 1, self.SkullCount do
        local skull = ents.Create( "termhunt_skull_pickup" )
        local offset = Vector(
            math.Rand( self.SkullOffsetMins.x, self.SkullOffsetMaxs.x ),
            math.Rand( self.SkullOffsetMins.y, self.SkullOffsetMaxs.y ),
            math.Rand( self.SkullOffsetMins.z, self.SkullOffsetMaxs.z )

        )
        skull:SetPos( self:LocalToWorld( offset ) )
        skull:SetAngles( AngleRand() )
        skull:SetParent( self )
        skull:Spawn()
        skull:Activate()

        table.insert( self.cachedSkulls, skull )
    end

    self:NextThink( CurTime() + 1 )
end

-- unparent all skulls, apply force to them upwards, with rampup delay for each
function ENT:Use()
    for i, skull in ipairs( self.cachedSkulls ) do
        if not IsValid( skull ) then continue end

        local preReleasePos = skull:GetPos()
        timer.Simple( i * math.Rand( 0.02, 0.04 ), function()
            if not IsValid( skull ) then return end

            skull:SetParent( NULL )
            skull:SetPos( preReleasePos ) -- some buggy bs where they have physics while parented


            local phys = skull:GetPhysicsObject()
            if not IsValid( phys ) then return end
            phys:Wake()
            phys:EnableMotion( true )

            timer.Simple( 0, function()
                if not IsValid( skull ) then return end
                phys:ApplyForceCenter( Vector( 0, 0, 2000 + ( i * 50 ) ) )

            end )
        end )
    end

    self.cachedSkulls = {}

    self:NextThink( CurTime() + 1 )

end

function ENT:Think()
    for _, skull in ipairs( self.cachedSkulls ) do
        if IsValid( skull ) then
            self:NextThink( CurTime() + 1 )
            return true

        end
    end

    self:Dissolve( 0, 1 )
    SafeRemoveEntityDelayed( self, 10 )
    return true

end
