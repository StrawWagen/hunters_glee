AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Tree"
ENT.Category = "Hunter's Glee"
ENT.Author = "Boomertaters"
ENT.Spawnable = true
ENT.AdminOnly = false


function ENT:Initialize()
    if CLIENT then return end

    self:SetModel( "models/props_foliage/tree_deciduous_03b.mdl" )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_NONE )
    self:SetSolid( SOLID_VPHYSICS )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:EnableMotion( false )
    end

    self:DropToFloor()
    self:SpawnBoxes()
end


function ENT:SpawnBoxes()
    for i = 0, 4 do
        local angle = i * ( math.pi * 2 / 5 )
        local offset = Vector(
            math.cos( angle ) * 80,
            math.sin( angle ) * 80,
            60
        )

        local box = ents.Create( "termhunt_box" )
        if not IsValid( box ) then continue end

        box:SetPos( self:GetPos() + offset )
        box:SetAngles( Angle( 0, math.random( 360 ), 0 ) )
        box:Spawn()

        local phys = box:GetPhysicsObject()
        if IsValid( phys ) then
            phys:Wake()
        end
    end
end


local GAMEMODE = GAMEMODE or GM
if not GAMEMODE.RandomlySpawnEnt then return end

GAMEMODE:RandomlySpawnEnt( "termhunt_tree", math.huge, 20, 165 )