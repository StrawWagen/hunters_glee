
-- burn damage credits whoever lit the fire, not the flame
-- so guilt, summoner relief and the killfeed all see fire kills
--
--     ent:Ignite( 5, 0, attacker, inflictor ) -- naming the igniter is optional
--
-- Ignite takes no attacker, so every flame works out who lit it, first match wins
--   the attacker named in the Ignite call
--   the damage being dealt when the flame was made, this is how spreading fire inherits it
--   whoever hurt the burning entity just before or just after it caught
--
-- it all starts at the bottom of the file
-- flames are born in IGNITING, and their damage is handed out in DAMAGE CREDITING

local entMeta = FindMetaTable( "Entity" )
entMeta.glee_RawIgnite = entMeta.glee_RawIgnite or entMeta.Ignite

local recentAttackWindow = 0.5 -- seconds, longer catches more ignites, but blames whoever last hit someone for a map's fire


-- ---------------------------------------------------------------------------
-- FLAME FINDING
-- which entity a flame is burning, and which flame is burning an entity
-- ---------------------------------------------------------------------------

local function isFlame( ent )
    return IsValid( ent ) and ent:GetClass() == "entityflame"

end

local function flameTarget( flame )
    local target = flame.glee_burnTarget
    if IsValid( target ) then return target end

    target = flame:GetInternalVariable( "m_hEntAttached" )
    if not IsValid( target ) then return end

    flame.glee_burnTarget = target
    target.glee_burningFlame = flame
    return target

end

-- Ignite gets called every tick by some, eg ENT:Touch, so the search is the rare path
local function findFlameOn( target )
    if not target:IsOnFire() then return end

    local cached = target.glee_burningFlame
    if IsValid( cached ) and flameTarget( cached ) == target then return cached end

    for _, flame in ipairs( ents.FindByClass( "entityflame" ) ) do
        if flameTarget( flame ) == target then return flame end

    end
end


-- ---------------------------------------------------------------------------
-- DAMAGE ATTACKER FINDING
-- works out who lit each flame
-- a flame born mid damage belongs to that damage's attacker, otherwise to whoever hurt its target last
-- ---------------------------------------------------------------------------

-- damage events in progress, innermost last
-- entries are dropped by tick too, a blocked event may never reach PostEntityTakeDamage
local damageStack = {}

local function currentDamage()
    local now = engine.TickCount()
    local top = damageStack[#damageStack]
    while top and top.tick ~= now do
        damageStack[#damageStack] = nil
        top = damageStack[#damageStack]

    end
    return top

end

hook.Add( "EntityTakeDamage", "glee_blamedfire_damagestarted", function( target, dmg )
    table.insert( damageStack, {
        target = target,
        attacker = dmg:GetAttacker(),
        inflictor = dmg:GetInflictor(),
        tick = engine.TickCount(),
    } )
end, HOOK_MONITOR_HIGH )

hook.Add( "PostEntityTakeDamage", "glee_blamedfire_damageended", function( target, dmg, took )
    local top = damageStack[#damageStack]
    if top and top.target == target then
        damageStack[#damageStack] = nil

    end

    if not took then return end

    local attacker = dmg:GetAttacker()
    if not IsValid( attacker ) then return end
    if attacker == target then return end
    -- burn from a flame nobody's credited for still names the flame, inferring from that loops forever
    if isFlame( attacker ) then return end

    target.glee_lastAttacker = attacker
    target.glee_lastAttackInflictor = dmg:GetInflictor()
    target.glee_lastAttackTime = CurTime()

end )


-- who lit each flame, worked out when it's lit, and guessed at later if nobody was known

local flameCredit -- spreading fire asks the flame it came from, see below

local function setFlameCredit( flame, attacker, inflictor )
    -- spreading fire, the new flame was lit by an old one
    -- only the attacker carries over, spread fire is just fire, not the crowbar that started it
    if isFlame( attacker ) then
        attacker = flameCredit( attacker )
        inflictor = nil

    end
    if not attacker then return end

    flame.glee_burnAttacker = attacker
    flame.glee_burnInflictor = inflictor
    flame.glee_inferringCredit = nil

end

local function inferFlameCredit( flame )
    local target = flameTarget( flame )
    if not IsValid( target ) then return end

    local attackTime = target.glee_lastAttackTime
    if not attackTime then return end

    -- either side of the ignite, some hit then ignite (flares), others ignite then hit (gland arcs)
    if math.abs( attackTime - flame.glee_igniteTime ) > recentAttackWindow then return end

    setFlameCredit( flame, target.glee_lastAttacker, target.glee_lastAttackInflictor )

end

-- who to credit for this flame's damage, nil when nobody is known
function flameCredit( flame )
    if flame.glee_inferringCredit then
        -- past the window no attack can match, stop looking
        if CurTime() > flame.glee_igniteTime + recentAttackWindow then
            flame.glee_inferringCredit = nil

        end
        inferFlameCredit( flame )

    end
    return flame.glee_burnAttacker, flame.glee_burnInflictor

end

-- a flame was just lit, or lit again
-- a guess never erases a credit the flame already has, only a found igniter replaces it
local function creditIgnite( flame, namedAttacker, namedInflictor )
    flame.glee_igniteTime = CurTime()

    if namedAttacker then
        setFlameCredit( flame, namedAttacker, namedInflictor )
        return

    end

    local damage = currentDamage()
    if damage then
        setFlameCredit( flame, damage.attacker, damage.inflictor )
        return

    end

    flame.glee_inferringCredit = true

end


-- ---------------------------------------------------------------------------
-- IGNITING
-- where every flame starts, and gets its credit
-- ---------------------------------------------------------------------------

local pendingIgnite -- set while the Ignite below runs, so the flame it makes knows its target

-- every Lua Ignite comes through here, so it can name an igniter, and tell the new flame what it's on
function entMeta:Ignite( length, radius, attacker, inflictor )
    local pending = { target = self, attacker = attacker, inflictor = inflictor }
    local outerPending = pendingIgnite
    pendingIgnite = pending

    self:glee_RawIgnite( length, radius )

    pendingIgnite = outerPending

    if pending.flame then return end

    -- no new flame, it was already burning
    local flame = findFlameOn( self )
    if not flame then return end

    creditIgnite( flame, attacker, inflictor )

end

do
    local getClass = entMeta.GetClass

    -- every flame is born here, even ones the Ignite above never sees, like the engine's own
    hook.Add( "OnEntityCreated", "glee_blamedfire_flameborn", function( ent )
        if getClass( ent ) ~= "entityflame" then return end

        local pending = pendingIgnite
        if pending and not pending.flame then
            pending.flame = ent
            ent.glee_burnTarget = pending.target
            pending.target.glee_burningFlame = ent
            creditIgnite( ent, pending.attacker, pending.inflictor )
            return

        end

        creditIgnite( ent )

    end )
end

-- ---------------------------------------------------------------------------
-- DAMAGE CREDITING
-- burn damage from a flame is handed to whoever lit it
-- ---------------------------------------------------------------------------

hook.Add( "EntityTakeDamage", "glee_blamedfire", function( _target, dmg )
    if not dmg:IsDamageType( DMG_BURN ) then return end

    local flame = dmg:GetInflictor()
    if not isFlame( flame ) then
        flame = dmg:GetAttacker()
        if not isFlame( flame ) then return end

    end

    local attacker, inflictor = flameCredit( flame )
    if not IsValid( attacker ) then return end -- nobody known, or the igniter left

    -- keep the flame as the inflictor when the igniter's is gone, it still reads as fire
    if not IsValid( inflictor ) then inflictor = nil end
    GAMEMODE:ApplyDamageBlame( dmg, attacker, inflictor )

end, HOOK_HIGH )
