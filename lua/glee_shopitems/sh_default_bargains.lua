local shopHelpers = GAMEMODE.shopHelpers
local cvarBase = "huntersglee_bargain_"
local cvarFlags = FCVAR_ARCHIVE + FCVAR_REPLICATED

local defaultOfferCount = 4
local cvarOfferCount = CreateConVar( cvarBase .. "huntersglee_bargainoffercount", -1, cvarFlags, "The number of bargains to offer to each player per round. -1 for default, " .. defaultOfferCount, 0, 256 )

local function getOfferCount()
    local offerCount = cvarOfferCount:GetInt()
    if offerCount == -1 then
        offerCount = defaultOfferCount

    end

    local hookResult = hook.Run( "glee_bargains_overridecount", offerCount )
    if isnumber( hookResult ) then
        offerCount = hookResult

    end

    return offerCount

end

-- odds of being offered, relative to each other. 0 or less is never offered
local defaultBargainWeight = 1
local defaultRareBargainWeight = 0.1

local function getBargainWeight( ply, item )
    local weight = item.tags.RareBargain and defaultRareBargainWeight or defaultBargainWeight

    local hookResult = hook.Run( "glee_bargains_overrideweight", ply, item, weight )
    if isnumber( hookResult ) then
        weight = hookResult

    end

    return weight

end

GAMEMODE.glee_BargainOffersPerPly = GAMEMODE.glee_BargainOffersPerPly or {} -- [ply] = { [shopItemName] = true, __count = count, }


-- returns offerTbl, calledReset
-- sets up and networks the bargain table to players when they request it
local function getOfferTbl( ply )
    local offerTbl = GAMEMODE.glee_BargainOffersPerPly[ply]
    if not offerTbl then
        offerTbl = { __count = 0, }
        GAMEMODE.glee_BargainOffersPerPly[ply] = offerTbl

        if SERVER then
            GAMEMODE:ResetBargainOffers( ply )
            return offerTbl, true

        end

    end

    return offerTbl

end

function GAMEMODE:GetOfferedBargainCount( ply )
    return getOfferTbl( ply ).__count

end

function GAMEMODE:IsBargainOffered( itemID, ply )
    return getOfferTbl( ply )[itemID] or false

end


-- Bargain offer reset
if SERVER then
    util.AddNetworkString( "glee_bargainoffers" )

    local function networkOffers( ply )
        local tbl = GAMEMODE.glee_BargainOffersPerPly[ply]
        local count = tbl and tbl.__count or 0

        net.Start( "glee_bargainoffers" )
        net.WriteUInt( count, 8 )
        for identifier in pairs( tbl or {} ) do
            if identifier ~= "__count" then
                net.WriteString( identifier )

            end

        end
        net.Send( ply )

    end


    function GAMEMODE:ResetBargainOffers( ply )
        if not ply then
            table.Empty( GAMEMODE.glee_BargainOffersPerPly )
            return

        end

        if not IsValid( ply ) or not ply:IsPlayer() then return end

        local offerTbl, calledReset = getOfferTbl( ply )
        if calledReset then return end

        table.Empty( offerTbl )
        offerTbl.__count = 0

        local offerCount = getOfferCount()
        if offerCount <= 0 then
            networkOffers( ply )
            return

        end

        local candidates = {}
        local totalWeight = 0
        for _, item in ipairs( shopHelpers.getItemsByTag( "Bargain" ) ) do
            -- no hook, our own glee_shop_canshow would block everything, nothing's on offer yet
            if not shopHelpers.runChecks( ply, item, nil, item.shCanShowInShop, "shCanShowInShop" ) then continue end

            local weight = getBargainWeight( ply, item )
            if weight <= 0 then continue end

            table.insert( candidates, { item = item, weight = weight } )
            totalWeight = totalWeight + weight

        end

        local offersLeft = math.min( offerCount, #candidates )
        offerTbl.__count = offersLeft

        while offersLeft > 0 do
            local roll = math.Rand( 0, totalWeight )
            local pickedIndex = #candidates -- float drift can leave roll a hair above 0 after the last one
            for index, candidate in ipairs( candidates ) do
                roll = roll - candidate.weight
                if roll <= 0 then
                    pickedIndex = index
                    break

                end
            end

            local picked = table.remove( candidates, pickedIndex )
            totalWeight = totalWeight - picked.weight
            offerTbl[picked.item.identifier] = true
            offersLeft = offersLeft - 1

        end

        networkOffers( ply )

    end


    -- Network to late joins. Should be pointless when players have different offers, but what if ply's offers generate before ply loads in?
    hook.Add( "glee_full_load", "glee_shopitems_bargainoffers", networkOffers )

    hook.Add( "huntersglee_round_into_inactive", "glee_shopitems_bargainoffers", function()
        -- Don't need to manually reset on all players here since the per-ply table gets wiped, and will generate as players open the shop.
        GAMEMODE:ResetBargainOffers()

    end )

    hook.Add( "glee_loadingtheshop", "glee_shopitems_bargainoffers", function( ply )
        getOfferTbl( ply )

    end )

else -- CLIENT

    net.Receive( "glee_bargainoffers", function()
        local offerTbl = getOfferTbl( LocalPlayer() )
        local count = net.ReadUInt( 8 )
        table.Empty( offerTbl )
        offerTbl.__count = count

        for _ = 1, count do
            offerTbl[net.ReadString()] = true

        end

    end )

end


local cheatsVar = GetConVar( "sv_cheats" )

-- Only show bargains that are on offer.
hook.Add( "glee_shop_canshow", "glee_shopitems_bargainoffers", function( ply, itemData )
    if not itemData.tags.Bargain then return end -- Not a bargain, don't care.
    if SERVER and cheatsVar:GetBool() then return end -- cheats, serverside? let them buy it with termhunt_purchase 
    if not GAMEMODE:IsBargainOffered( itemData.identifier, ply ) then return false, "This bargain is not on offer." end

end )


if SERVER then

    GAMEMODE:RegisterStatusEffect( "deafness",
        function( self, owner ) -- setup func
            function self:GiveDeaf()
                local effectOwner = self:GetOwner()
                effectOwner:SetDSP( 31 )

            end
            function self:UnDeafInternal()
                local effectOwner = self:GetOwner()
                effectOwner:SetDSP( 1 )

            end

            self:Timer( "manage_deafness", 0.1, 0, function()
                if owner:Health() <= 0 then self:UnDeafInternal() return end
                self:GiveDeaf()

            end )
        end,
        function( self, _ ) -- teardown func
            self:UnDeafInternal()

        end
    )


    local awfulKneeSounds = {
        "npc/barnacle/neck_snap1.wav",
        "npc/barnacle/barnacle_crunch2.wav",
        "physics/body/body_medium_break4.wav",

    }

    GAMEMODE:RegisterStatusEffect( "bad_knees",
        function( self, owner ) -- setup func
            -- save the old jump power so we can restore it later
            self.originalJumpPower = owner:GetJumpPower()
            self:Hook( "PlayerSpawn", function( spawned )
                if spawned ~= owner then return end
                spawned:SetJumpPower( self.originalJumpPower * 0.7 )

            end )

            owner:SetJumpPower( self.originalJumpPower * 0.7 )

            self:HookOnce( "glee_getfalldamage", function( ply, speed ) -- crazy high fall damage
                if not ply:HasStatusEffect( "bad_knees" ) then return end

                for count = 1, 4 do
                    local soundP = awfulKneeSounds[math.random( 1, #awfulKneeSounds )]
                    ply:EmitSound( soundP, 70, math.random( 70, 80 + count * 4 ), 1, CHAN_STATIC )

                end

                return speed

            end )

            self:HookOnce( "KeyPress", function( ply, key ) -- funny sounds and pain on jump
                if key ~= IN_JUMP then return end
                if not ply:HasStatusEffect( "bad_knees" ) then return end

                if not ply:OnGround() then return end
                if ply:WaterLevel() >= 3 then return end

                GAMEMODE:GivePanic( ply, 10 )
                ply:TakeDamage( 3, game.GetWorld(), game.GetWorld() )

                for count = 1, math.random( 1, 3 ) do
                    local soundP = awfulKneeSounds[math.random( 1, #awfulKneeSounds )]
                    ply:EmitSound( soundP, 70, math.random( 110, 120 + count * 4 ), 1, CHAN_STATIC )

                end
            end )
        end,
        function( self, owner ) -- teardown func
            owner:SetJumpPower( self.originalJumpPower )

        end
    )


    local beaconSoundPath = "npc/scanner/combat_scan1.wav"
    local beaconSoundInterval = 15

    GAMEMODE:RegisterStatusEffect( "beacon",
        function( self, owner ) -- setup func
            function self:DoBeaconPing() -- beep
                local effectOwner = self:GetOwner()

                -- make sure every bot on the map hears this
                sound.EmitHint( SOUND_COMBAT, effectOwner:GetPos(), 20000, 1, effectOwner )

                -- "echoey" ping
                effectOwner:EmitSound( beaconSoundPath, 150, math.random( 88, 91 ), 0.7, CHAN_STATIC )
                -- higher-pitched, but quieter ping
                effectOwner:EmitSound( beaconSoundPath, 120, math.random( 99, 101 ), 1, CHAN_STATIC )

                util.ScreenShake( effectOwner:GetPos(), 1, 20, 0.1, 1000 )

            end

            self:DoBeaconPing()

            self:Timer( "beacon_ping", beaconSoundInterval, 0, function() -- beep beep, beep beep
                if owner:Health() <= 0 then return end
                self:DoBeaconPing()

            end )
        end
    )


    local slipSound = Sound( "hunters_glee/482735__copyc4t__cartoon-long-throw.wav" )

    local function passesTheBpmTest( ply, added )
        added = added or 0
        return ply:GetNWInt( "termHuntPlyBPM" ) > math.random( 59, 300 + added )

    end

    GAMEMODE:RegisterStatusEffect( "greasy_hands",
        function( self, owner ) -- setup func
            self.queuedDrop = false

            function self:DropWeaponFunny( wep ) -- whoops! it slipped out of my hands!
                local effectOwner = self:GetOwner()
                effectOwner:EmitSound( slipSound, 78, math.random( 100, 110 ), 0.9 ) -- wee!

                timer.Simple( 0.1, function()
                    if not IsValid( effectOwner ) then return end
                    if not IsValid( wep ) then return end
                    if not effectOwner:HasWeapon( wep:GetClass() ) then return end
                    effectOwner:DropWeaponKeepAmmo( wep )

                end )
            end

            self:Hook( "PlayerSwitchWeapon", function( swapper, _, newWeapon ) -- drop on switch
                if swapper ~= owner then return end
                if owner:Health() <= 0 then return end

                if passesTheBpmTest( owner ) or self.queuedDrop then
                    if not owner:CanDropWeaponKeepAmmo( newWeapon ) then
                        self.queuedDrop = true
                        return

                    end
                    self.queuedDrop = false
                    self:DropWeaponFunny( newWeapon )

                end
            end )

            self:Timer( "check_firing", 0.75, 0, function() -- and drop when holding down an attack key!
                if owner:Health() <= 0 then return end

                if not owner:KeyDown( IN_ATTACK ) and not owner:KeyDown( IN_ATTACK2 ) then return end

                local wep = owner:GetActiveWeapon()

                if not owner:CanDropWeaponKeepAmmo( wep ) then return end
                if not passesTheBpmTest( owner, 100 ) then return end

                self:DropWeaponFunny( wep )

            end )
        end
    )


    GAMEMODE:RegisterStatusEffect( "high_cholesterol",
        function( self, owner ) -- setup func
            self:Hook( "huntersglee_restingbpmscale", function( ply ) -- increase resting bpm, so player gets stuck in heart attack range
                if ply ~= owner then return end
                local heartAttackScore = ply.glee_HeartAttackScore or 0
                if heartAttackScore > 100 then
                    return 3

                else
                    return 1.85

                end
            end )

            self:Hook( "huntersglee_blockpanicreset", function( ply ) --- prevent panic from resetting
                if ply ~= owner then return end
                local heartAttackScore = ply.glee_HeartAttackScore or 0
                if heartAttackScore > 100 then
                    return true

                end
            end )

            self:Hook( "huntersglee_getheartattackbpm", function( ply ) -- lower the heart attack threshold
                if ply ~= owner then return end
                return 150

            end )
        end
    )


    GAMEMODE:RegisterStatusEffect( "fish_lunged_sinker",
        function( self, owner ) -- setup func
            self:HookOnce( "glee_sv_drownbreathing_waterlevel", function( ply )
                if not ply:HasStatusEffect( "fish_lunged_sinker" ) then return end
                return ply:WaterLevel() >= 3 and 0 or 3
            end )

            self:HookOnce( "glee_sv_suppressswimpanic", function( ply )
                if not ply:HasStatusEffect( "fish_lunged_sinker" ) then return end
                if ply:WaterLevel() >= 3 then return true end
            end )

            self:HookOnce( "glee_sv_panicscream_waterlevel", function( ply )
                if not ply:HasStatusEffect( "fish_lunged_sinker" ) then return end
                return ply:WaterLevel() >= 3 and 0 or 3
            end )

            self:Timer( "fish_lunged_panic", 2, 0, function()
                if owner:WaterLevel() < 3 then
                    GAMEMODE:GivePanic( owner, 15 )
                end
            end )
        end,
        function( self, owner ) -- teardown func
            owner.glee_drowning = nil
            owner.glee_drowning_damagecount = nil

        end
    )


    -- fingers and the like are left out, too small to notice, and the pelvis is the root of everything
    local tumorBones = {
        "ValveBiped.Bip01_Neck1",
        "ValveBiped.Bip01_Spine",
        "ValveBiped.Bip01_Spine1",
        "ValveBiped.Bip01_Spine2",
        "ValveBiped.Bip01_Spine4",
        "ValveBiped.Bip01_L_Clavicle",
        "ValveBiped.Bip01_R_Clavicle",
        "ValveBiped.Bip01_L_UpperArm",
        "ValveBiped.Bip01_R_UpperArm",
        "ValveBiped.Bip01_L_Forearm",
        "ValveBiped.Bip01_R_Forearm",
        "ValveBiped.Bip01_L_Thigh",
        "ValveBiped.Bip01_R_Thigh",
        "ValveBiped.Bip01_L_Calf",
        "ValveBiped.Bip01_R_Calf",
        "ValveBiped.Bip01_L_Foot",
        "ValveBiped.Bip01_R_Foot",
    }

    local tumorManipKey = "the_growth"
    local tumorGrowInterval = {
        min = 8,
        max = 12,
    }
    local tumorGrowthPerStep = 0.02
    local tumorHurtsAboveScale = 1.4
    local tumorStepsBeforeHurting = math.Round( ( tumorHurtsAboveScale - 1 ) / tumorGrowthPerStep )
    local tumorFirstDamage = 2.5
    local tumorDamageRamp = 0.75
    local tumorMaxBloodEffects = 8
    local tumorSpreadsAboveDamage = 50

    GAMEMODE:RegisterStatusEffect( "the_growth",
        function( self, owner ) -- setup func
            function self:PickTumorBone()
                local available = {}
                for _, boneName in ipairs( tumorBones ) do
                    if owner:LookupBone( boneName ) then
                        available[#available + 1] = boneName

                    end
                end

                -- not a ValveBiped model, any bone will do
                if #available <= 0 then
                    for bone = 0, ( owner:GetBoneCount() or 0 ) - 1 do
                        available[#available + 1] = owner:GetBoneName( bone )

                    end
                end

                if #available <= 0 then
                    self.tumorBoneName = nil
                    return

                end

                self.tumorBoneName = available[math.random( 1, #available )]

            end

            function self:NewTumor()
                owner:RemoveBoneManips( tumorManipKey )
                self:PickTumorBone()
                self.tumorSteps = 0
                self.tumorDamageTicks = 0
                self.spreadTumorSteps = {}

            end

            -- spreading ignores tumorBones, anything but the root goes once it's this far gone
            function self:SpreadTumor()
                local available = {}
                for bone = 0, ( owner:GetBoneCount() or 0 ) - 1 do
                    local boneName = owner:GetBoneName( bone )
                    local isRoot = owner:GetBoneParent( bone ) < 0
                    if not isRoot and boneName ~= self.tumorBoneName and not self.spreadTumorSteps[boneName] then
                        available[#available + 1] = boneName

                    end
                end

                if #available <= 0 then return end

                self.spreadTumorSteps[available[math.random( 1, #available )]] = 0

            end

            function self:GrowTumor()
                self.tumorSteps = self.tumorSteps + 1

                -- looked up every time, the bone ids change when the model does
                local bone = self.tumorBoneName and owner:LookupBone( self.tumorBoneName )
                if not bone then
                    self:PickTumorBone()
                    bone = self.tumorBoneName and owner:LookupBone( self.tumorBoneName )
                    if not bone then return end

                end

                local scale = 1 + self.tumorSteps * tumorGrowthPerStep
                owner:RemoveBoneManips( tumorManipKey )
                owner:ApplyBoneScaleManip( tumorManipKey, bone, Vector( scale, scale, scale ) )

                for boneName, steps in pairs( self.spreadTumorSteps ) do
                    steps = steps + 1
                    self.spreadTumorSteps[boneName] = steps

                    local spreadBone = owner:LookupBone( boneName )
                    if spreadBone then
                        local spreadScale = 1 + steps * tumorGrowthPerStep
                        owner:ApplyBoneScaleManip( tumorManipKey, spreadBone, Vector( spreadScale, spreadScale, spreadScale ) )

                    end
                end

                if self.tumorSteps <= tumorStepsBeforeHurting then return end

                local damage = tumorFirstDamage + self.tumorDamageTicks * tumorDamageRamp

                if damage > tumorSpreadsAboveDamage then
                    self:SpreadTumor()

                end

                if self.lastDeathsHintedAt ~= owner:Deaths() then
                    self.lastDeathsHintedAt = owner:Deaths()
                    huntersGlee_Announce( { owner }, 50, 5, "Your growth...\nIt's consuming you..." )

                end

                if damage > 10 and self.lastDeathsBigHintedAt ~= owner:Deaths() then
                    self.lastDeathsBigHintedAt = owner:Deaths()
                    huntersGlee_Announce( { owner }, 50, 5, "oh GOD, your growth...\nit hurts" )

                end

                local bonePos = owner:GetBonePosition( bone ) or owner:WorldSpaceCenter()
                local bloodColor = owner:GetBloodColor()
                local bloodCount = math.min( math.ceil( damage ), tumorMaxBloodEffects )
                for _ = 1, bloodCount do
                    local edata = EffectData()
                    edata:SetOrigin( bonePos )
                    edata:SetColor( bloodColor )
                    edata:SetNormal( VectorRand() )
                    edata:SetEntity( owner )
                    util.Effect( "BloodImpact", edata )

                end

                local dmgInfo = DamageInfo()
                dmgInfo:SetDamage( damage )
                dmgInfo:SetAttacker( game.GetWorld() )
                dmgInfo:SetInflictor( game.GetWorld() )
                dmgInfo:SetDamageType( DMG_DIRECT )
                owner:TakeDamageInfo( dmgInfo )

                GAMEMODE:GivePanic( owner, damage * 2.5 )

                self.tumorDamageTicks = self.tumorDamageTicks + 1

            end

            self:NewTumor()

            self:Hook( "glee_true_PlayerSpawn", function( spawned )
                if spawned ~= owner then return end
                self:NewTumor()

            end )

            self:Timer( "grow_tumor", math.Rand( tumorGrowInterval.min, tumorGrowInterval.max ), 0, function()
                if owner:Health() <= 0 then return end
                self:GrowTumor()

            end )
        end,
        function( _self, owner ) -- teardown func
            owner:RemoveBoneManips( tumorManipKey )

        end
    )


    local bigHeadManipKey = "big_head"
    local bigHeadScale = Vector( 2.5, 2.5, 2.5 )
    local bigHeadSpeedModifier = -25

    GAMEMODE:RegisterStatusEffect( "big_head",
        function( self, owner ) -- setup func
            function self:ApplyBigHead()
                owner:RemoveBoneManips( bigHeadManipKey )
                if self.jiggledBone then
                    owner:ManipulateBoneJiggle( self.jiggledBone, 0 )

                end

                local headBone = owner:LookupBone( "ValveBiped.Bip01_Head1" )
                self.jiggledBone = headBone
                if not headBone then return end

                owner:ApplyBoneScaleManip( bigHeadManipKey, headBone, bigHeadScale )
                owner:ManipulateBoneJiggle( headBone, 1 )

            end

            self:ApplyBigHead()
            owner:DoSpeedModifier( bigHeadManipKey, bigHeadSpeedModifier )

            self:Hook( "PlayerSpawn", function( spawned )
                if spawned ~= owner then return end

                -- hooks run before GM:PlayerSpawn sets the model, and the head's bone id can change with it
                timer.Simple( 0, function()
                    if not IsValid( owner ) then return end
                    if not owner:HasStatusEffect( "big_head" ) then return end
                    self:ApplyBigHead()

                end )
            end )
        end,
        function( self, owner ) -- teardown func
            owner:DoSpeedModifier( bigHeadManipKey, nil )
            owner:RemoveBoneManips( bigHeadManipKey )
            if self.jiggledBone then
                owner:ManipulateBoneJiggle( self.jiggledBone, 0 )

            end
        end
    )


    local function canSeePlayer( ply, other )
        local trace = util.TraceLine( {
            start = ply:GetShootPos(),
            endpos = other:GetShootPos(),
            mask = MASK_BLOCKLOS,
            filter = { ply, other },
        } )
        return not trace.Hit

    end

    local panicTickInterval = 0.5
    local noticeablePanic = GAMEMODE.PanicDrainPerSecond * panicTickInterval -- any less per tick is outpaced by drain

    local socialAnxietyRadius = 600
    local socialAnxietyPanicPerPly = 6 -- per tick, at point blank

    GAMEMODE:RegisterStatusEffect( "social_anxiety",
        function( self, owner ) -- setup func
            self:Timer( "crowded_panic", panicTickInterval, 0, function()
                if owner:Health() <= 0 then return end

                local myPos = owner:GetShootPos()
                local panic = 0
                for _, other in player.Iterator() do
                    if other == owner then continue end
                    if other:Health() <= 0 then continue end

                    local dist = other:GetShootPos():Distance( myPos )
                    if dist > socialAnxietyRadius then continue end
                    if not canSeePlayer( owner, other ) then continue end

                    panic = panic + socialAnxietyPanicPerPly * ( 1 - dist / socialAnxietyRadius )

                end

                GAMEMODE:GivePanic( owner, panic )

                if panic >= noticeablePanic and self.lastDeathsHintedAt ~= owner:Deaths() then
                    self.lastDeathsHintedAt = owner:Deaths()
                    huntersGlee_Announce( { owner }, 50, 5, "Someone else...\nThey make me feel, anxious..." )

                end

            end )
        end
    )


    local bodyOdorRadius = 350
    local bodyOdorPanic = 8 -- per tick, at point blank

    GAMEMODE:RegisterStatusEffect( "body_odor",
        function( self, owner ) -- setup func
            self.victimDeathsHintedAt = {}

            self:Timer( "stink_panic", panicTickInterval, 0, function()
                if owner:Health() <= 0 then return end

                local myPos = owner:GetShootPos()
                for _, other in player.Iterator() do
                    if other == owner then continue end
                    if other:Health() <= 0 then continue end

                    local dist = other:GetShootPos():Distance( myPos )
                    if dist > bodyOdorRadius then continue end
                    if not canSeePlayer( owner, other ) then continue end

                    local panic = bodyOdorPanic * ( 1 - dist / bodyOdorRadius )
                    GAMEMODE:GivePanic( other, panic )

                    if panic < noticeablePanic then continue end

                    if self.victimDeathsHintedAt[other] ~= other:Deaths() then
                        self.victimDeathsHintedAt[other] = other:Deaths()
                        huntersGlee_Announce( { other }, 50, 5, "Ugh...\n" .. owner:Nick() .. " reeks." )

                    end

                    if self.lastDeathsHintedAt ~= owner:Deaths() then
                        self.lastDeathsHintedAt = owner:Deaths()
                        huntersGlee_Announce( { owner }, 50, 5, "They can smell you...\nNobody can stand to be near you." )

                    end
                end
            end )
        end
    )


    local abandonmentRadius = 1250
    local abandonmentGrace = 10
    local abandonmentRamp = 0.1 -- panic per tick, per second abandoned past the grace
    local abandonmentMinPanic = noticeablePanic * 0.75
    local abandonmentMaxPanic = 8

    GAMEMODE:RegisterStatusEffect( "abandonment_anxiety",
        function( self, owner ) -- setup func
            self.lastHadCompany = CurTime()

            self:Hook( "glee_true_PlayerSpawn", function( spawned )
                if spawned ~= owner then return end
                self.lastHadCompany = CurTime()

            end )

            self:Timer( "abandoned_panic", panicTickInterval, 0, function()
                if owner:Health() <= 0 then return end

                local myPos = owner:GetShootPos()
                for _, other in player.Iterator() do
                    if other == owner then continue end
                    if other:Health() <= 0 then continue end
                    if other:GetShootPos():Distance( myPos ) > abandonmentRadius then continue end
                    if not canSeePlayer( owner, other ) then continue end

                    self.lastHadCompany = CurTime()
                    return

                end

                local abandonedFor = CurTime() - self.lastHadCompany - abandonmentGrace
                if abandonedFor <= 0 then return end

                local panic = math.Clamp( abandonedFor * abandonmentRamp, abandonmentMinPanic, abandonmentMaxPanic )
                GAMEMODE:GivePanic( owner, panic )

                if panic >= noticeablePanic and self.lastDeathsHintedAt ~= owner:Deaths() then
                    self.lastDeathsHintedAt = owner:Deaths()
                    huntersGlee_Announce( { owner }, 50, 5, "Where did everyone go...?\nDid they abandon you?!" )

                end

            end )
        end
    )
end

if CLIENT then
    local stinkAlpha = 40
    local stinkOwnAlpha = 25 -- the owner's eyes are in the middle of it

    GAMEMODE:RegisterStatusEffect( "body_odor",
        function( self, owner ) -- setup func
            self.emitter = ParticleEmitter( owner:GetPos() )

            self:Timer( "waft_stink", 0.3, 0, function()
                if not IsValid( owner ) then return end
                if owner:IsDormant() then return end
                if owner:Health() <= 0 then return end

                local outward = VectorRand()
                outward.z = 0
                outward:Normalize()

                local mins, maxs = owner:OBBMins(), owner:OBBMaxs()
                local origin = owner:LocalToWorld( Vector(
                    math.Rand( mins.x, maxs.x ),
                    math.Rand( mins.y, maxs.y ),
                    math.Rand( mins.z, maxs.z )
                ) )
                self.emitter:SetPos( origin )

                local particle = self.emitter:Add( "particle/particle_smokegrenade1", origin )
                if not particle then return end

                local alpha = owner == GetViewEntity() and stinkOwnAlpha or stinkAlpha

                particle:SetVelocity( outward * math.Rand( 10, 25 ) + Vector( 0, 0, math.Rand( 10, 20 ) ) )
                particle:SetDieTime( math.Rand( 3, 5 ) )
                particle:SetColor( 120, 160, 50 )
                particle:SetStartAlpha( alpha )
                particle:SetEndAlpha( 0 )
                particle:SetStartSize( 8 )
                particle:SetEndSize( 30 )
                particle:SetRoll( math.Rand( -360, 360 ) )
                particle:SetRollDelta( math.Rand( -1, 1 ) * 2 )
                particle:SetAirResistance( 10 )
                particle:SetCollide( false )

            end )
        end,
        function( self, _ ) -- teardown func
            self.emitter:Finish()

        end
    )
end


-- shared to keep prediciton happy
local function theHopsCommand( ply, mvData )
    if not ply:HasStatusEffect( "the_hops" ) then return end

    if not ply:IsOnGround() then return end

    -- the engine only jumps on a fresh press, so IN_JUMP comes back out of the old buttons
    mvData:SetButtons( bit.bor( mvData:GetButtons(), IN_JUMP ) )
    mvData:SetOldButtons( bit.band( mvData:GetOldButtons(), bit.bnot( IN_JUMP ) ) )

end

GAMEMODE:RegisterStatusEffect( "the_hops",
    function( self, _owner ) -- setup func
        self:HookOnce( "Move", theHopsCommand )

    end
)


hook.Add( "glee_shop_canpurchase", "glee_shoptags_astralprojection", function( purchaser, itemData )
    if not purchaser:HasStatusEffect( "astrallyprojected" ) then return end
    if itemData.tags.SelfResurrecting then return false, "Astral Projection only goes one way..." end

end )

if SERVER then
    -- cannot respawn
    GAMEMODE:RegisterStatusEffect( "astrallyprojected",
        function( self, owner ) -- setup func
            self:HookOnce( "glee_block_respawn", function( ply ) -- block respawn
                if not ply:HasStatusEffect( "astrallyprojected" ) then return end
                return true

            end )

            if not owner:GetNW2Bool( "IsBeingWitnessed", true ) then return end

            GAMEMODE:DropAllWeapons( owner )

            owner:ScreenFade( SCREENFADE.OUT, Color( 0, 0, 0, 255 ), 1, 0 )

            timer.Simple( 1, function()
                if not IsValid( owner ) then return end

                local ragdoll = ents.Create( "prop_ragdoll" )
                if IsValid( ragdoll ) then

                    ragdoll.glee_isAstralprojectionRagdoll = true

                    ragdoll:SetMaxHealth( 100 )
                    ragdoll:SetHealth( 100 )

                    ragdoll:SetModel( owner:GetModel() )
                    ragdoll:SetPos( owner:GetPos() )
                    ragdoll:SetAngles( owner:GetAngles() )
                    ragdoll:Spawn()

                    owner:CopyBoneManipsTo( ragdoll )

                    -- Ragdolls only have physics objects for SOME bones (not all of them).
                    -- TranslatePhysBoneToBone maps physics-bone-index → model bone index,
                    -- so we iterate physics objects and look up the player bone for each one.
                    local physCount = ragdoll:GetPhysicsObjectCount()
                    for physBoneID = 0, physCount - 1 do
                        local currPhysObj = ragdoll:GetPhysicsObjectNum( physBoneID )
                        if not IsValid( currPhysObj ) then continue end

                        local boneID = ragdoll:TranslatePhysBoneToBone( physBoneID )
                        local bonePos, boneAng = owner:GetBonePosition( boneID )
                        if not bonePos then continue end

                        currPhysObj:SetPos( bonePos )
                        currPhysObj:SetAngles( boneAng )

                    end

                    GAMEMODE:HandleRagdollSkulling( ragdoll )

                    ragdoll:SetNW2Entity( "glee_astralprojection_ragdoll_owner", owner )
                    ragdoll:SetNWString( "glee_lookedat_statusline", "Just sleeping..." )

                    ragdoll.GetPlayerColor = function()
                        return owner:GetPlayerColor()

                    end
                    ragdoll.Nick = function()
                        return owner:Nick()

                    end
                end

                owner:KillSilent()

            end )

            self:HookOnce( "glee_ragdollskulldecapitated", function( ragdoll, skull )
                if not ragdoll.glee_isAstralprojectionRagdoll then return end

                ragdoll:SetNWString( "glee_lookedat_statusline", "Dead." )

                GAMEMODE:PanicSource( skull:GetPos(), 75, 200 )

            end )
        end
    )
else
    -- cannot respawn
    local backupPlyColor = Vector( 1, 1, 1 )
    GAMEMODE:RegisterStatusEffect( "astrallyprojected",
        function( self, _owner ) -- setup func
            self:HookOnce( "glee_block_respawn", function( ply ) -- block respawn
                if not ply:HasStatusEffect( "astrallyprojected" ) then return end
                return true

            end )
            self:HookOnce( "EntityNetworkedVarChanged", function( ent, valname, _, new )
                if valname ~= "glee_astralprojection_ragdoll_owner" then return end
                ent.GetPlayerColor = function()
                    local owner = ent:GetNW2Entity( "glee_astralprojection_ragdoll_owner" )
                    if not IsValid( owner ) then return backupPlyColor end
                    return owner:GetPlayerColor()

                end
                ent.Nick = function()
                    local owner = ent:GetNW2Entity( "glee_astralprojection_ragdoll_owner" )
                    if not IsValid( owner ) then return "???" end
                    return owner:Nick()

                end
                timer.Simple( 0, function()
                    if not IsValid( ent ) then return end
                    hook.Run( "glee_cl_proxyhud_pleasepaintthis", ent )

                end )

                if not IsValid( new ) then return end -- owner
                ent.glee_PlayerNameColorOverride = GAMEMODE:GetTeamColor( new )

            end )
        end
    )
end


-- blindness stuff
-- this is how you do clientside effects btw
-- server auths it, applies some shared effects
-- and the client just follows that
if CLIENT then
    local util_PointContents    = util.PointContents
    local surface_SetDrawColor  = surface.SetDrawColor
    local surface_DrawRect      = surface.DrawRect
    local ScrW                 = ScrW
    local ScrH                 = ScrH

    local skyOverrideMat = Material( "model/debugwhite" )
    local vecZero = Vector( 0, 0, 0 )
    local skyOverridePos = Vector( 0, 0, 200 )
    local skyOverrideColor = Color( 0, 0, 0 )
    local tiltedVecs = {
        Vector( 0.25, 0, -0.75 ),
        Vector( -0.25, 0, -0.75 ),
        Vector( 0, 0.25, -0.75 ),
        Vector( 0, -0.25, -0.75 ),

    }
    local vecUp = Vector( 0, 0, 1 )

    GAMEMODE:RegisterStatusEffect( "blindness",
        function( self, owner ) -- setup func
            if LocalPlayer() ~= owner then return end

            self:Hook( "PreDrawHUD", function() -- darken everything
                if owner:Health() <= 0 then return end

                local alpha = 230

                if bit.band( util_PointContents( EyePos() ), CONTENTS_WATER ) ~= 0 then -- fog is broken underwater
                    alpha = 255

                end

                surface_SetDrawColor( 0, 0, 0, alpha )
                surface_DrawRect( -ScrW(), -ScrH(), ScrW() * 2, ScrH() * 2 )

            end )

            self:Hook( "PostDraw2DSkyBox", function() -- block off the skybox
                if owner:Health() <= 0 then return end

                render.OverrideDepthEnable( true, false ) -- ignore Z to prevent drawing over 3D skybox

                -- Start 3D cam centered at the origin
                cam.Start3D( vecZero, EyeAngles() )
                    for _, tiltedVec in ipairs( tiltedVecs ) do
                        render.SetMaterial( skyOverrideMat )
                        render.DrawQuadEasy( skyOverridePos, tiltedVec, 32000, 32000, skyOverrideColor, 0 )

                    end
                    render.DrawQuadEasy( -skyOverridePos, vecUp, 32000, 32000, skyOverrideColor, 0 )

                cam.End3D()

                render.OverrideDepthEnable( false, false )

            end )

            local blindnessFog = function( scale ) -- and apply fog
                if owner:Health() <= 0 then return end

                scale = scale or 0.9

                render.FogMode( MATERIAL_FOG_LINEAR )
                render.FogStart( 50 * scale )
                render.FogEnd( 200 * scale )
                render.FogMaxDensity( 1 )
                render.FogColor( 0,0,0 )

                return true

            end

            self:Hook( "SetupWorldFog", blindnessFog )
            self:Hook( "SetupSkyboxFog", blindnessFog )

        end
    )
end
if SERVER then
    GAMEMODE:RegisterStatusEffect( "blindness",
        function( self, owner ) -- setup func
            function self:MakeEyesCloudy() -- replace player's eye materials with "cloudy" mat
                local submats = owner:GetMaterials()
                local eyeMats = {}
                for id, matName in ipairs( submats ) do
                    if not string.find( matName, "eyeball" ) then continue end
                    eyeMats[id] = matName

                end
                for id, _ in pairs( eyeMats ) do
                    owner:SetSubMaterial( id - 1, "shadertest/seamless8" )

                end
            end

            function self:RestoreEyes() -- restore original eye materials
                local submats = owner:GetMaterials()
                local eyeMats = {}
                for id, matName in ipairs( submats ) do
                    if not string.find( matName, "eyeball" ) then continue end
                    eyeMats[id] = matName

                end
                for id, _ in pairs( eyeMats ) do
                    owner:SetSubMaterial( id - 1, "" ) -- empty string restores original

                end
            end

            self:MakeEyesCloudy()
            self.OwnersOldModel = owner:GetModel()

            self:Hook( "Think", function()
                local currModel = owner:GetModel()
                if currModel == self.OwnersOldModel then return end
                self.OwnersOldModel = currModel

                if owner:Health() <= 0 then return end

                timer.Simple( 0, function()
                    self:RestoreEyes()
                    self:MakeEyesCloudy()

                end )
            end )

            self:HookOnce( "PlayerSpawn", function( spawned )
                if not spawned:HasStatusEffect( "blindness" ) then return end
                timer.Simple( 0, function()
                    if not IsValid( spawned ) then return end
                    self:RestoreEyes()
                    self:MakeEyesCloudy()

                end )
            end )
        end,
        function( self, _ ) -- teardown func
            self:RestoreEyes()

        end
    )
end


local function bloodDonorCanPurchase( purchaser )
    if purchaser:Health() <= 1 then return false, "You don't have any blood to donate!" end
    return true, ""

end

local function bloodDonorCalc( purchaser )
    local beginningHealth = purchaser:Health()
    local remainingHealth = beginningHealth - 100
    remainingHealth = math.Clamp( remainingHealth, 1, math.huge )

    local scoreGiven = math.abs( beginningHealth - remainingHealth ) * 1.5
    scoreGiven = math.ceil( scoreGiven )

    return scoreGiven, remainingHealth

end

local function bloodDonorCost( purchaser )
    return -bloodDonorCalc( purchaser )

end


local items = {
    -- Risk vs reward.
    ["blooddonor"] = {
        name = "Donate Blood.",
        desc = "Donate blood for score." .. GAMEMODE.glee_BargainDescrip,
        shCost = bloodDonorCost,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_ACTIVE, -- only purchasble when actively hunting, otherwise people would heal with cheap preround healthkits
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, bloodDonorCanPurchase },
        svOnPurchaseFunc = function( purchaser )
            local scoreGiven, remainingHealth = bloodDonorCalc( purchaser )

            GAMEMODE:Bleed( purchaser, scoreGiven )

            purchaser:GivePlayerScore( scoreGiven )

            purchaser:SetHealth( remainingHealth )
            purchaser.glee_LastSetHealthReason = "glee_blood_donor"

            for _ = 0, 2 do
                shopHelpers.playRandomSound( purchaser, shopHelpers.thwaps, 75, math.random( 100, 120 ) )

            end
        end,
    },
    ["deafness"] = {
        name = "Hard of Hearing.",
        desc = "You can barely hear a thing!" .. GAMEMODE.glee_BargainDescrip,
        shCost = -100,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "deafness" )

        end,
    },
    -- flat DOWNGRADE
    ["blindness"] = {
        name = "Legally Blind.",
        desc = "Become unable to see more than a few feet ahead." .. GAMEMODE.glee_BargainDescrip,
        shCost = -300,
        markup = 0.2,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "blindness" )

        end,
    },
    -- increased bpm but you get heart attacks easier
    ["highcholesterol"] = {
        name = "37 Years of\nCholesterol",
        desc = "All that delicious food, clogging everything up...\nYour heart beats much faster, but Heart Attacks may strike..." .. GAMEMODE.glee_BargainDescrip,
        shCost = -175,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -80,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "high_cholesterol" )

        end,
    },
    -- hilarious downgrade
    ["greasyhands"] = {
        name = "Greasy Hands.",
        desc = "Eating greasy food all your life,\nyour hands... adapted to their new, circumstances...\nUnder stress, the grease flows like a faucet." .. GAMEMODE.glee_BargainDescrip,
        shCost = -200,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -80,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "greasy_hands" )

        end,
    },
    -- flat downgrade
    ["badknees"] = {
        name = "62 Year old Knees.",
        desc = "62 years of living a sedentary lifestyle.\nJumping hurts, and is relatively useless.\nFall damage is lethal." .. GAMEMODE.glee_BargainDescrip,
        shCost = -162,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "bad_knees" )

        end,
    },
    ["beacon"] = {
        name = "Beacon",
        desc = "A beacon.\nThe hunters will never lose you for long." .. GAMEMODE.glee_BargainDescrip,
        shCost = -140,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        shCanShowInShop = shopHelpers.terminatorInSpawnPool,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "beacon" )

        end,
    },
    ["astralprojection"] = {
        name = "Astral Projection",
        desc = "Astrally project yourself.",
        shCost = -350,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        shCanShowInShop = shopHelpers.hasMultiplePeople,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "astrallyprojected" )

        end,
    },
    -- you know what that means
    ["fishlungedsinker"] = {
        name = "Fish Lunged Sinker.",
        desc = "Your lungs have adapted to the wrong medium.\nAir chokes you. Water does not." .. GAMEMODE.glee_BargainDescrip,
        shCost = -500,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "fish_lunged_sinker" )

        end,
    },
    ["thegrowth"] = {
        name = "The Growth",
        desc = "Acquire an unstable genome.\nYou will grow a... companion, every life..." .. GAMEMODE.glee_BargainDescrip,
        shCost = -200,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "the_growth" )

        end,
    },
    ["thehops"] = {
        name = "The Hops.",
        desc = "Your legs will never rest again.\nYou hop the moment you touch the ground, forever." .. GAMEMODE.glee_BargainDescrip,
        shCost = -75,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "the_hops" )

        end,
    },
    ["bighead"] = {
        name = "Big Head.",
        desc = "Your intellect has lead to your head becoming the size of a small refrigerator!" .. GAMEMODE.glee_BargainDescrip,
        shCost = -150,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        shCanShowInShop = shopHelpers.hasMultiplePeople,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "big_head" )

        end,
    },
    ["socialanxiety"] = {
        name = "Social Anxiety.",
        desc = "People make you nervous.\nPanic when anyone gets close." .. GAMEMODE.glee_BargainDescrip,
        shCost = -150,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        slots = { "sociability" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        shCanShowInShop = shopHelpers.hasMultiplePeople,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "social_anxiety" )

        end,
    },
    ["terriblebodyodor"] = {
        name = "Terrible Body Odor.",
        desc = "You reek.\nAnyone near you panics." .. GAMEMODE.glee_BargainDescrip,
        shCost = -150,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        shCanShowInShop = shopHelpers.hasMultiplePeople,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "body_odor" )

        end,
    },
    ["abandonmentanxiety"] = {
        name = "Abandonment Anxiety.",
        desc = "You have a potent fear of being alone.\nPanic when nobody's nearby." .. GAMEMODE.glee_BargainDescrip,
        shCost = -150,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "MUTATIONS", "Debuff", "Bargain", "Essential" },
        slots = { "sociability" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck, },
        shCanShowInShop = shopHelpers.hasMultiplePeople,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "abandonment_anxiety" )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )
