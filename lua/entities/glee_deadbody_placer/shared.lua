AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"
DEFINE_BASECLASS( ENT.Base )

ENT.Category = "Hunter's Glee"
ENT.PrintName = "Hollow Body Placer"
ENT.Author = "StrawWagen"
ENT.Purpose = "Place a body, with a skull."
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()
ENT.Model = "models/humans/group01/male_07.mdl"

ENT.HullCheckSize = Vector( 12, 12, 20 )
ENT.PosOffset = Vector( 0, 0, 20 )

ENT.noPurchaseReason_NoSkull = "You need a skull to place this."

local bodyModels = {
    "models/humans/group01/male_01.mdl",
    "models/humans/group01/male_03.mdl",
    "models/humans/group01/male_07.mdl",
    "models/humans/group01/male_09.mdl",
    "models/humans/group01/female_01.mdl",
    "models/humans/group01/female_06.mdl",
    "models/humans/group01/female_07.mdl",
}
for _, model in ipairs( bodyModels ) do
    util.PrecacheModel( model )

end

if CLIENT then
    function ENT:DoHudStuff()
        self:DrawPlacingLine( "A body, with a skull." )

    end
end

if not SERVER then return end

function ENT:ManageMyPos()
    BaseClass.ManageMyPos( self )

    local ang = Angle( 0, self.player:EyeAngles().y + 180, 0 )
    self:SetAngles( ang )

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( 0 )

end

function ENT:CalculateCanPlace()
    local canPlace, reason = BaseClass.CalculateCanPlace( self )
    if not canPlace then return canPlace, reason end

    local skullCost = self.skullCost or 0
    if skullCost > 0 and self.player:GetSkulls() < skullCost then return false, self.noPurchaseReason_NoSkull end
    return true

end

function ENT:Place()
    local body = ents.Create( "prop_ragdoll" )
    if not IsValid( body ) then return end

    body:SetModel( bodyModels[math.random( 1, #bodyModels )] )
    body:SetPos( self:GetPos() )
    body:SetAngles( self:GetAngles() )
    body:Spawn()
    body:Activate()

    GAMEMODE:HandleRagdollSkulling( body )

    body:EmitSound( "physics/body/body_medium_impact_hard" .. math.random( 1, 6 ) .. ".wav", 75, 100 )
    terminator_Extras.DoPFXFromEnt( "glee_ghostly_ectoplasm", body )

    -- charged here, not on purchase, so cancelling doesn't eat the skull
    local skullCost = self.skullCost or 0
    if skullCost ~= 0 and IsValid( self.player ) and self.player.GivePlayerSkulls then
        self.player:GivePlayerSkulls( -skullCost )

    end

    SafeRemoveEntity( self )

end
