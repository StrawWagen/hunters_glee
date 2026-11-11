
local infernalSEffectName = "infernalintervention_rawendofthedeal"

local PermaGuiltLevels = {
    NOT_GUILTY = 0,
    SLIGHTLY_GUILTY = 1,
    BARELY_GUILTY = 2,
    SOMEWHAT_GUILTY = 5,
    ALMOST_GUILTY = 10,
    GUILTY = 20,
    VERY_GUILTY = 35,
    EXTREMELY_GUILTY = 50,
    SUPREMELY_GUILTY = 100,
}
GM.PermaGuiltLevels = PermaGuiltLevels

-- The tiers' own colours, not any hud style's, so they read the same whatever style or
-- contrast setting draws them
local clearColor = Color( 200, 255, 140, 220 )
local calmColor  = Color( 255, 230, 0, 220 )
local evilColor  = Color( 255, 50, 50, 200 )

-- mixes color 1 with color 2, returns new color object
-- ratio 0 is entirely col1, ratio 1 is entirely col2
local function colorMix( col1, col2, ratio )
    ratio = math.Clamp( ratio, 0, 1 )

    local h1, s1, v1 = ColorToHSV( col1 )
    local h2, s2, v2 = ColorToHSV( col2 )
    local h = Lerp( ratio, h1, h2 )
    local s = Lerp( ratio, s1, s2 )
    local v = Lerp( ratio, v1, v2 )

    local col = HSVToColor( h, s, v )
    col.a = Lerp( ratio, col1.a, col2.a )

    return col

end

GM.PermaGuiltInfo = {
    [PermaGuiltLevels.NOT_GUILTY]  = {
        desc = "Your conscience is clear.",
        color = clearColor,
    },
    [PermaGuiltLevels.SLIGHTLY_GUILTY]  = {
        desc = "Your conscience is still.. a bit clear...",
        color = colorMix( calmColor, evilColor, 0.25 ),
    },
    [PermaGuiltLevels.BARELY_GUILTY]  = {
        desc = "You're just starting to become evil... Nobody will feel guilty for killing you.",
        color = colorMix( calmColor, evilColor, 0.25 ),
        killedForNoGuilt = true,
    },
    [PermaGuiltLevels.SOMEWHAT_GUILTY]  = {
        desc = "You're a bit evil.",
        message = "Your guilt grows.\nYou're a bit evil.",
        color = colorMix( calmColor, evilColor, 0.5 ),
        divineCostMul = 1.15,
        killedForNoGuilt = true,
    },
    [PermaGuiltLevels.ALMOST_GUILTY]  = {
        desc = "Things can't continue like this. You're almost evil.",
        color = colorMix( calmColor, evilColor, 0.7 ),
        message = "Your guilt grows.\nYou're almost evil.",
        divineCostMul = 1.25,
        killedForNoGuilt = true,
    },
    [PermaGuiltLevels.GUILTY]  = {
        desc = "You're evil. Your access to divine avenues is limited. You see halos over the innocent.",
        color = colorMix( calmColor, evilColor, 0.8 ),
        message = "You're evil.\nThe divine actors are displeased.",
        divineCostMul = 1.5,
        canPurchaseForgivenessRitual = true,
        killedForNoGuilt = true,
    },
    [PermaGuiltLevels.VERY_GUILTY] = {
        desc = "You're very evil. Divine paths are almost out of your reach.",
        color = colorMix( calmColor, evilColor, 0.9 ),
        message = "You're very evil.\nThe divine paths are closing...",
        divineCostMul = 2.5,
        canPurchaseForgivenessRitual = true,
        horriblyEvil = true,
        killedForNoGuilt = true,
    },
    [PermaGuiltLevels.EXTREMELY_GUILTY] = {
        desc = "You're extremely evil. The divine ways are closed to you. You are always one with the infernal powers. Smiting you atones for past sins.",
        message = "You're extremely evil.\nYou are now one with the infernal powers.",
        color = evilColor,
        divineItemsNotPurchaseable = true,
        alwaysTakingTheDeal = true,
        canPurchaseForgivenessRitual = true,
        horriblyEvil = true,
        cooldownMul = 1.25,
        killedForNoGuilt = true,
        godlySlayingRelievesGuilt = true, -- divine lightning and infernal summons forgive whoever killed them, see sv_guilt
    },
    [PermaGuiltLevels.SUPREMELY_GUILTY] = {
        desc = "You're supremely evil. The divine ways are closed to you. You are always one with the infernal powers. Smiting you atones for past sins. You are punished wickedly for harming the innocent. All shop item cooldowns are longer.",
        message = "You're supremely evil.\nYou are now punished wickedly for harming the innocent.",
        color = evilColor,
        divineItemsNotPurchaseable = true,
        alwaysTakingTheDeal = true,
        gleefulOnInnocentDamage = true,
        ignitesWhenGuiltyGleeful = true,
        canPurchaseForgivenessRitual = true,
        horriblyEvil = true,
        cooldownMul = 2,
        killedForNoGuilt = true,
        godlySlayingRelievesGuilt = true,
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

hook.Add( "glee_shop_itemcostmul", "glee_guiltycost", function( purchaser, itemData, adjust )
    if not active then return end
    if not itemData.tags.Divine then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( purchaser )
    if not guiltData.divineCostMul then return end

    adjust.mul = adjust.mul * guiltData.divineCostMul

end )

hook.Add( "glee_shop_itemcooldownmul", "glee_guiltycooldown", function( purchaser, _itemData, adjust )
    if not active then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( purchaser )
    if not guiltData.cooldownMul then return end

    adjust.mul = adjust.mul * guiltData.cooldownMul

end )

hook.Add( "glee_shop_canpurchase", "glee_guiltycantbuydivine", function( purchaser, itemData )
    if not active then return end
    if not itemData.tags.Divine then return end

    local _, guiltData = GAMEMODE:GetPlysGuiltLevel( purchaser )
    if not guiltData.divineItemsNotPurchaseable then return end

    return false, "You have unjustly claimed too many innocent lives.\nThe divine ways are closed to you."

end )

if CLIENT then
    net.Receive( "glee_persistguiltchanged", function()
        local oldGuiltInDays = net.ReadFloat()
        local newGuiltInDays = net.ReadFloat()
        if newGuiltInDays > oldGuiltInDays then
            hook.Run( "glee_persistentguilt_increased", newGuiltInDays )

        else
            hook.Run( "glee_persistentguilt_decreased", newGuiltInDays )

        end
    end )
    net.Receive( "glee_dealtpvpdamage", function()
        local damage = net.ReadInt( 16 )
        hook.Run( "glee_dealtpvpdamage", damage )

    end )
    net.Receive( "glee_homicidallygleeful", function()
        hook.Run( "glee_homicidallygleeful" )

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

    local guiltyGleeIgniteDuration = 8

    -- the Watchers' fury, the lightning that lights them. see eff_glee_halosmite
    -- hurt an innocent, and their halo strikes you itself
    -- otherwise it comes from just above your head
    local haloAboveEyes = 12 -- about where the halo is, for anyone not drawing it
    local smiteAboveGuilty = 40
    local smiteDelay = { 0.25, 0.5 } -- min, max seconds after the dance starts
    local thunderCracks = {
        "ambient/atmosphere/thunder1.wav",
        "ambient/atmosphere/thunder2.wav",
        "ambient/atmosphere/thunder3.wav",
        "ambient/atmosphere/thunder4.wav",
    }

    local function smiteFromHalo( guilty, innocent )
        local from
        if IsValid( innocent ) then
            from = innocent:EyePos() + Vector( 0, 0, haloAboveEyes )

        else
            from = guilty:EyePos() + Vector( 0, 0, smiteAboveGuilty )

        end

        local fx = EffectData()
            fx:SetOrigin( from )
            fx:SetStart( guilty:WorldSpaceCenter() )
            fx:SetEntity( innocent or NULL )
        util.Effect( "eff_glee_halosmite", fx )

        guilty:EmitSound( thunderCracks[math.random( #thunderCracks )], 95, math.random( 95, 110 ), 1, CHAN_STATIC )

    end

    -- only runs for Guilty Homicidal Glee, innocent dancers never reach this hook
    hook.Add( "glee_homicidallygleeful", "glee_guiltyglee_ignite", function( dancer, surfacer, _reason, _reasonGlobal, surfaceType )
        if not active then return end

        local _, guiltData = GAMEMODE:GetPlysGuiltLevel( dancer )
        if not guiltData.ignitesWhenGuiltyGleeful then return end

        -- only the innocent have a halo to strike from, any other surfacer is a ghost or the heli
        local innocent = surfaceType == "harmedInnocent" and surfacer or nil

        -- wait for the third person dance camera to pull out, so they see it land
        timer.Simple( math.Rand( smiteDelay[1], smiteDelay[2] ), function()
            if not IsValid( dancer ) then return end
            if not dancer:Alive() then return end

            dancer:Ignite( guiltyGleeIgniteDuration )
            smiteFromHalo( dancer, innocent )

        end )
    end )

    -- ignite if attacking perfectly innocment players
    hook.Add( "PostEntityTakeDamage", "glee_guiltyglee_oninnocentdamage", function( damaged, dmg, took )
        if not active then return end
        if not took then return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        if not damaged:IsPlayer() then return end

        local attacker = dmg:GetAttacker()
        if not IsValid( attacker ) or not attacker:IsPlayer() then return end
        if attacker == damaged then return end
        if not attacker:Alive() then return end
        if attacker:IsPlayingTaunt2() then return end

        local inflictor = dmg:GetInflictor()
        if IsValid( inflictor ) and inflictor.glee_GuiltFreeInflictor then return end

        local _, guiltData = GAMEMODE:GetPlysGuiltLevel( attacker )
        if not guiltData.gleefulOnInnocentDamage then return end

        local _, damagedsGuiltData = GAMEMODE:GetPlysGuiltLevel( damaged )
        if damagedsGuiltData.killedForNoGuilt then return end

        GAMEMODE:SurfaceHomicidalGlee( attacker, damaged, "harmedInnocent" )

    end )
end