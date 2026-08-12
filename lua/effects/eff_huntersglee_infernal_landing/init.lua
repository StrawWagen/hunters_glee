function EFFECT:Init( data )
    local vOffset = data:GetOrigin()
    self.Position = vOffset
    self.Scayul = data:GetScale()
    self.Emitter = ParticleEmitter( data:GetOrigin() )

    self:Dust()

    self.Emitter:Finish()
end

local vecUp = Vector( 0, 0, 1 )

function EFFECT:Dust()
    local emitter = self.Emitter
    local pos = self.Position
    local scale = self.Scayul * 0.5

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
    for _ = 1, 4 * scale do
        local Debris = emitter:Add( "effects/fire_cloud" .. math.random( 1, 2 ), pos )
        if Debris then
            Debris:SetVelocity( -vecUp * math.random( 0, 10 ) * scale + VectorRand():GetNormalized() * math.random( 0, 50 ) * scale )
            Debris:SetDieTime( math.Rand( 0.15, 0.5 ) * scale )
            Debris:SetStartAlpha( 255 )
            Debris:SetEndAlpha( 0 )
            Debris:SetStartSize( math.Rand( 15, 25 ) * scale )
            Debris:SetEndSize( 75 )
            Debris:SetRoll( math.Rand( 0, 360 ) )
            Debris:SetRollDelta( math.Rand( -5, 5 ) )
            Debris:SetAirResistance( 20 )
            Debris:SetColor( 255, 255, 255 )
            Debris:SetGravity( Vector( 0, 0, 600 ) )
            Debris:SetCollide( true )
            Debris:SetLighting( false )

        end
    end
end

function EFFECT:Render()
end
