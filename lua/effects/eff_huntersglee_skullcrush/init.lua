function EFFECT:Init( data )
    local vOffset = data:GetOrigin()
    self.Position = vOffset
    self.Scayul = data:GetScale()
    local emitter = ParticleEmitter( data:GetOrigin() )

    for _ = 1, 10 do
        local rollparticle = emitter:Add( "particle/particle_smokegrenade1", vOffset )
        local vel = VectorRand()
        vel.z = 0
        vel:Normalize()
        vel = vel * math.Rand( 5, 25 )
        rollparticle:SetVelocity( vel )
        rollparticle:SetDieTime( math.Rand( 4, 8 ) )
        rollparticle:SetColor( 250, 255, 220 )
        rollparticle:SetStartAlpha( 50 )
        rollparticle:SetEndAlpha( 0 )
        rollparticle:SetStartSize( 8 )
        rollparticle:SetEndSize( 30 )
        rollparticle:SetRoll( math.Rand( -360, 360 ) )
        rollparticle:SetRollDelta( math.Rand( -1, 1 ) * 2 )
        rollparticle:SetAirResistance( 10 )
        rollparticle:SetGravity( Vector( 4, 4, 0 ) )
        rollparticle:SetCollide( false )

    end

    emitter:Finish()
end

function EFFECT:Render()
end
