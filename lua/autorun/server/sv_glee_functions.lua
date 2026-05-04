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

-- Creates a prop_physics parented to `parent`, positioned/angled via local-space offsets.
-- On parent removal the detail unparents, falls to the world, then is cleaned up.
function terminator_Extras.AttachParentedDetail( parent, toSpawn, localPos, localAng )
    local detail
    if isstring( toSpawn ) then
        detail = ents.Create( "prop_physics" )
        if not IsValid( detail ) then return end

        detail:SetModel( toSpawn )

    elseif IsValid( toSpawn ) then
        detail = toSpawn

    else
        return

    end

    detail:SetPos( parent:LocalToWorld( localPos ) )
    detail:SetAngles( parent:LocalToWorldAngles( localAng ) )
    detail:SetCollisionGroup( COLLISION_GROUP_WEAPON )
    detail:Spawn()
    detail:SetParent( parent )

    parent:CallOnRemove( "glee_detailFallOff_" .. detail:GetCreationID(), function( _, det )
        if not IsValid( det ) then return end
        if parent:Health() > 0 then SafeRemoveEntity( det ) return end  -- if parent is removed while still alive, delete it
        local thePos = det:GetPos()
        det:SetParent()
        det:SetPos( thePos )
        SafeRemoveEntityDelayed( det, 35 )
        terminator_Extras.SmartSleepEntity( det, 3 )
    end, detail )

    return detail

end
