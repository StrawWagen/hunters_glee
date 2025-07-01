AddCSLuaFile()

game.AddAmmoType( { name = "Uranium 235", dmgtype = DMG_AIRBOAT } )
if CLIENT then
    language.Add( "Uranium 235_ammo", "Uranium 235" )

end

ENT.Author = "Dnjido"
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Uranium 235"
ENT.Category = "Hunter's Glee"
ENT.Editable = true
ENT.Spawnable = true
ENT.AdminOnly = false

function ENT:Draw()
    self:DrawModel()

end

local up10 = Vector( 0, 0, 10 )

function ENT:Initialize()
    if not SERVER then return end

    self:SetModel( "models/entity/uranium.mdl" )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetCollisionGroup( COLLISION_GROUP_INTERACTIVE )
    self:DrawShadow( false )
    self:SetPos( self:GetPos() + up10 )

    local phys = self:GetPhysicsObject()
    if not phys:IsValid() then return end
    phys:Wake()

end

function ENT:PhysicsCollide( data )
    if data.Speed <= 100 then return end
    self:EmitSound( "SolidMetal.ImpactSoft" )

end

function ENT:Touch( entity )
    if not entity:IsPlayer() then return end
    self.User = entity
    self:Remove()

end

function ENT:Use( entity )
    if not entity:IsPlayer() then return end
    self.User = entity
    self:Remove()
end

function ENT:OnRemove()
    if not SERVER or not IsValid( self.User ) then return end
    self.User:GiveAmmo( 20, "Uranium 235" )

end