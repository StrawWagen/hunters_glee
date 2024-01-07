local function setDropWeapons( ply, attacker, _ )
    for _, wep in pairs( ply:GetWeapons() ) do

        if not ply:CanDropWeaponKeepAmmo( wep ) then continue end

        local newWep = ply:DropWeaponKeepAmmo( wep )

        terminator_Extras.SmartSleepEntity( newWep, 20 )

    end
end

hook.Add( "DoPlayerDeath", "glee_dropper_dropweaponoverride", setDropWeapons )


local function checkAndRestoreWeapsAmmo( wep, ply )
    if not wep.glee_ammoInside then return end
    for _, ammoDat in pairs( wep.glee_ammoInside ) do
        if not istable( ammoDat ) then continue end
        if not ammoDat.count then continue end
        if not ammoDat.type then continue end
        ply:GiveAmmo( ammoDat.count, ammoDat.type )

    end

    local clips = wep.glee_ammoInside.clips
    if not isnumber( clips ) then return end
    if clips <= 0 then return end

    timer.Simple( 0, function()
        if not IsValid( wep ) then return end
        if not IsValid( ply ) then return end

        local wepsClipSize1 = wep:GetMaxClip1() * clips
        wepsClipSize1 = math.Round( wepsClipSize1 )

        local wepsAmmoType1 = wep:GetPrimaryAmmoType()

        if wepsAmmoType1 > -1 then
            ply:GiveAmmo( wepsClipSize1, wepsAmmoType1 )

        end


        local wepsClipSize2 = wep:GetMaxClip2() * clips
        wepsClipSize2 = math.Round( wepsClipSize2 )

        local wepsAmmoType2 = wep:GetPrimaryAmmoType()

        if wepsAmmoType2 > -1 then
            ply:GiveAmmo( wepsClipSize2, wepsAmmoType2 )

        end

        wep.glee_ammoInside.clips = 0


    end )
end

hook.Add( "WeaponEquip", "glee_restoreweapsammo", checkAndRestoreWeapsAmmo )


function GM:GiveWeaponClipsOfAmmo( wep, clips )
    if clips <= 0 then return end
    wep.glee_ammoInside = wep.glee_ammoInside or {}
    wep.glee_ammoInside.clips = clips

end

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