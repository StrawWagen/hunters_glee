AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"
DEFINE_BASECLASS( ENT.Base )

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
ENT.PosOffset     = Vector( 0, 0, 8 )
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

function ENT:ManageMyPos()
    BaseClass.ManageMyPos( self )

    -- on it's side, pointed in a random direction
    local ang = Angle( 90, ( self:EntIndex() * self:EntIndex() ) % 360, 0 )
    self:SetAngles( ang )

end

local maxPlyDist    = 4000      -- players past this distance give no score
local minPlyDist    = 1600      -- players closer than this = penalty instead of reward
local maxScore      = 175       -- best score you can get from a player
local tooClosePenalty = 100     -- negative score if player is too close
local maxVehPenalty = 3000      -- max points a vehicle can subtract
local maxVehDist    = 3000      -- vehicles inside this distance start hurting your score

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

    -- vehicles near? lose a LOT, can't escape that easily!
    local gasUsers = GAMEMODE.GasUsers
    if gasUsers then
        for _, user in ipairs( gasUsers ) do
            if not IsValid( user ) then continue end

            local dist = myPos:Distance( user:GetPos() )
            if dist > maxVehDist then continue end

            local penalty = maxVehPenalty * (1 - dist / maxVehDist)
            scoreGiven = scoreGiven - penalty

        end
    end

    scoreGiven = math.Clamp( scoreGiven, -maxVehPenalty, maxScore )

    self:SetGivenScore( scoreGiven )

end

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
