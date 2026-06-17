terminator_Extras = terminator_Extras or {}

local up = Vector( 0, 0, 1 )
local down = Vector( 0, 0, -1 )

function terminator_Extras.GleeFancySplode( pos, damage, radius, attacker, inflictor, nofx )

    util.BlastDamage( inflictor, attacker, pos, radius, damage )
    util.Decal( "FadingScorch", pos + up, pos + down * radius / 4, ent )

    if nofx then return end

    local contents = util.PointContents( pos )

    local explSound = "BaseExplosionEffect.Sound"
    if bit.band( contents, CONTENTS_WATER ) ~= 0 then
        explSound = "WaterExplosionEffect.Sound"

    end

    sound.Play( explSound, pos, 88, math.random( 95, 105 ) )

    local splode = EffectData()
    splode:SetOrigin( pos )
    splode:SetMagnitude( damage )
    splode:SetScale( radius )
    util.Effect( "Explosion", splode, nil, true )

end

-- Creates a prop_physics parented to `parent`, positioned/angled via local-space offsets.
-- On parent removal, the detail unparents, falls to the world, then is cleaned up.
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

    detail.glee_isGleeDetail = true
    detail.glee_gleeDetailParent = parent

    parent:CallOnRemove( "glee_detailFallOff_" .. detail:GetCreationID(), function( _, det )
        if not IsValid( det ) then return end
        if parent:Health() > 0 then SafeRemoveEntity( det ) return end  -- if parent is removed while still alive, delete it
        terminator_Extras.ParentedDetailFallOff( parent, det )

    end, detail )

    return detail

end

-- redirect uses to the parent
hook.Add( "PlayerUse", "glee_parentedDetailUseRedirect", function( ply, used )
    local parent = used.glee_gleeDetailParent
    if not IsValid( parent ) then return end

    parent:Use( ply, parent )

end )

hook.Add( "glee_PresserUsed", "glee_parentedDetailUseRedirect", function( ply, used )
    local parent = used.glee_gleeDetailParent
    if not IsValid( parent ) then return end

    parent:Use( ply, parent )

end )

function terminator_Extras.ParentedDetailFallOff( parent, detail )
    if not IsValid( parent ) or not IsValid( detail ) then return end
    local thePos = detail:GetPos()
    detail:SetParent()
    detail:SetPos( thePos )
    SafeRemoveEntityDelayed( detail, 35 )
    terminator_Extras.SmartSleepEntity( detail, 5 )

    detail.glee_isGleeDetail = nil
    detail.glee_gleeDetailParent = nil

end