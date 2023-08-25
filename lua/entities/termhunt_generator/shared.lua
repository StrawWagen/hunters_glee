AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Score Generator"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Generates score"
ENT.Spawnable    = false
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"

function ENT:SetupDataTables()
    self:NetworkVar( "Entity", 0, "Toucher" )
    self:NetworkVar( "Int", 0, "TouchExpire" )

end

-- spawned in random part of map
-- when people find it and hit +use on it
-- it starts
-- when people are close to it, it spawns score balls every 30 sec

-- terminators break it when they find it

util.PrecacheModel( "models/props_vehicles/generatortrailer01.mdl" )

function ENT:Initialize()
    if SERVER then
        self:SetModel( "models/props_vehicles/generatortrailer01.mdl" )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

        self:SetTrigger( true )
        self:UseTriggerBounds( true, 150 )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SetPos( self:GetPos() + Vector( 0, 0, offset ) )

        end )

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:Wake()

        end

    end
end

function ENT:Think()
end

function ENT:Touch( touched )
    ent.toucher = touched
    ent.touchExpire = CurTime()

end

function ENT:Use( user )
    self:DoScore( user )

end