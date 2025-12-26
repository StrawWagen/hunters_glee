-- all credit goes to the garrys gift people! https://steamcommunity.com/sharedfiles/filedetails/?id=3627597099&searchtext=garrys+gift
-- idk who made the code but i'm assuming its StrawWagen! https://steamcommunity.com/id/StrawWagen/

local colors = {
    Color(6,255,193),
    Color(255,6,110),
    Color(6,122,255),
    Color(238,255,6)
}
function EFFECT:Init( data )
  
    local delay = data:GetScale()
 

    local vOffset = data:GetOrigin()
    self.Position = vOffset
    self.Scayul = 1
    local emitter = ParticleEmitter( data:GetOrigin() )
    local rollparticle = emitter:Add( "particle/particle_glow_04_additive", vOffset )


    rollparticle:SetDieTime( math.Rand( 3,4 ) )
    local c =  colors[math.random(#colors)]
    rollparticle:SetColor(c.r,c.g,c.b )
    rollparticle:SetStartSize(30)
    rollparticle:SetEndSize(0)
    
 
    for _ = 1, 90 do
        local rollparticle = emitter:Add( "particle/particle_glow_04_additive", vOffset )
        local vel = VectorRand()
        vel.z = vel.z
        vel:Normalize()
        vel = vel * math.Rand( 90,200 )
        rollparticle:SetVelocity( vel )
        rollparticle:SetDieTime( math.Rand( 1,2 ) )
        local c =  colors[math.random(#colors)]
        rollparticle:SetColor(c.r,c.g,c.b )
        rollparticle:SetStartAlpha( 255 )
        rollparticle:SetEndAlpha( 0 )
        rollparticle:SetStartSize( 1 )
        rollparticle:SetEndSize( 3 )
        rollparticle:SetRoll( math.Rand( -360, 360 ) )
        rollparticle:SetRollDelta( math.Rand( -1, 1 ) * 2 )
        rollparticle:SetAirResistance( 170 )
        rollparticle:SetGravity( Vector(0,0,10) )
        rollparticle:SetCollide( false )

    end

    emitter:Finish()

end

function EFFECT:Render()
end
