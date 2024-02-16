AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

ENT.Category    = "Other"
ENT.PrintName   = "Homicidal Glee"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Makes a player immortal"
ENT.Spawnable    = false
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

if CLIENT then
    function ENT:DoHudStuff()
        -- no hud stuff
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
    if GAMEMODE.HasHomicided and not GAMEMODE:HasHomicided( currTarget, self.player ) then return false, "They haven't killed you!" end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    if not IsValid( self:GetCurrTarget() ) then return end
    return 0
end

function ENT:Place()
    local dancer = self:GetCurrTarget()

    if not IsValid( dancer ) then return end

    local danceSeq = self:GetDanceSeq()
    if danceSeq < 0 then return end

    if not dancer:TauntDance() then return end

    self.player.glee_nextHomicidalGleePlace = CurTime() + 15

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( dancer:GetShootPos() ) ) do
        if thing:IsPlayer() and thing ~= dancer then
            table.insert( plysToAlert, thing )

        end
    end

    huntersGlee_Announce( { dancer }, 10, 10, "You can't help but dance as the HOMICIDAL GLEE\nof killing " .. self.player:Name() .. "\nflashes through your mind..." )
    huntersGlee_Announce( plysToAlert, 5, 8, dancer:Name() .. " is overcome by their Homicidal Glee." )
end