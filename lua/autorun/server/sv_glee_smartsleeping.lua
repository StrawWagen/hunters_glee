terminator_Extras = terminator_Extras or {}

local IsValid = IsValid
local CurTime = CurTime

local nextPass = 0
local nextCleanup = 0
local slowEnoughToFreeze = 20^2

terminator_Extras.glee_smartSleep_toFreeze = terminator_Extras.glee_smartSleep_toFreeze or {}
terminator_Extras.glee_smartSleep_supportingTbls = terminator_Extras.glee_smartSleep_supportingTbls or {}

-- freeze inactive ents to reduce lag
-- eg guns, skulls
-- likely will majorly decrease lag on big glee sessions
-- call terminator_Extras.SmartSleepEntity( ent, checkinterval ) to add ent to system

local noNavTextures = {
    ["tools/toolsnodraw"] = true,
    ["halflife/black"] = true,
    ["tools/toolsblack"] = true,

}

local function handleSleep( ent, cur, lagging ) -- think func
    if not IsValid( ent ) then return end
    if not ent.glee_smartSleeping then return end
    if ent.glee_smartSleep_nextCheck > cur then return end

    if IsValid( ent:GetParent() ) then
        ent.glee_smartSleep_nextCheck = cur + ent.glee_smartSleep_interval * 2
        return

    end

    if ent:GetVelocity():LengthSqr() > slowEnoughToFreeze then
        ent.glee_smartSleep_nextCheck = cur + ent.glee_smartSleep_interval
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
        elseif tr.HitWorld and noNavTextures[tr.HitTexture] and not IsValid( navmesh.GetNavArea( ent:GetPos() ) ) then
            needsRemove = true

        end
        -- remove it!
        if needsRemove then
            SafeRemoveEntity( ent )
            --debugoverlay.Cross( ent:GetPos(), 20, 5, Color( 255, 0, 0 ), true )
            return

        end

        -- capture supporters before motion is disabled
        local supportingEnts
        local snapshot = obj:GetFrictionSnapshot()
        local supporterUnfrozen
        for _, data in pairs( snapshot ) do
            local otherEnt = data.Other:GetEntity()
            if not IsValid( otherEnt ) then continue end

            -- can fail for like hook shaped props, but bleh
            -- skip ents that are resting on top of us
            if data.ContactPoint.z > ent:WorldSpaceCenter().z then continue end

            local unfrozen = data.Other:IsMotionEnabled()
            supporterUnfrozen = supporterUnfrozen or unfrozen

            supportingEnts = supportingEnts or {}
            local dependDat = {
                ent = otherEnt,
                id = otherEnt:GetCreationID(),
            }
            table.insert( supportingEnts, dependDat )

        end

        if not lagging and supporterUnfrozen then return end

        -- freeze it
        obj:EnableMotion( false )
        ent.glee_smartSleep_nextCheck = cur + ent.glee_smartSleep_interval * 2
        --debugoverlay.Cross( ent:GetPos(), 10, 5, color_white, true )

        -- then save supportingEnts if there are any
        if not supportingEnts then return end

        local supportingTbls = terminator_Extras.glee_smartSleep_supportingTbls
        for _, dependDat in ipairs( supportingEnts ) do
            --debugoverlay.Line( ent:GetPos(), dependDat.ent:GetPos(), 5, color_white, true )
            local id = dependDat.id
            local dependEnt = dependDat.ent
            local supportTbl = supportingTbls[id]
            if not supportTbl then
                supportTbl = {
                    restingUpon = {},
                    ent = dependEnt,
                    pos = dependEnt:GetPos(),
                    ang = dependEnt:GetAngles(),
                    nextCheck = cur + 0.25,
                }
                supportingTbls[id] = supportTbl

            end
            supportTbl.restingUpon[ent] = true

        end
    else
        ent.glee_smartSleep_nextCheck = cur + ent.glee_smartSleep_interval * 2

    end
end

local function handleSupporterTbl( supportingTbl, disturbedId, cur )
    if supportingTbl.nextCheck > cur then return end

    local wake
    local supportEnt = supportingTbl.ent
    if not IsValid( supportingTbl.ent ) then
        wake = "inval"

    elseif supportEnt:GetPos() ~= supportingTbl.pos then
        wake = "pos"

    elseif supportEnt:GetAngles() ~= supportingTbl.ang then
        wake = "ang"

    end

    if not wake then supportingTbl.nextCheck = cur + math.Rand( 0.25, 0.5 ) return end

    --debugoverlay.Text( supportingTbl.pos, wake, 5, false )

    for supportedEnt, _ in pairs( supportingTbl.restingUpon ) do
        if not IsValid( supportedEnt ) then return end
        --debugoverlay.Line( supportingTbl.pos, supportedEnt:GetPos(), 5, Color( 255, 0, 0 ), true )
        hook.Run( "glee_smartsleep_unsupported", supportedEnt )
        supportedEnt.glee_smartSleep_nextCheck = CurTime() + math.Rand( 0.1, 1 )

    end

    terminator_Extras.glee_smartSleep_supportingTbls[disturbedId] = nil

end

hook.Add( "Think", "glee_dynamicfreezing_think", function() -- calls the thinker on all sleepy ents
    local cur = CurTime()
    if nextPass > cur then return end
    nextPass = cur + math.Rand( 0.1, 0.25 )

    local lagging
    if GAMEMODE.IsReallyHuntersGlee then
        lagging = GAMEMODE:IsLagging()

    end

    local toFreeze = terminator_Extras.glee_smartSleep_toFreeze

    for _, ent in ipairs( toFreeze ) do
        handleSleep( ent, cur, lagging )

    end


    local supportingTbls = terminator_Extras.glee_smartSleep_supportingTbls

    for disturbedId, supportingTbl in pairs( supportingTbls ) do
        handleSupporterTbl( supportingTbl, disturbedId, cur )

    end

    if nextCleanup > cur then return end
    nextCleanup = cur + 30

    local newToFreeze = {}

    for _, ent in ipairs( toFreeze ) do
        if IsValid( ent ) and ent.glee_smartSleeping then
            table.insert( newToFreeze, ent )

        end
    end

    terminator_Extras.glee_smartSleep_toFreeze = newToFreeze
    local newSupportingTbls = {}

    for id, supportTbl in pairs( supportingTbls ) do
        local anySupported
        for supportedEnt, _ in pairs( supportTbl.restingUpon ) do
            if IsValid( supportedEnt ) then
                anySupported = true

            else
                supportTbl.restingUpon[supportedEnt] = nil

            end
        end

        if anySupported then
            newSupportingTbls[id] = supportTbl

        end
    end

    terminator_Extras.glee_smartSleep_supportingTbls = newSupportingTbls

end )

local nextBreak = 0

hook.Add( "Think", "glee_dynamicfreezing_laggingthink", function() -- deal damage to random sleepers if the server is lagging
    local cur = CurTime()
    if nextBreak > cur then return end
    nextBreak = cur + 0.1

    local damage

    local bitLaggy
    local lagging
    if GAMEMODE.IsReallyHuntersGlee then
        local tickrate, threshold
        bitLaggy, tickrate, threshold = GAMEMODE:IsLagging()
        local threshLower = math.Clamp( threshold * 0.15, 2.5, 128 )
        lagging = tickrate < threshLower -- lower threshold
        lagType = "tickrate"
        damage = ( threshold - tickrate ) * 10

    end

    if not lagging then
        lagScale = physenv.GetLastSimulationTime() * 1000
        damage = lagScale * 20

        lagging = lagScale > math.random( 50, 100 )
        lagType = "lastSim"

    end
    if not lagging or bitLaggy then return end

    local toFreeze = terminator_Extras.glee_smartSleep_toFreeze
    local randomEnt = toFreeze[math.random( 1, #toFreeze )]
    if not IsValid( randomEnt ) then return end
    if IsValid( randomEnt:GetParent() ) then return end

    if bitLaggy then -- think about whether or not we should freeze this, NOW!
        randomEnt.glee_smartSleep_nextCheck = CurTime()
        return

    end

    randomEnt.glee_smartSleeping_dontWake = true

    -- damage the ent
    local dmg = DamageInfo()
    dmg:SetAttacker( game.GetWorld() )
    dmg:SetInflictor( game.GetWorld() )
    dmg:SetDamage( damage )
    dmg:SetDamageType( DMG_CRUSH )
    randomEnt:TakeDamageInfo( dmg )

    if not IsValid( randomEnt ) then return end

    randomEnt.glee_smartSleeping_dontWake = nil
    permaPrint( "GLEE: Really lagging, " .. lagType .. " damaging " .. tostring( randomEnt ) .. " for " .. damage .. " damage" )

    -- freeze the ent
    local entsObj = randomEnt:GetPhysicsObject()
    if not IsValid( entsObj ) then return end
    if not entsObj:IsMotionEnabled() then return end -- already frozen!
    entsObj:EnableMotion( false )

end )

function terminator_Extras.SmartSleepEntity( ent, interval )
    interval = interval or 10
    table.insert( terminator_Extras.glee_smartSleep_toFreeze, ent )
    ent.glee_smartSleeping = true
    ent.glee_smartSleep_interval = interval
    ent.glee_smartSleep_nextCheck = CurTime() + ent.glee_smartSleep_interval

end

local function unchainSleeper( sleeper ) -- wakes stuff up
    if not IsValid( sleeper ) then return end
    if not sleeper.glee_smartSleeping then return end
    if sleeper.huntersglee_breakablenails then return end

    local obj = sleeper:GetPhysicsObject()
    if not IsValid( obj ) then return end

    sleeper.glee_smartSleep_nextCheck = CurTime() + sleeper.glee_smartSleep_interval * 2
    obj:EnableMotion( true )
    obj:Wake()

    --debugoverlay.Cross( sleeper:GetPos(), 20, 5, color_white, true )

end

local function unchainSleeperLazy( sleeper )
    if not IsValid( sleeper ) then return end
    if not sleeper.glee_smartSleeping then return end
    local lastSimTime = physenv.GetLastSimulationTime() * 1000
    if lastSimTime > math.Rand( 1, 2 ) then return end
    unchainSleeper( sleeper )

end

function terminator_Extras.SmartSleepWakeEntity( sleeper )
    unchainSleeperLazy( sleeper )

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

hook.Add( "RappelDrag", "glee_unchainsleepers", function( dragged )
    unchainSleeper( dragged )

end )

hook.Add( "glee_OnEscapeeWindPushed", "glee_unchainsleepers", function( pushed )
    unchainSleeperLazy( pushed )

end )

hook.Add( "glee_smartsleep_unsupported", "glee_unchainsleepers", function( pushed )
    unchainSleeperLazy( pushed )

end )

local maxDamaged = 10
local damagedCount = 0
local name = "glee_sleeper_blastdamageratelimit"

-- dont unchain entire stacks of stuff, do it slowly!
hook.Add( "EntityTakeDamage", "glee_unchainsleepers", function( damaged, info )
    if not damaged.glee_smartSleeping then return end
    if damaged.glee_smartSleeping_dontWake then return end
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
    unchainSleeperLazy( damaged )

end )

hook.Add( "glee_shover_preshove", "glee_unchainsleepers", function( shoved )
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
        if ent.glee_smartSleeping then return end
        local class = ent:GetClass()
        if ent:IsWeapon() or fastSleepClasses[class] then
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
    if gmod.GetGamemode().IsReallyHuntersGlee then
        setupOnCreateHook()

    end
end )

local theGamemode = gmod.GetGamemode()

-- autorefresh
if theGamemode and theGamemode.IsReallyHuntersGlee then
    setupOnCreateHook()

end
