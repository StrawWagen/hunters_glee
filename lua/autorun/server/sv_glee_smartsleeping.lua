terminator_Extras = terminator_Extras or {}

local IsValid = IsValid
local CurTime = CurTime

local nextPass = 0
local nextCleanup = 0
local toFreeze = {}
local slowEnoughToFreeze = 10^2

-- freeze inactive ents to reduce lag
-- eg guns, skulls, crates
-- likely will majorly decrease lag on big glee sessions
-- call terminator_Extras.SmartSleepEntity( ent, checkinterval ) to add ent to system

hook.Add( "Think", "glee_dynamicfreezing_think", function()
    local curTime = CurTime()
    if nextPass > curTime then return end
    nextPass = curTime + 1

    for _, ent in ipairs( toFreeze ) do
        if IsValid( ent ) and ent.glee_issmartsleeping and ent.glee_nextsmartsleepcheck < curTime then
            if IsValid( ent:GetParent() ) then
                ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval * 4
                continue

            end
            ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval

            if ent:GetVelocity():LengthSqr() < slowEnoughToFreeze then
                local obj = ent:GetPhysicsObject()
                if obj:IsMotionEnabled() then
                    obj:EnableMotion( false )
                    ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval * 2

                else
                    ent.glee_nextsmartsleepcheck = curTime + ent.glee_smartsleepinterval * 4

                end
            end
        end
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

terminator_Extras.SmartSleepEntity = function( ent, interval )
    interval = interval or 10
    table.insert( toFreeze, ent )
    ent.glee_issmartsleeping = true
    ent.glee_smartsleepinterval = interval
    ent.glee_nextsmartsleepcheck = CurTime() + ent.glee_smartsleepinterval

end

local function unchainSleeper( sleeper )
    if not IsValid( sleeper ) then return end
    if not sleeper.glee_issmartsleeping then return end

    local obj = sleeper:GetPhysicsObject()
    if not IsValid( obj ) then return end
    if obj:IsMotionEnabled() then return end

    sleeper.glee_nextsmartsleepcheck = CurTime() + sleeper.glee_smartsleepinterval * 2
    obj:EnableMotion( true )

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

hook.Add( "EntityTakeDamage", "glee_unchainsleepers", function( damaged, info )
    if info:GetDamage() <= 1 then return end
    unchainSleeper( damaged )

end )

hook.Add( "glee_shover_shove", "glee_unchainsleepers", function( shoved )
    unchainSleeper( shoved )

end )

hook.Add( "InitPostEntity", "glee_setupsmartsleeping", function()
    if gmod.GetGamemode().ISHUNTERSGLEE then
        hook.Add( "OnEntityCreated", "glee_smartsleeping_detect", function( ent )
            if not IsValid( ent ) then return end
            if ent.glee_issmartsleeping then return end
            if ent:IsWeapon() or ent:GetClass() == "gib" then
                terminator_Extras.SmartSleepEntity( ent, 20 )

            end
        end )
    end
end )