AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

-- base ent for stuff that snaps to players and bots

ENT.Category    = "Other"
ENT.PrintName   = "Player Immortalizer"
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
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local scoreGained = math.Round( self:GetGivenScore() )
        local stringPt1 = "Immortalizing Cost: "

        local scoreString = stringPt1 .. tostring( scoreGained )

        surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

    end
end

function ENT:GetNearestTarget()
    local nearest = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all players within a radius of x units
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if ( thing:GetClass() == "player" or thing:IsNextBot() ) and thing:Health() > 0 then
            -- Calculate the distance between the ply and the entity
            local distance = myPos:DistToSqr( thing:GetPos() )
            if distance < nearestDistance then
                nearest = thing
                nearestDistance = distance

            end
        end
    end

    return nearest
end

function ENT:CalculateCanPlace()
    if not IsValid( self:GetCurrTarget() ) then return false, "Nothing to immortalize." end
    if self:GetCurrTarget().glee_DamageResistant then return false, "That's already immortal." end
    if not self:HasEnoughToPurchase() then return false, self:TooPoorString() end
    return true

end

if not SERVER then return end

function ENT:UpdateGivenScore()
    if not IsValid( self:GetCurrTarget() ) then return end
    if self:GetCurrTarget():IsPlayer() then
        self:SetGivenScore( -300 )

    elseif self:GetCurrTarget():IsNextBot() then
        self:SetGivenScore( -200 )

    end
end

local rics = {
    "weapons/fx/rics/ric3.wav",
    "weapons/fx/rics/ric5.wav",
}

local immortalTime = 21 -- seconds
local immortalTimeBackup = 40 -- in case the timer errors

function ENT:Place()
    local target = self:GetCurrTarget()

    if not IsValid( target ) then return end

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( target:GetShootPos() ) ) do
        if not thing:IsPlayer() then continue end
        if thing == target then continue end

        table.insert( plysToAlert, thing )

    end

    if target:IsPlayer() then
        huntersGlee_Announce( plysToAlert, 5, 6, "You feel an imposing presence..\n" .. self.player:Nick() .. " has gifted immortality to...\n" .. target:Nick() )
        huntersGlee_Announce( { target }, 10, 10, "Something's off, you feel strong, you feel... Immortal.\n" .. self.player:Nick() .. " has gifted you temporary Immortality." )

    else
        huntersGlee_Announce( plysToAlert, 5, 6, "You feel an imposing presence..\n" .. self.player:Nick() .. " has gifted immortality to " .. GAMEMODE:GetNameOfBot( target ) )

    end

    local timerName = "glee_immortality_timer_" .. tostring( target:GetCreationID() )
    local hookName = "glee_immortality_hook" .. tostring( target:GetCreationID() )

    target.glee_DamageResistant = true
    target.glee_DamageResistantExpires = CurTime() + immortalTimeBackup -- backup if timer errors

    target:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )
    target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 120, 1, CHAN_STATIC )

    util.ScreenShake( target:GetPos(), 40, 20, 1.5, 1500, true )

    local immortCancel = function()
        timer.Remove( timerName )
        hook.Remove( "EntityTakeDamage", hookName )

        if not IsValid( target ) then return end

        target.glee_DamageResistant = nil
        target.glee_DamageResistantExpires = nil

    end

    hook.Add( "EntityTakeDamage", hookName, function( victim, damage )
        if not IsValid( target ) then immortCancel() return end
        if victim ~= target then return end
        if target:Health() <= 0 then immortCancel() return end
        if not target.glee_DamageResistant then immortCancel() return end
        if not target.glee_DamageResistantExpires then immortCancel() return end
        if target.glee_DamageResistantExpires < CurTime() then immortCancel() return end

        if damage:IsBulletDamage() then
            target:EmitSound( table.Random( rics ), 75, math.random( 92, 100 ), 1, CHAN_STATIC )

        end

        local damageDealt = damage:GetDamage()

        local path = "physics/metal/metal_barrel_impact_hard" .. math.random( 5, 7 ) .. ".wav"
        local pit = 120 + ( -damageDealt / 10 )
        target:EmitSound( path, 85, pit, 1, CHAN_STATIC )

        GAMEMODE:GivePanic( target, damageDealt / 4 )

        damage:SetDamageForce( damage:GetDamageForce() * damageDealt )
        damage:ScaleDamage( 0 )

        util.ScreenShake( target:GetPos(), damageDealt / 2, 20, damageDealt / 1000, 1500, true )

        return true

    end )

    timer.Create( timerName, 1, immortalTime, function()
        if not IsValid( target ) then immortCancel() return end
        if not target.glee_DamageResistant then immortCancel() return end
        if target:Health() <= 0 then immortCancel() return end

        local timeLeft = timer.RepsLeft( timerName )
        timeLeft = timeLeft + -1

        local message

        if timeLeft <= 8 and timeLeft > 0 then
            message = "You feel your mortality returning...\n" .. tostring( timeLeft ) .. "."
            target:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 80, 80 + timeLeft * 2, 1, CHAN_STATIC )

        end
        if message and target:IsPlayer() then
            huntersGlee_Announce( { target }, 10, 1.5, message )

        end

        if timeLeft < 0 then
            immortCancel()
            target:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
            target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 40, 1, CHAN_STATIC )
            target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
            target:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )

        end
    end )

    local score = self:GetGivenScore()

    if self.player.GivePlayerScore and score then
        self.player:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( self.player, score )

    end

    self:TellPlyToClearHighlighter()

    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    SafeRemoveEntity( self )

end