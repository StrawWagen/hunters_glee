AddCSLuaFile()

ENT.Base = "base_gmodentity"
ENT.Type = "anim"
ENT.PrintName   = "Riot Shield"
ENT.Author      = "dedactedlife and IndefiniteXD"
ENT.Purpose     = "No bullets shall pass!"
ENT.Spawnable   = true
ENT.AdminOnly   = game.IsDedicated()
ENT.Category    = "Hunter's Glee"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "materials/entities/glee_backpackable_shield.png"
ENT.CurrentHealth = 1000

ENT.Model = "models/glee/weapons/shield/w_riot_shield.mdl" -- upside down, see SpawnFunction
ENT.GunModel = "models/glee/weapons/shield/w_riot_shield.mdl"

local glee_Carrying = terminator_Extras.glee_Carrying

if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_shield", "materials/entities/glee_backpackable_shield.png" )

end

glee_Carrying.MakeCarryable( ENT, "glee_backpackable_shield" )

function ENT:Initialize()
    self:SetModel( self.Model )
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	--self:SetCollisionGroup( COLLISION_GROUP_WEAPON )
	self:DrawShadow( true )
end

if SERVER then
    function ENT:OnTraceAttack(info,dir)
        if info:IsDamageType(DMG_BULLET) or info:IsDamageType(DMG_CLUB) then
            self:EmitSound("Computer.ImpactHard")
            self.CurrentHealth = self.CurrentHealth - info:GetDamage()
        end
    end

    function ENT:Think()
        if self.CurrentHealth <= 0 then
            self:Remove()
        end
    end
end