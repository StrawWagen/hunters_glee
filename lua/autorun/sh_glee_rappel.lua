-- local table for fast comparison
local rappellers = {}

sound.Add( {
    name = "Glee_Rappel.RopeAttach",
    channel = CHAN_WEAPON,
    volume = 1.0,
    level = 75,
    sound = {
        "npc/combine_soldier/zipline_clip1.wav",
        "npc/combine_soldier/zipline_clip2.wav",
    }
} )

glee_RappelSettings = {
    ropeAttachSound = "Glee_Rappel.RopeAttach",
    ropeDropSound = "weapons/tripwire/ropeshoot.wav",
    ropeCutSound = "physics/surfaces/tile_impact_bullet1.wav",
    descendSpeed = 100,
    ascendSpeed = 100,
    springRate = 25,
    ropeSnapOffset = 400,
    shouldSnap = true,
    heliOffsets = {},
    boardDistance = 45,
    ropeDropFromVehicleLength = 700,
    ropeUseHitboxWidth = 128,
    ropeUseAimTolerance = 100,
    rappelingFriction = 0.5,
}

local function getRappelAnchorPos( rappeller )
    local rappelSourceEntity = rappeller:GetNWEntity( "glee_RappelSourceEnt", NULL )
    local rappelOffsetFromSource = rappeller:GetNWVector( "glee_RappelSourceOffset", nil )
    if not IsValid( rappelSourceEntity ) or rappelSourceEntity:IsWorld() then
        return rappelOffsetFromSource

    end
    return rappelSourceEntity:LocalToWorld( rappelOffsetFromSource ), rappelSourceEntity

end

local up5 = Vector( 0, 0, 5 )

local function moveHook( ply, moveData )
    if CLIENT and not ply:GetNWBool( "glee_IsRappelling", false ) then return end
    if SERVER and not rappellers[ply] then return end

    local anchorPos, anchor = getRappelAnchorPos( ply )
    if not anchorPos then return end

    local toAnchor = anchorPos - ply:GetPos()
    local dist = toAnchor:Length()

    local ropeLength = ply:GetNWFloat( "glee_RappelRopeLength", dist )

    if moveData:KeyDown( IN_JUMP ) then
        local tickInterval = engine.TickInterval()
        ropeLength = math.max( ropeLength - glee_RappelSettings.ascendSpeed * tickInterval, 25 )

    elseif moveData:KeyDown( IN_DUCK ) then
        local tickInterval = engine.TickInterval()
        ropeLength = ropeLength + glee_RappelSettings.descendSpeed * tickInterval

    end

    if SERVER then
        ply:SetNWFloat( "glee_RappelRopeLength", ropeLength )

    end

    -- pull them until they're within the ropeLength
    if dist > ropeLength and dist > 10 then
        local pullDir = toAnchor / dist
        local vel = moveData:GetVelocity()

        -- Cancel velocity moving away from anchor (rope can't push)
        local awayVel = vel:Dot( -pullDir )
        if awayVel > 0 then
            vel = vel + pullDir * awayVel

        end

        -- Spring force to converge overshoot back to rope length, capped to avoid catapulting
        local springForce = math.min( ( dist - ropeLength ) * 20, glee_RappelSettings.springRate )
        vel = vel + pullDir * springForce

        moveData:SetVelocity( vel )

        -- snap ply off the ground
        if ply:OnGround() then
            moveData:SetOrigin( moveData:GetOrigin() + up5 )

        end

        -- pull on the anchor
        if IsValid( anchor ) then

            -- remove us from the Move hook, precaution
            timer.Simple( 0, function()
                if not IsValid( anchor ) then return end

                local anchorsObj = anchor:GetPhysicsObject()
                if not IsValid( anchorsObj ) then return end

                hook.Run( "RappelDrag", anchor )

                anchorsObj:ApplyForceOffset( -pullDir * springForce * 10, anchorPos )

            end )
        end
    end

    -- Horizontal friction: bleed off XY velocity while on the rope
    local frictVel = moveData:GetVelocity()
    local frictionMul = 1 - glee_RappelSettings.rappelingFriction * engine.TickInterval()
    frictVel.x = frictVel.x * frictionMul
    frictVel.y = frictVel.y * frictionMul
    moveData:SetVelocity( frictVel )

    if not glee_RappelSettings.shouldSnap then return end

    if not SERVER then return end

    local origin = moveData:GetOrigin()
    local distance = origin:Distance( anchorPos )
    if distance < ropeLength + glee_RappelSettings.ropeSnapOffset then return end

    hook.Run( "OnPlayerRappelRopeSnap", ply, ply.glee_RappelRope )
    ply:StopRapelling()

end

hook.Add( "Move", "glee_Rappel_Move", function( ... ) moveHook( ... ) end )

if SERVER then
    hook.Add( "OnPlayerStartRappellingTo", "glee_Rappel_CacheOnStartRappel", function( ply )
        rappellers[ply] = true
        rappellCount = table.Count( rappellers )

    end )
    hook.Add( "OnPlayerStopRappelling", "glee_Rappel_CacheOnStopRappel", function( ply )
        rappellers[ply] = nil
        rappellCount = table.Count( rappellers )

    end )

    -- DUCK + E to always cut rope
    hook.Add( "PlayerButtonDown", "glee_Rappel_OnPlayerButtonDown", function( ply, btn )
        if not rappellers[ply] then return end
        if not ply:KeyDown( IN_DUCK ) then return end
        if btn ~= KEY_E then return end

        hook.Run( "OnPlayerCutRappelRope", ply, ply.glee_RappelRope )
        ply:StopRapelling()
        ply:EmitSound( glee_RappelSettings.ropeCutSound, 70 )

    end )
end