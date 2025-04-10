AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Normal crate"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Normal item crate spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.placeCount = 3

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "(In)Convenince Score: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local GM = GAMEMODE

local MEMORY_BREAKABLE = 4
local maxScoreDist = 3000
local tooCloseToPlayer = 2000
local cratePunishmentDist = 950

function ENT:UpdateGivenScore()
    local plys = player.GetAll()
    local distToClosestPly = maxScoreDist^2
    local myPos = self:GetPos()

    for _, currentPly in ipairs( plys ) do
        if currentPly:Health() <= 0 then continue end
        local distToCurrentPlySqr = myPos:DistToSqr( currentPly:GetPos() )
        if distToCurrentPlySqr < distToClosestPly then
            distToClosestPly = distToCurrentPlySqr
        end
    end

    local closestCrateDist = cratePunishmentDist^2
    local tooCloseCount = 0
    local punishmentCount = 0

    for _, currentCrate in ipairs( ents.FindByClass( "item_item_crate" ) ) do
        local distToCurrentCrateSqr = myPos:DistToSqr( currentCrate:GetPos() )
        if distToCurrentCrateSqr < closestCrateDist then
            tooCloseCount = tooCloseCount + 1
            -- if we ever go above 3 crates in proximity, the proximity cost starts racking up
            if tooCloseCount < 3 then continue end
            punishmentCount = tooCloseCount
            closestCrateDist = distToCurrentCrateSqr
        end
    end

    local closestCrateDistLinear = math.sqrt( closestCrateDist )
    local distToClosestPlyLinear = math.sqrt( distToClosestPly )

    -- how far we from the crate punishment distance
    local punishmentGiven = math.abs( closestCrateDistLinear - cratePunishmentDist )
    punishmentGiven = punishmentGiven / cratePunishmentDist
    -- so we have more than 3 crates nearby, that's a base punishment, then we add onto that the closer the 4th crate is to us
    punishmentGiven = punishmentCount + ( punishmentGiven * 7 ) ^ 2

    local scoreGiven = math.Clamp( distToClosestPlyLinear, 0, maxScoreDist )
    scoreGiven = scoreGiven / maxScoreDist
    scoreGiven = ( scoreGiven * 5 )

    scoreGiven = scoreGiven + ( terminator_Extras.GetNookScore( myPos ) - 1.5 ) * 7

    scoreGiven = scoreGiven + -punishmentGiven
    scoreGiven = math.Clamp( scoreGiven, -math.huge, 30 )

    if distToClosestPlyLinear < tooCloseToPlayer then
        scoreGiven = scoreGiven * 0.25
    end

    self:SetGivenScore( scoreGiven )

end

function GM:NormalCrate( pos )
    local itemToSpawn = "dynamic_resupply_fake"
    local count = 1
    if GAMEMODE.roundExtraData then
        local normalCratePlacedCount = GAMEMODE.roundExtraData.normalCratePlacedCount or 0
        GAMEMODE.roundExtraData.normalCratePlacedCount = normalCratePlacedCount + 1
        if ( GAMEMODE.roundExtraData.normalCratePlacedCount % 12 ) == 4 then
            itemToSpawn = "dynamic_specials_resupply_fake"
            count = 10

        end
    end

    local crate = ents.Create( "item_item_crate" )
    crate:SetPos( pos )
    local random = math.random( -4, 4 ) * 45
    crate:SetAngles( Angle( 0, random, 0 ) )
    crate:SetKeyValue( "ItemClass", itemToSpawn )
    crate:SetKeyValue( "ItemCount", count )
    crate:Spawn()

    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE
    end

    return crate

end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()
    local crate = GAMEMODE:NormalCrate( self:OffsettedPlacingPos() )

    crate:EmitSound( "items/ammocrate_open.wav", 75, 100 + -( self.placeCount * 10 ) )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    self.placeCount = self.placeCount + -1

    if self.placeCount > 0 then return end

    SafeRemoveEntity( self )

end