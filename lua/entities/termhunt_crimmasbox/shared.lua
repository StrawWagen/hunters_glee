AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Box"
ENT.Category = "Hunter's Glee"
ENT.Author = "Boomertaters"
ENT.Spawnable = true
ENT.AdminOnly = false

local models = {
    "models/props_junk/cardboard_box001a.mdl",
    "models/props_junk/cardboard_box001b.mdl",
    "models/props_junk/cardboard_box002a.mdl",
    "models/props_junk/cardboard_box002b.mdl",
    "models/props_junk/cardboard_box003a.mdl",
    "models/props_junk/cardboard_box003b.mdl"
}


function ENT:Initialize()
    if CLIENT then return end

    self:SetModel( table.Random( models ) )
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetUseType( CONTINUOUS_USE )
    self:PrecacheGibs()

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
    end
end

function ENT:Use( user )
    if CLIENT then return end
    if not IsValid( user ) or not user:IsPlayer() then return end
    if user:Health() <= 0 or user:GetEyeTrace().Entity ~= self then return end

    local progress = generic_WaitForProgressBar( user, "termhunt_giftbox_open", 0.1, 5 )

    if progress > 0 and progress < 100 and progress ~= self.lastProgress then
        self:HandleShake()
        self.lastProgress = progress
    end

    if progress < 100 then return end

    self:OpenBox()
end


function ENT:HandleShake()
    if timer.Exists( "termhunt_box_shake_" .. self:EntIndex() ) then return end

    self:EmitSound( "physics/cardboard/cardboard_box_impact_soft" .. math.random( 1, 3 ) .. ".wav", 65, math.random( 95, 105 ) )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:ApplyForceCenter( VectorRand() * 50 )
        phys:AddAngleVelocity( VectorRand() * 250 )
    end

    timer.Create( "termhunt_box_shake_" .. self:EntIndex(), 0.27, 1, function() end )
end


function ENT:OpenBox()
    generic_KillProgressBar( nil, "termhunt_giftbox_open" )
    self:EmitSound( "items/ammocrate_open.wav", 155 )

    for i = 1, math.random( 3, 8 ) do
        local supply = ents.Create( "dynamic_box_resupply_fake" )
        if IsValid( supply ) then
            supply:SetPos( self:GetPos() + Vector( 0, 0, 20 ) )
            supply:Spawn()

            local phys = supply:GetPhysicsObject()
            if IsValid( phys ) then
                phys:SetVelocity( VectorRand() * 200 + Vector( 0, 0, 300 ) )
            end
        end
    end

    self:GibBreakServer( Vector( 0, 0, 1000 ) )
    self:Remove()
end


local GAMEMODE = GAMEMODE or GM
if not GAMEMODE.RandomlySpawnEnt then return end

GAMEMODE:RandomlySpawnEnt( "termhunt_crimmasbox", math.huge, 45, 40 )