local function setDropWeapons( ply, attacker, _ )
    for _, wep in pairs( ply:GetWeapons() ) do

        if not IsValid( wep ) then continue end
        if wep.ShouldDropOnDie and wep:ShouldDropOnDie() == false then continue end

        local oldWeapClass = wep:GetClass()
        local newWep = wep
        -- stupid bug
            ply:DropNamedWeapon( oldWeapClass )
        newWep.glee_ammoInside = {}
        local primaryAmmoType = wep:GetPrimaryAmmoType()

        if primaryAmmoType and ply:GetAmmoCount( primaryAmmoType ) > 0 then
            local count = ply:GetAmmoCount( primaryAmmoType )
            newWep.glee_ammoInside.primary = {}
            newWep.glee_ammoInside.primary.type = primaryAmmoType
            newWep.glee_ammoInside.primary.count = count
            ply:RemoveAmmo( count, primaryAmmoType )

        end
        local secondaryAmmoType = wep:GetSecondaryAmmoType()

        if secondaryAmmoType and ply:GetAmmoCount( secondaryAmmoType ) > 0 then
            local count = ply:GetAmmoCount( secondaryAmmoType )
            newWep.glee_ammoInside.secondary = {}
            newWep.glee_ammoInside.secondary.type = secondaryAmmoType
            newWep.glee_ammoInside.secondary.count = count
            ply:RemoveAmmo( count, secondaryAmmoType )

        end

        newWep:SetCollisionGroup( COLLISION_GROUP_WEAPON )
        local forceDir = ply:GetAimVector()

        timer.Simple( 0, function()
            if not IsValid( newWep ) then return end
            if not IsValid( ply ) then return end

            local newWepObj = newWep:GetPhysicsObject()
            if not newWepObj or not newWepObj.IsValid or not newWepObj:IsValid() then return end
            newWepObj:ApplyForceCenter( forceDir * newWepObj:GetMass() * math.random( 150, 300 ) )

        end )

        local wepWeight = 0
        if attacker.GetWeightOfWeapon then
            wepWeight = attacker:GetWeightOfWeapon( wep )

        end

        timer.Simple( math.random( 240, 280 ) + wepWeight * 40, function()
            if not IsValid( newWep ) then return end
            if IsValid( newWep:GetOwner() ) or IsValid( newWep:GetParent() ) then return end

        end )
    end
end

hook.Add( "DoPlayerDeath", "glee_dropper_dropweaponoverride", setDropWeapons )


local function checkAndRestoreWeapsAmmo( wep, ply )
    if not wep.glee_ammoInside then return end
    for _, ammoDat in pairs( wep.glee_ammoInside ) do
        if not ammoDat.count then continue end
        if not ammoDat.type then continue end
        ply:GiveAmmo( ammoDat.count, ammoDat.type )

    end
end

hook.Add( "WeaponEquip", "glee_restoreweapsammo", checkAndRestoreWeapsAmmo )