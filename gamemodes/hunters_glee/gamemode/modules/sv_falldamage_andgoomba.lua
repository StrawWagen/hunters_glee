
local falldamageDivisor = 15 -- how much damage per speed falling

-- fall on breakable stuff to reduce fall damage!
function GM:GetFallDamage( faller, speed )
    local damage = speed / falldamageDivisor

    local fallersHealth = faller:Health()
    local maxDamage = fallersHealth * 4 -- they only have this much "mass" to deal damage with
    damage = math.min( damage, maxDamage )

    local groundEnt = faller:GetGroundEntity()

    if IsValid( groundEnt ) then
        local healthBefore = groundEnt:Health()

        local goombaDamageScale
        if healthBefore > fallersHealth then
            -- we're landing on something stronger than us, so it takes less damage from us
            goombaDamageScale = 0.45

        else
            -- landing on something weaker than us, we can break it easier
            goombaDamageScale = 0.9

        end

        local goombaDamage = damage * goombaDamageScale

        -- crush it!
        local dmgInfo = DamageInfo()
        dmgInfo:SetDamage( goombaDamage )
        dmgInfo:SetAttacker( faller )
        dmgInfo:SetInflictor( faller )
        dmgInfo:SetDamageType( bit.bor( DMG_CRUSH, DMG_FALL ) )
        dmgInfo:SetDamageForce( faller:GetVelocity() * 10 )
        dmgInfo:SetDamagePosition( faller:GetPos() )
        groundEnt:TakeDamageInfo( dmgInfo )

        local healthAfter = math.max( 0, groundEnt:Health() )
        if healthAfter < healthBefore then
            local absorbed = healthBefore - healthAfter

            absorbed = absorbed
            damage = math.max( 0, damage - absorbed )

        end
    end

    -- allow other hooks to modify damage
    local newDamage = hook.Run( "glee_getfalldamage", faller, speed, damage )
    if newDamage then
        return newDamage

    end

    return damage

end