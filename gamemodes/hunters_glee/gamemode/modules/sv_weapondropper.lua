local function setDropWeapons( ply, attacker, _ )
    for _, wep in pairs( ply:GetWeapons() ) do

        if not ply:CanDropWeaponKeepAmmo( wep ) then continue end

        local newWep = ply:DropWeaponKeepAmmo( wep )

        local wepWeight = 0
        if attacker.GetWeightOfWeapon then
            wepWeight = attacker:GetWeightOfWeapon( wep )

        end

        timer.Simple( math.random( 240, 280 ) + wepWeight * 40, function()
            if not IsValid( newWep ) then return end
            if IsValid( newWep:GetOwner() ) or IsValid( newWep:GetParent() ) then return end

            SafeRemoveEntity( newWep )

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

local plyMeta = FindMetaTable( "Player" )

function plyMeta:CanDropWeaponKeepAmmo( wep )
    if not IsValid( wep ) then return end
    if wep.ShouldDropOnDie and wep:ShouldDropOnDie() == false then return end

    return true

end

function plyMeta:DropActiveWeaponKeepAmmo()
    local wep = self:GetActiveWeapon()
    if not self:CanDropWeaponKeepAmmo( wep ) then return end
    self:DropWeaponKeepAmmo( wep )

end

function plyMeta:DropWeaponKeepAmmo( wep )
    local newWep = wep
    self:DropWeapon( wep )
    newWep.glee_ammoInside = {}
    local primaryAmmoType = wep:GetPrimaryAmmoType()

    if primaryAmmoType and self:GetAmmoCount( primaryAmmoType ) > 0 then
        local count = self:GetAmmoCount( primaryAmmoType )
        newWep.glee_ammoInside.primary = {}
        newWep.glee_ammoInside.primary.type = primaryAmmoType
        newWep.glee_ammoInside.primary.count = count
        self:RemoveAmmo( count, primaryAmmoType )

    end
    local secondaryAmmoType = wep:GetSecondaryAmmoType()

    if secondaryAmmoType and self:GetAmmoCount( secondaryAmmoType ) > 0 then
        local count = self:GetAmmoCount( secondaryAmmoType )
        newWep.glee_ammoInside.secondary = {}
        newWep.glee_ammoInside.secondary.type = secondaryAmmoType
        newWep.glee_ammoInside.secondary.count = count
        self:RemoveAmmo( count, secondaryAmmoType )

    end

    newWep:SetCollisionGroup( COLLISION_GROUP_WEAPON )
    local forceDir = self:GetAimVector()

    timer.Simple( 0, function()
        if not IsValid( newWep ) then return end
        if not IsValid( self ) then return end

        local newWepObj = newWep:GetPhysicsObject()
        if not newWepObj or not newWepObj.IsValid or not newWepObj:IsValid() then return end
        newWepObj:ApplyForceCenter( forceDir * newWepObj:GetMass() * math.random( 150, 300 ) )

    end )

    return newWep

end