AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Beartrap Spawner"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Spawns beartraps."
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/stiffy360/beartrap.mdl"

ENT.HullCheckSize = Vector( 1, 1, 1 )
ENT.PosOffset = Vector( 0, 0, 10 )


if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local str = "Cost: " .. tostring( scoreGained )
        local intersectCost = self:GetNW2Int( "glee_additionalcontext1", 0 )
        local proxCost = self:GetNW2Int( "glee_additionalcontext2", 0 )
        if intersectCost ~= 0 or proxCost ~= 0 then
            str = str .. "\nMarked up because it's..."
        end
        if intersectCost ~= 0 then
            str = str .. "\nBasically touching something."
        end
        if proxCost ~= 0 then
            str = str .. "\nToo close to someone."
        end
        surface.drawShadowedTextBetter( str, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local IntersectingHull = Vector( 50, 50, 10 )
local maxScoreDist = 4000
local tooCloseToPlayer = 800

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

    local distToClosestPlyLinear = math.sqrt( distToClosestPly )

    local trStruc = {
        start = myPos + self.PosOffset,
        endpos = myPos + self.PosOffset,
        mins = -IntersectingHull,
        maxs = IntersectingHull,
        ignoreworld = true,
    }
    local result = util.TraceHull( trStruc )
    local isUnderSomething = result.Hit

    local punishmentGiven = 0
    if isUnderSomething then
        punishmentGiven = 100

    end
    self:SetNW2Int( "glee_additionalcontext1", punishmentGiven )

    local cost = math.Clamp( distToClosestPlyLinear, 0, maxScoreDist )
    cost = ( maxScoreDist - cost ) / maxScoreDist
    cost = ( cost * 15 )

    local proxCost = 0

    if distToClosestPlyLinear < tooCloseToPlayer then
        proxCost = ( cost * 5 ) + 200

    end
    cost = cost + proxCost

    cost = cost + punishmentGiven
    self:SetNW2Int( "glee_additionalcontext2", proxCost )

    self:SetGivenScore( -cost )
end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()
    local beartrap = GAMEMODE:SpawnABearTrap( self:GetPos() )

    beartrap:SetCreator( owner )
    beartrap.undeadbeartrap_placer = self.player
    beartrap:EmitSound( "items/ammocrate_open.wav", 75, 100 )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )
        GAMEMODE:sendPurchaseConfirm( self.player, betrayalScore )

    end

    SafeRemoveEntity( self )

end

hook.Add( "glee_beartrap_snapped", "trackundeadbeartraps", function( trap, snapped )
    local placer = trap.undeadbeartrap_placer
    if not IsValid( placer ) then return end
    if not IsValid( snapped ) then return end

    local msg = ""

    if trap:GetPhysicsObject():IsMotionEnabled() then
        -- check if the thing trapped is a player
        if snapped:IsPlayer() then
            -- give the player some score
            placer:GivePlayerScore( 75 )
            msg = "You've damaged a player, 75 score."

        -- check if the thing trapped is a nextbot
        elseif snapped:IsNextBot() then
            -- give the player a bit less score
            placer:GivePlayerScore( 40 )
            msg = "You've damaged " .. GAMEMODE:GetNameOfBot( snapped ) .. ", 40 score."

        end
    else
        -- check if the thing trapped is a player
        if snapped:IsPlayer() then
            if snapped == placer then
                placer:GivePlayerScore( -50 )
                msg = "You placed this beartrap. -50 score."

            -- check if the player has a specific value
            elseif IsValid( snapped.huntersGleeHunterThatIsTargetingPly ) then
                -- give the player a bunch of score
                placer:GivePlayerScore( 250 )
                msg = "You've trapped a fleeing player, you gain 250 score!"

            else
                -- give the player some score
                placer:GivePlayerScore( 150 )
                msg = "You've trapped a player, you gain 150 score!"

            end
        -- check if the thing trapped is a nextbot
        elseif snapped:IsNextBot() then
            -- give the player a bit less score
            placer:GivePlayerScore( 80 )
            msg = "You've trapped " .. GAMEMODE:GetNameOfBot( snapped ) .. ", you gain 80 score!"

        end
    end
    huntersGlee_Announce( { placer }, 5, 10, msg )

end )