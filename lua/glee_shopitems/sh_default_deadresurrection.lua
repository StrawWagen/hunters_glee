
local shopHelpers = GAMEMODE.shopHelpers

local function divineInterventionCost( purchaser )
    local cost = 350
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

local healAmountAfterRez = 50
local dmgResistAfterRez = 8

if SERVER then
    GAMEMODE:RegisterStatusEffect( "divineintervention_blessing", -- healing and damage resist after rez
        function( self, owner ) -- setup func
            self.removeOnDeath = true -- magic variable, sets the effect to be removed on death

            local stopTime = CurTime() + dmgResistAfterRez

            self:Hook( "EntityTakeDamage", function( target, dmgInfo )
                if target ~= owner then return end
                if stopTime < CurTime() then return end

                GAMEMODE:GivePanic( owner, dmgInfo:GetDamage() )
                dmgInfo:ScaleDamage( 0.15 )

            end )

            local healAmount = healAmountAfterRez
            self:Timer( "heal", 1, 0, function()
                if healAmount <= 1 then return end

                if math.random( 0, 100 ) > healAmount then return end

                healAmount = healAmount * 0.75
                local newHealth = math.min( owner:Health() + healAmount, owner:GetMaxHealth() )

                owner:SetHealth( newHealth )

            end )
        end
    )
end

local function divineIntervention( purchaser )
    if not SERVER then return end
    if not purchaser.Resurrect then return end

    if purchaser:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then
        purchaser:RemoveStatusEffect( "infernalintervention_rawendofthedeal" ) -- don't you get it? you're divine now!

    end

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

        purchaser:GiveStatusEffect( "divineintervention_blessing" )
    end )

    GAMEMODE:CloseShopOnPly( purchaser )

end


local shriveledScale = Vector( 0.5, 0.5, 0.5 )
local normalScale = Vector( 1, 1, 1 )
local crumpleForce = Vector( 0, 0, -150000 )

local function infernalInterventionDeathCooldown( purchaser )
    local lastDeathTime = purchaser:GetNW2Int( "glee_divineintervetion_lastdietime", 0 )
    local reviveTime = lastDeathTime + minTimeBetweenResurrections / 2
    local timeTillRevive = math.abs( reviveTime - CurTime() )
    timeTillRevive = math.Round( timeTillRevive, 1 )

    if reviveTime > CurTime() then return false, "Death cooldown.\nPurchasable in " .. tostring( timeTillRevive ) .. " seconds." end
    return true

end

if CLIENT then
    GAMEMODE:RegisterStatusEffect( "infernalintervention_rawendofthedeal",
        function( self, owner ) -- setup func
            -- crunch their clientside ragdolls
            self:HookOnce( "CreateClientsideRagdoll", function( died, ragdoll )
                if not IsValid( died ) then return end
                if not died:IsPlayer() then return end
                if not died:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then return end

                local bc = ragdoll:GetBoneCount() or 0
                for i = 0, bc - 1 do
                    ragdoll:ManipulateBoneScale( i, shriveledScale * math.Rand( 0.25, 2 ) )

                end
            end )
        end
    )
end

if SERVER then
    GAMEMODE:RegisterStatusEffect( "infernalintervention_rawendofthedeal",
        function( self, owner ) -- setup func
            -- shove infernal intervention players to kill them with no blame
            self:HookOnce( "glee_shover_shove", function( shoved )
                if not shoved:IsPlayer() then return end
                if not shoved:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then return end

                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage( math.random( 1, 3 ) )
                dmgInfo:SetAttacker( game.GetWorld() )
                dmgInfo:SetInflictor( game.GetWorld() )
                if shoved:Health() <= 5 then
                    dmgInfo:SetDamageForce( crumpleForce )

                end
                shoved:TakeDamageInfo( dmgInfo )

            end )

            -- damage weakness
            self:HookOnce( "EntityTakeDamage", function( target, dmgInfo )
                if not target:IsPlayer() then return end
                if not target:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then return end

                if dmgInfo:IsDamageType( DMG_BURN ) then -- OH GOD IT BURNS
                    dmgInfo:ScaleDamage( 6 )

                else
                    dmgInfo:ScaleDamage( 2 )

                end
            end )

            -- apply effects on spawn
            self:HookOnce( "PlayerSpawn", function( ply )
                if not ply:HasStatusEffect( "infernalintervention_rawendofthedeal" ) then return end

                -- shrivel all bones
                local bc = ply:GetBoneCount() or 0
                for i = 0, bc - 1 do
                    ply:ManipulateBoneScale( i, shriveledScale * math.Rand( 0.5, 1.75 ) )

                end

                -- apply speed mod
                ply:DoSpeedModifier( "infernalintervention", -25 )

                -- wake up screaming with terror!
                GAMEMODE:GivePanic( ply, 100 )

                -- spawn in with 1 health
                ply:SetHealth( 1 )

                -- fix health just in case
                timer.Simple( 0, function() -- juggernaut, etc
                    if not IsValid( ply ) then return end
                    if not ply:Alive() then return end -- this would be unlucky!
                    ply:SetHealth( 1 )

                    GAMEMODE:GivePanic( ply, 50 )
                    GAMEMODE:EmulateHistoricHighBPM( ply ) -- spawn with a pounding heart

                    ply:TauntDance( ACT_HL2MP_ZOMBIE_SLUMP_IDLE ) -- zombie rising anim

                    timer.Simple( 0.5, function() -- delay because of high ping players
                        if not IsValid( ply ) then return end
                        if not ply:Alive() then return end
                        ply:BlockAnimEventsFor( -1 ) -- reset TauntDance cooldown, animate NOW!
                        ply:TauntDance( ACT_HL2MP_ZOMBIE_SLUMP_RISE )

                    end )
                end )

                -- bleeding effect on spawn, just visual
                local timerName = "glee_devilbleed_" .. ply:GetCreationID()
                local strength = 100
                timer.Create( timerName, 0.05, 200, function()
                    if not IsValid( ply ) then return end
                    if not ply:Alive() then return end
                    if math.random( 0, 100 ) > strength then return end
                    strength = strength * 0.9

                    GAMEMODE:Bleed( ply, strength )
                end )

                -- spawning sounds
                ply:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 75, math.random( 70, 80 ) )
                ply:EmitSound( "npc/antlion/digdown1.wav", 75, math.random( 150, 160 ) )

            end )

            -- check if player reaches full health to end the deal
            self:Timer( "check_full_health", 1, 0, function()
                if owner:Health() <= 0 then return end
                if owner:Health() < owner:GetMaxHealth() then return end

                owner:RemoveStatusEffect( "infernalintervention_rawendofthedeal" )

                huntersGlee_Announce( { owner }, 20, 5, "Is the deal over?\nIt's like a weight has been lifted..." )

            end )
        end,
        function( _self, owner ) -- teardown func
            owner:DoSpeedModifier( "infernalintervention", nil )
            GAMEMODE:FixAnglesOf( owner ) -- the TauntDance may leave them tilted, wait until teardown to fix lol

            local bc = owner:GetBoneCount() or 0
            for i = 0, bc - 1 do
                owner:ManipulateBoneScale( i, normalScale )

            end
        end
    )
end

local function infernalIntervention( purchaser )
    if not SERVER then return end
    if not purchaser.Resurrect then return end

    timer.Simple( 1, function()
        if not purchaser then return end
        if purchaser:Health() > 0 then return end

        -- intervention pos, but further from a player, and they can be unsafe.
        local interventionPos = divineInterventionPos( purchaser, true, 10 )

        purchaser:GiveStatusEffect( "infernalintervention_rawendofthedeal" )

        purchaser.unstuckOrigin = interventionPos
        purchaser:Resurrect()

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
        shPurchaseCheck = { shopHelpers.undeadCheck, infernalInterventionDeathCooldown },
        svOnPurchaseFunc = infernalIntervention,
    },
    -- soft reason to get around the map, go places people have died 
    [ "revivekit" ] = {
        name = "Revive Kit",
        desc = "Revives dead players.\nYou gain 300 score per resurrection.",
        shCost = 30,
        markup = 1.5,
        cooldown = 0.5,
        tags = { "ITEMS", "Resurrecting", "Weapon", "Utility" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -100,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( purchaser )
            local weap = purchaser:GetWeapon( "termhunt_reviver" )
            local hasWeap = IsValid( weap )

            if hasWeap then
                weap:AddResurrect()
                weap:AddResurrect()

            else
                weap = purchaser:Give( "termhunt_reviver", false )
                weap:AddResurrect()
                shopHelpers.loadoutConfirm( purchaser, 2 )

            end
        end,
        shCanShowInShop = shopHelpers.hasMultiplePeople,
    },
}

GAMEMODE:GobbleShopItems( items )