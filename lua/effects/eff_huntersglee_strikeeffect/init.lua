function EFFECT:Init( data )
    local vOffset = data:GetOrigin()
    self.Position = vOffset
    self.Scayul = data:GetScale()
    local emitter = ParticleEmitter( data:GetOrigin() )
    local rollparticle = emitter:Add( "sprites/animglow02", vOffset + vector_up * self.Scayul )

    if rollparticle then
        rollparticle:SetLifeTime( 0 )
        local life = .2 + ( self.Scayul * 0.1 )
        rollparticle:SetDieTime( life )
        rollparticle:SetColor( 150, 150, 255 )
        rollparticle:SetStartAlpha( 255 )
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

    emitter:Finish()
end

function EFFECT:Render()
end
