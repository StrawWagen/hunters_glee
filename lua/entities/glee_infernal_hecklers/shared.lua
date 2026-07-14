AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"

ENT.Category    = "Other"
ENT.PrintName   = "Infernal Hecklers"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Summons infernal skeletons to heckle the living"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"
ENT.Model = "models/hunter/tubes/circle2x2.mdl"

ENT.HullCheckSize = Vector( 20, 20, 10 )
ENT.PosOffset = Vector( 0, 0, 10 )

-- how many skeletons, and what they are
ENT.SkeletonClass = "terminator_nextbot_infernalskeleton"
ENT.MinHecklers = 3
ENT.MaxHecklers = 4

-- configurable distances
ENT.GuiltyCheckRadius = 2500 -- alive players within this decide the cost tier
ENT.CloseRadius = 500 -- any alive player within this doubles the cost

-- configurable cost tiers
ENT.CostNobody = 50
ENT.CostAllInnocent = 400 -- nobody guilty nearby ( or nobody at all )
ENT.CostMixed = 200 -- both guilty and innocent nearby
ENT.CostAllGuilty = -100 -- only guilty nearby, profitable
ENT.CloseCostMult = 2

ENT.OnlyNetworkToOwner = false

if CLIENT then
    function ENT:DoHudStuff()
        local screenMiddleW = ScrW() / 2
        local screenMiddleH = ScrH() / 2

        local cost = math.Round( self:GetGivenScore() )

        local scoreString = "Hecklers Cost: " .. tostring( cost )

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

    end
end

if not SERVER then return end

function ENT:PostInitializeFunc()
    if not GAMEMODE.ISHUNTERSGLEE then SafeRemoveEntity( self ) return end
    self:SetMaterial( "lights/white002" )

end

-- cheaper the guiltier the crowd, dearer the more innocent, doubled if you drop it on someone
function ENT:UpdateGivenScore()
    local myPos = self:GetPos()

    local closeRadiusSqr = self.CloseRadius ^ 2
    local checkRadiusSqr = self.GuiltyCheckRadius ^ 2

    local anyInnocent = false
    local anyGuilty = false
    local anyClose = false

    for _, ply in ipairs( player.GetAll() ) do
        if not ply:Alive() then continue end

        local distSqr = ply:GetPos():DistToSqr( myPos )

        if distSqr < closeRadiusSqr then
            anyClose = true

        end

        if distSqr > checkRadiusSqr then continue end

        -- guilty players make it cheaper ( green ), innocents make it dearer ( red )
        if GAMEMODE:IsInnocent( ply ) then
            anyInnocent = true
            self:AddBlameReason( ply, -25, "Innocent Nearby" )

        else
            anyGuilty = true
            self:AddBlameReason( ply, 25, "Guilty Nearby" )

        end
    end

    local cost
    if anyGuilty and anyInnocent then
        cost = self.CostMixed

    elseif anyGuilty then
        cost = self.CostAllGuilty

    elseif anyInnocent then
        cost = self.CostAllInnocent -- only innocents

    else
        cost = self.CostNobody

    end

    if anyClose then
        cost = math.abs( cost )
        cost = cost * self.CloseCostMult

    end

    self:SetGivenScore( -cost )

end

function ENT:SpawnAHeckler( aroundPos )
    local skele = ents.Create( self.SkeletonClass )
    if not IsValid( skele ) then return end

    local offset = VectorRand()
    offset.z = 0
    offset:Normalize()
    offset = offset * math.random( 20, 70 )
    local spawnPos = aroundPos + offset + Vector( 0, 0, 10 )

    util.Decal( "Scorch", spawnPos, spawnPos + Vector( 0, 0, -50 ) )

    skele:SetPos( spawnPos )
    skele:SetAngles( Angle( 0, math.random( -180, 180 ), 0 ) )
    skele:Spawn()

    GAMEMODE:RegisterAsSpawnedHunter( skele )

    terminator_Extras.DoPFXFromEnt( "glee_ghostly_ectoplasm", skele )

    return skele

end

PrecacheParticleSystem( "fire_large_01" )
PrecacheParticleSystem( "fire_medium_02" )


function ENT:BumpNearbyEnts()
    local nearbyEnts = ents.FindInSphere( self:GetPos(), self:GetModelRadius() * 2 )
    for _, ent in ipairs( nearbyEnts ) do
        terminator_Extras.SmartSleepWakeEntity( ent )
        local entsObj = ent:GetPhysicsObject()
        if not IsValid( entsObj ) then continue end

        entsObj:ApplyForceCenter( VectorRand() * entsObj:GetMass() )
    end
end

function ENT:Place()
    local myPos = self:GetPos()

    -- charge the ( negative ) cost
    local cost = self:GetGivenScore()
    if self.player and self.player.GivePlayerScore and cost then
        self.player:GivePlayerScore( cost )
        GAMEMODE:sendPurchaseConfirm( self.player, cost )

    end

    GAMEMODE:AddMischievousness( self.player, 10, "summoned infernal hecklers" )
    GAMEMODE:IncrementPersistentGuilt( self.player, 0.25 )

    self:DetachFromOwner()

    local baseDelay = 2
    local betweenSpawnsDelay = 0.15

    terminator_Extras.DoPFXFromEnt( "fire_medium_02", self )

    self.fleshBurnSound = CreateSound( self, "player/general/flesh_burn.wav" )
    self.fleshBurnSound:PlayEx( 1, 100 )
    self.fleshBurnSound:ChangePitch( 200, baseDelay * 0.95 )

    self.IsFlaming = true
    self:SetTrigger( true )
    self:UseTriggerBounds( true, 25 )

    self:BumpNearbyEnts()

    timer.Simple( baseDelay, function()
        if not IsValid( self ) then return end
        terminator_Extras.DoPFXFromEnt( "fire_large_01", self )

        self:EmitSound( "ambient/fire/gascan_ignite1.wav", 90, 75 )

        local snd = CreateSound( self, "npc/stalker/laser_burn.wav" )
        snd:PlayEx( 0.5, 200 )
        snd:ChangePitch( 90, 1 )
        snd:ChangeVolume( 1, 1 )
        self.fleshBurnSound:ChangePitch( 50, 0.5 )

        self:BumpNearbyEnts()

    end )

    local count = math.random( self.MinHecklers, self.MaxHecklers )
    for i = 1, count do
        timer.Simple( baseDelay + ( i - 1 ) * betweenSpawnsDelay, function()
            if not IsValid( self ) then return end
            self:SpawnAHeckler( myPos )

            self:BumpNearbyEnts()

        end )
    end

    timer.Simple( baseDelay + count * betweenSpawnsDelay + 3, function()
        if not IsValid( self ) then return end
        sound.Play( "ambient/fire/mtov_flame2.wav", self:GetPos(), 76, 80 )
        SafeRemoveEntity( self )

    end )
end

function ENT:Touch( touched )
    touched:Ignite( 5 )

end