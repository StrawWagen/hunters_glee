AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"
DEFINE_BASECLASS( ENT.Base )

ENT.PrintName   = "ATM Placer"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Send the ATM somewhere."
ENT.Spawnable   = false
ENT.Category    = "Hunter's Glee"

ENT.Model = "models/glee/atm/atm01.mdl"

-- The ATM stands on the floor, so PosOffset has to stay zero for Place to put it
-- there. That leaves the base's check sampling from floor + 15, which only has room
-- for a shallow hull before it starts hitting the ground; BodyCheck covers the rest.
ENT.PosOffset       = Vector( 0, 0, 0 )
ENT.HullCheckSize   = Vector( 18, 18, 14 )
ENT.BodyCheckOffset = Vector( 0, 0, 47 )
ENT.BodyCheckSize   = Vector( 18, 18, 45 )

ENT.noPurchaseReason_NoArrival = "There's no way to get an ATM in there."

function ENT:SetupDataTablesExtra()
    self:NetworkVar( "String", 0, "ArrivalMethod" ) -- "" when nothing can reach here

end

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local method = self:GetArrivalMethod()
        local line

        if method == "" then
            line = self.noPurchaseReason_NoArrival

        else
            line = string.upper( method ) .. " - " .. math.abs( self:GetGivenScore() )

        end

        surface.drawShadowedTextBetter( line, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

if not SERVER then return end

local floorNudge = Vector( 0, 0, 8 )

-- The ATM is a heavy thing that stands on the ground, so it goes on the floor under
-- where they're aiming, rather than riding the surface they hit like a crate does.
function ENT:BestPosToBe()
    local trace = self.player:GetEyeTrace()
    if not trace.Hit then return end

    local floorTr = terminator_Extras.getFloorTr( trace.HitPos + floorNudge )
    if not floorTr.Hit then return trace.HitPos end

    return floorTr.HitPos

end

function ENT:ManageMyPos()
    BaseClass.ManageMyPos( self )

    local toPlayer = self.player:GetPos() - self:GetPos()
    toPlayer.z = 0
    if toPlayer:LengthSqr() < 1 then return end

    self:SetAngles( toPlayer:Angle() )

end

-- The price of this spot is whatever the cheapest arrival that reaches it costs.
function ENT:UpdateGivenScore()
    local method, cost = terminator_Extras.glee_ATMArrivalAt( self:OffsettedPlacingPos() )

    self:SetArrivalMethod( method or "" )
    self:SetGivenScore( method and -cost or 0 )

end

local vecUpOne = Vector( 0, 0, 1 )

-- The base only checks a hull just above the floor, which the ATM towers over.
function ENT:BodyFits()
    local checkPos = self:OffsettedPlacingPos() + self.BodyCheckOffset

    local tr = util.TraceHull( {
        start  = checkPos,
        endpos = checkPos + vecUpOne,
        filter = self,
        mins   = -self.BodyCheckSize,
        maxs   = self.BodyCheckSize,
    } )

    return not tr.Hit

end

function ENT:CalculateCanPlace()
    if self:GetArrivalMethod() == "" then return false, self.noPurchaseReason_NoArrival end
    if terminator_Extras.glee_ATMExists() then return false, "The ATM is already active." end
    if not self:BodyFits() then return false, self.noPurchaseReason_NoRoom end

    return BaseClass.CalculateCanPlace( self )

end

-- CanPlace is only refreshed every 0.15s, so 2 atms can very rarely exist from here,
-- but that's fine
function ENT:Place()
    local method = self:GetArrivalMethod()
    if method == "" then return end

    local placingPos = self:OffsettedPlacingPos()
    local cost = self:GetGivenScore()

    local atm = ents.Create( "glee_bank_atm" )
    if not IsValid( atm ) then return end

    atm:SetPos( placingPos )
    atm:SetAngles( self:GetAngles() )
    atm:Spawn()
    atm:StartArrival( method, placingPos, self.player )

    if self.player and self.player.GivePlayerScore then
        self.player:GivePlayerScore( cost )
        GAMEMODE:sendPurchaseConfirm( self.player, cost )

    end

    SafeRemoveEntity( self )

end
