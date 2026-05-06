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

ENT.HullSize = Vector( 600, 400, 200 )
ENT.PosOffset = Vector( 0, 0, 0 )
ENT.PosOffsetPostPlace = Vector( 0, 0, 65 ) -- Additional offset that applies after placing (mostly affects sound origin)
ENT.Cooldown = 30

ENT.PushDelayMin = 1.5
ENT.PushDelayMax = 1.75
ENT.PushPitch = -25 -- Negative is upwards
ENT.PushStrengthPlayer = 590 -- Exact velocity for players
ENT.PushStrengthNPC = 1000 -- Raw force for NPCs (NextBots don't work...)
ENT.PushStrengthMisc = 10000 -- Raw force for everything else

ENT.TargetRefindInterval = 0.25

ENT.MiniPushStrengthMin = 0.1
ENT.MiniPushStrengthMax = 0.2
ENT.MiniPushIntervalMin = 0.1
ENT.MiniPushIntervalMax = 0.5

ENT.PushVariancePlayerMin = 1
ENT.PushVariancePlayerMax = 1.2
ENT.PushVarianceMiscMin = 0.75
ENT.PushVarianceMiscMax = 1

ENT.ParticleRampDuration = ENT.PushDelayMin * 0.75
ENT.ParticleIntervalStart = 0.2
ENT.ParticleIntervalEnd = 0.05
ENT.ParticleSpeedStart = 400
ENT.ParticleSpeedEnd = 800
ENT.ParticleDieTimeStart = 1.25
ENT.ParticleDieTimeEnd = 0.75

ENT.CanPlaceColor = Color( 0, 200, 255, 150 )
ENT.CannotPlaceColor = Color( 255, 0, 0, 150 )
ENT.OnlyNetworkToOwner = false

ENT.WindHullMin = ENT.HullSize * -0.5
ENT.WindHullMax = ENT.HullSize * 0.5


--[[ TODO:
    - Better sounds + param tuning
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
        if LocalPlayer() ~= self:GetOwner() then
            self:SetNoDraw( true )
            return

        end

        self:SetNoDraw( false )

    end

    function ENT:OwnerlessThink()
        self:SetNoDraw( true )
        self:ParticleThink()

        -- Sync ghostEnt update with server since ghost wind doesn't delete immediately
        if LocalPlayer().ghostEnt == self then
            LocalPlayer().ghostEnt = nil

        end
    end

    function ENT:ParticleThink()
        local finalPush = self.windParticleFinalPush

        if not self:GetParticlesActive() then
            if not finalPush then return end

            self.windParticleFinalPush = false -- Do a big wave of particles right at the end.

        else
            finalPush = false -- Not actually the final push until :GetParticlesActive() is false!

        end

        if not self.windParticleNextTime then -- First active tick, make emitter.
            self.windParticleEmitter = ParticleEmitter( self:GetPos(), false )
            self.windParticleStartTime = CurTime()
            self.windParticleNextTime = 0
            self.windParticleFinalPush = true

        end

        local emitter = self.windParticleEmitter
        if not emitter then return end -- Got lost due to fullupdate + CallOnRemove.

        local now = CurTime()
        if now < self.windParticleNextTime then return end

        local elapsed = now - self.windParticleStartTime
        local frac = math.min( elapsed / self.ParticleRampDuration, 1 )
        local speed = Lerp( frac, self.ParticleSpeedStart, self.ParticleSpeedEnd )
        local dieTime = Lerp( frac, self.ParticleDieTimeStart, self.ParticleDieTimeEnd )

        local center = self:GetPos()
        local yaw = self:GetAngles()[2]
        local memAng = Angle()
        local hullMin = self.WindHullMin
        local hullMax = self.WindHullMax
        local amount = finalPush and 75 or math.random( 0, 1 )

        self.windParticleNextTime = Lerp( frac, self.ParticleIntervalStart, self.ParticleIntervalEnd )

        for _ = 1, amount do
            memAng[1] = math.Rand( -1, 1 ) * 5
            memAng[2] = math.Rand( -1, 1 ) * 5 + yaw

            local part = emitter:Add( "particle/Particle_Glow_04_Additive", center + Vector(
                math.Rand( hullMin[1], hullMax[1] ),
                math.Rand( hullMin[2], hullMax[2] ),
                math.Rand( hullMin[3], hullMax[3] )
            ) )

            part:SetDieTime( dieTime )
            part:SetStartAlpha( 20 )
            part:SetEndAlpha( 0 )
            part:SetAngles( memAng )
            part:SetVelocity( memAng:Forward() * speed )
            part:SetAirResistance( 5 )

            part:SetStartSize( 2 )
            part:SetEndSize( 20 )
            part:SetStartLength( 200 )
            part:SetEndLength( 150 )

        end
    end
end

function ENT:PostInitializeFunc()
    self:SetMaterial( "models/props_lab/warp_sheet" )
    self:DrawShadow( false )
    self:SetParticlesActive( false )

    self.nextTargFind = 0

    if SERVER then return end

    local matrix = Matrix()
    matrix:Scale( self.HullSize )
    self:EnableMatrix( "RenderMultiply", matrix )
    self:SetRenderBounds( self.WindHullMin, self.WindHullMax )

    self:CallOnRemove( "glee_escapeewind_removeemitter", function( ent )
        if not IsValid( ent ) then return end
        if not ent.windParticleEmitter then return end

        ent.windParticleEmitter:Finish()
        ent.windParticleEmitter = nil

    end )

end

function ENT:SetupDataTablesExtra()
    self:NetworkVar( "Bool", 2, "ParticlesActive" )

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

function ENT:OwnerlessThink()
    if self.nextTargFind < CurTime() then
        self.nextTargFind = CurTime() + self.TargetRefindInterval
        self:FindGustTargets()

    end
    if self.miniPushActive then
        self:TryMiniGust()

    end

    self:NextThink( CurTime() )

end

function ENT:FindGustTargets()
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

    self.pushTargets = targets

end

function ENT:Place()

    self:FindGustTargets()

    local windPos = self:GetPos()

    local owner = self.player
    self.pushOwner = owner
    self.miniPushActive = true
    self:SetPos( windPos + self.PosOffsetPostPlace ) -- Raise up so sounds don't play from the floor
    self:SetParticlesActive( true )

    local score = self:GetGivenScore()

    if owner.GivePlayerScore and score then
        owner:GivePlayerScore( score )
        GAMEMODE:sendPurchaseConfirm( owner, score )

    end

    GAMEMODE:AddMischievousness( owner, 1, "used a gust of wind" )
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

    local delay = math.Rand( self.PushDelayMin, self.PushDelayMax )
    local telegraphSound = CreateSound( self, "ambient/wind/windgust_strong.wav" )
    self.telegraphSound = telegraphSound
    telegraphSound:SetSoundLevel( 85 )
    telegraphSound:PlayEx( 0, 90 )
    telegraphSound:ChangeVolume( 1, delay )
    telegraphSound:ChangePitch( 150, delay )

    timer.Simple( delay, function()
        if not IsValid( self ) then return end

        self:FinalGust()

    end )
end

function ENT:Gust( strength, shakeMult, countMischief )
    if not self.pushTargets then return end

    local pushAng = self:GetAngles()
    pushAng[1] = self.PushPitch
    strength = strength or 1
    shakeMult = shakeMult or 1

    util.ScreenShake( self:GetPos(), 3 * strength * shakeMult, 40, 4 * math.max( strength, 0.5 ), 1000, true )

    local pushVec = pushAng:Forward() * strength
    local pushVecPlayer = pushVec * self.PushStrengthPlayer
    local pushVecNPC = pushVec * self.PushStrengthNPC
    local pushVecMisc = pushVec * self.PushStrengthMisc
    local owner = IsValid( self.pushOwner ) and self.pushOwner
    local targets = self.pushTargets

    for _, target in ipairs( targets ) do
        if not IsValid( target ) then continue end

        local physObj = target:GetPhysicsObject()
        if not IsValid( physObj ) then continue end

        if target:IsPlayer() then
            if not target:Alive() then continue end

            target:SetVelocity( pushVecPlayer * math.Rand( self.PushVariancePlayerMin, self.PushVariancePlayerMax ) )
            if owner and countMischief then GAMEMODE:AddMischievousness( owner, 5, "pushed a player with wind" ) end

        elseif target:IsNPC() or target:IsNextBot() then
            if not target:Alive() then continue end

            local mult = math.max( 100 / physObj:GetMass(), 0.5 )
            target:SetVelocity( physObj:GetVelocity() + pushVecNPC * mult )

        else
            target:GetPhysicsObject():ApplyForceCenter( pushVecMisc * math.Rand( self.PushVarianceMiscMin, self.PushVarianceMiscMax ) )
            hook.Run( "glee_OnEscapeeWindPushed", target )

        end
    end
end

function ENT:TryMiniGust()
    local now = CurTime()
    if self.miniPushNextTime and self.miniPushNextTime > now then return end

    self.miniPushNextTime = now + math.Rand( self.MiniPushIntervalMin, self.MiniPushIntervalMax )
    self:Gust( math.Rand( self.MiniPushStrengthMin, self.MiniPushStrengthMax ) )

end

function ENT:FinalGust()
    if not self.pushTargets then return end

    self.telegraphSound:ChangeVolume( 0, 1.5 )
    self.telegraphSound:ChangePitch( 90, 1.5 )
    self:EmitSound( "ambient/wind/windgust.wav", 85, 130, 1 )

    self:Gust( 1, 2, true )
    self.pushTargets = nil
    self.miniPushActive = false

    timer.Simple( 1, function()
        if not IsValid( self ) then return end
        self:SetParticlesActive( false )

    end )

    timer.Simple( 6, function()
        if not IsValid( self ) then return end

        if self.telegraphSound then
            self.telegraphSound:Stop()
            self.telegraphSound = nil

        end

        self:Remove()

    end )
end
