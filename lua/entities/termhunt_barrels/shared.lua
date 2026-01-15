AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Barrels"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Random barrel spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/props_c17/oildrum001_explosive.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.placeCount = 6

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local scoreGainedAlt = math.Round( self:GetGivenScoreAlt() )

        local scoreString = "Barreling Score: " .. tostring( scoreGained )
        local stringPt2 = "\nToo far/close to players cost: "

        if scoreGainedAlt ~= 0 then
            scoreString = scoreString .. stringPt2 .. tostring( scoreGainedAlt )

        end

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:SkinRandomize()
    self:SetSkin( math.random( 0, self:SkinCount() ) )

end

function ENT:BarrelRandomize()
    local model = ""
    if math.random( 0, 100 ) > 35 then
        model = "models/props_c17/oildrum001_explosive.mdl"

    else
        model = "models/props_c17/oildrum001.mdl"

    end

    self:SetModel( model )

    local yaw = math.Rand( -180, 180 )
    local ang = Angle( 0, yaw ,0 )
    self:SetAngles( ang )

    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        self:SkinRandomize()

    end )
end

if not SERVER then return end

local termhunt_barrels_spawned = {}

function ENT:GetBarrels()
    local potentialBarrels = ents.FindByClass( "prop_physics" )

    termhunt_barrels_spawned = {}

    potentialBarrels = table.Add( potentialBarrels )

    for _, barrel in ipairs( potentialBarrels ) do
        if barrel:GetNWBool( "placedbybarrel" ) == true then
            table.insert( termhunt_barrels_spawned, barrel )

        end
    end
end

function ENT:PostInitializeFunc()
    termhunt_barrels_spawned = self:GetBarrels()

end

local MEMORY_VOLATILE = 8
local barrelPunishmentDist = 1250

local tooCloseToPlySqr = 200^2
local tooFarFromPlySqr = 1500^2

function ENT:UpdateGivenScore()
    local smallestPunishmentDist = barrelPunishmentDist^2
    local tooCloseCount = 0
    local punishmentCount = 0

    local myPos = self:GetPos()
    local nearestPly, nearestPlyDistSqr
    local roundCostPermanent

    if GAMEMODE.ISHUNTERSGLEE then
        nearestPly, nearestPlyDistSqr = GAMEMODE:nearestAlivePlayer( myPos )
        roundCostPermanent = GAMEMODE.roundExtraData.BarrelPlacedCount or 0
        roundCostPermanent = roundCostPermanent / 20 -- so barrels eventually always become unprofitable on super super long rounds

    end

    if termhunt_barrels_spawned then
        for _, currentBarrel in ipairs( termhunt_barrels_spawned ) do
            if not IsValid( currentBarrel ) then continue end -- table is validated elsewhere
            local distToCurrentBarrelSqr = myPos:DistToSqr( currentBarrel:GetPos() )

            if distToCurrentBarrelSqr < smallestPunishmentDist then
                tooCloseCount = tooCloseCount + 1
                if tooCloseCount < 6 then continue end
                punishmentCount = tooCloseCount
                smallestPunishmentDist = distToCurrentBarrelSqr

            end
        end
    end

    local punishmentLinear = math.sqrt( smallestPunishmentDist )

    local punishmentGiven = math.abs( punishmentLinear - barrelPunishmentDist )
    punishmentGiven = punishmentGiven / barrelPunishmentDist
    punishmentGiven = punishmentGiven ^ 2
    punishmentGiven = punishmentCount + punishmentGiven * 40

    local barrelCount = 0
    if termhunt_barrels_spawned and #termhunt_barrels_spawned then
        barrelCount = #termhunt_barrels_spawned

    end

    if IsValid( nearestPly ) and ( nearestPlyDistSqr < tooCloseToPlySqr or nearestPlyDistSqr > tooFarFromPlySqr ) then
        local proxPenalty = 40
        punishmentGiven = punishmentGiven + proxPenalty
        self:SetGivenScoreAlt( -proxPenalty )

    else
        self:SetGivenScoreAlt( 0 )

    end

    local scoreGiven = 40 - barrelCount -- 40 score if 0 barrels, 0 score if 40
    scoreGiven = scoreGiven + -roundCostPermanent -- always cost more, the more barrels placed
    scoreGiven = scoreGiven + -punishmentGiven
    scoreGiven = math.Clamp( scoreGiven, -75, 15 )
    scoreGiven = scoreGiven + ( terminator_Extras.GetNookScore( myPos ) * 2 ) -- flat add if placed in nooks

    self:SetGivenScore( scoreGiven )

end

function ENT:Place()
    local barrel = ents.Create( "prop_physics" )
    barrel:SetPos( self:OffsettedPlacingPos() )
    barrel:SetModel( self:GetModel() )
    barrel:SetAngles( self:GetAngles() )
    barrel:SetSkin( self:GetSkin() )
    barrel:Spawn()

    terminator_Extras.SmartSleepEntity( barrel, 40 )

    self:GetBarrels()

    barrel:SetNWBool( "placedbybarrel", true )
    barrel:EmitSound( "Metal_Barrel.ImpactHard", 75, 100 + -( self.placeCount * 10 ) )

    if barrel:Health() > 0 then
        barrel.terminatorHunterInnateReaction = function()
            return MEMORY_VOLATILE

        end
    end

    local betrayalScore = self:GetGivenScore()

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

        GAMEMODE.roundExtraData.BarrelPlacedCount = ( GAMEMODE.roundExtraData.BarrelPlacedCount or 0 ) + 1

    end

    GAMEMODE:AddMischievousness( self.player, 1, "placed a barrel" )

    self.placeCount = self.placeCount + -1

    if self.placeCount > 0 then
        self:BarrelRandomize()

        return
    end

    SafeRemoveEntity( self )

end