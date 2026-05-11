AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "termhunt_weapon_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Heavy Weapons Crate"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Heavy weapons inside!"
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

function GM:HeavyWeaponsCrate( pos )
    if not pos then return end

    local crate = ents.Create( "item_item_crate" )
    crate:SetPos( pos )
    local random = math.random( -4, 4 ) * 45
    crate:SetAngles( Angle( 0, random, 0 ) )
    crate:SetKeyValue( "ItemClass", "dynamic_heavy_weapons" )
    crate:SetKeyValue( "ItemCount", 3 )
    crate:Spawn()

    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE
    end

    return crate

end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()
    local crate = GAMEMODE:HeavyWeaponsCrate( self:OffsettedPlacingPos() )

    crate:EmitSound( "items/ammocrate_open.wav", 75, 100 )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    SafeRemoveEntity( self )

end