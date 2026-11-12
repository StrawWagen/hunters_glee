
-- hands damage to whoever is to blame for it
-- a blamed attacker or inflictor that's gone becomes the world, so the death still reads as caused by something
function GM:ApplyDamageBlame( dmg, attacker, inflictor )
    if not IsValid( attacker ) then attacker = game.GetWorld() end
    dmg:SetAttacker( attacker )

    if not inflictor then return end
    if not IsValid( inflictor ) then inflictor = game.GetWorld() end
    dmg:SetInflictor( inflictor )

end
