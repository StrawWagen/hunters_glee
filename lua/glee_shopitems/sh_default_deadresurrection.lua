
local shopHelpers = GAMEMODE.shopHelpers

local minTimeBetweenResurrections = 20

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
            local isChosen = chosenResurrectAnchor:HasStatusEffect( "divine_chosen" )
            if isChosen or GAMEMODE:HasSlighted( purchaser, chosenResurrectAnchor ) >= 50 or GAMEMODE:HasSlighted( chosenResurrectAnchor, purchaser ) >= 50 then
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

local healAmountAfterRez = 50
local dmgResistAfterRez = 8

if SERVER then
    GAMEMODE:RegisterStatusEffect( "divineintervention_blessing", -- healing and damage resist after rez
        function( self, owner ) -- setup func
            self:SetRemoveOnDeath( true ) -- its not a persistent effect, remove it on death

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

        if purchaser:HasStatusEffect( "divine_chosen" ) and purchaser.glee_divineChosenResurrect then
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


-- begin infernal intervention stuff
local shriveledScale = Vector( 0.5, 0.5, 0.5 )
local normalScale = Vector( 1, 1, 1 )
local crumpleForce = Vector( 0, 0, -150000 )

if CLIENT then
    GAMEMODE:RegisterStatusEffect( "infernalintervention_rawendofthedeal",
        function( self, _owner ) -- setup func
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

                    ply:TauntDance( ACT_HL2MP_ZOMBIE_SLUMP_IDLE ) -- start lying down

                    timer.Simple( 0.5, function() -- delay because of high ping players
                        if not IsValid( ply ) then return end
                        if not ply:Alive() then return end
                        ply:BlockAnimEventsFor( -1 ) -- reset TauntDance cooldown, animate NOW!
                        ply:TauntDance( ACT_HL2MP_ZOMBIE_SLUMP_RISE ) -- RISE!

                    end )
                end )

                -- bleeding effect on spawn, just visual
                local timerName = "glee_devilbleed_" .. ply:GetCreationID()
                local strength = 100
                timer.Create( timerName, 0.05, 200, function()
                    if not IsValid( ply ) then return end
                    if not ply:Alive() then timer.Remove( timerName ) return end
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
                if not owner:Alive() then return end
                if owner:Health() < owner:GetMaxHealth() + -1 then return end

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

        purchaser:GiveStatusEffect( "infernalintervention_rawendofthedeal" )

        -- intervention pos, but further from a player, and they can be unsafe.
        local interventionPos = divineInterventionPos( purchaser, true, 10 )

        purchaser.unstuckOrigin = interventionPos
        purchaser:Resurrect()

    end )

    GAMEMODE:PutInnateInProperCleanup( nil, breakTheDeal, purchaser )

end


-- grigori stuff
local defaultDivisor = 10
local minGrigoriMinutes = 5

-- overcomplicated way to make grigori happen later if rounds are 'interesting' ( people earning lots of score )
local glee_scoretochosentimeoffset_divisor = CreateConVar(
    "huntersglee_scoretochosentimeoffset_divisor1",
    "-1",
    bit.bor( FCVAR_REPLICATED, FCVAR_ARCHIVE ),
    "-1 = default, if set bigger, grigori can happen sooner, if smaller, happens later",
    0,
    100000

)

local sv_cheats = GetConVar( "sv_cheats" )

local function isCheats()
    return sv_cheats:GetBool()

end

if SERVER then
    SetGlobal2Int( "glee_chosen_timeoffset", 0 )
    local nextTimeOffsetNetwork = 0

    -- when people earn score, it 'increases patience', meaning grigori happens later if people are earning alot
    hook.Add( "huntersglee_givescore", "glee_chosentrackscore", function( ply, scoreGivenRaw )
        if GAMEMODE.roundExtraData.grigoriWasPurchased then return end -- end increase if someone's bought grigori
        if ply:Health() <= 0 then return end -- don't increase time if earner is dead

        local scoreGiven = math.abs( scoreGivenRaw )
        local divisor = glee_scoretochosentimeoffset_divisor:GetFloat()
        if divisor <= 0 then
            divisor = defaultDivisor

        end
        local moreTime = scoreGiven / divisor
        moreTime = moreTime / #player.GetAll() -- don't make this blow up on full servers!

        local startTimeOffset = GAMEMODE.roundExtraData.divineChosen_StartTimeOffset or 0
        startTimeOffset = startTimeOffset + moreTime
        GAMEMODE.roundExtraData.divineChosen_StartTimeOffset = startTimeOffset

        if nextTimeOffsetNetwork < CurTime() then -- don't spam network
            nextTimeOffsetNetwork = CurTime() + 1
            SetGlobal2Int( "glee_chosen_timeoffset", startTimeOffset )

        end
    end )
end

local function divineChosenCanPurchase( purchaser )
    local addedBySpending = GetGlobal2Int( "glee_chosen_timeoffset", 0 ) / 60
    local minutes = minGrigoriMinutes + addedBySpending
    minutes = math.Clamp( minutes, minGrigoriMinutes, 20 )

    local offset = 60 * minutes
    local allowTime = GetGlobalInt( "huntersglee_round_begin_active" ) + offset
    local remaining = allowTime - CurTime()
    local formatted = string.FormattedTime( remaining, "%02i:%02i" )

    local pt1 = "Their patience has ended."
    local block
    if allowTime > CurTime() then
        pt1 = "Presently, their patience lasts " .. formatted .. "."
        block = true

    end

    if block then return isCheats(), pt1 end

    if SERVER then
        -- ONLY ONE CHANCE PER ROUND!
        GAMEMODE.roundExtraData.divineChosenSpent = GAMEMODE.roundExtraData.divineChosenSpent or {}
        if GAMEMODE.roundExtraData.divineChosenSpent[ purchaser:GetCreationID() ] == true then return nil, "You had your chance." end

    end

    if purchaser:HasStatusEffect( "divine_chosen" ) then
        return nil, "You are already divine."

    end

    return true, nil

end

if CLIENT then
    -- triumphant font
    local fontData = {
        font = "Arial",
        extended = false,
        size = glee_sizeScaled( nil, 40 ),
        weight = 500,
        blursize = 0,
        scanlines = 0,
        antialias = true,
        underline = false,
        italic = false,
        strikeout = false,
        symbol = false,
        rotary = false,
        shadow = true,
        additive = false,
        outline = false,
    }
    surface.CreateFont( "huntersglee_divineorders", fontData )

    local screenMiddleW = ScrW() / 2
    local demandFlashing = Color( 255, 0, 0 )
    local spacingHeight = 30

    GAMEMODE:RegisterStatusEffect( "divine_chosen",
        function( self, owner ) -- setup func
            if LocalPlayer() ~= owner then return end

            self:Hook( "HUDPaint", function()
                local chosenWeap = owner:GetWeapon( "termhunt_divine_chosen" )
                if not ( IsValid( chosenWeap ) or owner:Health() <= 0 ) then return end

                local noPatienceTime = GetGlobal2Int( "divineChosenPatienceEnds", 0 )
                if noPatienceTime == 0 or noPatienceTime == -2147483648 then return end

                huntersGlee_BlockAnnouncements( owner, 5 )

                local timeTillNoPatience = noPatienceTime - CurTime()
                if timeTillNoPatience > 0 then
                    local Text = "KILL THEM OR LOSE IT ALL"
                    surface.drawShadowedTextBetter( Text, "huntersglee_divineorders", color_white, screenMiddleW, 128 )

                    local timeTillNoPatienceFormatted = string.FormattedTime( timeTillNoPatience, "%02i:%02i" )
                    local demandColor = color_white

                    Text = "OUR PATIENCE: " .. tostring( timeTillNoPatienceFormatted )

                    if timeTillNoPatience < 30 then
                        if CurTime() % 2 > 1 then
                            demandColor = demandFlashing

                        end
                        Text = "KILL THEM: " .. tostring( timeTillNoPatienceFormatted )

                    end
                    surface.drawShadowedTextBetter( Text, "huntersglee_divineorders", demandColor, screenMiddleW, 128 + spacingHeight * 2 )

                else
                    local Text = "YOU HAVE FAILED US."
                    for var = 0, 200 do
                        local drawOffset = var * 0.1
                        surface.drawShadowedTextBetter( Text, "huntersglee_divineorders", demandFlashing, screenMiddleW, 128 + spacingHeight * drawOffset )
                        local time = var * 0.08
                        if timeTillNoPatience > -time then return end

                    end
                end
            end )

            self:Hook( "huntersglee_cl_displayhint_predeadhints", function( me )
                if me ~= owner then return end
                if owner:GetNW2Int( "glee_divineintervetion_respawncount", 0 ) >= 3 then return end

                return true, "Stop wasting time, RESPAWN YOURSELF.\nYou are true DIVINE INTERVENTION."

            end )
        end
    )
end
if SERVER then
    local function isStillGoing()
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE or GAMEMODE:CountWinnablePlayers() <= 0 then return false end
        return true

    end

    GAMEMODE:RegisterStatusEffect( "divine_chosen",
        function( self, owner ) -- setup func
            SetGlobalBool( "chosenhasarrived", true )
            GAMEMODE.roundExtraData.grigoriWasPurchased = true

            huntersGlee_Announce( player.GetAll(), 500, 15, "The ultimate sacrifice has been made.\nBEWARE OF " .. string.upper( owner:Nick() ) )

            -- weapon maintenance timer
            self:Timer( "maintainWeapon", 0.1, 0, function()
                if owner:Health() <= 0 then return end

                GAMEMODE:GivePanic( owner, -25 )

                local chosenWeap = owner:GetWeapon( "termhunt_divine_chosen" )
                if not IsValid( chosenWeap ) then
                    owner:Give( "termhunt_divine_chosen" )
                    owner:SelectWeapon( "termhunt_divine_chosen" )

                end
            end )

            -- dont play the sv_modelspeaking lines, termhunt_divine_chosen plays its own
            self:Hook( "glee_block_modellines", function( ply )
                if ply ~= owner then return end
                return true

            end )

            -- this person is NOT a safe spawn anchor
            self:Hook( "huntersglee_blockspawn_nearplayers", function( spawner, _ )
                if spawner ~= owner then return end
                return true

            end )

            -- patience system - global timer, but we track if we created it
            GAMEMODE.roundExtraData.divinePatienceEnds = GAMEMODE.roundExtraData.divinePatienceEnds or ( CurTime() + 90 )

            -- increase patience on player deaths (global hook, only create once)
            if not GAMEMODE.roundExtraData.createdThePatienceIncreaseHook then
                GAMEMODE.roundExtraData.createdThePatienceIncreaseHook = true

                hook.Add( "PlayerDeath", "hunterslgee_increasedivinepatience", function( victim, _, _ )
                    if victim:HasStatusEffect( "divine_chosen" ) then return end
                    if isStillGoing() == false then
                        hook.Remove( "PlayerDeath", "hunterslgee_increasedivinepatience" )

                    else
                        if not GAMEMODE.roundExtraData.divinePatienceEnds then
                            hook.Remove( "PlayerDeath", "hunterslgee_increasedivinepatience" )
                            return

                        end
                        GAMEMODE.roundExtraData.divinePatienceEnds = math.max( CurTime() + 90, GAMEMODE.roundExtraData.divinePatienceEnds + 40 )

                    end
                end )
            end

            -- hard limit on how long you get to be grigori
            if not timer.Exists( "huntersglee_divinepatiencetimer" ) then
                timer.Create( "huntersglee_divinepatiencetimer", 1, 0, function()
                    if isStillGoing() == false then -- round ended
                        timer.Remove( "huntersglee_divinepatiencetimer" )
                        SetGlobal2Int( "divineChosenPatienceEnds", nil )

                        return

                    end

                    -- still going

                    SetGlobal2Int( "divineChosenPatienceEnds", GAMEMODE.roundExtraData.divinePatienceEnds )
                    if GAMEMODE.roundExtraData.divinePatienceEnds > CurTime() + -5 then return end

                    GAMEMODE.roundExtraData.divineChosenSpent = GAMEMODE.roundExtraData.divineChosenSpent or {}

                    for _, potentialChosen in ipairs( player.GetAll() ) do
                        if not potentialChosen:HasStatusEffect( "divine_chosen" ) then continue end

                        GAMEMODE.roundExtraData.divineChosenSpent[ potentialChosen:GetCreationID() ] = true
                        potentialChosen:RemoveStatusEffect( "divine_chosen" )

                        huntersGlee_Announce( player.GetAll(), 500, 15, string.upper( potentialChosen:Nick() ) .. " has FAILED their divine task..." )

                        timer.Simple( 0.1, function()
                            if not IsValid( potentialChosen ) then return end
                            if potentialChosen:Health() <= 1 then return end
                            potentialChosen:SetHealth( 1 )

                        end )
                    end
                end )
            end

            -- resurrect function stored on self
            self.resurrect = function()
                local area = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
                local randAreasCenter = area:GetCenter()
                owner.unstuckOrigin = randAreasCenter

                owner:Resurrect()

                self.respawnCount = ( self.respawnCount or 0 ) + 1
                owner:SetNW2Int( "glee_divineintervention_respawncount", self.respawnCount )

                timer.Simple( 0.1, function()
                    if not IsValid( owner ) then return end

                    owner:GodEnable()
                    local lightning = ents.Create( "glee_lightning" )
                    lightning:SetOwner( owner )
                    lightning:SetPos( randAreasCenter )
                    lightning:SetPowa( 12 )
                    lightning:Spawn()

                    timer.Simple( 0.5, function()
                        if not IsValid( owner ) then return end
                        owner:GodDisable()

                    end )
                end )
            end

            -- also store on owner for external access (divine intervention check)
            owner.glee_divineChosenResurrect = self.resurrect

            -- resurrect immediately
            self.resurrect()

            -- make all spectators watch the first chosen
            if not GAMEMODE.roundExtraData.divineChosenSnapped then
                GAMEMODE.roundExtraData.divineChosenSnapped = true

                timer.Simple( 0.5, function()
                    if not IsValid( owner ) then return end
                    for _, ply in player.Iterator() do
                        if not IsValid( ply ) then continue end
                        if ply:Health() > 0 then continue end

                        GAMEMODE:SpectateThing( ply, owner )

                    end
                end )
            end
        end,
        function( self, owner ) -- teardown func
            owner.glee_divineChosenResurrect = nil
            SetGlobalBool( "chosenhasarrived", false )

            owner:SetNW2Int( "glee_divineintervention_respawncount", 0 )

            local weap = owner:GetWeapon( "termhunt_divine_chosen" )
            SafeRemoveEntity( weap )

            -- Note: global hooks/timers are left for other potential chosen players
            -- They clean themselves up when round ends

        end
    )
end

local items = {
    -- lets dead people take the initiative
    [ "resurrection" ] = {
        name = "Divine Intervention",
        desc = "Resurrect yourself.\nYou will revive next to another living player and have " .. dmgResistAfterRez .. "s of damage resistance.",
        shCost = function( purchaser )
            local cost = 350
            local chosenHasArrived = GetGlobalBool( "chosenhasarrived", false )
            if chosenHasArrived then
                local isChosen = purchaser:HasStatusEffect( "divine_chosen" )
                if isChosen then
                    return 0

                elseif not isChosen then
                    return cost * 1.25

                end
            end
            return cost

        end,
        markup = 1,
        markupPerPurchase = 0.25,
        cooldown = function( purchaser )
            local isChosen = purchaser:HasStatusEffect( "divine_chosen" )
            if isChosen then
                return 0

            else
                return minTimeBetweenResurrections

            end
        end,
        tags = { "DEADGIFTS", "Resurrecting", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -201,
        shPurchaseCheck = { shopHelpers.undeadCheck, function( purchaser )
            local isChosen = purchaser:HasStatusEffect( "divine_chosen" )
            if isChosen then return true end

            local lastDeathTime = purchaser:GetNW2Int( "glee_divineintervetion_lastdietime", 0 )
            local reviveTime = lastDeathTime + minTimeBetweenResurrections
            local timeTillRevive = math.abs( reviveTime - CurTime() )
            timeTillRevive = math.Round( timeTillRevive, 1 )

            if reviveTime > CurTime() then return false, "Death cooldown.\nPurchasable in " .. tostring( timeTillRevive ) .. " seconds." end
            return true

        end, },
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
        shPurchaseCheck = { shopHelpers.undeadCheck, function( purchaser )
            local lastDeathTime = purchaser:GetNW2Int( "glee_divineintervetion_lastdietime", 0 )
            local reviveTime = lastDeathTime + minTimeBetweenResurrections / 2
            local timeTillRevive = math.abs( reviveTime - CurTime() )
            timeTillRevive = math.Round( timeTillRevive, 1 )

            if reviveTime > CurTime() then return false, "Death cooldown.\nPurchasable in " .. tostring( timeTillRevive ) .. " seconds." end
            return true

        end, },
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
    -- END THE ROUND!!!
    [ "divinechosen" ] = {
        name = "grigori",
        desc = "grigori.",
        shCost = 2000,
        markup = 1,
        markupPerPurchase = 0,
        cooldown = 0,
        tags = { "DEADGIFTS", "CloseShopOnPurchase" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 30,
        shPurchaseCheck = { shopHelpers.undeadCheck, divineChosenCanPurchase },
        svOnPurchaseFunc = function( purchaser )
            purchaser:GiveStatusEffect( "divine_chosen" )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )