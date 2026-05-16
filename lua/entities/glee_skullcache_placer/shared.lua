AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "termhunt_weapon_crate"
DEFINE_BASECLASS( ENT.Base )

ENT.Category = "Hunter's Glee"
ENT.PrintName = "Skull Cache Placer"
ENT.Author = "StrawWagen"
ENT.Purpose = "Place a hidden cache of skulls."
ENT.Spawnable = true
ENT.AdminOnly = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/crunchy/props/contagion_props/ammo_crate_b.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 20 )

ENT.weapCrateScoreMultiplier = 2


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

function ENT:ManageMyPos()
    BaseClass.ManageMyPos( self )

    local ang = Angle( 0, self.player:EyeAngles().y + 180, 0 )
    self:SetAngles( ang )

end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()

    local cache = ents.Create( "glee_skullcache" )
    cache:SetPos( self:OffsettedPlacingPos() )
    cache:SetAngles( self:GetAngles() )
    cache:Spawn()

    cache:EmitSound( "items/ammocrate_open.wav", 75, 100 )
    terminator_Extras.DoPFXFromEnt( "glee_ghostly_ectoplasm", cache )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    SafeRemoveEntity( self )

end
