AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Homicidal Glee"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Makes a player immortal"
ENT.Spawnable    = false
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

if CLIENT then
    function ENT:DoHudStuff()
        if not IsValid( self:GetCurrTarget() ) then return end
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2
        local scoreGained = math.Round( self:GetGivenScore() )
        local scoreString = "They've killed you before.\nTheir Homicidal Glee costs nothing to surface!"
        if scoreGained < 0 then
            scoreString = "Cost: " .. tostring( scoreGained )

        end

        surface.SetFont( "scoreGainedOnPlaceFont" )
        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:GetDanceSeq( targ )
    targ = targ or self:GetCurrTarget()
    return targ:SelectWeightedSequence( ACT_GMOD_TAUNT_DANCE )

end

function ENT:GetNearestTarget()
    local nearestPly = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all players within a radius of x units
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if thing:GetClass() == "player" and thing:Health() > 0 then
            -- Calculate the distance between the ply and the entity
            local distance = myPos:DistToSqr( thing:GetPos() )
            if distance < nearestDistance then
                nearestPly = thing
                nearestDistance = distance

            end
        end
    end

    return nearestPly
end

function ENT:CalculateCanPlace()
    local currTarget = self:GetCurrTarget()
    if not IsValid( currTarget ) then return false, "You have to find a vessel for Homicidal Glee." end
    if self:GetDanceSeq() < 0 then return false, "They're too boring to dance." end -- lol if this happens
    if currTarget:IsPlayingTaunt2() then return false, "They're already dancing!" end
    if self.player.glee_nextHomicidalGleePlace and self.player.glee_nextHomicidalGleePlace > CurTime() then return false, "Wait. It's too soon for you to surface one's Homicidal Glee." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    local currTarget = self:GetCurrTarget()
    if not IsValid( currTarget ) then return end
    if GAMEMODE.HasSlighted and GAMEMODE:HasSlighted( currTarget, self.player ) >= 100 then self:SetGivenScore( 0 ) return end

    self:SetGivenScore( -200 )

end

local happyLines = {
    "vo/npc/male01/fantastic01.wav",
    "vo/npc/male01/fantastic02.wav",
    "vo/npc/male01/finally.wav",
    "vo/npc/male01/yeah02.wav",
    "vo/npc/male01/yougotit02.wav",

}
local cheers = {
    "vo/coast/odessa/male01/nlo_cheer01.wav",
    "vo/coast/odessa/male01/nlo_cheer02.wav",
    "vo/coast/odessa/male01/nlo_cheer03.wav",
    "vo/coast/odessa/male01/nlo_cheer04.wav",

}

function ENT:Place()
    local dancer = self:GetCurrTarget()

    if not IsValid( dancer ) then return end

    local danceSeq = self:GetDanceSeq()
    if danceSeq < 0 then return end

    if dancer:InVehicle() then
        dancer:ExitVehicle()

    end

    if not dancer:TauntDance() then return end

    dancer:EmitSound( happyLines[math.random( 1, #happyLines )], 75, math.random( 95, 105 ) )
    timer.Simple( 1, function()
        dancer:EmitSound( cheers[math.random( 1, #cheers )], 75, math.random( 95, 105 ) )

    end )

    local timerName = "homicidal_glee_cheering_" .. dancer:GetCreationID()

    timer.Create( timerName, 3, 0, function()
        -- rage quit!
        if not IsValid( dancer ) then timer.Remove( timerName ) return end
        -- F
        if dancer:Health() < 0 then timer.Remove( timerName ) return end
        if not dancer:IsPlayingTaunt2() then timer.Remove( timerName ) return end

        dancer:EmitSound( cheers[math.random( 1, #cheers )], 75, math.random( 95, 105 ) )

    end )

    self.player.glee_nextHomicidalGleePlace = CurTime() + 30

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( dancer:GetShootPos() ) ) do
        if thing:IsPlayer() and thing ~= dancer then
            table.insert( plysToAlert, thing )

        end
    end

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    local reason = ""
    local reasonGlobal = ""
    if GAMEMODE:HasSlighted( dancer, self.player ) >= 100 then
        reason = "You can't help but dance as the HOMICIDAL GLEE\nof killing " .. self.player:Nick() .. "\nflashes through your mind..."
        reasonGlobal = dancer:Nick() .. " is overcome by their Homicidal Glee."

    else
        reason = "You can't help but dance as " .. self.player:Nick() .. "\nbrings your HOMICIDAL GLEE to the surface..."
        reasonGlobal = dancer:Nick() .. " is overcome with Homicidal Glee."

    end


    huntersGlee_Announce( { dancer }, 10, 8, reason )
    huntersGlee_Announce( plysToAlert, 5, 6, reasonGlobal )

end