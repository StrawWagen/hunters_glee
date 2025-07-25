terminator_Extras = terminator_Extras or {}

util.doorIsUsable = function( door )
    local center = door:WorldSpaceCenter()
    local forward = door:GetForward()
    local starOffset = forward * 50
    local endOffset  = forward * 2

    local traceDatF = {
        mask = MASK_SOLID_BRUSHONLY,
        start = center + starOffset,
        endpos = center + endOffset
    }

    local traceDatB = {
        mask = MASK_SOLID_BRUSHONLY,
        start = center + -starOffset,
        endpos = center + -endOffset
    }

    local traceBack = util.TraceLine( traceDatB )
    local traceFront = util.TraceLine( traceDatF )

    local canSmash = not traceBack.Hit and not traceFront.Hit
    return canSmash

end

local up = Vector( 0, 0, 1 )
local down = Vector( 0, 0, -1 )

function terminator_Extras.GleeFancySplode( pos, damage, radius, attacker, inflictor )

    -- escape primary fire jankiness
    local splode = EffectData()
    splode:SetOrigin( pos )
    splode:SetMagnitude( damage )
    splode:SetScale( radius )
    util.Effect( "Explosion", splode, nil, true )

    local contents = util.PointContents( pos )

    local explSound = "BaseExplosionEffect.Sound"
    if bit.band( contents, CONTENTS_WATER ) ~= 0 then
        explSound = "WaterExplosionEffect.Sound"

    end

    sound.Play( explSound, pos, 88, math.random( 95, 105 ) )
    util.BlastDamage( inflictor, attacker, pos, radius, damage )
    util.Decal( "FadingScorch", pos + up, pos + down * radius / 4, ent )

end