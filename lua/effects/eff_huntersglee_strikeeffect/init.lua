local FLAG_NODUST = 1 -- skip the cement flecks and embers, for when something else at this spot already throws them

function EFFECT:Init( data )
    local vOffset = data:GetOrigin()
    self.Position = vOffset
    self.Scayul = data:GetScale()

    self.NoDust = bit.band( data:GetFlags(), FLAG_NODUST ) ~= 0

    self.Emitter = ParticleEmitter( data:GetOrigin() )
    local rollparticle = self.Emitter:Add( "sprites/animglow02", vOffset + vector_up * self.Scayul )

    if rollparticle then
        rollparticle:SetLifeTime( 0 )
        local life = .2 + ( self.Scayul * 0.1 )
        rollparticle:SetDieTime( life )
        rollparticle:SetColor( 150, 150, 255 )
        rollparticle:SetStartAlpha( 50 )
        rollparticle:SetEndAlpha( 0 )
        rollparticle:SetStartSize( 150 * self.Scayul )
        rollparticle:SetEndSize( 0 )
        rollparticle:SetRoll( math.Rand( -360, 360 ) )
        rollparticle:SetRollDelta( math.Rand( -0.61, 0.61 ) * 5 )
        rollparticle:SetAirResistance( 0 )
        rollparticle:SetGravity( Vector( 0, 0, 0 ) )
        rollparticle:SetCollide( false )
        rollparticle:SetLighting( false )

    end

    local rollparticle2 = self.Emitter:Add( "sprites/animglow02", vOffset + vector_up * self.Scayul )
    if rollparticle2 then
        rollparticle2:SetLifeTime( 0 )
        local life = .1 + ( self.Scayul * 0.05 )
        rollparticle2:SetDieTime( life )
        rollparticle2:SetColor( 150, 150, 255 )
        rollparticle2:SetStartAlpha( 255 )
        rollparticle2:SetEndAlpha( 0 )
        rollparticle2:SetStartSize( 150 * self.Scayul )
        rollparticle2:SetEndSize( 0 )
        rollparticle2:SetRoll( math.Rand( -360, 360 ) )
        rollparticle2:SetRollDelta( math.Rand( -0.61, 0.61 ) * 5 )
        rollparticle2:SetAirResistance( 0 )
        rollparticle2:SetGravity( Vector( 0, 0, 0 ) )
        rollparticle2:SetCollide( false )
        rollparticle2:SetLighting( false )

    end

    self:Particles()

    self.Emitter:Finish()
end

local vecUp = Vector( 0, 0, 1 )

function EFFECT:Particles()
    local emitter = self.Emitter
    local pos = self.Position
    local scale = self.Scayul * 0.5

    for _ = 1, 2 * scale do
        local Debris = emitter:Add( "effects/fire_cloud" .. math.random( 1, 2 ), pos )
        if Debris then
            Debris:SetVelocity( vecUp * math.random( 0, 500 ) * scale + VectorRand():GetNormalized() * math.random( 0, 2000 ) * scale )
            Debris:SetDieTime( math.Rand( 0.15, 0.5 ) * scale )
            Debris:SetStartAlpha( 255 )
            Debris:SetEndAlpha( 0 )
            Debris:SetStartSize( math.Rand( 15, 25 ) * scale )
            Debris:SetRoll( math.Rand( 0, 360 ) )
            Debris:SetRollDelta( math.Rand( -5, 5 ) )
            Debris:SetAirResistance( 20 )
            Debris:SetColor( 255, 255, 255 )
            Debris:SetGravity( Vector( 0, 0, 600 ) )
            Debris:SetCollide( true )
            Debris:SetLighting( false )

        end
    end

    if self.NoDust then return end

    for _ = 1, 12 * scale do
        local Debris = emitter:Add( "effects/fleck_cement" .. math.random( 1, 2 ), pos )
        if Debris then
            Debris:SetVelocity( vecUp * math.random( 0, 700 ) * scale + VectorRand():GetNormalized() * math.random( 0, 700 ) * scale )
            Debris:SetDieTime( math.random( 1, 2 ) * scale )
            Debris:SetStartAlpha( 255 )
            Debris:SetEndAlpha( 0 )
            Debris:SetStartSize( math.random( 5, 10 ) * scale )
            Debris:SetRoll( math.Rand( 0, 360 ) )
            Debris:SetRollDelta( math.Rand( -5, 5 ) )
            Debris:SetAirResistance( 40 )
            Debris:SetColor( 60, 60, 60 )
            Debris:SetGravity( Vector( 0, 0, -600 ) )
            Debris:SetCollide( true )

        end
    end
    for _ = 1, 50 * scale do
        local Debris = emitter:Add( "effects/fire_embers" .. math.random( 1, 3 ), pos )
        if Debris then
            Debris:SetVelocity( vecUp * math.random( 0, 1000 ) * scale + VectorRand():GetNormalized() * math.random( 0, 2000 ) * scale )
            Debris:SetDieTime( math.Rand( 0.5, 15 ) * scale )
            Debris:SetStartAlpha( 255 )
            Debris:SetEndAlpha( 0 )
            Debris:SetStartSize( math.Rand( 0.5, 4 ) * scale )
            Debris:SetRoll( math.Rand( 0, 360 ) )
            Debris:SetRollDelta( math.Rand( -5, 5 ) )
            Debris:SetAirResistance( 10 )
            Debris:SetColor( 255, 255, 255 )
            Debris:SetGravity( Vector( 0, 0, -600 ) )
            Debris:SetCollide( true )
            Debris:SetLighting( false )

        end
    end
end

function EFFECT:Render()
end
