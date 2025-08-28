-- maps that spawn players high up....
local hasGrace = {}
hook.Add( "PlayerSpawn", "glee_firstfallgrace", function( ply )
    hasGrace[ply] = true

end )

hook.Add( "OnPlayerHitGround", "glee_firstfallgrace", function( ply )
    if not hasGrace[ply] then return end
    timer.Simple( 0, function()
        hasGrace[ply] = nil

    end )
end )

hook.Add( "EntityTakeDamage", "glee_firstfallgrace", function( victim, dmg )
    if not dmg:IsFallDamage() then return end
    if not hasGrace[victim] then return end

    local maxDamage = victim:Health() + -1
    if dmg:GetDamage() < maxDamage then return end
    dmg:SetDamage( maxDamage )
    GAMEMODE:GivePanic( victim, maxDamage )

end )
