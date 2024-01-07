AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Terminator Overcharger"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Overcharges a terminator"
ENT.Spawnable    = false
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local stringPt1 = "Overcharging Cost: "

        local scoreString = stringPt1 .. tostring( scoreGained )

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:GetNearestTarget()
    local nearestTerm = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all terminators
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if thing.isTerminatorHunterBased and thing:Health() > 0 then
            -- Calculate the distance between the ply and the entity
            local distance = myPos:DistToSqr( thing:GetPos() )
            if distance < nearestDistance then
                nearestTerm = thing
                nearestDistance = distance

            end
        end
    end

    return nearestTerm
end

function ENT:CalculateCanPlace()
    if not IsValid( self:GetCurrTarget() ) then return false, "You can't overcharge nothing." end
    if self:GetCurrTarget().terminator_OverCharged then return false, "It's already overcharged." end
    if GAMEMODE:isTemporaryTrueBool( "glee_playerplaced_termovercharger" ) then return false, "It's too soon for another terminator to be overcharged." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    if not IsValid( self:GetCurrTarget() ) then self:SetGivenScore( 0 ) return end
    self:SetGivenScore( -400 )
end

function ENT:Place()
    local targ = self:GetCurrTarget()

    if not IsValid( targ ) then return end

    -- see autorun/server/huntersglee_lightning
    glee_Overcharge( targ )
    GAMEMODE:setTemporaryTrueBool( "glee_playerplaced_termovercharger", 180 )

    huntersGlee_Announce( player.GetAll(), 80, 15, self.player:Nick() .. " has overcharged a Terminator..." )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )

    end

    self:TellPlyToClearHighlighter()

    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    SafeRemoveEntity( self )

end