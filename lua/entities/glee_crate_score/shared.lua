AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "termhunt_normal_crate"
DEFINE_BASECLASS( ENT.Base )

ENT.Category    = "Other"
ENT.PrintName   = "Score Crate"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops score pickups, the more score you get from it the more score pickups it drops"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )


if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "(In)Convenience Score: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local GM = GAMEMODE

ENT.normCrateScoreMultiplier = 2

function GM:ScoreCrate( pos, scoreBallsToGive )
    if not pos then return end

    scoreBallsToGive = scoreBallsToGive or 3

    local crate = ents.Create( "item_item_crate" )
    crate:SetPos( pos )
    local random = math.random( -4, 4 ) * 45
    crate:SetAngles( Angle( 0, random, 0 ) )
    crate:SetKeyValue( "ItemClass", "termhunt_score_pickup" )
    crate:SetKeyValue( "ItemCount", scoreBallsToGive )
    crate:Spawn()

    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE
    end

    return crate

end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()

    local scoreBallsToGive = math.ceil( betrayalScore / 15 )
    local crate = GAMEMODE:ScoreCrate( self:OffsettedPlacingPos(), scoreBallsToGive )

    crate:EmitSound( "items/ammocrate_open.wav", 75, 100 )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    self.placeCount = self.placeCount + -1

    if self.placeCount > 0 then return end

    SafeRemoveEntity( self )

end