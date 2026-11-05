-- what the gunship does to others, and what it takes from them
local gunship = terminator_Extras.glee_Gunship

-- its pulse gun, and its missiles, the missiles are env_explosions it owns
local damageMul = 4

local damageCfg = gunship.DamageCfg

-- call once, after Setup makes its state
function gunship.SetupStanding( npc )
    local state = npc.glee_GunshipState
    state.biggestHitTaken = 0
    state.spiteDamage = 0
    state.hurtSinceBombRun = false -- it only dodges rockets once they've proven they can hurt it
    state.nextHurtable = 0
    state.nextTauHalving = 0

    local maxHealth = gunship.BaseHealth + gunship.HealthPerPlayer * player.GetCount()
    npc:SetMaxHealth( maxHealth )
    npc:SetHealth( maxHealth )

    -- spawning counts as having just fired, so it's not owed missiles the moment it's over someone
    state.lastGunVolley = CurTime()

    -- it shoots through its own side, the combine hunters skip their friendly fire reduction for it
    npc.term_BypassFriendlyFire = true
    npc.isTerminatorHunterChummy = "combine"

end

-- the rescue heli's missiles blind fire, so they almost never land square on it, when one does it's a kill
local function heliMissileDirectHit( dmg )
    local inflictor = dmg:GetInflictor()
    if not IsValid( inflictor ) or inflictor:GetClass() ~= "glee_helimissile" then return false end
    return dmg:IsDamageType( DMG_DIRECT )

end

-- before its first hit, the floor's where it starts
local function healthFloor( npc, state )
    local sinceFirstHit = state.firstHurtTime and CurTime() - state.firstHurtTime or 0
    local fraction = damageCfg.startFloor * math.max( 1 - sinceFirstHit / damageCfg.minLife, 0 )
    return npc:GetMaxHealth() * fraction

end

local function floorTapered( npc, state, damage )
    local floor = healthFloor( npc, state )
    if floor <= 0 then return damage end

    -- the taper shrinks with the floor, so there's none left once minLife's up
    local aboveFloor = npc:Health() - floor
    local taperMul = math.Clamp( aboveFloor / ( floor * damageCfg.taperOfFloor ), 0, 1 )
    return math.max( math.min( damage * taperMul, aboveFloor ), 0 )

end

local function damageToTake( npc, state, rawDamage )
    if CurTime() < state.nextHurtable then return 0 end
    return floorTapered( npc, state, math.min( rawDamage, damageCfg.maxPerHit ) )

end

-- could the biggest hit it can take right now kill it, past the cap, and the health floor
function gunship.NextHitCouldKill( npc )
    local state = npc.glee_GunshipState
    return floorTapered( npc, state, damageCfg.maxPerHit ) >= npc:Health()

end

-- a fully charged tau cannon halves it, past the cap and the hit cooldown
-- it's got its own cooldown, or the shot's every pellet would halve it again
hook.Add( "glee_taucannon_overchargehit", "glee_gunship_tauhalving", function( npc )
    local state = npc.glee_GunshipState
    if not state then return end

    local cur = CurTime()
    if cur < state.nextTauHalving then return end
    state.nextTauHalving = cur + damageCfg.hitCooldown

    local damage = floorTapered( npc, state, npc:Health() / 2 )
    if damage <= 0 then return end

    npc:SetHealth( math.ceil( npc:Health() - damage ) )
    state.firstHurtTime = state.firstHurtTime or cur

end )

hook.Add( "EntityTakeDamage", "glee_gunship_damage", function( target, dmg )
    local attacker = dmg:GetAttacker()
    if IsValid( attacker ) and attacker.glee_GunshipState and attacker ~= target then
        dmg:ScaleDamage( damageMul )

    end

    local state = target.glee_GunshipState
    if not state then return end

    local health = target:Health()
    local rawDamage = dmg:GetDamage()
    local damage

    -- straight through the floor, and the engine only takes blast damage
    if heliMissileDirectHit( dmg ) then
        dmg:SetDamageType( DMG_BLAST )
        damage = health

    else
        damage = damageToTake( target, state, rawDamage )

    end

    -- the engine takes a fixed chunk of health per hit, whatever the damage, so we set its health up for that chunk
    -- a lethal hit, it's left with 1 so the chunk kills it, and the death's the engine's own
    -- otherwise it's full so the chunk can't, and PostEntityTakeDamage takes the real damage
    state.healthBeforeHit = health
    state.hitRawDamage = rawDamage
    state.hitDamage = damage

    if damage >= health then
        target:SetHealth( 1 )

    else
        target:SetHealth( target:GetMaxHealth() )

    end
end )

hook.Add( "PostEntityTakeDamage", "glee_gunship_realdamage", function( target, _dmg, took )
    local state = target.glee_GunshipState
    if not state then return end

    local before = state.healthBeforeHit
    if not before then return end
    state.healthBeforeHit = nil

    if target:Health() <= 0 then return end

    -- immune to it, bullets and the like, it still holds a grudge
    if not took then
        target:SetHealth( before )
        state.spiteDamage = state.spiteDamage + state.hitRawDamage
        return

    end

    local damage = state.hitDamage
    target:SetHealth( math.ceil( before - damage ) )
    state.spiteDamage = state.spiteDamage + math.max( state.hitRawDamage - damage, 0 )
    if damage <= 0 then return end

    local cur = CurTime()
    state.firstHurtTime = state.firstHurtTime or cur
    state.nextHurtable = cur + damageCfg.hitCooldown
    state.biggestHitTaken = math.max( state.biggestHitTaken, damage )
    state.hurtSinceBombRun = true

end )

-- when its pulse gun last fired, hit or miss
hook.Add( "EntityFireBullets", "glee_gunship_gunvolley", function( shooter )
    local state = shooter.glee_GunshipState
    if not state then return end
    state.lastGunVolley = CurTime()

end )

hook.Add( "OnNPCKilled", "glee_gunship_death", function( npc )
    if not npc.glee_GunshipState then return end
    npc:EmitSound( "NPC_CombineGunship.Pain", 150, 80, 1, CHAN_STATIC )

end )
