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

ENT.DecapitatedReward = 300
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

        local scoreGained = math.Round( self:GetGivenScore() )
        if scoreGained < 0 then
            self:DrawPlacingLine( "Cost: " .. scoreGained, nil, 1 )
            self:DrawPlacingLine( "Pays +" .. self.DecapitatedReward .. " when its skull comes off", nil, 2 )

        end
    end
end

if not SERVER then return end

function ENT:ManageMyPos()
    BaseClass.ManageMyPos( self )

    local ang = Angle( 0, self.player:EyeAngles().y + 180, 0 )
    self:SetAngles( ang )

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( -( self.scoreCost or 0 ) )

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

    local score = self:GetGivenScore()
    if score ~= 0 and IsValid( self.player ) and self.player.GivePlayerScore then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    if self.rewardsDecapitation then
        body.glee_deadbodyRewardee = self.player

    end

    SafeRemoveEntity( self )

end

local decapitatedReward = ENT.DecapitatedReward

hook.Add( "glee_ragdollskulldecapitated", "glee_deadbody_payrewardee", function( ragdoll, skull )
    local rewardee = ragdoll.glee_deadbodyRewardee
    if not IsValid( rewardee ) then return end
    ragdoll.glee_deadbodyRewardee = nil

    local reward = decapitatedReward
    rewardee:GivePlayerScore( reward )
    GAMEMODE:SendPlacableScorePopup( rewardee, skull, reward )

end )
