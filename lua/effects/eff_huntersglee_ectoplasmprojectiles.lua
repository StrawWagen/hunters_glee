

function EFFECT:Init( data )
    self.Pos = data:GetOrigin() -- Origin determines the global position of the effect
    self.Scale = data:GetScale() -- Scale determines how large the effect is
    self.Emitter = ParticleEmitter( self.Pos ) -- Emitter must be there so you don't get an error

    self:Splat()

    self.Emitter:Finish()

end

function EFFECT:Render()
end

function EFFECT:Splat()
    local emitter = self.Emitter
    local pos = self.Pos
    local scale = self.Scale

    for _ = 1, math.random( 1, 3 ) * scale do
        local plasm = emitter:Add( "particle/particle_ring_wave_8", pos )
        if plasm then
            local randVec = VectorRand()
            randVec.z = randVec.z * 0.25 -- mentos shape
            randVec:Normalize()
            local randVel = randVec * 600 * scale

            plasm:SetVelocity( randVel )
            plasm:SetDieTime( math.Rand( 0.05, 0.25 ) )
            plasm:SetStartAlpha( 230 )
            plasm:SetEndAlpha( 0 )
            plasm:SetStartSize( 1 * scale )
            plasm:SetEndSize( 5 * scale )
            plasm:SetRoll( math.Rand( 150, 360 ) )
            plasm:SetRollDelta( math.Rand( -1, 1 ) )
            plasm:SetAirResistance( 5 )
            plasm:SetGravity( Vector( 0, 0, -2000 ) )
            plasm:SetColor( 178, 245, 255 )
            plasm:SetCollide( true )

            -- when it collides, apply decal! and remove!
            plasm:SetCollideCallback( function( _particle, hitPos, hitNormal )
                util.Decal( "Nought", hitPos, hitPos + -hitNormal * 10 )
                plasm:SetDieTime( 0 ) -- die now!

            end )
        end
    end
end