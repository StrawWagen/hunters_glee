AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Score Pickup"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Locks doors"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0, "Score" )

end

util.PrecacheModel( "models/maxofs2d/hover_rings.mdl" )

local color_good = Color( 0,255,0 )
local color_bad = Color( 255,0,0 )
local defaultScore = 15

function ENT:Initialize()
    if SERVER then
        self.nextAllowedMerge = CurTime() + 1
        self.nextScoreDecay = CurTime() + 30
        self.canBePickedUpTime = CurTime() + 0.1
        self.nextScoreClick = CurTime() + 3
        self.DoNotDuplicate = true
        if self:GetScore() == 0 then
            self:SetScore( 15 )

        end
        self:SetModel( "models/maxofs2d/hover_rings.mdl" )
        self:SetTrigger( true )

        self:ReflectScoreInAppearance()

        self:SetCollisionGroup( COLLISION_GROUP_WEAPON )

        terminator_Extras.SmartSleepEntity( self, 10 )

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:SetBuoyancyRatio( 8 )
            phys:SetMaterial( "glass" )

        end

        self:HandleScorePhysics()

        self:SoundThink( 1 )

    end
end

function ENT:GetScoreScaleMagicNum()
    return 0.5 + math.abs( self:GetScore() ) / 100

end

function ENT:UpdateScoreLive()

    self.nextAllowedMerge = CurTime() + 0.5

    self:ReflectScoreInAppearance()
    self:HandleScorePhysics()

end

function ENT:ReflectScoreInAppearance()
    local scale = self:GetScoreScaleMagicNum()

    local color = nil
    if self:GetScore() > 0 then
        color = color_good

    elseif self:GetScore() <= 0 then
        color = color_bad

    end

    self:PhysicsInitSphere( self:GetModelRadius() * scale )
    self:SetModelScale( scale, 0.0001 )
    self:SetColor( color )

end

function ENT:HandleScorePhysics()
    timer.Simple( 0, function()
        if not IsValid( self ) then return end
        local scale = self:GetScoreScaleMagicNum()
        local offset = ( self:GetModelRadius() * scale ) / 4

        self:SetPos( self:GetPos() + Vector( 0, 0, offset ) )
        local phys = self:GetPhysicsObject()

        if IsValid( phys ) then
            phys:SetMass( self:GetScore() * 4 )
            phys:Wake()

            self:UseTriggerBounds( true, 24 )

        end
    end )
end

function ENT:DoClicking()
    if self.nextScoreClick > CurTime() then return end

    self:SoundThink( 1 )
    local flash = EffectData()
    flash:SetScale( 0.25 )
    flash:SetOrigin( self:WorldSpaceCenter() )
    util.Effect( "eff_huntersglee_scoreball_flash", flash )

    self.nextScoreClick = CurTime() + 3 + math.Rand( -0.1, 0.1 )

end

function ENT:Think()
    if CLIENT then
        self:SetNextClientThink( CurTime() + 1100101010 )
        return true

    else
        self:DoClicking()
        -- slowly lose score
        if self.nextScoreDecay > CurTime() then return end
        if self.nextAllowedMerge > CurTime() then return end
        self.nextScoreDecay = CurTime() + 30
        if IsValid( self:GetPhysicsObject() ) and self:GetPhysicsObject():GetVelocity():LengthSqr() > 15^2 then return end

        local newScore = 0
        local scoreStep = 2
        local oldScore = self:GetScore()
        if oldScore >= defaultScore or oldScore <= defaultScore then
            newScore = oldScore * 0.99

        elseif oldScore < 0 then
            newScore = oldScore + -scoreStep

        elseif oldScore > 0 then
            newScore = oldScore + scoreStep

        end
        if newScore < scoreStep and newScore > -scoreStep then
            SafeRemoveEntity( self )
            return

        end

        self:SetScore( newScore )
        self:UpdateScoreLive()

    end
end

function ENT:MergeWith( otherEnt )
    if self.beingMergedWithAnotherBall then return end -- idk if this will really be needed
    if self.nextAllowedMerge > CurTime() then return end
    if otherEnt.nextAllowedMerge > CurTime() then return end
    local theBestOne = nil
    local myScore = self:GetScore()
    local theirScore = otherEnt:GetScore()

    if myScore == theirScore then
        theBestOne = self
        theWorstOne = otherEnt

    elseif myScore > theirScore then
        theBestOne = self
        theWorstOne = otherEnt

    else
        theBestOne = otherEnt
        theWorstOne = self

    end

    theWorstOne.beingMergedWithAnotherBall = true

    local velocitiesAdded = Vector()
    if IsValid( theWorstOne:GetPhysicsObject() ) then
        velocitiesAdded = velocitiesAdded + theWorstOne:GetVelocity()

    end
    if IsValid( theBestOne:GetPhysicsObject() ) then
        velocitiesAdded = velocitiesAdded + theBestOne:GetVelocity()
        timer.Simple( 0, function()
            if not IsValid( theBestOne ) then return end
            theBestOne:GetPhysicsObject():SetVelocity( velocitiesAdded )

        end )
    end

    theBestOne:SetScore( theBestOne:GetScore() + theWorstOne:GetScore() )
    theBestOne:PloopSound()
    theBestOne:UpdateScoreLive()

    SafeRemoveEntity( theWorstOne )

end

function ENT:PloopSound()
    local pit = 100 + -math.abs( self:GetScore() ) / 2
    if pit < 30 then
        pit = 30 + -math.abs( self:GetScore() ) / 20

    end
    self:EmitSound( "garrysmod/balloon_pop_cute.wav", 75, pit )
    if self:GetScore() <= 0 then
        self:EmitSound( "buttons/combine_button2.wav", 75, pit )

    end
end

function ENT:DoScore( reciever )
    if not reciever:IsPlayer() then return end

    self:PloopSound()

    local pos = self:WorldSpaceCenter()
    local mul = self:GetScore() / defaultScore

    timer.Simple( 0, function()
        local flash = EffectData()
        flash:SetScale( 0.35 * mul )
        flash:SetOrigin( pos )
        util.Effect( "eff_huntersglee_scoreball_flash", flash )

    end )

    if not reciever.GivePlayerScore then SafeRemoveEntity( self ) return end

    reciever:GivePlayerScore( self:GetScore() )

    SafeRemoveEntity( self )

end

function ENT:Touch( touched )
    if self.canBePickedUpTime > CurTime() then return end
    self:DoScore( touched )

end

function ENT:Use( user )
    if user:Health() <= 0 then return end
    self:DoScore( user )

end

function ENT:OnTakeDamage( dmg )
    self:TakePhysicsDamage( dmg )
    local absScore = math.abs( self:GetScore() )
    if dmg:GetDamage() > absScore and math.random( 0, 100 ) > 25 then
        local pit = math.random( 150, 160 ) + -( absScore / 4 )
        self:EmitSound( "physics/glass/glass_sheet_break3.wav", 70 + ( absScore / 2 ), pit )

        SafeRemoveEntity( self )

    end
end

function ENT:PhysicsCollide( colData, _ )
    self:DoScore( colData.HitEntity )
    if colData.HitEntity:GetClass() == "termhunt_score_pickup" then
        local toMerge = colData.HitEntity
        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            if not IsValid( toMerge ) then return end
            self:MergeWith( toMerge )

        end )
        return

    end
    if colData.Speed < 30 then return end
    self:SoundThink( colData.Speed / 100 )


end

function ENT:SoundThink( volume )
    if not self.impactSound then
        local sndPath = "ambient/materials/dinnerplates1.wav"
        if self:GetScore() > 25 then
            sndPath = "EpicMetal.ImpactHard"

        end
        self.impactSound = CreateSound( self, sndPath )

    end
    if self.impactSound then
        self.impactSound:Stop()
        self.impactSound:SetSoundLevel( math.Clamp( 65 + math.abs( self:GetScore() / 2 ), 0, 140 ) )

        local pit = 150 + -math.abs( self:GetScore() ) / 1.5
        if pit < 30 then
            pit = 30 + -math.abs( self:GetScore() ) / 20

        end
        self.impactSound:PlayEx( volume, pit )
        util.ScreenShake( self:GetPos(), 0.2, 20, 0.2, 600, true )

    end
end