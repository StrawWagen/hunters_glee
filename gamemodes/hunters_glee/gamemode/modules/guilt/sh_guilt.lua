
-- TODO: IMPLIMENT GUILT EFFECTS

local PermaGuiltLevels = {
    NOT_GUILTY = 0,
    SLIGHTLY_GUILTY = 1,
    SOMEWHAT_GUILTY = 5,
    ALMOST_GUILTY = 10,
    GUILTY = 20,
    VERY_GUILTY = 35,
    EXTREMELY_GUILTY = 50,
}
GM.PermaGuiltLevels = PermaGuiltLevels

GM.PermaGuiltInfo = {
    [PermaGuiltLevels.NOT_GUILTY]  = {
        message = "Your conscience is clear.",
        color = Color( 200, 200, 200 ),
    },
    [PermaGuiltLevels.SLIGHTLY_GUILTY]  = {
        message = "Your conscience is still.. a bit clear...",
        color = Color( 210, 200, 120 ),
    },
    [PermaGuiltLevels.SOMEWHAT_GUILTY]  = {
        message = "You're a bit evil. But you are still forgiven.",
        color = Color( 210, 200, 120 ),
    },
    [PermaGuiltLevels.ALMOST_GUILTY]  = {
        message = "Things can't continue like this. You're almost evil.",
        color = Color( 215, 180, 0 ),
    },
    [PermaGuiltLevels.GUILTY]  = {
        message = "You're evil. Your access to divine avenues is limited.",
        color = Color( 220, 140,   0 ),
        divineCostMul = 1.5,
    },
    [PermaGuiltLevels.VERY_GUILTY] = {
        message = "You're very evil. Divine paths are almost out of your reach.",
        color = Color( 220,  50,   0 ),
        divineCostMul = 2.5,
    },
    [PermaGuiltLevels.EXTREMELY_GUILTY] = {
        message = "You're extremely evil. The divine ways are closed to you. You are always at one with the infernal powers.",
        color = Color( 200,   0,   0 ),
        divineItemsNotPurchaseable = true,
    },
}

function GM:GetPersistentGuilt( ply )
    local guiltInDays = ply:GetNWFloat( "glee_persistentguilt_days", 0 )
    return guiltInDays

end

function getGuiltLevel( guiltInDays )
    local guiltLevel = 0
    local guiltData
    for level, data in pairs( GAMEMODE.PermaGuiltInfo ) do
        if guiltInDays >= level and level > guiltLevel then
            guiltLevel = level
            guiltData = data

        end
    end

    return guiltLevel, guiltData

end

function GM:GetPlysGuiltLevel( ply )
    local guiltInDays = self:GetPersistentGuilt( ply )
    local old_cachedDays = ply.glee_cachedGuiltDays or 0
    if guiltInDays ~= old_cachedDays then
        local guiltLevel, guiltData = getGuiltLevel( guiltInDays )

        ply.glee_cachedGuiltDays = guiltInDays
        ply.glee_cachedGuiltLevel = guiltLevel
        ply.glee_cachedGuiltData = guiltData
        return guiltLevel, guiltData

    else
        return ply.glee_cachedGuiltLevel, ply.glee_cachedGuiltData

    end
end

hook.Add( "glee_shop_itemcostmul", "glee_guiltycost", function( purchaser, itemData, costMulTbl )
    if not itemData.Divine then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( purchaser )
    if not guiltData.divineCostMul then return end

    costMulTbl[1] = costMulTbl[1] * guiltData.divineCostMul

end )

hook.Add( "glee_shop_canpurchase", "glee_guiltycantbuydivine", function( purchaser, itemData )
    if not itemData.Divine then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( purchaser )
    if not guiltData.divineItemsNotPurchaseable then return end

    return false, "You have unjustly claimed too many innocent lives.\nThe divine ways are closed to you."

end )

if CLIENT then
    net.Receive( "glee_persistguiltincreased", function()
        local guiltInDays = net.ReadFloat()
        hook.Run( "glee_persistentguilt_increased", guiltInDays )

    end )
    net.Receive( "glee_dealtpvpdamage", function()
        local damage = net.ReadInt( 16 )
        hook.Run( "glee_dealtpvpdamage", damage )

    end )
    net.Receive( "glee_homicidallygleeful", function()
        hook.Run( "glee_homicidallygleeful" )

    end )

    hook.Add( "glee_persistentguilt_increased", "glee_guiltnotif", function( days )
        timer.Create( "glee_persistguilt_delayedmessage", 0.1, 1, function()
            local msg
            if days <= 1 then
                msg = "Killing an innocent soul...\nYou feel... Guilty?"

            elseif days <= 5 then
                msg = "Your guilt grows"
                for _ = 1, math.floor( days ) do
                    msg = msg .. "."

                end
            end
            if msg then
                notification.AddLegacy( msg, NOTIFY_ERROR, 10 )

            end
        end )
    end )
end