
hook.Add( "EntityTakeDamage", "huntersglee_doorsexplode", function( target, dmg )
    if not dmg:IsExplosionDamage() then return end
    if not dmg:GetDamagePosition() then return end

    -- let nails do their thing
    if target.huntersglee_breakablenails then return end

    -- already bashed
    if not target:IsSolid() then return end

    local targsClass = target:GetClass()
    if targsClass ~= "prop_door_rotating" then return end

    -- real fake door
    if not terminator_Extras.CanBashDoor( target ) then terminator_Extras.StrainSound( target ) return end

    local locked = target:GetInternalVariable( "m_bLocked" ) == true

    -- too weak?
    local damage = dmg:GetDamage()
    if damage < 40 then
        terminator_Extras.StrainSound( target )
        return

    end
    if damage < 80 then
        if locked then
            terminator_Extras.DoorHitSound( target )
            terminator_Extras.StrainSound( target )

        else
            terminator_Extras.DoorHitSound( target )
            terminator_Extras.OpenDoorQuicklyAwayFrom( target, dmg:GetInflictor() )

        end
        return

    end

    if locked then -- lock BREAK!
        terminator_Extras.EmitSparksFromDoorHandle( target )

    end

    terminator_Extras.DehingeDoor( dmg:GetAttacker(), target )

end )
