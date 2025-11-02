
local shopHelpers = GAMEMODE.shopHelpers

local function divineInterventionCost( purchaser )
    local shCost = 350
    local chosenHasArrived = GetGlobalBool( "chosenhasarrived", false )
    if chosenHasArrived then
        local isChosen = purchaser:GetNW2Bool( "isdivinechosen", false )
        if isChosen then
            return 0

        elseif not isChosen then
            return cost * 1.25

        end
    end
    return cost

end

local minTimeBetweenResurrections = 20
local dmgResistAfterRez = 8

local function divineInterventionCooldown( purchaser )
    local isChosen = purchaser:GetNW2Bool( "isdivinechosen", false )
    if isChosen then
        return 0

    else
        return minTimeBetweenResurrections

    end
end

local function divineInterventionPos( purchaser, spawnUnsafe, radAdd )
    radAdd = radAdd or 0
    local plys = GAMEMODE:returnWinnableInTable( player.GetAll() )

    if #plys <= 0 then
        local randomNavArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
        return randomNavArea:GetCenter()

    end

    local randomValidPos = nil
    local chosenResurrectAnchor
    for _ = 1, #plys do
        chosenResurrectAnchor = table.remove( plys, math.random( 1, #plys ) )

        if not spawnUnsafe then
            -- dont spawn them next to someone who they killed or they will kill.
            local isChosen = chosenResurrectAnchor:GetNW2Bool( "isdivinechosen", false ) == true
            if isChosen or GAMEMODE:HasHomicided( purchaser, chosenResurrectAnchor ) or GAMEMODE:HasHomicided( chosenResurrectAnchor, purchaser ) then
                continue

            end
        end

        for count = 1, 12 do
            -- search nearby chosen player in increasing radius
            randomValidPos = GAMEMODE:GetNearbyWalkableArea( chosenResurrectAnchor, chosenResurrectAnchor:GetPos(), count + radAdd )

            if randomValidPos then break end

        end
        if randomValidPos then break end

    end

    if randomValidPos and isvector( randomValidPos ) then
        return randomValidPos, chosenResurrectAnchor

    else
        -- find area not underwater
        local randomNavArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup( true )
        return randomNavArea:GetCenter()

    end

end

if SERVER then
    hook.Add( "PlayerDeath", "glee_storelastdeathtime", function( died )
        died:SetNW2Int( "glee_divineintervetion_lastdietime", math.ceil( CurTime() ) )

    end )
end

local function divineInterventionDeathCooldown( purchaser )
    local isChosen = purchaser:GetNW2Bool( "isdivinechosen", false )
    if isChosen then return true end

    local lastDeathTime = purchaser:GetNW2Int( "glee_divineintervetion_lastdietime", 0 )
    local reviveTime = lastDeathTime + minTimeBetweenResurrections
    local timeTillRevive = math.abs( reviveTime - CurTime() )
    timeTillRevive = math.Round( timeTillRevive, 1 )

    if reviveTime > CurTime() then return false, "Death cooldown.\nPurchasable in " .. tostring( timeTillRevive ) .. " seconds." end
    return true

end

local function divineIntervention( shopItem, purchaser )
    if not SERVER then return end
    if not purchaser.Resurrect then return end

    timer.Simple( 1, function()
        if not purchaser then return end
        if purchaser:Health() > 0 then return end

        if purchaser:GetNW2Bool( "isdivinechosen", false ) == true and purchaser.glee_divineChosenResurrect then
            purchaser:glee_divineChosenResurrect()
            return

        end

        local interventionPos, anchor = divineInterventionPos( purchaser )

        if IsValid( anchor ) then
            huntersGlee_Announce( { purchaser }, 20, 5, "Respawned next to " .. anchor:Nick() )

        end

        purchaser.unstuckOrigin = interventionPos
        purchaser:Resurrect()

        termHunt_ElectricalArcEffect( purchaser, interventionPos, vector_up, 4 )

        local stopTime = CurTime() + dmgResistAfterRez
        local hookName = "glee_divineintervention_damage_" .. purchaser:GetCreationID()
        hook.Add( "EntityTakeDamage", hookName, function( target, dmgInfo )
            if target ~= purchaser then hook.Remove( hookName ) return end
            if stopTime < CurTime() then hook.Remove( hookName ) return end

            GAMEMODE:GivePanic( purchaser, dmgInfo:GetDamage() )
            dmgInfo:ScaleDamage( 0.15 )

        end )

        local healTimerName = "glee_divineintervention_heal_" .. purchaser:GetCreationID()
        local healAmount = 50
        timer.Create( healTimerName, 1, 0, function()
            if not IsValid( purchaser ) then timer.Remove( healTimerName ) return end
            if purchaser:Health() <= 0 then timer.Remove( healTimerName ) return end
            if healAmount <= 0 then timer.Remove( healTimerName ) return end

            if math.random( 0, 100 ) > healAmount then return end

            healAmount = healAmount * 0.75
            local newHealth = math.min( purchaser:GetMaxHealth(), purchaser:Health() + healAmount )

            purchaser:SetHealth( newHealth )

        end )
    end )

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function infernalInterventionCanPurchase()
    local chosenHasArrived = GetGlobalBool( "chosenhasarrived", false )
    if chosenHasArrived then
        return false, "Something has weakened the infernal powers..."

    end
    return true, ""

end

local shriveledScale = Vector( 0.5, 0.5, 0.5 )
local normalScale = Vector( 1, 1, 1 )

if CLIENT then
    hook.Add( "CreateClientsideRagdoll", "glee_ragdoll_scale", function( died, ragdoll )
        if not IsValid( died ) then return end
        if died:GetNW2Int( "glee_DevilDealDeathEnd", 0 ) < CurTime() then return end

        local bc = ragdoll:GetBoneCount() or 0
        for i = 0, bc - 1 do
            ragdoll:ManipulateBoneScale( i, shriveledScale * math.Rand( 0.25, 2 ) )

        end
    end )
end

local function breakTheDeal( ply )
    if not ply:GetNW2Bool( "glee_DidADealWithTheDevil", false ) then return end

    ply:SetNW2Int( "glee_DevilDealDeathEnd", CurTime() + 2 )
    ply:SetNW2Bool( "glee_DidADealWithTheDevil", false )

    ply:doSpeedModifier( "infernalintervention", nil )

    plysAng = ply:GetAngles()
    ply:SetAngles( Angle( plysAng.p, plysAng.y, 0 ) ) -- RAAAGH ROLL

    local bc = ply:GetBoneCount() or 0
    for i = 0, bc - 1 do
        ply:ManipulateBoneScale( i, normalScale )

    end
end

local crumpleForce = Vector( 0, 0, -150000 )

hook.Add( "glee_shover_shove", "glee_infernalinstantdeath", function( shoved )
    if not shoved:GetNW2Bool( "glee_DidADealWithTheDevil", false ) then return end
    if shoved:Health() >= 25 then return end -- they're not weak enough

    local dmgInfo = DamageInfo()
    dmgInfo:SetDamage( math.random( 1, 3 ) )
    dmgInfo:SetAttacker( game.GetWorld() )
    dmgInfo:SetInflictor( game.GetWorld() )
    if shoved:Health() <= 5 then
        dmgInfo:SetDamageForce( crumpleForce )

    end
    shoved:TakeDamageInfo( dmgInfo ) -- kill with no blame

end )

hook.Add( "EntityTakeDamage", "glee_infernaldamageweakness", function( target, dmgInfo )
    if not target:GetNW2Bool( "glee_DidADealWithTheDevil", false ) then return end

    if dmgInfo:IsDamageType( DMG_BURN ) then
        dmgInfo:ScaleDamage( 6 )

    else
        dmgInfo:ScaleDamage( 2 )

    end
end )

hook.Add( "PlayerDeath", "glee_reset_shrivel_on_death", function( victim )
    if not victim:GetNW2Bool( "glee_DidADealWithTheDevil", false ) then return end
    breakTheDeal( victim )

end )

local function infernalInterventionDeathCooldown( purchaser )
    local lastDeathTime = purchaser:GetNW2Int( "glee_divineintervetion_lastdietime", 0 )
    local reviveTime = lastDeathTime + minTimeBetweenResurrections / 2
    local timeTillRevive = math.abs( reviveTime - CurTime() )
    timeTillRevive = math.Round( timeTillRevive, 1 )

    if reviveTime > CurTime() then return false, "Death cooldown.\nPurchasable in " .. tostring( timeTillRevive ) .. " seconds." end
    return true

end

local function infernalIntervention( shopItem, purchaser )
    if not SERVER then return end
    if not purchaser.Resurrect then return end

    timer.Simple( 1, function()
        if not purchaser then return end
        if purchaser:Health() > 0 then return end

        -- intervention pos, but further from a player, and they can be unsafe.
        local interventionPos = divineInterventionPos( purchaser, true, 10 )

        purchaser:SetNW2Bool( "glee_DidADealWithTheDevil", true )

        purchaser.unstuckOrigin = interventionPos
        purchaser:Resurrect()

        -- shrivel all bones
        local bc = purchaser:GetBoneCount() or 0
        for i = 0, bc - 1 do
            purchaser:ManipulateBoneScale( i, shriveledScale * math.Rand( 0.5, 1.75 ) )

        end

        purchaser:doSpeedModifier( "infernalintervention", -25 )

        GAMEMODE:GivePanic( purchaser, 100 )

        purchaser:SetHealth( 1 )
        timer.Simple( 0, function() -- juggernaut, etc
            if not IsValid( purchaser ) then return end
            if not purchaser:Alive() then return end -- this would be unlucky!
            purchaser:SetHealth( 1 )

            GAMEMODE:GivePanic( purchaser, 50 )
            GAMEMODE:EmulateHistoricHighBPM( purchaser )

            purchaser:TauntDance( ACT_HL2MP_ZOMBIE_SLUMP_IDLE ) -- start with idle

            timer.Simple( 0.5, function() -- delay because of high ping players
                if not IsValid( purchaser ) then return end
                if not purchaser:Alive() then return end
                purchaser:BlockAnimEventsFor( -1 ) -- reset TauntDance setting this
                purchaser:TauntDance( ACT_HL2MP_ZOMBIE_SLUMP_RISE )

            end )
        end )

        local timerName = "glee_devilbleed_" .. purchaser:GetCreationID()
        local strength = 100
        timer.Create( timerName, 0.05, 200, function()
            if not IsValid( purchaser ) then return end
            if not purchaser:Alive() then return end

            if math.random( 0, 100 ) > strength then return end
            strength = strength * 0.9

            GAMEMODE:Bleed( purchaser, strength )

        end )

        purchaser:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 75, math.random( 70, 80 ) )
        purchaser:EmitSound( "npc/antlion/digdown1.wav", 75, math.random( 150, 160 ) )

        local goAwayTimer = "glee_divineintervention_goaway_" .. purchaser:GetCreationID()
        timer.Create( goAwayTimer, 5, 0, function()
            if not IsValid( purchaser ) then timer.Remove( goAwayTimer ) return end
            if not purchaser:GetNW2Bool( "glee_DidADealWithTheDevil", false ) then timer.Remove( goAwayTimer ) return end

            if purchaser:Health() <= 0 then timer.Remove( goAwayTimer ) return end
            if purchaser:Health() < purchaser:GetMaxHealth() then return end

            breakTheDeal( purchaser )
            timer.Remove( goAwayTimer )

            huntersGlee_Announce( { purchaser }, 20, 5, "Is the deal over?\nIt's like a weight has been lifted..." )

        end )
    end )

    GAMEMODE:PutInnateInProperCleanup( nil, breakTheDeal, purchaser )

end

local items = {
    -- lets dead people take the initiative
    [ "resurrection" ] = {
        name = "Divine Intervention",
        desc = "Resurrect yourself.\nYou will revive next to another living player and have " .. dmgResistAfterRez .. "s of damage resistance.",
        shCost = divineInterventionCost,
        markup = 1,
        markupPerPurchase = 0.25,
        cooldown = divineInterventionCooldown,
        tags = { "DEADGIFTS", "Resurrecting", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -201,
        shPurchaseCheck = { shopHelpers.undeadCheck, divineInterventionDeathCooldown },
        svOnPurchaseFunc = divineIntervention,
    },
    -- for people who just want to BE ALIVE!
    [ "resurrectioncrappy" ] = {
        name = "Infernal Intervention",
        desc = "Make a deal with the devil.\nYou will come back as a shriveled, weak, husk.",
        shCost = 150,
        canGoInDebt = true,
        markup = 1,
        markupPerPurchase = 1,
        cooldown = 5,
        tags = { "DEADGIFTS", "Resurrecting", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -200,
        shPurchaseCheck = { shopHelpers.undeadCheck, infernalInterventionCanPurchase, infernalInterventionDeathCooldown },
        svOnPurchaseFunc = infernalIntervention,
    },
}

GAMEMODE:GobbleShopItems( items )