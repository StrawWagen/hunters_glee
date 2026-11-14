-- An infernal skeleton getting hit. Bone chips and embers fly off, and its glow jitters, see terminator_nextbot_infernalskeleton.lua
-- local fx = EffectData()
-- fx:SetOrigin( hitPos )
-- fx:SetEntity( skeleton )
-- fx:SetScale( 1 ) -- about 20 damage worth of chips
-- util.Effect( "eff_huntersglee_skeletonhurt", fx )

local vecUp = Vector( 0, 0, 1 )
local chipGravity = Vector( 0, 0, -600 )

local function flungVelocity( minSpeed, maxSpeed )
    return VectorRand():GetNormalized() * math.random( minSpeed, maxSpeed ) + vecUp * math.random( 25, 100 )

end

function EFFECT:Init( data )
    local skeleton = data:GetEntity()
    if IsValid( skeleton ) then
        skeleton.glee_lastSkeleHurt = CurTime()

    end

    local pos = data:GetOrigin()
    local scale = data:GetScale()
    local emitter = ParticleEmitter( pos )

    -- solid all the way down, fading and shrinking made them read as goop
    for _ = 1, math.ceil( 6 * scale ) do
        local chip = emitter:Add( "effects/fleck_wood" .. math.random( 1, 2 ), pos )
        if chip then
            chip:SetVelocity( flungVelocity( 150, 350 ) )
            chip:SetDieTime( math.Rand( 0.4, 0.8 ) )
            chip:SetStartAlpha( 255 )
            chip:SetEndAlpha( 255 )
            chip:SetStartSize( math.Rand( 0.75, 1.5 ) )
            chip:SetColor( 235, 225, 205 )
            chip:SetRoll( math.Rand( 0, 360 ) )
            chip:SetRollDelta( math.Rand( -30, 30 ) )
            chip:SetAirResistance( 20 )
            chip:SetGravity( chipGravity )
            chip:SetCollide( true )
            chip:SetBounce( 0.3 )

        end
    end

    for _ = 1, math.ceil( 3 * scale ) do
        local ember = emitter:Add( "effects/fire_embers" .. math.random( 1, 3 ), pos )
        if ember then
            ember:SetVelocity( flungVelocity( 100, 300 ) )
            ember:SetDieTime( math.Rand( 0.3, 1 ) )
            ember:SetStartAlpha( 255 )
            ember:SetEndAlpha( 0 )
            ember:SetStartSize( math.Rand( 0.25, 1 ) )
            ember:SetRoll( math.Rand( 0, 360 ) )
            ember:SetRollDelta( math.Rand( -5, 5 ) )
            ember:SetAirResistance( 20 )
            ember:SetGravity( chipGravity )
            ember:SetCollide( true )
            ember:SetLighting( false )

        end
    end

    emitter:Finish()

end

function EFFECT:Think()
    return false

end

function EFFECT:Render()
end
