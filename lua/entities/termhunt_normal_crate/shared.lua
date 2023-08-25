AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Normal crate"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Normal item crate spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.placeCount = 3

local MEMORY_BREAKABLE = 4
local maxScoreDist = 3000
local tooCloseToPlayer = 2000
local cratePunishmentDist = 1100

function ENT:GetGivenScore()
    local plys = player.GetAll()
    local smallestDist = maxScoreDist^2

    for _, currentPly in ipairs( plys ) do
        if currentPly:Health() <= 0 then continue end
        local distToCurrentPlySqr = self:GetPos():DistToSqr( currentPly:GetPos() )
        if distToCurrentPlySqr < smallestDist then
            smallestDist = distToCurrentPlySqr
        end
    end

    local smallestPunishmentDist = cratePunishmentDist^2
    local tooCloseCount = 0
    local punishmentCount = 0

    for _, currentCrate in ipairs( ents.FindByClass( "item_item_crate" ) ) do
        local distToCurrentCrateSqr = self:GetPos():DistToSqr( currentCrate:GetPos() )
        if distToCurrentCrateSqr < smallestPunishmentDist then
            tooCloseCount = tooCloseCount + 1
            if tooCloseCount < 3 then continue end
            punishmentCount = tooCloseCount
            smallestPunishmentDist = distToCurrentCrateSqr
        end
    end

    local punishmentLinear = math.sqrt( smallestPunishmentDist )
    local smallestDistLinear = math.sqrt( smallestDist )

    local punishmentGiven = math.abs( punishmentLinear - cratePunishmentDist )
    punishmentGiven = punishmentGiven / cratePunishmentDist
    punishmentGiven = punishmentCount + punishmentGiven * 7

    local scoreGiven =  math.Clamp( smallestDistLinear, 0, maxScoreDist )
    scoreGiven = scoreGiven / maxScoreDist
    scoreGiven = ( scoreGiven * 15 )

    scoreGiven = scoreGiven + -punishmentGiven

    if smallestDistLinear < tooCloseToPlayer then
        scoreGiven = scoreGiven * 0.25
    end

    return scoreGiven, punishmentGiven

end

hook.Add( "HUDPaint", "specialscrate_paintscore", function()
    if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
    if not IsValid( LocalPlayer().specialsCrate ) then return end

    local screenMiddleW = ScrW() / 2
    local screenMiddleH = ScrH() / 2

    local scoreGained = math.Round( GAMEMODE:ValidNum( LocalPlayer().specialsCrate.oldScoreGiven ) )

    local scoreGainedString = "(In)Convenince Score: " .. tostring( scoreGained )
    surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

end )

function ENT:SetupPlayer()
    self.player.specialsCrate = self
    self.player.ghostEnt = self
end

if not SERVER then return end

local GM = GAMEMODE

function GM:NormalCrate( pos )
    local itemToSpawn = "dynamic_resupply_fake"
    local count = 1
    if GAMEMODE.roundExtraData then
        local normalCratePlacedCount = GAMEMODE.roundExtraData.normalCratePlacedCount or 0
        GAMEMODE.roundExtraData.normalCratePlacedCount = normalCratePlacedCount + 1
        if ( GAMEMODE.roundExtraData.normalCratePlacedCount % 12 ) == 4 then
            itemToSpawn = "dynamic_specials_resupply_fake"
            count = 12

        end
    end

    local crate = ents.Create( "item_item_crate" )
    crate:SetPos( pos )
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
    local crate = GAMEMODE:NormalCrate( self:GetPos2() )

    crate:EmitSound( "items/ammocrate_open.wav", 75, 100 + -( self.placeCount * 10 ) )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )

    end

    self.placeCount = self.placeCount + -1

    if self.placeCount > 0 then return end

    SafeRemoveEntity( self )

end