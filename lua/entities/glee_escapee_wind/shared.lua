AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Ghostly Wind"
ENT.Author      = "TwoLemons"
ENT.Purpose     = "A strong gust of wind"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/glee/unit_cube.mdl"

ENT.HullSize = Vector( 400, 300, 200 )
ENT.PosOffset = Vector( 0, 0, 0 )
ENT.Cooldown = 30
ENT.PushPitch = -20 -- Negative is upwards
ENT.PushStrengthPlayer = 750 -- Exact velocity for players
ENT.PushStrengthNPC = 1000 -- Raw force for NPCs (NextBots don't work...)
ENT.PushStrengthMisc = 10000 -- Raw force for everything else

ENT.CanPlaceColor = Color( 0, 200, 255, 150 )
ENT.CannotPlaceColor = Color( 255, 0, 0, 150 )

ENT.WindHullMin = ENT.HullSize * -0.5
ENT.WindHullMax = ENT.HullSize * 0.5


--[[ TODO:
    - Small sound and gust -> short delay -> FULL gust
    - Effects
    - Temporarily ragdoll players on full gust
        - Will need a dedicated ragdoll system, out of scope for now
        - Could maybe ragdoll select nextbots as well to work around them being unpushable?
--]]

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local stringPt1 = ""
        if scoreGained < 0 then
            stringPt1 = "Cost: "

        end

        local scoreString = stringPt1 .. math.abs( scoreGained )

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end

    function ENT:ClientThink()
        if LocalPlayer() ~= self.player then
            self:SetNoDraw( true )
            return

        end

        self:SetNoDraw( false )

    end

end

function ENT:PostInitializeFunc()
    self:SetMaterial( "models/props_lab/warp_sheet" )
    self:DrawShadow( false )

    if SERVER then return end

    local matrix = Matrix()
    matrix:Scale( self.HullSize )
    self:EnableMatrix( "RenderMultiply", matrix )
    self:SetRenderBounds( self.WindHullMin, self.WindHullMax )

end

function ENT:CalculateCanPlace()
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

function ENT:ManageMyPos()
    local ang = self.player:EyeAngles()
    ang[1] = 0
    ang[3] = 0

    self:SetPos( self.player:GetEyeTrace().HitPos + self.PosOffset )
    self:SetAngles( ang )

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    self:SetGivenScore( -75 )

end

function ENT:Place()
    local windPos = self:GetPos()
    local windAng = self:GetAngles()
    local hullMin = self.WindHullMin
    local hullMax = self.WindHullMax

    -- Approximate search from AABB bounds
    local aabbMins, aabbMaxs = self:GetRotatedAABB( hullMin, hullMax )
    local targets = ents.FindInBox( aabbMins + windPos, aabbMaxs + windPos )

    for i = #targets, 1, -1 do
        local target = targets[i]
        local badTarget =
            not IsValid( target ) or
            not IsValid( target:GetPhysicsObject() ) or
            not target:GetPhysicsObject():IsMotionEnabled() or
            ( target:IsPlayer() and not target:Alive() ) or
            not util.IsOBBIntersectingOBB( target:GetPos(), target:GetAngles(), target:OBBMins(), target:OBBMaxs(), windPos, windAng, hullMin, hullMax )

        if badTarget then

            table.remove( targets, i )

        end

    end

    if #targets == 0 then return end

    -- TODO: Sound

    windAng[1] = self.PushPitch
    local pushDir = windAng:Forward()
    local pushVecPlayer = pushDir * self.PushStrengthPlayer
    local pushVecNPC = pushDir * self.PushStrengthNPC
    local pushVecMisc = pushDir * self.PushStrengthMisc
    local owner = self.player

    for _, target in ipairs( targets ) do
        if target:IsPlayer() then
            target:SetVelocity( pushVecPlayer )
            GAMEMODE:AddMischievousness( owner, 5, "pushed a player with wind" )

        elseif target:IsNPC() or target:IsNextBot() then
            local physObj = target:GetPhysicsObject()
            local mult = math.max( 100 / physObj:GetMass(), 0.5 )

            target:SetVelocity( physObj:GetVelocity() + pushVecNPC * mult )
        else
            target:GetPhysicsObject():ApplyForceCenter( pushVecMisc )

        end
    end

    local score = self:GetGivenScore()

    if owner.GivePlayerScore and score then
        owner:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( owner, score )

    end

    GAMEMODE:AddMischievousness( owner, 3, "used a gust of wind" )
    GAMEMODE:doShopCooldown( owner, self.itemIdentifier, self.Cooldown )

    -- grrr this should be handled inside :doShopCooldown()
    net.Start( "glee_sendshopcooldowntoplayer" )
        net.WriteFloat( self.Cooldown )
        net.WriteString( self.itemIdentifier )
    net.Send( owner )

    owner.placableTargeted = nil
    owner.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )
    SafeRemoveEntity( self )

end
