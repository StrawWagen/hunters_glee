
-- TODO: IMPLIMENT GUILT EFFECTS

local PermaGuiltLevels = {
    NOT_GUILTY = 0,
    SLIGHTLY_GUILTY = 2,
    SOMEWHAT_GUILTY = 6,
    GUILTY = 20,
    VERY_GUILTY = 30,
    EXTREMELY_GUILTY = 50,
}
GM.PermaGuiltLevels = PermaGuiltLevels

GM.PermaGuiltInfo = {
    [PermaGuiltLevels.NOT_GUILTY]  = {
        message = "Your conscience is clear.",
        color = Color( 200, 200, 200 )
    },
    [PermaGuiltLevels.SLIGHTLY_GUILTY]  = {
        message = "Your conscience is still.. a bit clear...",
        color = Color( 210, 200, 120 )
    },
    [PermaGuiltLevels.SOMEWHAT_GUILTY]  = {
        message = "You're a bit evil. But you are still forgiven.",
        color = Color( 210, 200, 120 )
    },
    [PermaGuiltLevels.GUILTY]  = {
        message = "You're evil. Your access to divine avenues is limited.",
        color = Color( 220, 140,   0 )
    },
    [PermaGuiltLevels.VERY_GUILTY] = {
        message = "You're very evil. Divine paths are almost out of your reach.",
        color = Color( 220,  50,   0 )
    },
    [PermaGuiltLevels.EXTREMELY_GUILTY] = {
        message = "You're extremely evil. The divine ways are closed to you. You are always at one with the infernal powers.",
        color = Color( 200,   0,   0 )
    },
}

function GM:GetPersistentGuilt( ply )
    local guiltInDays = ply:GetNWFloat( "glee_persistentguilt_days", 0 )
    return guiltInDays

end

function getGuiltLevel( guiltInDays )
    local guiltLevel = 0
    for level, _ in pairs( GAMEMODE.PermaGuiltInfo ) do
        if guiltInDays >= level and level > guiltLevel then
            guiltLevel = level
        end
    end

    return guiltLevel

end

function GM:GetPlysGuiltLevel( ply )
    local guiltInDays = self:GetPersistentGuilt( ply )
    local guiltLevel = getGuiltLevel( guiltInDays )
    return guiltLevel

end

if CLIENT then
    net.Receive( "glee_dealtpvpdamage", function()
        local damage = net.ReadInt( 16 )
        hook.Run( "glee_dealtpvpdamage", damage )

    end )
    net.Receive( "glee_homicidallygleeful", function()
        hook.Run( "glee_homicidallygleeful" )

    end )
end