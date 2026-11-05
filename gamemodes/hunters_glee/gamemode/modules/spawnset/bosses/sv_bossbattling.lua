
-- a boss fight is the whole round, so the cleanup that removes boring hunters leaves a battling boss alone
-- see the stale, wrong navmesh group, and lag removals

-- every kill, and every hit traded with a player, keeps a boss battling for this long
local battleMemory = 60 * 10

function GM:MarkBossAsBattling( ent )
    if not self:IsActiveBoss( ent ) then return end
    ent.glee_BossLastFoughtTime = CurTime()

end

function GM:IsThisABattlingBoss( ent )
    if not self:IsActiveBoss( ent ) then return false end

    local lastFought = ent.glee_BossLastFoughtTime
    if lastFought and lastFought + battleMemory > CurTime() then return true end

    local enemy
    if ent.GetEnemy then
        enemy = ent:GetEnemy()

    elseif ent.GetTarget then
        enemy = ent:GetTarget()

    end
    return IsValid( enemy ) and enemy.isTerminatorHunterChummy ~= ent.isTerminatorHunterChummy

end

-- the boss, or the boss's projectile
local function bossBehind( ent )
    if not IsValid( ent ) then return end
    if GAMEMODE:IsActiveBoss( ent ) then return ent end

    local owner = ent:GetOwner()
    if IsValid( owner ) and GAMEMODE:IsActiveBoss( owner ) then return owner end

end

-- kills are marked by the spawner's PlayerDeath hook, it also credits bosses that kill without dealing damage
hook.Add( "PostEntityTakeDamage", "glee_bossbattling_damage", function( target, dmg )
    if target:IsPlayer() then
        local boss = bossBehind( dmg:GetAttacker() ) or bossBehind( dmg:GetInflictor() )
        if boss then
            GAMEMODE:MarkBossAsBattling( boss )

        end
        return

    end

    if not GAMEMODE:IsActiveBoss( target ) then return end

    local attacker = dmg:GetAttacker()
    if IsValid( attacker ) and attacker:IsPlayer() then
        GAMEMODE:MarkBossAsBattling( target )

    end
end )
