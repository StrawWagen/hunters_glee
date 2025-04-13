AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "player_swapper"

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
    local nearestPly = nil
    local nearestDistance = math.huge
    local myPos = self:GetPos()

    -- Find all players within a radius of x units
    local stuff = ents.FindInSphere( myPos, 512 )
    for _, thing in ipairs( stuff ) do
        if ( thing:GetClass() == "player" or thing:IsNextBot() ) and thing:Health() > 0 then
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

function ENT:Place()
    local plyToImmortal = self:GetCurrTarget()

    if not IsValid( plyToImmortal ) then return end

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( plyToImmortal:GetShootPos() ) ) do
        if thing:IsPlayer() and thing ~= plyToImmortal then
            table.insert( plysToAlert, thing )

        end
    end

    if plyToImmortal:IsPlayer() then
        huntersGlee_Announce( plysToAlert, 5, 6, "You feel an imposing presence..\n" .. self.player:Nick() .. " has gifted immortality to...\n" .. plyToImmortal:Nick() )
        huntersGlee_Announce( { plyToImmortal }, 10, 10, "Something's off, you feel strong, you feel... Immortal.\n" .. self.player:Nick() .. " has gifted you temporary Immortality." )

    else
        huntersGlee_Announce( plysToAlert, 5, 6, "You feel an imposing presence..\n" .. self.player:Nick() .. " has gifted immortality to " .. GAMEMODE:GetNameOfBot( plyToImmortal ) )

    end

    local timerName = "glee_immortality_timer_" .. tostring( plyToImmortal:GetCreationID() )
    local hookName = "glee_immortality_hook" .. tostring( plyToImmortal:GetCreationID() )

    plyToImmortal.glee_DamageResistant = true
    plyToImmortal.glee_DamageResistantExpires = CurTime() + 40 -- backup if timer errors

    plyToImmortal:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )
    plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 120, 1, CHAN_STATIC )

    util.ScreenShake( plyToImmortal:GetPos(), 40, 20, 1.5, 1500, true )

    local immortCancel = function()
        timer.Remove( timerName )
        hook.Remove( "EntityTakeDamage", hookName )

        if not IsValid( plyToImmortal ) then return end

        plyToImmortal.glee_DamageResistant = nil
        plyToImmortal.glee_DamageResistantExpires = nil

    end

    hook.Add( "EntityTakeDamage", hookName, function( victim, damage )
        if not IsValid( plyToImmortal ) then immortCancel() return end
        if victim ~= plyToImmortal then return end
        if plyToImmortal:Health() <= 0 then immortCancel() return end
        if not plyToImmortal.glee_DamageResistant then immortCancel() return end
        if not plyToImmortal.glee_DamageResistantExpires then immortCancel() return end
        if plyToImmortal.glee_DamageResistantExpires < CurTime() then immortCancel() return end

        if damage:IsBulletDamage() then
            plyToImmortal:EmitSound( table.Random( rics ), 75, math.random( 92, 100 ), 1, CHAN_STATIC )

        end

        local damageDealt = damage:GetDamage()

        local path = "physics/metal/metal_barrel_impact_hard" .. math.random( 5, 7 ) .. ".wav"
        local pit = 120 + ( -damageDealt / 10 )
        plyToImmortal:EmitSound( path, 85, pit, 1, CHAN_STATIC )

        GAMEMODE:GivePanic( plyToImmortal, damageDealt / 4 )

        damage:SetDamageForce( damage:GetDamageForce() * damageDealt )
        damage:ScaleDamage( 0 )

        util.ScreenShake( plyToImmortal:GetPos(), damageDealt / 2, 20, damageDealt / 1000, 1500, true )

        return true

    end )

    timer.Create( timerName, 1, 21, function()
        if not IsValid( plyToImmortal ) then immortCancel() return end
        if not plyToImmortal.glee_DamageResistant then immortCancel() return end
        if plyToImmortal:Health() <= 0 then immortCancel() return end

        local timeLeft = timer.RepsLeft( timerName )
        timeLeft = timeLeft + -1

        if timeLeft <= 8 and timeLeft > 0 then
            message = "You feel your mortality returning...\n" .. tostring( timeLeft ) .. "."
            plyToImmortal:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 80, 80 + timeLeft * 2, 1, CHAN_STATIC )

        end
        if message and plyToImmortal:IsPlayer() then
            huntersGlee_Announce( { plyToImmortal }, 10, 1.5, message )

        end

        if timeLeft < 0 then
            immortCancel()
            plyToImmortal:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
            plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 40, 1, CHAN_STATIC )
            plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
            plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )

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