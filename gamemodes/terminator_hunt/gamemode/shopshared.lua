AddCSLuaFile( "shopshared.lua" )

include( "shopitems.lua" )


if not CLIENT then
    include( "sv_shophandler.lua" ) --not shared

end

-- shared functions
function GM:canPurchase( ply, toPurchase )
    local dat = GAMEMODE.shopItems[toPurchase]
    if not dat then return false end

    local frags = ply:Frags()
    local cost = dat.cost
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE and dat.markup then 
        cost = cost * dat.markup 
    end
    if frags < cost then return false end

    local currState = GAMEMODE:RoundState()
    local times = dat.purchaseTimes
    local goodTime = table.HasValue( times, currState )
    if not goodTime then return end 

    return true
end