AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Placable Barnacle"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Placable Barnacle Spawner"
ENT.Spawnable    = true
ENT.AdminOnly    = false
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.Category = "Hunter's Glee"
ENT.Model = "models/barnacle.mdl"

--sandbox support
function ENT:SpawnFunction( ply, tr, ClassName )

    if not tr.Hit then return end

    local SpawnPos = tr.HitPos + tr.HitNormal * 16

    local ent = ents.Create( ClassName )
    ent:SetPos( SpawnPos )
    ent:SetOwner( ply )
    ent:Spawn()
    ent:Activate()

    if not GAMEMODE.ISHUNTERSGLEE then
        ent:Place()
    end

    return ent

end

function ENT:Initialize()
    self:SetModel( self.Model )
    if SERVER then
        self:SetRenderMode( RENDERMODE_TRANSCOLOR )
        self:SetNoDraw( false )
        self:DrawShadow( true )

    end
end

ENT.HullCheckSize = Vector( 20, 20, 10 )

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )

        local scoreGainedString = "Spacing Cost: " .. tostring( scoreGained )
        surface.drawShadowedTextBetter( scoreGainedString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

local function IsHullTraceFull( startPos, hullMaxs, ignoreEnt )
    local traceData = {
        start = startPos,
        endpos = startPos + Vector(0,0,1),
        filter = ignoreEnt,
        mins = -hullMaxs,
        maxs = hullMaxs
    }
    local trace = util.TraceHull(traceData)

    return trace.Hit

end

local function getNearestNavFloor( pos )
    if not SERVER then return true end
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + Vector( 0,0,-500 ),
        mask = 131083
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, 25, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea

end

function ENT:BarnacleTrace()
    local trace = self.player:GetEyeTrace()
    local eyePos = trace.HitPos
    local traceData = {
        start = eyePos + Vector( 0,0,10 ),
        endpos = eyePos + Vector( 0,0,2500 ),
        mask = MASK_SOLID_BRUSHONLY,

    }
    return util.TraceLine( traceData ), eyePos

end


function ENT:CanPlaceNonScore()
    local traceData = self:BarnacleTrace()

    --debugoverlay.Cross( traceData.HitPos() )

    if not traceData.HitWorld then return false, "It needs to be under something." end
    if traceData.HitSky == true then return false, "It needs to be under something." end

    local checkPos = traceData.HitPos + Vector( 0, 0, -50 )

    if IsHullTraceFull( checkPos, self.HullCheckSize, self ) then return false, self.noPurchaseReason_NoRoom end
    if getNearestNavFloor( checkPos ) == NULL then return false, self.noPurchaseReason_OffNavmesh end

    return true

end

function ENT:CalculateCanPlace()
    local canPlace, reason = self:CanPlaceNonScore()
    if not canPlace then return canPlace, reason end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

function ENT:BestPosToBe()
    local bestPos = nil
    local canPlaceNonScore = self:CanPlaceNonScore()
    local placeTraceResult, eyePos = self:BarnacleTrace()

    if canPlaceNonScore then
        bestPos = placeTraceResult.HitPos

    else
        bestPos = eyePos + Vector( 0, 0, 100 )

    end
    return bestPos

end


if not SERVER then return end


local tooCloseToPlayer = 350
local sortaCloseToPlayers = 1000
local barnaclePunishmentDist = 750

function ENT:UpdateGivenScore()
    local plys = player.GetAll()

    local smallestDist = 16000^2

    for _, currentPly in ipairs( plys ) do
        if currentPly:Health() <= 0 then continue end
        local distToCurrentPlySqr = self:GetPos():DistToSqr( currentPly:GetPos() )
        if distToCurrentPlySqr < smallestDist then
            smallestDist = distToCurrentPlySqr
        end
    end

    local smallestPunishmentDist = barnaclePunishmentDist^2
    local tooCloseCount = 0
    local punishmentCount = 0

    for _, currentBarnacle in ipairs( ents.FindByClass( "npc_barnacle" ) ) do
        if currentBarnacle.barnacleCreator == self then continue end
        local distToCurrentBarnacleSqr = self:GetPos():Distance2DSqr( currentBarnacle:GetPos() )
        if distToCurrentBarnacleSqr < smallestPunishmentDist then
            tooCloseCount = tooCloseCount + 1
            if tooCloseCount < 2 then continue end
            punishmentCount = tooCloseCount
            smallestPunishmentDist = distToCurrentBarnacleSqr
        end
    end

    local punishmentLinear = math.sqrt( smallestPunishmentDist )
    local smallestDistLinear = math.sqrt( smallestDist )

    local punishmentGiven = math.abs( punishmentLinear - barnaclePunishmentDist )
    punishmentGiven = punishmentGiven / barnaclePunishmentDist
    punishmentGiven = punishmentCount * 3 + punishmentGiven * 7

    local scoreGiven = 0
    local playerPenalty = 0

    if smallestDistLinear < tooCloseToPlayer then
        playerPenalty = -125
        scoreGiven = scoreGiven + playerPenalty

    elseif smallestDistLinear < sortaCloseToPlayers then
        playerPenalty = -40
        scoreGiven = scoreGiven + playerPenalty

    end

    scoreGiven = scoreGiven + -punishmentGiven

    --print( scoreGiven )

    self:SetGivenScore( scoreGiven, playerPenalty )

end

function ENT:Place()
    local yaw = math.Rand( -180, 180 )
    local ang = Angle( 0, yaw ,0 )

    local placeTraceResult = self:BarnacleTrace()

    local barnacle = ents.Create( "npc_barnacle" )
    barnacle:SetPos( placeTraceResult.HitPos + Vector( 0,0,-2 ) )
    barnacle:SetAngles( ang )
    barnacle:Spawn()
    barnacle:Activate()

    barnacle.glee_PlacedBarnacle = true
    barnacle.barnacleCreator = self
    barnacle.barnacleOwner = self.player

    local timerName = "SoundTimer_" .. self:GetClass() .. self:EntIndex()

    -- Create a timer on the barnacle
    timer.Create( timerName, 1, 0, function()
        -- Check if the barnacle is still valid and alive
        if not IsValid( barnacle ) or barnacle:Health() <= 0 then
            if IsValid( barnacle ) and barnacle:Health() <= 0 then
                SafeRemoveEntityDelayed( barnacle, 20 )

            end
            -- Stop the timer if the barnacle is dead or invalid
            timer.Stop( timerName )
            return
        end
        local enemy = barnacle:GetEnemy()
        if IsValid( enemy ) and enemy:IsPlayer() and IsValid( barnacle.barnacleOwner ) and barnacle.barnacleOwner ~= enemy then
            local scoreToGive = 15
            if not barnacle.hasGivenHugeScoreBump then
                barnacle.hasGivenHugeScoreBump = true
                scoreToGive = 100
            end
            barnacle.barnacleOwner:GivePlayerScore( scoreToGive )
            huntersGlee_Announce( { barnacle.barnacleOwner }, 5, 6, "One of your barnacles has grabbed a player!" )

        end
    end )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    SafeRemoveEntity( self )

end

local IsValid = IsValid

hook.Add( "EntityTakeDamage", "glee_placedbarnacle_extradamage", function( _, dmg )
    local attacker = dmg:GetAttacker()
    if not IsValid( attacker ) or not attacker.glee_PlacedBarnacle then return end

    dmg:ScaleDamage( 2 )

end )