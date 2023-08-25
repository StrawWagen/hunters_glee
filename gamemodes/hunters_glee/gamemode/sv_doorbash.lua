-- THESE ARE FROM TERMINATOR FISTS
local function DoorHitSound( ent )
    ent:EmitSound( "ambient/materials/door_hit1.wav", 100, math.random( 80, 120 ) )
end
local function BreakSound( ent )
    local Snd = "physics/wood/wood_furniture_break" .. tostring( math.random( 1, 2 ) ) .. ".wav"
    ent:EmitSound( Snd, 110, math.random( 80, 90 ) )
end


local function MakeDoor( referencePos, ent, dmg )
    local vel = terminator_Extras.dirToPos( referencePos, ent:WorldSpaceCenter() ) * 18000
    pos = ent:GetPos()
    ang = ent:GetAngles()
    mdl = ent:GetModel()
    ski = ent:GetSkin()

    ent:SetKeyValue( "returndelay", -1 )
    ent:Fire( "Open" )

    local getRidOf = { ent }
    table.Add( getRidOf, ent:GetChildren() )
    for _, toRid in pairs( getRidOf ) do
        toRid:SetNotSolid( true )
        toRid:SetNoDraw( true )
    end
    prop = ents.Create( "prop_physics" )
    prop:SetPos( pos )
    prop:SetAngles( ang )
    prop:SetModel( mdl )
    prop:SetSkin( ski or 0 )
    prop:Spawn()
    prop:SetVelocity( vel )
    prop:GetPhysicsObject():ApplyForceOffset( vel, referencePos )
    prop:SetPhysicsAttacker( dmg:GetAttacker() or game.GetWorld() )
    DoorHitSound( prop )
    BreakSound( prop )

    prop.isBustedDoor = true
    prop.bustedDoorHp = 400

end

local function CanBashDoor( door )
    if door:GetClass() ~= "prop_door_rotating" then return nil end
    local nextCheck = door.nextDoorSmashValidityCheck or 0
    if nextCheck < CurTime() then
        door.nextDoorSmashValidityCheck = CurTime() + 2.5

        local center = door:WorldSpaceCenter()
        local forward = door:GetForward()
        local starOffset = forward * 25
        local endOffset  = forward * 2

        local traceDatF = {
            mask = MASK_SOLID_BRUSHONLY,
            start = center + starOffset,
            endpos = center + endOffset
        }

        local traceDatB = {
            mask = MASK_SOLID_BRUSHONLY,
            start = center + -starOffset,
            endpos = center + -endOffset
        }

        --debugoverlay.Line( center + starOffset, center + forward, 30, Color( 255, 255, 255 ), true )
        --debugoverlay.Line( center + -starOffset, center + -endOffset, 30, Color( 255, 255, 255 ), true )

        local traceBack = util.TraceLine( traceDatB )
        local traceFront = util.TraceLine( traceDatF )

        local canSmash = not traceBack.Hit and not traceFront.Hit
        door.doorCanSmashCached = canSmash
        return canSmash

    else
        return door.doorCanSmashCached
    end
end
-- END TRANSPLANTED CODE

hook.Add( "FindUseEntity", "huntersglee_dontusethedoorbashprops", function( user, used ) 
    if not used.isDoorDamageListener then return end
    return used.realDoor

end )

hook.Add( "PostCleanupMap", "huntersglee_makeallthedoorsbashable", function()
    for _, door in ipairs( ents.FindByClass( "prop_door_rotating" ) ) do
        local doorDamageListener = ents.Create( "prop_physics" )
        doorDamageListener.isDoorDamageListener = true
        doorDamageListener.terminatorIgnoreEnt = true

        doorDamageListener:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
        doorDamageListener:SetPos( door:WorldSpaceCenter() )
        doorDamageListener:SetOwner( door )
        doorDamageListener:SetParent( door )
        doorDamageListener:Spawn()

        doorDamageListener:SetNoDraw( true )
        doorDamageListener:SetCollisionGroup( COLLISION_GROUP_WORLD )

        door.doorDamageListener = doorDamageListener
        doorDamageListener.realDoor = door
        doorDamageListener.isDoorDamageListener = true

    end
end )


hook.Add( "EntityTakeDamage", "huntersglee_doorsexplode", function( target, dmg )
    if not target.isDoorDamageListener then return end
    local atkIsBot = dmg:GetAttacker():IsNextBot()
    if not dmg:IsExplosionDamage() and not atkIsBot then return end
    if dmg:GetDamage() < 60 and not atkIsBot then return end
    if not dmg:GetDamagePosition() then return end
    if not target.realDoor:IsSolid() then return end
    -- let nails do their thing
    if target.realDoor.huntersglee_breakablenails then return end
    if not CanBashDoor( target.realDoor ) then return end

    MakeDoor( dmg:GetDamagePosition(), target.realDoor, dmg )

end )