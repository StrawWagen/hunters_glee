
local shopHelpers = GAMEMODE.shopHelpers
local cvarBase = "huntersglee_bargain_"
local cvarFlags = FCVAR_ARCHIVE + FCVAR_REPLICATED

local defaultOfferCount = 3
local cvarOfferCount = CreateConVar( cvarBase .. "huntersglee_bargainoffercount", -1, cvarFlags, "The number of bargains to offer to each player per round. -1 for default, " .. defaultOfferCount, 0, 256 )

local function getOfferCount()
    local offerCount = cvarOfferCount:GetInt()
    if offerCount == -1 then
        offerCount = defaultOfferCount

    end

    return offerCount

end

GAMEMODE.glee_BargainOffersPerPly = GAMEMODE.glee_BargainOffersPerPly or {} -- [ply] = { [shopItemName] = true, __count = count, }

-- appended on the end of all bargain items' descriptions
local bargainDescrip = "\n\nThis is a bargain. You might not see it again..."


-- returns offerTbl, calledReset
-- sets up and networks the bargain table to players when they request it
local function getOfferTbl( ply )
    local offerTbl = GAMEMODE.glee_BargainOffersPerPly[ ply ]
    if not offerTbl then
        offerTbl = { __count = 0, }
        GAMEMODE.glee_BargainOffersPerPly[ ply ] = offerTbl

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
    return getOfferTbl( ply )[ itemID ] or false

end


-- Bargain offer reset
if SERVER then
    util.AddNetworkString( "glee_bargainoffers" )

    local function networkOffers( ply )
        local tbl = GAMEMODE.glee_BargainOffersPerPly[ ply ]
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

        local items = shopHelpers.getItemsByTag( "Bargain" )

        local offersLeft = math.min( offerCount, #items )
        offerTbl.__count = offersLeft

        while offersLeft > 0 do
            local item = table.remove( items, math.random( 1, #items ) )
            offerTbl[ item.identifier ] = true
            offersLeft = offersLeft - 1
            PrintTable( item )
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
            offerTbl[ net.ReadString() ] = true

        end

    end )

end


-- Only show bargains that are on offer.
hook.Add( "glee_shop_canshow", "glee_shopitems_bargainoffers", function( ply, itemData )
    if not itemData.tags.Bargain then return end -- Not a bargain, don't care.
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
                    local soundP = awfulKneeSounds[ math.random( 1, #awfulKneeSounds ) ]
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
                    local soundP = awfulKneeSounds[ math.random( 1, #awfulKneeSounds ) ]
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


    local slipSound = Sound( "482735__copyc4t__cartoon-long-throw.wav" )

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
            self:Hook( "PlayerSpawn", function( ply )
                if ply ~= owner then return end
                timer.Simple( 0, function() -- next frame
                    if not IsValid( ply ) then return end
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

    local scoreGiven = math.abs( beginningHealth - remainingHealth ) * 1.15
    scoreGiven = math.ceil( scoreGiven )

    return scoreGiven, remainingHealth

end

local function bloodDonorCost( purchaser )
    return -bloodDonorCalc( purchaser )

end


local items = {
    -- Risk vs reward.
    [ "blooddonor" ] = {
        name = "Donate Blood.",
        desc = "Donate blood for score." .. bargainDescrip,
        shCost = bloodDonorCost,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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

            for _ = 0, 2 do
                shopHelpers.playRandomSound( purchaser, shopHelpers.thwaps, 75, math.random( 100, 120 ) )

            end
        end,
    },
    [ "deafness" ] = {
        name = "Hard of Hearing.",
        desc = "You can barely hear a thing!" .. bargainDescrip,
        shCost = -75,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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
    [ "blindness" ] = {
        name = "Legally Blind.",
        desc = "Become unable to see more than a few feet ahead." .. bargainDescrip,
        shCost = -240,
        markup = 0.2,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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
    [ "highcholesterol" ] = {
        name = "37 Years of\nCholesterol",
        desc = "Your body is weak, your heart, clogged...\nA lifetime of eating absolutely delicious food, has left you unprepared for The Hunt...\nYour heart beats much faster.\nBut you become succeptible to Heart Attacks." .. bargainDescrip,
        shCost = -140,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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
    [ "greasyhands" ] = {
        name = "Greasy Hands.",
        desc = "Eating greasy food all your life,\nyour hands... adapted to their new, circumstances...\nUnder stress, the grease flows like a faucet." .. bargainDescrip,
        shCost = -160,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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
    [ "badknees" ] = {
        name = "62 Year old Knees.",
        desc = "62 years of living a sedentary lifestyle.\nJumping hurts, and is relatively useless.\nFall damage is lethal." .. bargainDescrip,
        shCost = -140,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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
    [ "beacon" ] = {
        name = "Beacon",
        desc = "A beacon.\nThe hunters will never lose you for long." .. bargainDescrip,
        shCost = -120,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff", "Bargain" },
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
}

GAMEMODE:GobbleShopItems( items )
