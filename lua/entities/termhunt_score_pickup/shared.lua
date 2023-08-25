AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category    = "Other"
ENT.PrintName   = "Score Pickup"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Locks doors"
ENT.Spawnable    = true
ENT.AdminOnly    = false
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
        self.canDoScoreTime = CurTime() + 0.5
        self.DoNotDuplicate = true
        if self:GetScore() == 0 then
            self:SetScore( 15 )

        end
        local scale = 0.5 + math.abs( self:GetScore() ) / 100

        local color = nil
        if self:GetScore() > 0 then
            color = color_good

        elseif self:GetScore() <= 0 then
            color = color_bad

        end

        self:SetModel( "models/maxofs2d/hover_rings.mdl" )
        self:SetModelScale( scale, 0.0001 )
        local offset = ( self:GetModelRadius() * scale ) / 2
        self:PhysicsInitSphere( self:GetModelRadius() * scale )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetSolid( SOLID_VPHYSICS )
        self:SetColor( color )

        self:SetTrigger( true )
        self:UseTriggerBounds( true, 24 )

        timer.Simple( 0, function()
            if not IsValid( self ) then return end
            self:SetPos( self:GetPos() + Vector( 0, 0, offset ) )

        end )

        local phys = self:GetPhysicsObject()
        if IsValid( phys ) then
            phys:Wake()
            phys:SetMass( self:GetScore() * 4 )
            phys:SetBuoyancyRatio( 8 )
            phys:SetMaterial( "glass" )
        end

        self:SoundThink( 1 )

    end
end

function ENT:Think()
    if CLIENT then
        if not IsValid( self ) then return end
        self:SoundThink( 1 )
        local flash = EffectData()
        flash:SetScale( 0.25 )
        flash:SetOrigin( self:WorldSpaceCenter() )
        util.Effect( "eff_huntersglee_scoreball_flash", flash )

        self:SetNextClientThink( CurTime() + 3 + math.Rand( -0.1, 0.1 ) )
        return true

    end
end

function ENT:DoScore( reciever )
    if not reciever:IsPlayer() then return end

    self:EmitSound( "garrysmod/balloon_pop_cute.wav", 75, 100 + -math.abs( self:GetScore() ) / 2 )
    if self:GetScore() <= 0 then
        self:EmitSound( "buttons/combine_button2.wav", 75, 100 + -math.abs( self:GetScore() ) / 2 )

    end

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
    if self.canDoScoreTime > CurTime() then return end
    self:DoScore( touched )

end

function ENT:Use( user )
    self:DoScore( user )

end

function ENT:OnTakeDamage( dmg )
    local absScore = math.abs( self:GetScore() )
    if dmg:GetDamage() > absScore and math.random( 0, 100 ) > 25 then
        local pit = math.random( 150, 160 ) + -( absScore / 4 )
        self:EmitSound( "physics/glass/glass_sheet_break3.wav", 70 + ( absScore / 2 ), pit )

        SafeRemoveEntity( self )

    end
end

function ENT:PhysicsCollide( colData, _ )
    self:DoScore( colData.HitEntity )
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
        self.impactSound:PlayEx( volume, 150 + -( math.abs( self:GetScore() ) / 1.5 ) )
        util.ScreenShake( self:GetPos(), 0.2, 20, 0.2, 600 )

    end
end