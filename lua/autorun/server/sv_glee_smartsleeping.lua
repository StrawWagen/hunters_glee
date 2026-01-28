terminator_Extras = terminator_Extras or {}

local IsValid = IsValid
local CurTime = CurTime

local nextPass = 0
local nextCleanup = 0
local toFreeze = {}
local slowEnoughToFreeze = 20^2

-- freeze inactive ents to reduce lag
-- eg guns, skulls
-- likely will majorly decrease lag on big glee sessions
-- call terminator_Extras.SmartSleepEntity( ent, checkinterval ) to add ent to system

local noNavTextures = {
    ["tools/toolsnodraw"] = true,
    ["halflife/black"] = true,
    ["tools/toolsblack"] = true,

}

local function handleSleep( ent, curTime ) -- think func
    if not IsValid( ent ) then return end
    if not ent.glee_issmartsleeping then return end
    if ent.glee_nextsmartsleepcheck > curTime then return end

    if IsValid( ent:GetParent() ) then
        ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval * 2
        return

    end

    if ent:GetVelocity():LengthSqr() > slowEnoughToFreeze then
        ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval
        return

    end

    if ent.huntersglee_breakablenails then return end

    local obj = ent:GetPhysicsObject()
    if IsValid( obj ) and obj:IsMotionEnabled() then
        local tr = terminator_Extras.getFloorTr( ent:GetPos() )
        local needsRemove
        if tr.HitSky then -- fell into the void!
            needsRemove = true

        -- if it landed on one of these, and there's no navarea nearby, remove it
        elseif tr.HitWorld and noNavTextures[ tr.HitTexture ] and not IsValid( navmesh.GetNavArea( ent:GetPos() ) ) then
            needsRemove = true

        end
        if needsRemove then
            SafeRemoveEntity( ent )
            --debugoverlay.Cross( ent:GetPos(), 20, 5, Color( 255, 0, 0 ), true )

        else
            obj:EnableMotion( false )
            ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval * 2
            --debugoverlay.Cross( ent:GetPos(), 10, 5, color_white, true )

        end
    else
        ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval * 2

    end
end

hook.Add( "Think", "glee_dynamicfreezing_think", function() -- calls the thinker on all sleepy ents
    local curTime = CurTime()
    if nextPass > curTime then return end
    nextPass = curTime + 1

    for _, ent in ipairs( toFreeze ) do
        handleSleep( ent, curTime )

    end

    if nextCleanup > curTime then return end
    nextCleanup = curTime + 30

    local newToFreeze = {}

    for _, ent in ipairs( toFreeze ) do
        if IsValid( ent ) and ent.glee_issmartsleeping then
            table.insert( newToFreeze, ent )

        end
    end

    toFreeze = newToFreeze

end )

local nextBreak = 0

hook.Add( "Think", "glee_dynamicfreezing_laggingthink", function() -- deal damage to random sleepers if the server is lagging
    local curTime = CurTime()
    if nextBreak > curTime then return end
    nextBreak = curTime + 1

    local lagScale = physenv.GetLastSimulationTime() * 1000

    local lagging = lagScale > 100
    if not lagging then return end

    local randomFrozenEnt = toFreeze[ math.random( 1, #toFreeze ) ]
    if not IsValid( randomFrozenEnt ) then return end

    damaged.glee_smartsleepingdontwake = true

    local dmg = DamageInfo()
    dmg:SetAttacker( game.GetWorld() )
    dmg:SetInflictor( game.GetWorld() )
    dmg:SetDamage( lagScale * 2 )
    dmg:SetDamageType( DMG_CRUSH )
    randomFrozenEnt:TakeDamageInfo( dmg )

    damaged.glee_smartsleepingdontwake = nil

end )

terminator_Extras.SmartSleepEntity = function( ent, interval )
    interval = interval or 10
    table.insert( toFreeze, ent )
    ent.glee_issmartsleeping = true
    ent.glee_smartsleepinterval = interval
    ent.glee_nextsmartsleepcheck = CurTime() + ent.glee_smartsleepinterval

end

local function unchainSleeper( sleeper ) -- wakes stuff up
    if not IsValid( sleeper ) then return end
    if not sleeper.glee_issmartsleeping then return end
    if sleeper.huntersglee_breakablenails then return end

    local obj = sleeper:GetPhysicsObject()
    if not IsValid( obj ) then return end

    sleeper.glee_nextsmartsleepcheck = CurTime() + sleeper.glee_smartsleepinterval * 2
    obj:EnableMotion( true )
    --debugoverlay.Cross( sleeper:GetPos(), 20, 5, color_white, true )

end

hook.Add( "GravGunPickupAllowed", "glee_unchainsleepers", function( _, pickedUp )
    unchainSleeper( pickedUp )

end )

hook.Add( "AllowPlayerPickup", "glee_unchainsleepers", function( _, pickedUp )
    unchainSleeper( pickedUp )

end )

hook.Add( "WeaponEquip", "glee_unchainsleepers", function( pickedUp )
    unchainSleeper( pickedUp )

end )

hook.Add( "PlayerUse", "glee_unchainsleepers", function( _, used )
    unchainSleeper( used )

end )

local maxDamaged = 8
local damagedCount = 0
local name = "glee_sleeper_blastdamageratelimit"

-- dont unchain entire stacks of stuff, do it slowly!
hook.Add( "EntityTakeDamage", "glee_unchainsleepers", function( damaged, info )
    if not damaged.glee_issmartsleeping then return end
    if damaged.glee_smartsleepingdontwake then return end
    if info:GetDamage() <= 1 then return end
    damagedCount = damagedCount + 1
    if damagedCount >= maxDamaged then
        if timer.Exists( name ) then
            timer.Remove( name )

        end
        timer.Create( name, 0.5, 0, function()
            damagedCount = 0

        end )
        return
    end
    unchainSleeper( damaged )

end )

hook.Add( "glee_shover_shove", "glee_unchainsleepers", function( shoved )
    unchainSleeper( shoved )

end )

local propsInMap = 0
local wepGibCount = 0
hook.Add( "PreCleanupMap", "glee_smartsleep_resetpropcount", function()
    propsInMap = 0
    wepGibCount = 0

end )

local fastSleepClasses = {
    gib = true,
    npc_satchel = true,
    item_healthvial = true,

}

local function setupOnCreateHook()
    hook.Add( "OnEntityCreated", "glee_smartsleeping_detect", function( ent )
        if not IsValid( ent ) then return end
        if ent.glee_issmartsleeping then return end
        local class = ent:GetClass()
        if ent:IsWeapon() or fastSleepClasses[ class ] then
            wepGibCount = wepGibCount + 1
            local sleepTime = 30
            -- map with npcs dropping weapons?
            if wepGibCount > 80 then
                sleepTime = 2

            elseif wepGibCount > 40 then
                sleepTime = 10

            end
            terminator_Extras.SmartSleepEntity( ent, sleepTime )
            return

        end
        if class == "prop_physics" then
            propsInMap = propsInMap + 1
            if propsInMap < 50 then return end

            timer.Simple( 0, function()
                if not IsValid( ent ) then return end

                local phys = ent:GetPhysicsObject()
                if not IsValid( phys ) then return end
                if phys:GetMass() >= 20 then return end

                if IsValid( ent:GetParent() ) then return end

                local radius = ent:GetModelRadius()
                if not radius or radius >= 25 then return end

                local nearSubstantialCount = 0
                local near = ents.FindInSphere( ent:GetPos(), radius * 3 )
                for _, curr in ipairs( near ) do
                    local obj = curr:GetPhysicsObject()
                    if IsValid( obj ) and obj:IsMotionEnabled() then
                        nearSubstantialCount = nearSubstantialCount + 1

                    end
                end
                if nearSubstantialCount <= 5 then return end

                terminator_Extras.SmartSleepEntity( ent, 20 )

            end )
        end
    end )
end

hook.Add( "InitPostEntity", "glee_setupsmartsleeping", function()
    if gmod.GetGamemode().ISHUNTERSGLEE then
        setupOnCreateHook()

    end
end )

local theGamemode = gmod.GetGamemode()

-- autorefresh
if theGamemode and theGamemode.ISHUNTERSGLEE then
    setupOnCreateHook()

end