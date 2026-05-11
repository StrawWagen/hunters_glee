
function GM:BlameForFallDamage( ply, attacker, inflictor )
    if not IsValid( ply ) then return end
    if not attacker or ( not IsValid( attacker ) and not attacker:IsWorld() ) then return end
    if not inflictor or ( not IsValid( inflictor ) and not inflictor:IsWorld() ) then return end

    ply.glee_fallDamageAttacker = attacker
    ply.glee_fallDamageInflictor = inflictor
    timer.Remove( "glee_resetfalldamageblame_" .. ply:EntIndex() )

end

hook.Add( "OnPlayerHitGround", "glee_resetfalldamageblame", function( ply )
    timer.Create( "glee_resetfalldamageblame_" .. ply:EntIndex(), 0, 1, function()
        if not IsValid( ply ) then return end
        ply.glee_fallDamageAttacker = nil
        ply.glee_fallDamageInflictor = nil

    end )
end )


hook.Add( "EntityTakeDamage", "glee_blamefalldamage", function( target, dmg )
    local attacker = target.glee_fallDamageAttacker
    if not attacker or ( not IsValid( attacker ) and not attacker:IsWorld() ) then return end
    if not dmg:IsFallDamage() then return end

    dmg:SetAttacker( attacker )

    local inflictor = target.glee_fallDamageInflictor
    if not inflictor or ( not IsValid( inflictor ) and not inflictor:IsWorld() ) then return end
    dmg:SetInflictor( inflictor )

end )
