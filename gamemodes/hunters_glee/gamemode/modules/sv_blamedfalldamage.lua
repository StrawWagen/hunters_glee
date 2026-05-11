
function GM:BlameForFallDamage( ply, attacker, inflictor )
    if not IsValid( ply ) then return end
    if not ply:IsPlayer() then return end
    if not attacker or ( not IsValid( attacker ) and not attacker:IsWorld() ) then return end
    if not inflictor or ( not IsValid( inflictor ) and not inflictor:IsWorld() ) then return end

    ply.glee_fallDamageAttacker = attacker
    ply.glee_fallDamageInflictor = inflictor
    timer.Remove( "glee_resetfalldamageblame_" .. ply:EntIndex() )

end

hook.Add( "OnPlayerHitGround", "glee_resetfalldamageblame", function( ply )
    if not ply.glee_fallDamageAttacker then return end

    timer.Create( "glee_resetfalldamageblame_" .. ply:EntIndex(), 0, 1, function()
        if not IsValid( ply ) then return end
        ply.glee_fallDamageAttacker = nil
        ply.glee_fallDamageInflictor = nil

    end )

    -- Run a hook so blame can reliably be re-applied (if needed).
    hook.Run( "glee_falldamageblame_hitground", ply, ply.glee_fallDamageAttacker, ply.glee_fallDamageInflictor )

end )


hook.Add( "EntityTakeDamage", "glee_blamefalldamage", function( target, dmg )
    local attacker = target.glee_fallDamageAttacker
    if not attacker then return end
    if not IsValid( attacker ) then attacker = game.GetWorld() end
    if not dmg:IsFallDamage() then return end

    dmg:SetAttacker( attacker )

    local inflictor = target.glee_fallDamageInflictor
    if not inflictor then return end
    if not IsValid( inflictor ) then inflictor = game.GetWorld() end
    dmg:SetInflictor( inflictor )

end, HOOK_HIGH )
