AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Christmas Tree"
ENT.Category = "Hunter's Glee"
ENT.Author = "Boomertaters"
ENT.Spawnable = true
ENT.AdminOnly = false


function ENT:Initialize()
    if CLIENT then return end

    self:SetModel( "models/models_kit/xmas/xmastree_mini.mdl" )
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

        local box = ents.Create( "termhunt_crimmasbox" )
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

GAMEMODE:RandomlySpawnEnt( "termhunt_crimmastree", math.huge, 45, 85 )
