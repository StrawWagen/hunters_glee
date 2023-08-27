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

if SERVER then
    util.AddNetworkString( "gleenomoreimmortalizer" )

end

if CLIENT then
    local nextNoMoreImmortalizer = 0
    net.Receive( "gleenomoreimmortalizer", function()
        if nextNoMoreImmortalizer > CurTime() then return end
        nextNoMoreImmortalizer = CurTime() + 0.1

        if IsValid( LocalPlayer().playerImmortalizer ) then 
            LocalPlayer().playerImmortalizer:NukeHighlighter()

        end

        LocalPlayer().playerImmortalizer = nil
        LocalPlayer().ghostEnt = nil

    end )

end


function ENT:PostInitializeFunc()
    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end
    --self:SetOwner( Entity( 1 ) )
end

function ENT:GetGivenScore()
    if not IsValid( self.nearestThing ) then return end
    if self.nearestThing:IsPlayer() then
        return -300

    elseif self.nearestThing:IsNextBot() then
        return -200

    end
end

hook.Add( "HUDPaint", "plyimmortalizer_paintscore", function()
    if not GAMEMODE.CanShowDefaultHud or not GAMEMODE:CanShowDefaultHud() then return end
    if not IsValid( LocalPlayer().playerImmortalizer ) then return end

    local screenMiddleW = ScrW() / 2
    local screenMiddleH = ScrH() / 2

    local scoreGained = math.Round( GAMEMODE:ValidNum( LocalPlayer().playerImmortalizer:GetGivenScore() ) )
    local stringPt1 = "(In)Convenience Score: "

    local scoreString = stringPt1 .. tostring( math.abs( scoreGained ) )

    surface.drawShadowedTextBetter( scoreString, "scoreGainedOnPlaceFont", color_white, screenMiddleW, screenMiddleH + 20 )

end )

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

function ENT:NukeHighlighter()
    if SERVER then return end
    SafeRemoveEntity( self.player.thingHighliter )

end

if CLIENT then

    local green = {0,255,0}
    local red = {255,0,0}

    local materialOverride = render.MaterialOverride
    local setColorModulation = render.SetColorModulation
    local cam_Start3D = cam.Start3D
    local cam_End3D = cam.End3D

    local playerOverrideMat = CreateMaterial( "CHAMSMATPLAYERIMMORTALIZER1", "UnlitGeneric", { ["$basetexture"] = "lights/white001", ["$model"] = 1, ["$ignorez"] = 1 } )

    function ENT:HighlightNearestThing()
        if not IsValid( self.nearestThing ) then return end
        if not IsValid( self.player.thingHighliter ) then
            self.player.thingHighliter = ClientsideModel( self.nearestThing:GetModel() )

            self.player.thingHighliter:Spawn()

        elseif self.lastNearestThing ~= self.nearestThing then
            self.lastNearestThing = self.nearestThing
            self.nearestThing:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 200 )
            self.player.thingHighliter:SetParent( self.nearestThing )
            self.player.thingHighliter:SetModel( self.nearestThing:GetModel() )
            self.player.thingHighliter:SetPos( self.nearestThing:GetPos() )
            self.player.thingHighliter:SetAngles( self.nearestThing:GetAngles() )

        end
        if IsValid( self.player.thingHighliter ) then
            cam_Start3D();
                materialOverride( playerOverrideMat )

                local color = green
                if not self:HasEnoughToPurchase() then
                    color = red

                end

                setColorModulation( color[1], color[2], color[3] )

                self.player.thingHighliter:DrawModel()
                materialOverride()

            cam_End3D();

        end
    end
end

function ENT:CanPlace()
    if not IsValid( self.nearestThing ) then return end
    if self.nearestThing.glee_DamageResistant then return false end
    if not self:HasEnoughToPurchase() then return false end
    return true

end

function ENT:ModifiableThink()

    self:SetPos( self.player:GetEyeTrace().HitPos + self.PosOffset )

    self.nearestThing = self:GetNearestTarget()

    if CLIENT then
        -- HACK
        self:SetNoDraw( true )

    end

    if SERVER and self:AliveCheck() then return end

end

function ENT:SetupPlayer()
    self.player.playerImmortalizer = self
    self.player.ghostEnt = self
    if CLIENT and LocalPlayer() == self.player then
        hook.Add( "PostDrawOpaqueRenderables", "termHuntDrawNearestThingImmortalizer", function()
            if not IsValid( self ) or not IsValid( self.player ) then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestThingImmortalizer" ) return end
            if self.player ~= LocalPlayer() then hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestThingImmortalizer" ) return end
            if not self.player.playerImmortalizer then self:NukeHighlighter() hook.Remove( "PostDrawOpaqueRenderables", "termHuntDrawNearestThingImmortalizer" ) return end
            self:HighlightNearestThing()
        end )
    end
end

function ENT:OnRemove()
    self:NukeHighlighter()

end

local rics = {
    "weapons/fx/rics/ric3.wav",
    "weapons/fx/rics/ric5.wav",
}

function ENT:Place()
    local plyToImmortal = self.nearestThing

    if not IsValid( plyToImmortal ) then return end

    local plysToAlert = {}
    for _, thing in ipairs( ents.FindInPVS( plyToImmortal:GetShootPos() ) ) do
        if thing:IsPlayer() and thing ~= plyToImmortal then
            table.insert( plysToAlert, thing )

        end
    end

    if self.nearestThing:IsPlayer() then
        huntersGlee_Announce( plysToAlert, 5, 8, "You feel an imposing presence..\n" .. self.player:Name() .. " has gifted immortality to...\n" .. plyToImmortal:Name() )
        huntersGlee_Announce( { plyToImmortal }, 10, 10, "Something's off, you feel strong, you feel... Immortal.\n" .. self.player:Name() .. " has gifted you temporary Immortality." )

    else
        huntersGlee_Announce( plysToAlert, 5, 8, "You feel an imposing presence..\n" .. self.player:Name() .. " has gifted immortality to a Terminator." )

    end

    local timerName = "glee_immortality_timer_" .. tostring( plyToImmortal:GetCreationID() )
    local hookName = "glee_immortality_hook" .. tostring( plyToImmortal:GetCreationID() )

    plyToImmortal.glee_DamageResistant = true
    plyToImmortal.glee_DamageResistantExpires = CurTime() + 40 -- backup if timer errors

    plyToImmortal:EmitSound( "physics/metal/metal_canister_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 60, 1, CHAN_STATIC )
    plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 80, 1, CHAN_STATIC )
    plyToImmortal:EmitSound( "physics/concrete/boulder_impact_hard3.wav", 90, 120, 1, CHAN_STATIC )

    util.ScreenShake( plyToImmortal:GetPos(), 40, 20, 1.5, 1500 )

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

        util.ScreenShake( plyToImmortal:GetPos(), damageDealt / 2, 20, damageDealt / 1000, 1500 )

        return true

    end )

    timer.Create( timerName, 1, 16, function()
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
            huntersGlee_Announce( { plyToImmortal }, 10, 1, message )

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

    end

    net.Start( "gleenomoreimmortalizer" )
    net.Send( self.player )

    self.player.playerImmortalizer = nil
    self.player.ghostEnt = nil

    self.player = nil
    self:SetOwner( NULL )

    SafeRemoveEntity( self )

end