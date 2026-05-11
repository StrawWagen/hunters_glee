
function GM:BlameForFallDamage( ply, attacker, inflictor )
    if not IsValid( ply ) then return end
    if not IsValid( attacker ) then return end
    if not IsValid( inflictor ) then return end

    ply.glee_fallDamageAttacker = attacker
    ply.glee_fallDamageInflictor = inflictor

end

hook.Add( "OnPlayerHitGround", "glee_resetfalldamageblame", function( ply )
    timer.Simple( 0, function()
        if not IsValid( ply ) then return end
        ply.glee_fallDamageAttacker = nil
        ply.glee_fallDamageInflictor = nil

    end )
end )


hook.Add( "EntityTakeDamage", "glee_blamefalldamage", function( target, dmg )
    local attacker = target.glee_fallDamageAttacker
    if not IsValid( attacker ) then return end
    if not dmg:IsFallDamage() then return end

    dmg:SetAttacker( attacker )

    local inflictor = target.glee_fallDamageInflictor
    if not IsValid( inflictor ) then return end
    dmg:SetInflictor( inflictor )

end )
