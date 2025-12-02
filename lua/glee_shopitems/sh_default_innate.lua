
local shopHelpers = GAMEMODE.shopHelpers

if SERVER then

    local speedBoostBeginsAt = 95
    local bpmToSpeedScale = 4

    GAMEMODE:RegisterStatusEffect( "cold_blooded",
        function( self, owner ) -- setup func
            self:Timer( "manage_coldblooded", 0.1, 0, function() -- adjust speed based on heartrate
                local BPM = owner:GetNWInt( "termHuntPlyBPM" ) or 60
                local usefulBPM = BPM - speedBoostBeginsAt
                usefulBPM = usefulBPM * bpmToSpeedScale

                owner:DoSpeedModifier( "coldblooded", usefulBPM )

            end )
        end,
        function( _, owner ) -- teardown func, disables the speedmodifier
            owner:DoSpeedModifier( "coldblooded", nil )

        end
    )


    GAMEMODE:RegisterStatusEffect( "superior_metabolism",
        function( self, owner ) -- setup func
            self:Hook( "huntersglee_heartbeat_beat", function( ply ) -- heal a bit on each heartbeat
                if ply ~= owner then return end

                local amount = 1

                local newHealth = math.Clamp( owner:Health() + amount, 0, owner:GetMaxHealth() )
                owner:SetHealth( newHealth )

            end )
        end
    )


    GAMEMODE:RegisterStatusEffect( "deafness",
        function( self, owner ) -- setup func
            owner.glee_IsDeaf = true

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
        function( self, owner ) -- teardown func
            self:UnDeafInternal()
            owner.glee_IsDeaf = false

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
            owner:SetJumpPower( self.originalJumpPower * 0.70 )

            self:Hook( "GetFallDamage", function( ply, speed ) -- crazy high fall damage
                if ply ~= owner then return end

                for count = 1, 4 do
                    local soundP = awfulKneeSounds[ math.random( 1, #awfulKneeSounds ) ]
                    ply:EmitSound( soundP, 70, math.random( 70, 80 + count * 4 ), 1, CHAN_STATIC )

                end

                return speed

            end )

            self:Hook( "KeyPress", function( ply, key ) -- funny sounds and pain on jump
                if ply ~= owner then return end
                if key ~= IN_JUMP then return end

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


    GAMEMODE:RegisterStatusEffect( "witness_me",
        function( self, owner ) -- setup func
            function self:PowerfulDeath( attacker ) -- amped up death with lots of extra effects
                if not IsValid( owner ) then return end
                if not IsValid( attacker ) then return end

                GAMEMODE:Bleed( owner, math.huge )

                game.SetTimeScale( 0.4 )
                util.ScreenShake( owner:GetPos(), 10, 0.1, 3, 5000, true )
                for _ = 0, 4 do
                    shopHelpers.playRandomSound( owner, shopHelpers.thwaps, 150, math.random( 20, 40 ) )

                end

                if owner:Health() > 0 then -- handle the "ensured death"
                    -- instant death
                    local damage = DamageInfo()
                    damage:SetDamage( 5000000 )
                    damage:SetDamagePosition( owner:WorldSpaceCenter() )
                    damage:SetDamageForce( terminator_Extras.dirToPos( attacker:GetShootPos(), owner:GetShootPos() ) * 200000000 )
                    damage:SetAttacker( attacker )
                    damage:SetInflictor( attacker )
                    damage:SetDamageType( DMG_CLUB )
                    owner:TakeDamageInfo( damage )

                end

                attacker:FireBullets( { -- shoot a hull bullet to break anything in the way
                    Attacker = attacker,
                    Damage = 5000000,
                    Force = 0,
                    HullSize = 64,
                    Num = 1,
                    Src = attacker:GetShootPos(),
                    Dir = terminator_Extras.dirToPos( attacker:GetShootPos(), owner:GetShootPos() ),
                    Spread = vector_zero,
                    Tracer = 0,
                    IgnoreEntity = attacker,

                } )
            end

            self.additionalHooksName = "glee_witnesseddeathconfirm_" .. owner:SteamID()

            owner.AttackConfirmed = function( owner, attacker ) -- this is called inside term shooting_handler task
                if not attacker or not owner then return end
                if GAMEMODE.roundExtraData.witnessed == true then return end
                if attacker:GetEnemy() ~= owner then return end
                if not terminator_Extras.PosCanSee( attacker:GetShootPos(), owner:GetShootPos(), MASK_SOLID_BRUSHONLY ) then return end

                local witnessing = {}

                local purchaseShootPos = owner:GetShootPos()
                for _, ply in ipairs( player.GetAll() ) do
                    if ply == owner then continue end
                    if not terminator_Extras.PosCanSee( purchaseShootPos, ply:GetShootPos(), MASK_SOLID_BRUSHONLY ) then continue end
                    table.insert( witnessing, ply )

                end

                local witnessingCount = #witnessing

                if witnessingCount <= 0 then -- no witnesses :(
                    local nextInvalidWitness = owner.nextInvalidWitness or 0
                    if nextInvalidWitness > CurTime() then return end -- don't spam
                    owner.nextInvalidWitness = CurTime() + 1
                    owner:EmitSound( "ambient/machines/thumper_hit.wav", 90, 80, 0.5 )
                    owner:EmitSound( "weapons/fx/nearmiss/bulletltor07.wav", 90, 80, 0.3 )
                    huntersGlee_Announce( { owner }, 5, 4, "There is nobody to witness your fate..." )
                    return

                end

                huntersGlee_Announce( witnessing, 20, 10, "YOU WITNESS " .. string.upper( owner:Nick() ) )

                -- s OR not s
                local SorNotS = ""
                local SorNotSOpp = "S"

                if #witnessing > 1 then
                    SorNotS = "S"
                    SorNotSOpp = ""

                end
                huntersGlee_Announce( { owner }, 25, 15, #witnessing .. " SOUL" .. SorNotS .. " BARE" .. SorNotSOpp .. " WITNESS TO YOUR FATE" )

                local scorePerWitness = 250
                local score = witnessingCount * scorePerWitness

                score = math.Clamp( score, 0, math.huge )
                owner:GivePlayerScore( score )

                -- magic variable that forces term bots to aim at this entity
                attacker.OverrideShootAtThing = owner

                -- dont fire early!
                attacker:BlockWeaponFiringUntil( CurTime() + 0.39 )

                -- ONE witness per round
                GAMEMODE.roundExtraData.witnessed = true

                -- can't be an effect:Hook, that one is only added on effect setup, and we're well past that now
                -- scale all damage from the attacker, let them destroy anything in the way
                hook.Add( "EntityTakeDamage", self.additionalHooksName, function( target, dmgInfo )
                    local attackerEnt = dmgInfo:GetAttacker()
                    if not IsValid( attackerEnt ) then return end
                    if attackerEnt ~= attacker then return end

                    dmgInfo:ScaleDamage( 1000 )
                    local dmgForce = dmgInfo:GetDamageForce() or terminator_Extras.dirToPos( attackerEnt:GetShootPos(), target:GetShootPos() )
                    dmgForce = dmgForce * 500
                    dmgInfo:SetDamageForce( dmgForce )

                end )

                -- we leave a big gap between bot primary attacking, and forcing the player to die
                -- hopefully this means the bot kills them with their weapon, not the ensured death
                hook.Add( "PlayerDeath", self.additionalHooksName, function( died )
                    if died ~= owner then return end
                    self:PowerfulDeath( attacker )

                end )

                -- ookay effects time

                util.ScreenShake( owner:GetPos(), 0.5, 20, 3, 5000, true )
                owner:EmitSound( "ambient/machines/thumper_hit.wav", 150, 40, 0.5 )

                -- slow down time! 
                game.SetTimeScale( 0.2 )

                -- even weak bots get to throw strong crobars for this
                attacker.gleeWitness_OldThrowingForceMul = attacker.ThrowingForceMul
                attacker.ThrowingForceMul = ( attacker.ThrowingForceMul or 1000 ) * 1000

                -- ATTACK!!!!!
                timer.Simple( 0.4, function()
                    if not IsValid( attacker ) then return end
                    if not IsValid( owner ) then return end

                    attacker.gleeWitness_OldCanWeaponPrimaryAttack = attacker.CanWeaponPrimaryAttack
                    attacker.CanWeaponPrimaryAttack = function() return true end -- FIRE

                    local primaryWeapon = attacker:GetActiveLuaWeapon()
                    if IsValid( primaryWeapon ) then
                        primaryWeapon.gleeWitness_OldCanPrimaryAttack = primaryWeapon.CanPrimaryAttack
                        primaryWeapon.CanPrimaryAttack = function() return true end -- FIRE FIRE FIRE FIRE

                    end

                    attacker:WeaponPrimaryAttack()

                    -- thank u 
                    attacker.CanWeaponPrimaryAttack = attacker.gleeWitness_OldCanWeaponPrimaryAttack
                    if IsValid( primaryWeapon ) and primaryWeapon.gleeWitness_OldCanPrimaryAttack then
                        primaryWeapon.CanPrimaryAttack = primaryWeapon.gleeWitness_OldCanPrimaryAttack
                        primaryWeapon.gleeWitness_OldCanPrimaryAttack = nil

                    end

                    owner:EmitSound( "weapons/fx/nearmiss/bulletltor07.wav", 150, 80, 0.3 )

                end )

                -- the "big gap"

                -- ENSURE DEATH
                -- really funny how this makes bots with cameras instakill people
                timer.Simple( 2, function()
                    if not IsValid( owner ) then return end
                    if owner:Health() <= 0 then return end -- they already died!
                    self:PowerfulDeath( attacker )

                end )

                -- cleanup time
                timer.Simple( 2.5, function()
                    if IsValid( attacker ) then
                        attacker.OverrideShootAtThing = nil
                        attacker.ThrowingForceMul = attacker.gleeWitness_OldThrowingForceMul
                        attacker.gleeWitness_OldThrowingForceMul = nil

                    end
                    hook.Remove( "EntityTakeDamage", self.additionalHooksName )
                    hook.Remove( "PlayerDeath", self.additionalHooksName )
                    game.SetTimeScale( 1 )

                end )

                -- play echo sound to all witnesses
                timer.Simple( 3, function()
                    if not IsValid( owner ) then return end
                    local witnessFilter = RecipientFilter()

                    for _, witness in ipairs( witnessing ) do
                        if not IsValid( witness ) then continue end
                        if witness == owner then continue end
                        if not terminator_Extras.PosCanSee( witness:GetShootPos(), owner:GetShootPos(), MASK_SOLID_BRUSHONLY ) then continue end
                        witnessFilter:AddPlayer( witness )

                    end
                    owner:EmitSound( "ambient/atmosphere/thunder3.wav", 150, 65, 1, CHAN_STATIC, 0, 0, witnessFilter )

                end )
            end
        end,
        function( _, owner ) -- teardown func
            owner.AttackConfirmed = nil

        end
    )


    GAMEMODE:RegisterStatusEffect( "juggernaut",
        function( self, owner ) -- setup func

            function self:ApplyJuggernaut()
                local currentHealthRatio = owner:Health() / owner:GetMaxHealth()

                local newMaxHealth = ( owner.Glee_BaseHealth or 100 ) * 5 -- 500 by default
                local newHealth = newMaxHealth * currentHealthRatio

                owner:SetMaxHealth( newMaxHealth )
                owner:SetHealth( newHealth )

                owner:DoSpeedClamp( "juggernautclamp", 0 ) -- blocks speed modifiers from increasing speed beyond normal sprint speed

            end

            self:ApplyJuggernaut()

            self:Hook( "PlayerSpawn", function( spawned )
                if spawned ~= owner then return end

                timer.Simple( 0.1, function()
                    if not IsValid( owner ) then return end
                    if not owner:HasStatusEffect( "juggernaut" ) then return end

                    self:ApplyJuggernaut()

                end )
            end )

            self:Hook( "PlayerFootstep", function( ply, _, foot ) -- clomp clomp
                if ply ~= owner then return end

                local target = 0
                if foot == 0 then
                    target = math.random( 1, 3 )

                elseif foot == 1 then
                    target = math.random( 4, 6 )

                end

                local stepSnd = "npc/metropolice/gear" .. target .. ".wav"

                local velLeng = ply:GetVelocity():Length()

                util.ScreenShake( ply:GetPos(), velLeng / 150, 20, 0.6, velLeng * 1.5 )

                local pitch = 60 + ( velLeng / 30 )
                local volume = 0.2 + ( velLeng / 600 )
                ply:EmitSound( stepSnd, 90, pitch, volume, CHAN_AUTO )
                ply:EmitSound( "npc/headcrab_poison/ph_wallhit2.wav", 90, math.random( 70, 90 ), 0.2, CHAN_STATIC )

                return true

            end )
        end,
        function( _, owner ) -- teardown func
            owner:DoSpeedClamp( "juggernautclamp", nil )
            owner.isJuggernaut = nil

        end
    )

    GAMEMODE:RegisterStatusEffect( "chameleon",
        function( self, owner ) -- setup func
            function self:Chameleonize()
                owner:Fire( "alpha", 20, 0 )
                owner:SetRenderMode( RENDERMODE_TRANSALPHA )

            end
            function self:UnChameleonize()
                owner:Fire( "alpha", 255, 0 )
                owner:SetRenderMode( RENDERMODE_NORMAL )

            end

            self.chameleonColorRestore = chameleonColorRestore

            self:Chameleonize()

            self:Timer( "manageChamelonize",0.1, 0, function()
                if owner:Health() <= 0 then return end
                if owner:GetColor().a == 20 then return end

                self:Chameleonize()

            end )

            self:Hook( "EntityTakeDamage", function( target, dmg )
                if target ~= owner then return end
                if owner:Health() <= 0 then return end

                dmg:ScaleDamage( 2 )
                target:EmitSound( "Cardboard.Break" )
                if target.glee_chameleonHint then return end
                target.glee_chameleonHint = true

                huntersGlee_Announce( { target }, 15, 4, "Ouch! Chameleon skin is weak!" )

            end )
        end,
        function( self, owner ) -- teardown func
            owner.glee_chameleonHint = nil
            self:UnChameleonize()
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
                surface_DrawRect( -ScrW() * 0.5, -ScrH() * 0.5, ScrW(), ScrH() )

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


-- sixth sense stuff
if CLIENT then
    local LocalPlayer   = LocalPlayer
    local CurTime       = CurTime
    local IsValid       = IsValid
    local VectorRand    = VectorRand

    local function sortForClosestTo( sortPos, stuffToSort )
        if #stuffToSort <= 1 then return stuffToSort end
        table.sort( stuffToSort, function( a, b )
            if not IsValid( b ) then return end
            if not IsValid( a ) then return end
            local aDist = a:GetPos():DistToSqr( sortPos )
            local bDist = b:GetPos():DistToSqr( sortPos )
            return aDist < bDist

        end )
        return stuffToSort
    end

    local sixthSenseHunter = Color( 255, 0, 0 )
    local sixthSenseItem = Color( 0, 255, 0 )
    local sixthSensePlayer = Color( 0, 0, 255 )

    local maxDistance = 5000

    GAMEMODE:RegisterStatusEffect( "sixth_sense",
        function( self, owner ) -- setup func
            if LocalPlayer() ~= owner then return end

            self.armor = {}
            self.slams = {}
            self.skulls = {}
            self.medkits = {}
            self.hunters = {}
            self.players = {}
            self.ar2Balls = {}
            self.bearTraps = {}
            self.scoreBalls = {}
            self.itemCrates = {}
            self.sixthSenseStuff = {}
            self.nextCache = 0
            self.nextSort = 0

            self:Hook( "HUDPaint", function()
                if owner:Health() <= 0 then return end
                if not owner:GetNWBool( "huntersglee_hassixthsense", false ) then return end

                local curTime = CurTime()

                -- big find!
                if self.nextCache < curTime then
                    self.nextCache = curTime + 2

                    self.armor = ents.FindByClass( "item_battery" )
                    self.slams = ents.FindByClass( "npc_tripmine" )
                    self.skulls = ents.FindByClass( "termhunt_skull_pickup" )

                    self.medkits = ents.FindByClass( "item_healthkit" )
                    table.Add( self.medkits, ents.FindByClass( "item_healthvial" ) )

                    self.players = ents.FindByClass( "player" )
                    self.hunters = ents.FindByClass( "terminator_nextbot*" )

                    self.ar2Balls = ents.FindByClass( "item_ammo_ar2_altfire" )

                    self.bearTraps = ents.FindByClass( "termhunt_bear_trap" )

                    self.scoreBalls = ents.FindByClass( "termhunt_score_pickup" )
                    self.itemCrates = ents.FindByClass( "item_item_crate" )

                -- sort em and filter for stuff we actually care bout
                elseif self.nextSort < curTime then
                    self.nextSort = curTime + 0.5

                    table.Empty( self.sixthSenseStuff )

                    local myPos = owner:GetPos()

                    if owner:Armor() < owner:GetMaxArmor() then
                        table.Add( self.sixthSenseStuff, self.armor )

                    end
                    if owner:Health() < owner:GetMaxHealth() then
                        table.Add( self.sixthSenseStuff, self.medkits )

                    end
                    if IsValid( owner:GetWeapon( "weapon_ar2" ) ) then
                        table.Add( self.sixthSenseStuff, self.ar2Balls )

                    end

                    -- laggyyyyy but its on client and staggered :)
                    table.Add( self.sixthSenseStuff, self.skulls )
                    table.Add( self.sixthSenseStuff, self.slams )
                    table.Add( self.sixthSenseStuff, self.hunters )
                    table.Add( self.sixthSenseStuff, self.players )
                    table.Add( self.sixthSenseStuff, self.bearTraps )
                    table.Add( self.sixthSenseStuff, self.scoreBalls )
                    table.Add( self.sixthSenseStuff, self.itemCrates )

                    self.sixthSenseStuff = sortForClosestTo( myPos, self.sixthSenseStuff )

                end

                local myPos = owner:GetShootPos()
                local shown = 0
                local sharedColor = Color( 255, 255, 255, 255 ) -- just 1 color object!

                for _, sensed in ipairs( self.sixthSenseStuff ) do -- put the blobs on stuff!
                    if shown > 25 then return end
                    if not IsValid( sensed ) then continue end
                    if sensed == owner then continue end

                    local sensedPos = sensed:WorldSpaceCenter()
                    local distance = sensedPos:Distance( myPos )

                    if distance > maxDistance then break end

                    local reversedDistance = maxDistance - distance
                    reversedDistance = math.abs( reversedDistance )

                    local unknownAlphaBite = 0 -- make stuff have less alpha when we dont see it for a while
                    local oldPos = sensed.sixthSenseOldPos or sensedPos
                    local randomScale = distance / 50
                    if sensed:IsDormant() or ( sensed.IsHomeless and not sensed:IsSolid() ) then
                        sensed.glee_sixthsense_wasdormant = true
                        sensedPos = oldPos
                        randomScale = randomScale * 0.75

                        local lastRealSeen = sensed.glee_sixthsense_lastRealSeen or 0
                        if lastRealSeen ~= 0 then
                            local timeSinceLastSeen = curTime - lastRealSeen
                            unknownAlphaBite = timeSinceLastSeen / 45

                        end
                    else
                        sensed.glee_sixthsense_lastRealSeen = curTime
                        if sensed.glee_sixthsense_wasdormant then
                            sensed.glee_sixthsense_wasdormant = nil
                            sensed.glee_sixthsense_revealed = nil

                        end
                    end

                    local sixthSenseColor = sixthSenseItem
                    local spriteSize = 50

                    local classOfSensed = sensed:GetClass()
                    local suspicious = string.find( classOfSensed, "disguised" )

                    --gregori
                    if sensed:GetNW2Bool( "isdivinechosen", nil ) then
                        if sensed:Health() <= 0 then continue end
                        sixthSenseColor = sixthSenseHunter
                        spriteSize = 200

                    -- baad item!
                    elseif classOfSensed == "termhunt_bear_trap" or classOfSensed == "npc_tripmine" then
                        if distance > 2000 then continue end
                        sixthSenseColor = sixthSenseHunter

                        local terror = reversedDistance + -( maxDistance * 0.8 )
                        terror = terror / 2
                        terror = terror^1.04

                        spriteSize = terror

                    -- baad thing!
                    elseif sensed:IsNPC() or sensed:IsNextBot() or sensed:GetNW2Bool( "glee_IsHunter", false ) and not ( suspicious and not sensed.glee_sixthsense_revealed and math.random( 0, 300 ) < distance ) then
                        if sensed:Health() <= 0 then continue end
                        sixthSenseColor = sixthSenseHunter

                        local overwhelmingTerror = reversedDistance + -( maxDistance * 0.75 )
                        overwhelmingTerror = math.max( overwhelmingTerror, 1 )
                        overwhelmingTerror = overwhelmingTerror^1.16

                        randomScale = randomScale + overwhelmingTerror / 18
                        spriteSize = 150 + overwhelmingTerror

                        local scaryness = GAMEMODE:GetBotScaryness( owner, sensed ) -- makes blobs bigger/smaller when low health, or when enemy is really weak
                        randomScale = randomScale * scaryness
                        spriteSize = spriteSize * scaryness

                        if suspicious then
                            sensed.glee_sixthsense_revealed = true

                        end

                    -- player, always a player, never a sus player!
                    elseif sensed:IsPlayer() or suspicious then
                        if sensed:Health() <= 0 then continue end
                        sixthSenseColor = sixthSensePlayer
                        spriteSize = 100

                    end

                    -- handle the pos smoothing and randomization
                    local newPos = sensedPos + ( VectorRand() * randomScale )
                    local posSmoothed = ( newPos * 0.08 ) + ( oldPos * 0.92 )
                    local imprecisePos = posSmoothed
                    sensed.sixthSenseOldPos = posSmoothed

                    local pos2d = imprecisePos:ToScreen()
                    local opaqueWhenClose = ( ( reversedDistance / maxDistance ) * 2 ) + -unknownAlphaBite

                    sharedColor.r = sixthSenseColor.r * opaqueWhenClose
                    sharedColor.g = sixthSenseColor.g * opaqueWhenClose
                    sharedColor.b = sixthSenseColor.b * opaqueWhenClose
                    local centeringOffset = -spriteSize / 2

                    local texturedQuadStructure = {
                        texture = surface.GetTextureID( "sprites/light_glow02_add_noz" ),
                        color   = sharedColor,
                        x       = pos2d.x + centeringOffset,
                        y       = pos2d.y + centeringOffset,
                        w       = spriteSize,
                        h       = spriteSize
                    }

                    draw.TexturedQuad( texturedQuadStructure )

                    shown = shown + 1

                end
            end )
        end
    )

end
if SERVER then
    GAMEMODE:RegisterStatusEffect( "sixth_sense",
        function( self, owner ) -- setup func
            owner:SetNWBool( "huntersglee_hassixthsense", true )
            owner.glee_hasSixthSense = true

            self:Hook( "terminator_spotenemy", function( term, spotted ) -- play arresting sound when an enemy spots us
                if spotted ~= owner then return end
                if not owner.glee_hasSixthSense then return end

                local nextSound = owner.glee_nextSixthSenseSpottedSound or 0
                if nextSound > CurTime() then return end

                local scaryness = GAMEMODE:GetBotScaryness( owner, term )
                if scaryness < 0.7 then return end -- not scary, zzzzzzzzz

                owner.glee_nextSixthSenseSpottedSound = CurTime() + 30

                local distance = owner:GetPos():Distance( term:GetPos() )

                if distance > 800 * scaryness then
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 140, 0.7, CHAN_STATIC )
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 180, 0.5, CHAN_STATIC )
                    GAMEMODE:GivePanic( owner, 30 * scaryness )

                else
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 100, 0.7, CHAN_STATIC )
                    owner:EmitSound( "ambient/levels/canals/windmill_wind1.wav", 70, 40, 0.5, CHAN_STATIC )
                    GAMEMODE:GivePanic( owner, 60 * scaryness )

                end
            end )

            self:Hook( "terminator_enemythink", function( term, theThingWhoIsEnemy ) -- give panic when an enemy has its eyes on us
                if theThingWhoIsEnemy ~= owner then return end
                if not owner.glee_hasSixthSense then return end

                local nextSixthSenseTrackingPanic = owner.glee_nextSixthSenseTrackingPanic or 0
                if nextSixthSenseTrackingPanic > CurTime() then return end

                -- dont do like a billion of these events
                owner.glee_nextSixthSenseTrackingPanic = CurTime() + 1

                local distance = term:GetPos():Distance( owner:GetPos() )
                local scaryness = GAMEMODE:GetBotScaryness( owner, term )

                -- extra scary if very very close
                if scaryness >= 0.7 and distance < 350 then
                    GAMEMODE:GivePanic( owner, 100 * scaryness )

                end

                -- scary if close
                if distance < 500 then
                    GAMEMODE:GivePanic( owner, 12 * scaryness )

                -- if they have LOS on us, or are nearby
                elseif distance < 1000 or term.IsSeeEnemy then
                    GAMEMODE:GivePanic( owner, 8 * scaryness )

                end
            end )
        end,
        function( _, owner ) -- teardown func
            owner:SetNWBool( "huntersglee_hassixthsense", false )
            owner.glee_hasSixthSense = nil
            owner.glee_nextSixthSenseSpottedSound = nil
            owner.glee_nextSixthSenseTrackingPanic = nil

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
        desc = "Donate blood for score.",
        shCost = bloodDonorCost,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
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
        desc = "You can barely hear a thing!",
        shCost = -75,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "deafness" )

        end,
    },
    -- flat DOWNGRADE
    [ "blindness" ] = {
        name = "Legally Blind.",
        desc = "Become unable to see more than a few feet ahead.",
        shCost = -240,
        markup = 0.2,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "blindness" )

        end,
    },
    -- increased bpm but you get heart attacks easier
    [ "highcholesterol" ] = {
        name = "37 Years of\nCholesterol",
        desc = "Your body is weak, your heart, clogged...\nA lifetime of eating absolutely delicious food, has left you unprepared for The Hunt...\nYour heart beats much faster.\nBut you become succeptible to Heart Attacks.",
        shCost = -140,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "high_cholesterol" )

        end,
    },
    -- hilarious downgrade
    [ "greasyhands" ] = {
        name = "Greasy Hands.",
        desc = "Eating greasy food all your life,\nyour hands... adapted to their new, circumstances...\nUnder stress, the grease flows like a faucet.",
        shCost = -160,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "greasy_hands" )

        end,
    },
    -- flat downgrade
    [ "badknees" ] = {
        name = "62 Year old Knees.",
        desc = "62 years of living a sedentary lifestyle.\nJumping hurts, and is relatively useless.\nFall damage is lethal.",
        shCost = -140,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "bad_knees" )

        end,
    },
    [ "beacon" ] = {
        name = "Beacon",
        desc = "A beacon.\nThe hunters will never lose you for long.",
        shCost = -120,
        markup = 0.25,
        cooldown = math.huge,
        tags = { "INNATE", "Debuff" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "beacon" )

        end,
        shCanShowInShop = shopHelpers.terminatorInSpawnPool,
    },
    -- this is to give the noobs in a lobby a huge score boost, also it's cool
    [ "witnessme" ] = {
        name = "Witness Me.",
        desc = "You die instantly to hunters if you have any witnesses.\nDead players can bear witness\nGain 250 score per witness.\nOnly happens once per round.",
        shCost = 30,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = -100,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "witness_me" )

        end,
        shCanShowInShop = shopHelpers.multiplePeopleAndTerm,
    },
    [ "coldblooded" ] = {
        name = "Cold Blooded.",
        desc = "Your top speed is linked to your heartrate.",
        shCost = 150,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "cold_blooded" )

        end,
    },
    -- flat upgrade
    [ "superiormetabolism" ] = {
        name = "Superior Metabolism.",
        desc = "You've always been different than those around you.\nWhat would hospitalize others for weeks, passed over you in days.\nYou regenerate health as your heart beats.",
        shCost = 200,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "superior_metabolism" )

        end,
    },
    [ "sixthsense" ] = {
        name = "Sixth Sense.",
        desc = "You gain a sixth sense.\nYou innately know where things are.\nBut the sixth sense can be overwhelming.\nPanic will mount as the hunters close in.",
        shCost = 225,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "sixth_sense" )

        end,
    },
    -- flat upgrade
    [ "juggernaut" ] = {
        name = "Juggernaut",
        desc = "Attain a new level of physique.\nYour footsteps are loud and bulky.\nYou cannot move quicker with Augmentations\nMax 500 health.",
        shCost = 350,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 120,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "juggernaut" )

        end,
    },
    -- Risk vs reward.
    [ "chameleon" ] = {
        name = "Chameleon Gene",
        desc = "Become nearly invisible.\nYour chameleon skin can't take a beating, you take twice as much damage.\nYour weapons, and flashlight are still visible.",
        shCost = 350,
        markup = 2,
        cooldown = math.huge,
        tags = { "INNATE" },
        purchaseTimes = {
            GAMEMODE.ROUND_INACTIVE,
            GAMEMODE.ROUND_ACTIVE,
        },
        weight = 85,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = function( ply )
            ply:GiveStatusEffect( "chameleon" )

        end,
    },
}

GAMEMODE:GobbleShopItems( items )