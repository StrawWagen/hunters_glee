
-- Keyed max health. Every source owns its own entry, and max health is all of them combined.
--
-- ply:DoMaxHealthMul( "juggernaut", 5 )
-- ply:DoMaxHealthMul( "juggernaut", nil ) -- off again
--
-- Entries live on the player, so they survive death. Take yours off when you're done.
-- Max health is the playermodel's health plus every add, raised to the highest floor,
-- times every mul, then capped by the lowest cap.
-- The glee_ply_maxhealth hook runs last, for anything a key can't say.
-- GM:PlayerSpawn calls ply:UpdateMaxHealth, after the player class resets max health.

local plyMeta = FindMetaTable( "Player" )

local function getMods( ply )
    local mods = ply.glee_maxhealthmods
    if not mods then
        mods = { add = {}, floor = {}, mul = {}, cap = {} }
        ply.glee_maxhealthmods = mods

    end
    return mods

end

local function setMod( ply, kind, key, value )
    if value ~= nil and not isnumber( value ) then
        error( "GLEE: max health " .. kind .. " for key " .. tostring( key ) .. " must be a number or nil, got " .. type( value ), 3 )

    end

    getMods( ply )[kind][key] = value
    ply:UpdateMaxHealth( key )

end

--[[---------------------------------------------------------
    ply:DoMaxHealthAdd
    @desc Adds a flat amount onto the playermodel's health. All keys' adds are summed.
    @param key: Any table key identifying the source.
    @param amount: number, or nil to remove this key's entry.
    @return: None
--]]---------------------------------------------------------
function plyMeta:DoMaxHealthAdd( key, amount )
    setMod( self, "add", key, amount )

end

--[[---------------------------------------------------------
    ply:DoMaxHealthFloor
    @desc Raises max health to at least this, before muls. The highest floor wins.
        Applied after adds, so players already above it keep theirs.
    @param key: Any table key identifying the source.
    @param floor: number, or nil to remove this key's entry.
    @return: None
--]]---------------------------------------------------------
function plyMeta:DoMaxHealthFloor( key, floor )
    setMod( self, "floor", key, floor )

end

--[[---------------------------------------------------------
    ply:DoMaxHealthMul
    @desc Multiplies max health. All keys' muls are multiplied together.
    @param key: Any table key identifying the source.
    @param mul: number, or nil to remove this key's entry.
    @return: None
--]]---------------------------------------------------------
function plyMeta:DoMaxHealthMul( key, mul )
    setMod( self, "mul", key, mul )

end

--[[---------------------------------------------------------
    ply:DoMaxHealthCap
    @desc Caps max health, after everything else. The lowest cap wins.
    @param key: Any table key identifying the source.
    @param cap: number, or nil to remove this key's entry.
    @return: None
--]]---------------------------------------------------------
function plyMeta:DoMaxHealthCap( key, cap )
    setMod( self, "cap", key, cap )

end

local function errorMitt( err )
    ErrorNoHaltWithStack( err )

end

--[[---------------------------------------------------------
    ply:UpdateMaxHealth
    @desc Rebuilds max health from glee_BaseHealth, every key's entry, then the glee_ply_maxhealth hook.
        Health keeps its ratio to max health, so a player at half health stays at half.
        The hook runs as ( ply, adjust ), every listener gets the same adjust table, already holding the keys' work:
            maxHealth     base health with adds and floors applied
            maxHealthMul  every mul multiplied together, multiply it to stack
            maxMaxHealth  the lowest cap, or math.huge, the result is capped here
        Result is maxHealth * maxHealthMul, capped by maxMaxHealth.
        A listener erroring, or leaving a non-number behind, throws out every listener's work, but not the keys'.
    @param reason: Stored on ply.glee_LastSetMaxHealthReason, for debugging.
    @return: None
--]]---------------------------------------------------------
function plyMeta:UpdateMaxHealth( reason )
    local mods = getMods( self )

    local maxHealth = self:GetNW2Int( "glee_BaseHealth", 100 )
    for _, amount in pairs( mods.add ) do
        maxHealth = maxHealth + amount

    end
    for _, floor in pairs( mods.floor ) do
        maxHealth = math.max( maxHealth, floor )

    end

    local maxHealthMul = 1
    for _, mul in pairs( mods.mul ) do
        maxHealthMul = maxHealthMul * mul

    end

    local maxMaxHealth = math.huge
    for _, cap in pairs( mods.cap ) do
        maxMaxHealth = math.min( maxMaxHealth, cap )

    end

    local newMaxHealth = math.min( maxHealth * maxHealthMul, maxMaxHealth )

    local adjust = {
        maxHealth = maxHealth,
        maxHealthMul = maxHealthMul,
        maxMaxHealth = maxMaxHealth,
    }
    local noErrors = xpcall( hook.Run, errorMitt, "glee_ply_maxhealth", self, adjust )
    if not noErrors then
        permaPrint( "GLEE: !!!!!!!!!! glee_ply_maxhealth errored for " .. tostring( self ) .. "!!!!!!!!!!!" )

    elseif not isnumber( adjust.maxHealth ) or not isnumber( adjust.maxHealthMul ) or not isnumber( adjust.maxMaxHealth ) then
        permaPrint( "GLEE: !!!!!!!!!! glee_ply_maxhealth left a non-number for " .. tostring( self ) .. "!!!!!!!!!!!" )

    else
        newMaxHealth = math.min( adjust.maxHealth * adjust.maxHealthMul, adjust.maxMaxHealth )

    end

    newMaxHealth = math.max( math.Round( newMaxHealth ), 1 )

    local oldMaxHealth = self:GetMaxHealth()
    if newMaxHealth == oldMaxHealth then return end

    self:SetMaxHealth( newMaxHealth )
    self.glee_LastSetMaxHealthReason = reason

    -- dead players stay dead
    local health = self:Health()
    if health <= 0 then return end

    local ratio = health / math.max( oldMaxHealth, 1 )
    self:SetHealth( math.max( math.Round( newMaxHealth * ratio ), 1 ) )
    self.glee_LastSetHealthReason = reason

end
