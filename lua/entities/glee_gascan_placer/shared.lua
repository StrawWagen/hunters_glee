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

        local scoreGainedString = "Gas Can (In)Convenience Score: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

function ENT:ManageMyPos()
    BaseClass.ManageMyPos( self )

    -- on it's side, pointed in a random direction
    local entIndex = self:EntIndex()
    local yaw = ( entIndex * entIndex ) % 360
    local ang = Angle( 90, yaw, 0 )
    self:SetAngles( ang )

end

local maxPlyDist      = 6000      -- players past this distance give no score
local minPlyDist      = 2000      -- players closer than this = penalty instead of reward
local maxScore        = 200       -- best score you can get from a player
local tooClosePenalty = 500       -- negative score if player is too close (full penalty when right next to player, half at minPlyDist)
local maxVehPenalty   = 2000      -- max points a vehicle can subtract
local maxVehDist      = 3000      -- vehicles inside this distance start hurting your score

function ENT:UpdateGivenScore()
    local myPos = self:GetPos()

    local nearestPly, nearestPlyDistSqr = GAMEMODE:nearestAlivePlayer( myPos )

    local scoreGiven = 0
    if IsValid( nearestPly ) then
        local dist = math.sqrt( nearestPlyDistSqr )

        if dist < minPlyDist then
            -- scale penalty from half at minPlyDist up to full when right next to a player
            local closeFraction = 1 - dist / minPlyDist
            local penalty = tooClosePenalty * ( 0.5 + closeFraction * 0.5 )
            scoreGiven = -penalty

            local width = ( scoreGiven / maxPlyDist ) * 500
            self:AddBlameReason( nearestPly, width, "Player" )

        else
            -- scale score with distance up to maxPlyDist
            local distPastMin    = dist - minPlyDist
            local scorableRange  = maxPlyDist - minPlyDist
            local distanceFraction = math.Clamp( distPastMin / scorableRange, 0, 1 )
            scoreGiven = distanceFraction * maxScore

            local width = ( scoreGiven / maxPlyDist ) * 500
            self:AddBlameReason( nearestPly, width, "Player" )

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

            local vehDistFraction = dist / maxVehDist
            local penalty = maxVehPenalty * ( 1 - vehDistFraction )
            scoreGiven = scoreGiven - penalty

            local width = ( -penalty / maxVehPenalty ) * 500
            self:AddBlameReason( user, width, "Gas User" )

        end
    end

    scoreGiven = math.Clamp( scoreGiven, -maxVehPenalty, maxScore )

    self:SetGivenScore( scoreGiven )

end

function ENT:Place()
    local inconvenienceScore = self:GetGivenScore()

    local gas = ents.Create( "prop_physics" )
    local gasModel = gasModels[math.random( #gasModels )]
    gas:SetModel( gasModel )
    gas:SetPos( self:OffsettedPlacingPos() )
    gas:SetAngles( Angle( 90, math.random( 0, 360 ), 0 ) )
    gas:Spawn()
    GAMEMODE:RegisterAsGas( gas )

    terminator_Extras.DoPFXFromEnt( "glee_ghostly_ectoplasm", gas )

    if self.player and self.player.GivePlayerScore and inconvenienceScore then
        self.player:GivePlayerScore( inconvenienceScore )
        GAMEMODE:sendPurchaseConfirm( self.player, inconvenienceScore )

    end

    GAMEMODE:AddMischievousness( self.player, 1, "placed a gas can" )

    SafeRemoveEntity( self )

end
