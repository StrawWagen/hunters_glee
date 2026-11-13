-- An infernal skeleton starting its death anim. Its glow cuts out and its bones crumble, see terminator_nextbot_infernalskeleton.lua
-- local fx = EffectData()
-- fx:SetOrigin( skeleton:WorldSpaceCenter() )
-- fx:SetEntity( skeleton )
-- util.Effect( "eff_huntersglee_skeletondeath", fx )

local vecUp = Vector( 0, 0, 1 )
local debrisGravity = Vector( 0, 0, -600 )
local dustDrift = Vector( 0, 0, -20 )

-- all at model scale 1, multiplied by scale squared so big skeletons visibly fall apart
local dustCount = 4
local chipCount = 16
local emberCount = 6

local function burstVelocity( scale, minSpeed, maxSpeed )
    return ( VectorRand():GetNormalized() * math.random( minSpeed, maxSpeed ) + vecUp * math.random( 25, 100 ) ) * scale

end

function EFFECT:Init( data )
    local skeleton = data:GetEntity()
    if not IsValid( skeleton ) then return end

    skeleton.glee_skeleDead = true

    local scale = skeleton:GetModelScale()
    local scaleSqr = scale * scale
    local getBonePos = terminator_Extras.GetRandomHitboxPoint

    local emitter = ParticleEmitter( data:GetOrigin() )

    -- same bone dust as eff_huntersglee_skullcrush
    for _ = 1, math.ceil( dustCount * scaleSqr ) do
        local dust = emitter:Add( "particle/particle_smokegrenade1", getBonePos( skeleton ) )
        if dust then
            dust:SetVelocity( burstVelocity( scale, 20, 60 ) )
            dust:SetDieTime( math.Rand( 1, 2 ) * scale )
            dust:SetColor( 250, 255, 220 )
            dust:SetStartAlpha( 120 )
            dust:SetEndAlpha( 0 )
            dust:SetStartSize( 8 * scale )
            dust:SetEndSize( 35 * scale )
            dust:SetRoll( math.Rand( 0, 360 ) )
            dust:SetRollDelta( math.Rand( -1, 1 ) )
            dust:SetAirResistance( 60 )
            dust:SetGravity( dustDrift )
            dust:SetCollide( false )

        end
    end

    -- solid all the way down like eff_huntersglee_skeletonhurt's, fading and shrinking made them read as goop
    for _ = 1, math.ceil( chipCount * scaleSqr ) do
        local chip = emitter:Add( "effects/fleck_wood" .. math.random( 1, 2 ), getBonePos( skeleton ) )
        if chip then
            chip:SetVelocity( burstVelocity( scale, 100, 250 ) )
            chip:SetDieTime( math.Rand( 0.8, 1.5 ) )
            chip:SetStartAlpha( 255 )
            chip:SetEndAlpha( 255 )
            chip:SetStartSize( math.Rand( 1.5, 3 ) * scale )
            chip:SetColor( 235, 225, 205 )
            chip:SetRoll( math.Rand( 0, 360 ) )
            chip:SetRollDelta( math.Rand( -30, 30 ) )
            chip:SetAirResistance( 20 )
            chip:SetGravity( debrisGravity )
            chip:SetCollide( true )
            chip:SetBounce( 0.3 )

        end
    end

    for _ = 1, math.ceil( emberCount * scaleSqr ) do
        local ember = emitter:Add( "effects/fire_embers" .. math.random( 1, 3 ), getBonePos( skeleton ) )
        if ember then
            ember:SetVelocity( burstVelocity( scale, 100, 250 ) )
            ember:SetDieTime( math.Rand( 1, 2.5 ) * scale )
            ember:SetStartAlpha( 255 )
            ember:SetEndAlpha( 0 )
            ember:SetStartSize( math.Rand( 4, 8 ) * scale )
            ember:SetRoll( math.Rand( 0, 360 ) )
            ember:SetRollDelta( math.Rand( -5, 5 ) )
            ember:SetAirResistance( 20 )
            ember:SetGravity( debrisGravity )
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
