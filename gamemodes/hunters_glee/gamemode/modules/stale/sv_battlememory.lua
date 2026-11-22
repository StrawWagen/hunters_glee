
-- Remembers which hunters have been fighting players
-- so the cleanups that remove boring hunters leave them alone
-- see the stale and wrong navmesh group removals

-- It goes by what the hunter does, not what it is.
-- Flying, krangled, other addons' bases, anything that trades hits with players counts.

-- a hunter remembers a fight for this many seconds per point of max health
-- the same leeway the stale cleanup gives a hunter without an enemy
local memoryPerMaxHealth = 0.5
-- a boss fight is the whole round, so bosses always get the longest memory
local bossMemory = 60 * 10

local function memoryOf( hunter )
    if GAMEMODE:IsActiveBoss( hunter ) then return bossMemory end
    return math.min( hunter:GetMaxHealth() * memoryPerMaxHealth, bossMemory )

end

--[[---------------------------------------------------------
    GM:MarkHunterAsBattling
    @desc Remembers that this hunter just fought a player. Does nothing for anything that isn't a hunter.
    @param hunter: The hunter.
    @return: None
--]]---------------------------------------------------------
function GM:MarkHunterAsBattling( hunter )
    if not hunter.glee_IsAHunter then return end
    hunter.glee_LastFoughtTime = CurTime()

end

--[[---------------------------------------------------------
    GM:IsHunterBattling
    @desc Is this hunter fighting, or did it fight a player recently?
    @param hunter: The hunter.
    @return: bool
--]]---------------------------------------------------------
function GM:IsHunterBattling( hunter )
    local lastFought = hunter.glee_LastFoughtTime
    if lastFought and lastFought + memoryOf( hunter ) > CurTime() then return true end

    local enemy
    if hunter.GetEnemy then
        enemy = hunter:GetEnemy()

    elseif hunter.GetTarget then
        enemy = hunter:GetTarget()

    end
    return IsValid( enemy ) and enemy.isTerminatorHunterChummy ~= hunter.isTerminatorHunterChummy

end

-- the hunter, or the hunter's projectile
local function hunterBehind( ent )
    if not IsValid( ent ) then return end
    if ent.glee_IsAHunter then return ent end

    local owner = ent:GetOwner()
    if IsValid( owner ) and owner.glee_IsAHunter then return owner end

end

-- kills are marked by the spawner's PlayerDeath hook, it also credits krangled hunters that kill without dealing damage
hook.Add( "PostEntityTakeDamage", "glee_battlememory_damage", function( target, dmg )
    if target:IsPlayer() then
        local hunter = hunterBehind( dmg:GetAttacker() ) or hunterBehind( dmg:GetInflictor() )
        if hunter then
            GAMEMODE:MarkHunterAsBattling( hunter )

        end
        return

    end

    if not target.glee_IsAHunter then return end

    local attacker = dmg:GetAttacker()
    if IsValid( attacker ) and attacker:IsPlayer() then
        GAMEMODE:MarkHunterAsBattling( target )

    end
end )
