
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
    if dmg:GetDamage() < 60 and not atkIsBot then terminator_Extras.StrainSound( target ) return end
    if not dmg:GetDamagePosition() then return end
    if not target.realDoor:IsSolid() then return end
    -- let nails do their thing
    if target.realDoor.huntersglee_breakablenails then return end
    if not terminator_Extras.CanBashDoor( target.realDoor ) then return end

    terminator_Extras.DehingeDoor( dmg:GetAttacker(), target.realDoor )

end )

hook.Add( "GravGunPickupAllowed", "glee_dontgravgun_doordamagelisteners", function( _, gravgunned )
    if gravgunned.isDoorDamageListener then return false end

end )

hook.Add( "FindUseEntity", "huntersglee_dontusethedoorbashprops", function( user, used ) 
    if not used.isDoorDamageListener then return end
    return used.realDoor

end )