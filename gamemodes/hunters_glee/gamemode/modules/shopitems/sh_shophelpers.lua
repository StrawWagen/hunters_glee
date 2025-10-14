local GM = GM or GAMEMODE

local shopHelpers = {}
GM.shopHelpers = shopHelpers

function shopHelpers.aliveCheck( purchaser )
    if purchaser:Health() <= 0 then return false, "You must be alive to purchase this." end
    return true, ""

end

function shopHelpers.undeadCheck( purchaser )
    if purchaser:Health() > 0 then return false, "You must be dead to purchase this." end
    return true, ""

end

local gunCock = Sound( "items/ammo_pickup.wav" )
function shopHelpers.loadoutConfirm( ply, count )
    for _ = 0, count do
        ply:EmitSound( gunCock, 60, math.random( 90, 110 ) )

    end
end

function shopHelpers.purchaseWeapon( purchaser, data )
    local wepClass = data.class
    local ammoType = data.ammoType
    local purchaseClips = data.purchaseClips
    local resupplyClips = data.resupplyClips

    local weapon = purchaser:GetWeapon( wepClass )

    if resupplyClips and IsValid( weapon ) then
        ammoType = ammoType or weapon:GetPrimaryAmmoType()

        local clipSize = weapon:GetMaxClip1()
        local ammoToGive = clipSize * resupplyClips
        purchaser:GiveAmmo( ammoToGive, ammoType, true )

    else
        weapon = purchaser:Give( wepClass )
        if purchaseClips and IsValid( weapon ) then
            ammoType = ammoType or weapon:GetPrimaryAmmoType()

            local clipSize = weapon:GetMaxClip1()
            local ammoToGive = clipSize * purchaseClips
            purchaser:GiveAmmo( ammoToGive, ammoType, true )

        end
    end

    local confirmSoundWeight = data.confirmSoundWeight
    if confirmSoundWeight then
        GAMEMODE.shopHelpers.loadoutConfirm( purchaser, confirmSoundWeight )

    end
end