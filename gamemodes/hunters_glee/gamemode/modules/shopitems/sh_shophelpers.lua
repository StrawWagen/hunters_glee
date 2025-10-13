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
function shopHelpers.loadoutConfirm( ply, Count )
    for _ = 0, Count do
        ply:EmitSound( gunCock, 60, math.random( 90, 110 ) )

    end
end

function shopHelpers.purchaseWeapon( purchaser, wepClass, ammoData )
    local ammoType = ammoData.ammoType
    local purchaseClips = ammoData.purchaseClips
    local resupplyClips = ammoData.resupplyClips

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

    GAMEMODE.shopHelpers.loadoutConfirm( purchaser, 2 )

end