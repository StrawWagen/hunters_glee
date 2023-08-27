AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Weapons crate"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Weapon item crate spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/Items/item_item_crate.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

local MEMORY_BREAKABLE = 4
local maxScoreDist = 4000
local tooCloseToPlayer = 2000
local cratePunishmentDist = 1100

function ENT:GetGivenScore()
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
            if tooCloseCount < 1 then continue end
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
    punishmentGiven = punishmentCount + ( punishmentGiven * 10 )^2

    local scoreGiven = math.Clamp( distToClosestPlyLinear, 0, maxScoreDist )
    scoreGiven = scoreGiven / maxScoreDist
    scoreGiven = ( scoreGiven * 15 )

    local nookingComp = terminator_Extras.GetNookScore( myPos, 1200 ) + -2
    nookingComp = math.Clamp( nookingComp * 20, 0, 60 )

    scoreGiven = scoreGiven + nookingComp

    scoreGiven = scoreGiven + -punishmentGiven

    if distToClosestPlyLinear < tooCloseToPlayer then
        scoreGiven = scoreGiven * 0.25
        scoreGiven = scoreGiven + -25
    end

    return scoreGiven, punishmentGiven

end

hook.Add( "HUDPaint", "weaponcrate_paintscore", function()
    if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
    if not IsValid( LocalPlayer().weaponCrate ) then return end

    local screenMiddleW = ScrW() / 2
    local screenMiddleH = ScrH() / 2

    local scoreGained = math.Round( GAMEMODE:ValidNum( LocalPlayer().weaponCrate.oldScoreGiven ) )

    local scoreGainedString = "(In)Convenience Score: " .. tostring( scoreGained )
    surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

end )

function ENT:SetupPlayer()
    self.player.weaponCrate = self
    self.player.ghostEnt = self
end

if not SERVER then return end

local GM = GAMEMODE

function GM:WeaponsCrate( pos )
    if not pos then return end

    local crate = ents.Create( "item_item_crate" )
    crate:SetPos( pos )
    crate:SetKeyValue( "ItemClass", "dynamic_weapons" )
    crate:SetKeyValue( "ItemCount", 6 )
    crate:Spawn()

    crate.terminatorHunterInnateReaction = function()
        return MEMORY_BREAKABLE
    end

    return crate

end

function ENT:Place()
    local betrayalScore = self:GetGivenScore()
    local crate = GAMEMODE:WeaponsCrate( self:GetPos2() )

    crate:EmitSound( "items/ammocrate_open.wav", 75, 100 )

    if self.player and self.player.GivePlayerScore and betrayalScore then
        self.player:GivePlayerScore( betrayalScore )

    end

    SafeRemoveEntity( self )

end