AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Barrels"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Random barrel spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.Category = "Hunter's Glee"
ENT.Model = "models/props_c17/oildrum001_explosive.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

ENT.placeCount = 6

local termhunt_barrels_spawned = {}

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "Barreling Score: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

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
        self:SkinRandomize()

    end )

end

function ENT:GetBarrels()
    local potentialBarrels = ents.FindByClass( "prop_physics" )

    termhunt_barrels_spawned = {}

    potentialBarrels = table.Add( potentialBarrels, potentialBarrels2 )

    for _, barrel in ipairs( potentialBarrels ) do
        if barrel:GetNWBool( "placedbybarrel" ) == true then
            table.insert( termhunt_barrels_spawned, barrel )

        end
    end
end

function ENT:PostInitializeFunc()
    termhunt_barrels_spawned = self:GetBarrels()

end

local nextCountCheck = 0

function ENT:ClientThink()
    if nextCountCheck > CurTime() then return end

    nextCountCheck = CurTime() + 0.5

    self:GetBarrels()

end

if not SERVER then return end

local MEMORY_VOLATILE = 8
local barrelPunishmentDist = 1250

function ENT:UpdateGivenScore()
    local smallestPunishmentDist = barrelPunishmentDist^2
    local tooCloseCount = 0
    local punishmentCount = 0

    local myPos = self:GetPos()

    if termhunt_barrels_spawned then
        for _, currentBarrel in ipairs( termhunt_barrels_spawned ) do
            if not IsValid( currentBarrel ) then continue end
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

    local scoreGiven = 40 - barrelCount
    scoreGiven = scoreGiven + -punishmentGiven
    scoreGiven = math.Clamp( scoreGiven, -75, 10 )
    scoreGiven = scoreGiven + terminator_Extras.GetNookScore( myPos ) * 2

    self:SetGivenScore( scoreGiven )

end

function ENT:Place()
    local barrel = ents.Create( "prop_physics" )
    barrel:SetPos( self:GetPos2() )
    barrel:SetModel( self:GetModel() )
    barrel:SetAngles( self:GetAngles() )
    barrel:SetSkin( self:GetSkin() )
    barrel:Spawn()

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

    end

    self.placeCount = self.placeCount + -1

    if self.placeCount > 0 then
        self:BarrelRandomize()

        return
    end

    SafeRemoveEntity( self )

end