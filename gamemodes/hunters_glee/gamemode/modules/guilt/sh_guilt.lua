
local infernalSEffectName = "infernalintervention_rawendofthedeal"

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

local hud = terminator_Extras.glee_HL2Hud or {}

-- mixes color 1 with color 2, returns new color object
-- ratio 0 is entirely col1, ratio 1 is entirely col2
-- hack since glee_HL2Hud doesnt exist on client
local function colorMixCl( col1, col2, ratio )
    if SERVER then return end
    if not col1 or not col2 then return Color( 255, 255, 255, 255 ) end
    ratio = math.Clamp( ratio, 0, 1 )

    return Color(
        math.Round( Lerp( ratio, col1.r, col2.r ) ),
        math.Round( Lerp( ratio, col1.g, col2.g ) ),
        math.Round( Lerp( ratio, col1.b, col2.b ) ),
        math.Round( Lerp( ratio, col1.a, col2.a ) )
    )
end

GM.PermaGuiltInfo = {
    [PermaGuiltLevels.NOT_GUILTY]  = {
        desc = "Your conscience is clear.",
        color = hud.colorHappyYellow,
    },
    [PermaGuiltLevels.SLIGHTLY_GUILTY]  = {
        desc = "Your conscience is still.. a bit clear...",
        color = colorMixCl( hud.colorHappyYellow, hud.colorRedUrgent, 0.9 ),
    },
    [PermaGuiltLevels.SOMEWHAT_GUILTY]  = {
        desc = "You're a bit evil. But you are still forgiven.",
        message = "Your guilt grows.\nYou're a bit evil.",
        color = colorMixCl( hud.colorHappyYellow, hud.colorRedUrgent, 0.8 ),
        divineCostMul = 1.15,
    },
    [PermaGuiltLevels.ALMOST_GUILTY]  = {
        desc = "Things can't continue like this. You're almost evil.",
        color = colorMixCl( hud.colorHappyYellow, hud.colorRedUrgent, 0.7 ),
        message = "Your guilt grows.\nYou're almost evil.",
        divineCostMul = 1.25,
    },
    [PermaGuiltLevels.GUILTY]  = {
        desc = "You're evil. Your access to divine avenues is limited.",
        color = colorMixCl( hud.colorHappyYellow, hud.colorRedUrgent, 0.5 ),
        message = "You're evil.\nThe divine actors are displeased.",
        divineCostMul = 1.5,
    },
    [PermaGuiltLevels.VERY_GUILTY] = {
        desc = "You're very evil. Divine paths are almost out of your reach.",
        color = colorMixCl( hud.colorHappyYellow, hud.colorRedUrgent, 0.25 ),
        message = "You're very evil.\nThe divine paths are closing...",
        divineCostMul = 2.5,
    },
    [PermaGuiltLevels.EXTREMELY_GUILTY] = {
        desc = "You're extremely evil. The divine ways are closed to you. You are always one with the infernal powers.",
        message = "You're extremely evil.\nYou are now one with the infernal powers.",
        color = hud.colorRedUrgent,
        divineItemsNotPurchaseable = true,
        alwaysTakingTheDeal = true,
    },
}

local developerVar = GetConVar( "developer" )
-- guilt effects are a dedicated server only mechanic
-- developer 1 enables them for testing
local active = game.IsDedicated() or developerVar:GetBool()

function GM:GetPersistentGuilt( ply )
    local guiltInDays = ply:GetNWFloat( "glee_persistentguilt_days", 0 )
    return guiltInDays

end

function getGuiltLevel( guiltInDays )
    local guiltLevel = 0
    local guiltData = GAMEMODE.PermaGuiltInfo[PermaGuiltLevels.NOT_GUILTY]
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
    local old_cachedDays = ply.glee_cachedGuiltDays
    if not old_cachedDays or guiltInDays ~= old_cachedDays then
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
    if not active then return end
    if not itemData.tags.Divine then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( purchaser )
    if not guiltData.divineCostMul then return end

    costMulTbl[1] = costMulTbl[1] * guiltData.divineCostMul

end )

hook.Add( "glee_shop_canpurchase", "glee_guiltycantbuydivine", function( purchaser, itemData )
    if not active then return end
    if not itemData.tags.Divine then return end

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

    local oldLevel

    hook.Add( "glee_persistentguilt_increased", "glee_guiltnotif", function( days )
        if not active then return end
        timer.Create( "glee_persistguilt_delayeddesc", 0.1, 1, function()
            local msg
            local level, levelData = GAMEMODE:GetPlysGuiltLevel( LocalPlayer() )
            if oldLevel and level ~= oldLevel and level > oldLevel then -- play transition message if this teir has one
                msg = levelData.message

            elseif days <= 1 then -- first day of guilt
                msg = "Killing an innocent soul...\nYou feel... Guilty?"

            elseif days <= 5 then -- first 5 days
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
if SERVER then
    local function applyPermaInfernal( spawned )
        if not GAMEMODE:GetRegisteredStatusEffect( infernalSEffectName ) then return end
        if spawned:HasStatusEffect( infernalSEffectName ) then return end

        local _, guiltData = GAMEMODE:GetPlysGuiltLevel( spawned )
        if not guiltData.alwaysTakingTheDeal then return end

        local effect = spawned:GiveStatusEffect( infernalSEffectName )
        effect.fromPermaGuiltLevel = true

    end
    hook.Add( "glee_true_PlayerSpawn", "glee_permainfernal", function( spawned )
        if not active then return end
        ProtectedCall( function( spawnedP )
            applyPermaInfernal( spawnedP )

        end, spawned )
    end )
    hook.Add( "PlayerInitialSpawn", "glee_permainfernal", function( spawned )
        if not active then return end
        -- get out of this hook, it's dangerous to error in it
        ProtectedCall( function( spawnedP )
            applyPermaInfernal( spawnedP )

        end, spawned )
    end )
end