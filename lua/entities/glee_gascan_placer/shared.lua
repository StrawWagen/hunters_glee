AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.PrintName   = "Gas Can Placer"
ENT.Author      = "Boomer T Tots"
ENT.Purpose     = "Place a gas can."
ENT.Spawnable   = false
ENT.Category    = "Hunter's Glee"

local gasModels = {
    "models/props_junk/gascan001a.mdl",
    "models/props_junk/metalgascan.mdl",
}

ENT.Model         = gasModels[1]
ENT.HullCheckSize = Vector( 10, 10, 8 )
ENT.PosOffset     = Vector( 0, 0, 40 )
ENT.placeCount    = 1
ENT.OverrideOffsetFromFloor = 25

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "Gas Can Score: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local maxPlyDist    = 4000
local minPlyDist    = 600
local maxScore      = 175
local tooClosePenalty = 100

function ENT:UpdateGivenScore()
    local myPos = self:GetPos()

    local nearestPly, nearestPlyDistSqr = GAMEMODE:nearestAlivePlayer( myPos )

    local scoreGiven = 0
    if IsValid( nearestPly ) then
        local dist = math.sqrt( nearestPlyDistSqr )

        if dist < minPlyDist then
            -- way too close, hard punish
            scoreGiven = -tooClosePenalty
        else
            -- scale score with distance up to maxPlyDist
            local t = math.Clamp( ( dist - minPlyDist ) / ( maxPlyDist - minPlyDist ), 0, 1 )
            scoreGiven = t * maxScore
        end
    end

    scoreGiven = scoreGiven + ( terminator_Extras.GetNookScore( myPos ) * 6 )
    scoreGiven = math.Clamp( scoreGiven, -100, 200 )

    self:SetGivenScore( scoreGiven )

end

-- had to add this so it would play the ectoplasm effect 
function ENT:Place()
    local betrayalScore = self:GetGivenScore()

    local gas = ents.Create( "prop_physics" )
    gas:SetModel( gasModels[math.random( #gasModels )] )
    gas:SetPos( self:OffsettedPlacingPos() )
    gas:SetAngles( Angle( 90, math.random( 0, 360 ), 0 ) )
    gas:Spawn()
    GAMEMODE:RegisterAsGas( gas )

    terminator_Extras.DoPFXFromEnt( "glee_ghostly_ectoplasm", gas )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    GAMEMODE:AddMischievousness( self.player, 1, "placed a gas can" )

    self.placeCount = self.placeCount + -1
    if self.placeCount > 0 then return end

    SafeRemoveEntity( self )

end
