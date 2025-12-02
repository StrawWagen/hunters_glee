-- yes, this is my ideas file too

-- officially announce modding support
-- change workshop icon
-- add gifs to workshop page

-- glee exists to entertain the CEOS
-- CEOS are stupid and crony
-- some CEOS ( goals ) work on small navmeshes
-- when round starts players can pick which ceo they like
-- all ceos work on big navmeshes
-- each ceo has a stupid and FUNNY! quota that players have to do to win
-- eg, olive branch, one person has to pay 10k to win
-- CEOS IS A GIMMICK, NOT GONNA DO IT!!

-- placables need to use run on key -- done
-- boot player from shop when they buy a placable -- done
-- door locker is fucked -- done
-- make beacon supplies simpler -- done
-- wasd kicks out of spectate -- done
-- standardize +- placable hud stuff -done
-- flares are SUPER LAGGYYYYY -- done
-- fix the broken dice -- DONE!
-- dead people can hear alive global? -- done
-- barrels sweet spot? -- done

-- DO THESE!

-- ignore locked doors have been proven as unpathable -done
    -- build ignored list, whenever we bash a door, clear the list -DONE
-- fix bot jumping when bashing doors - DONE
-- polish bot handling wierd jumps - DONE
-- make bot avoid where it was damaged - DONME 
-- expect sweps to have a hint function - DONE
    -- pre / post hint stack funcs? - DONE
-- give all glee sweps hints -- DONE

-- chameleon gene makes you take 2x damage -done
-- switch to generic procedural spawner -DONE
-- replace killfeed -no

-- SIMPLIFY RADIO!!! --DONE!
-- make tab menu opaque when alive --DONE!
-- same with kill feed -DONE

-- true goal
    -- skulls spawn when people die -- DONE
    -- skulls persist thru rounds -- DONE
    -- terminators drop metal skulls ( when not dissolved! ), worth 2x skulls -- DONE
    -- if map has skulls in it, use those first -- DONE
    -- plys drop 10% of their skulls when they die as finest prey -- DONE!

    -- highlight player with most skulls -- done
    -- add sounds for finest prey stealing! -- DONE!
    -- use score as tiebreaker in finest prey -- DONE
    -- make skull hints not stupid -- DONE!
    -- above undone

-- charge system
    -- use suit energy as battery -DONE
    -- makes damage even scarier
    -- spawn with 60 suit energy -DONE
    -- remove flashlight, binoculars items -DONE
    -- make them always work when you have suit energy instead -- DONE
    -- radio uses suit battery -- DONE

-- fov decrease with panic! -DONE! -- undone
-- make radio only transmit when held in hand -NO!

-- make nailer bit stronger -done

-- make alive players not be able to see text chats from the dead --done

-- revenge/friendly items
-- curse, "Homicidal Glee" -DONE
    -- undead player buys, can only place on people who killed them, makes them dance -DONE

-- overcharge terminator undead item? -- DONE
-- bear trap PASS -- DONE!!!

-- spawn waves
    -- only spawn terminators when all die or after x minutes --done
    -- linked hunter random spawn --done!
-- dont respawn next to people you have homicided -- DONE!
-- does bot over-predict when people juke it towards it --no, done

-- pull nails rclick? --NO

-- do intro if 1 player online and its their first time --DONE!
-- check brutalist kfc doors -- DONE

-- only withdraw/deposit when round is starting / player is dead --done
-- make all undead evil items cost 2x --doneish

-- check lag compensation on all npcs -- done
-- do the los check for bot unstucker --done

-- overcharged bots throw with sonic boom --done
-- bot avoid damaging ents idea, needs path building pass. -- done
-- bot placing of slams + beartrap --done

-- Replace stupid temp bools with ints, polish conduit/inversion cooldowns
-- fix stupid visual immortalizer bug -- done?

-- blessing -- done
    -- crappier version of immortality
    -- but it lasts like minutes
-- fix balls infinite money --no
-- give notifs when people break your crates/barrels? --no
-- PULL ALL SPECTATORS TO GRIGORI -- done

-- effigy
-- pushes dead people away, makes them look away
-- steals their money when they get close, or aim near it
-- make homicidal glee cost more

-- loan

-- server-based leaderboard
-- quickest to 10 skulls
-- most skulls
-- flat, most hunter kills
-- most skulls, additive ( all players skulls in one session, added up )

-- radio draw channel instead of ammo

-- ghostly wind undead item
-- ttt button replacement
-- barrels scoring confusing

-- bhop perk?

local shopHelpers = GM.shopHelpers

local sv_cheats = GetConVar( "sv_cheats" )

local function isCheats()
    return sv_cheats:GetBool()

end


-- put here so we are not rebuilding a static table
local frogLegsJumpSounds = {
    "npc/barnacle/barnacle_tongue_pull1.wav",
    "npc/barnacle/barnacle_tongue_pull2.wav",
    "npc/barnacle/barnacle_tongue_pull3.wav"
}

local function frogLegsPurchase( purchaser )
    -- We'll use this variable to track whether the player owns the item
    purchaser.hasFrogLegs = true

    local function giveFrogLegs( personWhoHasFrogLegs )
        personWhoHasFrogLegs:DoSpeedModifier( "froglegs", -100 )
        personWhoHasFrogLegs.canWallkick = true
        personWhoHasFrogLegs.parkourForce = 1.25

    end

    -- This function undoes what we do
    local function frogLegsRestore( personWhoHasFrogLegs )
        personWhoHasFrogLegs:DoSpeedModifier( "froglegs", nil )
        -- Remove this variable so the hooks delete themselves 
        personWhoHasFrogLegs.hasFrogLegs = nil
        personWhoHasFrogLegs.froglegsPrimedJump = nil
        personWhoHasFrogLegs.canWallkick = nil
        personWhoHasFrogLegs.parkourForce = nil

    end

    local hookName = "huntersglee_froglegs" .. purchaser:GetCreationID()

    hook.Add( "PlayerSpawn", hookName, function( spawned )
        timer.Simple( 0.1, function()
            if not IsValid( spawned ) then return end
            if not IsValid( purchaser ) then hook.Remove( "PlayerSpawn", hookName ) return end
            if spawned ~= purchaser then return end
            if not purchaser.hasFrogLegs then hook.Remove( "PlayerSpawn", hookName ) return end

            giveFrogLegs( purchaser )

        end )
    end )

    hook.Add( "GetFallDamage", hookName, function( ply, speed )
        if not IsValid( purchaser ) then hook.Remove( "GetFallDamage", hookName ) return end
        if ply ~= purchaser then return end
        if not ply.hasFrogLegs then hook.Remove( "GetFallDamage", hookName ) return end

        local dmg = speed / 60
        dmg = dmg + -15
        if dmg < 0 then
            ply:EmitSound( "npc/barnacle/barnacle_bark1.wav", 78, math.random( 70, 90 ) + -dmg * 2, 0.3 )
            return 0

        end

        dmg = dmg * 2 -- if we get past the check, punish player

        return dmg

    end )

    -- do this so we can run code when the purchaser jumps
    hook.Add( "KeyPress", hookName, function( ply, key )
        if not IsValid( purchaser ) then hook.Remove( "KeyPress", hookName ) return end
        if ply ~= purchaser then return end
        if not ply.hasFrogLegs then hook.Remove( "KeyPress", hookName ) return end

        if key == IN_DUCK and ply:OnGround() and not ply.froglegsPrimedJump then
            ply.froglegsPrimedJump = true
            ply:EmitSound( "weapons/bugbait/bugbait_squeeze3.wav", 78, math.random( 110, 120 ), 0.6, CHAN_STATIC )

        end

        if key ~= IN_JUMP then return end

        if not ply:OnGround() then return end
        if ply:WaterLevel() >= 3 then return end

        timer.Simple( 0, function()
            if not IsValid( ply ) then return end

            local pitchOff = 0
            local scalar = 150
            if ply:Crouching() then
                if  ply.froglegsPrimedJump then
                    ply.froglegsPrimedJump = nil
                    scalar = 350
                    pitchOff = -20

                else
                    scalar = 75

                end
            end

            local dir = ply:GetVelocity():GetNormalized()
            dir.z = math.Clamp( dir.z, -0.15, 0.15 )
            dir:Normalize()
            local vel = dir * scalar
            ply:SetVelocity( vel )

            local theSound = frogLegsJumpSounds[ math.random( 1, #frogLegsJumpSounds ) ]
            ply:EmitSound( theSound, 78, math.random( 180, 200 ) + pitchOff, 1, CHAN_STATIC )

        end )
    end )

    -- only give them once all the above code hasn't errored
    giveFrogLegs( purchaser )

    local undoInnate = function( respawner )
        frogLegsRestore( respawner )

    end

    -- This function cleans up the shop item when a new round is started, or the map is cleaned up.
    -- The first variable is nil because it's usually a unique identifier for a timer, and this shop item doesn't use one.
    -- The function works even if the var is nil
    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end

--[[local function mimicMadnessPurchase( purchaser )
    -- We'll use this variable to track whether the player owns the item
    purchaser.hasMimicMadness = true
    purchaser.originalMimicModel = purchaser:GetModel()

    local function mimicPropIsValid( prop )
        if not IsValid( prop.playerOwner ) then return end
        if prop.playerOwner:Health() <= 0 then return end
        if not prop.playerOwner.gleeIsMimic then return end
        return true

    end

    local function startMimicPropManagment( propToTimer )
        if not IsValid( propToTimer ) then return end
        if not mimicPropIsValid( propToTimer ) then SafeRemoveEntity( propToTimer ) return end
        local timerKey = "huntersglee_mimicpropmanagingtimer_" .. propToTimer:GetCreationID()

        local hookKey = "huntersglee_mimicpropmanaginghook_" .. propToTimer:GetCreationID()

        hook.Add( "EntityTakeDamage", hookKey, function( target, dmg )
            if not IsValid( propToTimer ) then hook.Remove( "EntityTakeDamage", hookKey ) return end
            if not mimicPropIsValid( propToTimer ) then hook.Remove( "EntityTakeDamage", hookKey ) return end
            if target ~= propToTimer then return end

            target.playerOwner:TakeDamage( dmg:GetDamage() / 3 )

        end )

        timer.Create( timerKey, 0, 0, function()
            if not IsValid( propToTimer ) then timer.Remove( timerKey ) return end
            if not mimicPropIsValid( propToTimer ) then
                timer.Remove( timerKey )
                SafeRemoveEntity( propToTimer )
                return

            end
            propToTimer:SetPos( propToTimer:GetOwner():WorldSpaceCenter() )
            propToTimer:DropToFloor()
            propToTimer:GetPhysicsObject():Sleep()

        end )
    end

    local function getMimicAngles( ply )
        local propAng = ply:GetAimVector():Angle()
        propAng.p = 0
        propAng.r = 0

        return propAng

    end

    local function nukeWeapon( ply )
        local weap = ply:GetActiveWeapon()
        local shove = "termhunt_shove"
        if IsValid( weap ) and weap:GetClass() ~= shove then
            ply:SelectWeapon( shove )
            ply:DrawViewModel( false, 0 )

        end
    end

    local function turnIntoProp( ply )
        local nearestProp = ply.mimicNearestProp
        local nearestDist = 300^2

        for _, ent in ipairs( ents.FindInSphere( ply:GetPos(), 300 ) ) do
            local obj = ent:GetPhysicsObject()
            if string.find( ent:GetClass(), "prop" ) and obj and obj:IsValid() and not IsValid( ent.playerOwner ) and not ent.isDoorDamageListener and ent:IsSolid() then
                local dist = ply:GetPos():DistToSqr( ent:GetPos() )
                if dist < nearestDist then
                    nearestDist = dist
                    nearestProp = ent
                end
            end
        end

        if IsValid( nearestProp ) then
            local modelRad = nearestProp:GetModelRadius()

            -- doesn't work with concave ents, w/e
            local trInfo = {
                start = nearestProp:GetPos() + vector_up * modelRad * 2,
                endpos = nearestProp:GetPos() + -vector_up * modelRad * 2,
                ignoreworld = true,
                filter = function( ent ) if ent == nearestProp then return true end return false end,
            }
            local result = util.TraceLine( trInfo )

            local surfaceProps = result.SurfaceProps
            local surfaceData = util.GetSurfaceData( surfaceProps )
            local morphedSound = surfaceData.impactHardSound
            ply.unMimicMorphSound = surfaceData.impactSoftSound

            ply:EmitSound( morphedSound )
            ply:Fire( "alpha", 0, 0 )
            ply:SetRenderMode( RENDERMODE_TRANSALPHA )

            local propAng = getMimicAngles( ply )

            theMimicPropOnTop = ents.Create( "prop_physics" )
            ply.theMimicPropOnTop = theMimicPropOnTop

            theMimicPropOnTop:SetPos( ply:WorldSpaceCenter() )
            theMimicPropOnTop:SetAngles( propAng )
            theMimicPropOnTop:SetModel( nearestProp:GetModel() )
            theMimicPropOnTop:SetSkin( nearestProp:GetSkin() )
            theMimicPropOnTop:SetOwner( ply )
            theMimicPropOnTop:Spawn()

            theMimicPropOnTop:SetNotSolid( true )

            ply.theMimicPropOnTop.playerOwner = ply

            timer.Simple( 0.1, function()
                if not IsValid( theMimicPropOnTop ) then return end
                theMimicPropOnTop:DropToFloor()
                theMimicPropOnTop:GetPhysicsObject():Sleep()

                startMimicPropManagment( ply.theMimicPropOnTop )

            end )
            ply.oldMimicWeapon = nil
            if IsValid( ply:GetActiveWeapon() ) then
                ply.oldMimicWeapon = ply:GetActiveWeapon():GetClass()

            end

            nukeWeapon( ply )

            ply:SpectateEntity( theMimicPropOnTop )
            ply:SetObserverMode( OBS_MODE_CHASE )

            ply.mimicNearestProp = nearestProp
            ply.gleeIsMimic = true
        end
    end

    local function turnBackToPlayer( ply )
        if not IsValid( ply ) then return end

        if ply.gleeIsMimic then
            ply:SetModel( ply.originalMimicModel )
            local unMorphSound = ply.unMimicMorphSound
            if not unMorphSound then
                unMorphSound = "Wood_Box.ImpactHard"

            end

            if ply:Health() > 0 then
                ply:UnSpectate()
                ply:SetObserverMode( OBS_MODE_NONE )

                ply:DrawViewModel( true, 0 )
                if ply.oldMimicWeapon then
                    ply:SelectWeapon( ply.oldMimicWeapon )

                end
            end

            ply:Fire( "alpha", 255, 0 )
            ply:SetRenderMode( RENDERMODE_NORMAL )

            ply:EmitSound( unMorphSound, 75, 100, 0.1, CHAN_STATIC )
        end

        if IsValid( ply.theMimicPropOnTop ) then
            SafeRemoveEntity( ply.theMimicPropOnTop )

        end

        ply.unMimicMorphSound = nil
        ply.gleeIsMimic = nil
    end

    local timerName = "mimicmadness_timer_" .. tostring( purchaser:GetCreationID() )

    timer.Create( timerName, 0.1, 0, function()
        if not IsValid( purchaser ) then timer.Remove( timerName ) return end
        if not purchaser.hasMimicMadness then timer.Remove( timerName ) return end

        local mimicWithBustedProp = purchaser.gleeIsMimic and not IsValid( purchaser.theMimicPropOnTop )
        local ducking = purchaser:KeyDown( IN_DUCK ) and purchaser:OnGround()
        local wasDucking = purchaser.glee_MimicWasDucking
        local firstDuck = ducking and not wasDucking

        local jumping = purchaser:KeyDown( IN_JUMP )
        local wasJumping = purchaser.glee_MimicWasJumping
        local firstJump = jumping and not wasJumping

        if purchaser.gleeIsMimic then
            nukeWeapon( purchaser )

            if firstJump or purchaser:Health() <= 0 or mimicWithBustedProp then
                turnBackToPlayer( purchaser )

                if mimicWithBustedProp then
                    purchaser.forcedNotMimic = true

                end
            end

            local vel = purchaser:GetVelocity()

            if IsValid( purchaser.theMimicPropOnTop ) and purchaser.unMimicMorphSound and vel:LengthSqr() > ( purchaser:GetWalkSpeed() + 10 ) ^ 2 then
                local speed = vel:Length()
                if math.random( 1, purchaser:GetRunSpeed() * 1.5 ) < speed then
                    local unMorphSound = purchaser.unMimicMorphSound
                    purchaser:EmitSound( unMorphSound, 60 + speed / 8, 80 + speed / 4, 0.1, CHAN_STATIC )

                    local dir = vel:GetNormalized()
                    local ang = dir:Angle()
                    ang.p = ang.p * 0.25
                    ang.r = ang.r * 0.25

                    purchaser.theMimicPropOnTop:SetAngles( ang + AngleRand() * 0.01 )

                end
            end
        else
            if purchaser.forcedNotMimic and not ducking then
                purchaser.forcedNotMimic = nil

            end
            if firstDuck then
                turnIntoProp( purchaser )

            end
        end

        purchaser.glee_MimicWasDucking = ducking
        purchaser.glee_MimicWasJumping = jumping

    end )

    local mimicMadnessRestore = function( someoneWithMimicMadness )
        turnBackToPlayer( someoneWithMimicMadness )
        someoneWithMimicMadness.gleeIsMimic = nil
        someoneWithMimicMadness.glee_MimicWasDucking = nil
        someoneWithMimicMadness.glee_MimicWasJumping = nil
        someoneWithMimicMadness.hasMimicMadness = nil
        someoneWithMimicMadness.mimicNearestProp = nil
        someoneWithMimicMadness.oldMimicWeapon = nil

    end

    local undoInnate = function( respawner )
        mimicMadnessRestore( respawner )

    end

    -- This function cleans up the shop item when a new round is started, or the map is cleaned up.
    -- The first variable is nil because it's usually a unique identifier for a timer, and this shop item doesn't use one.
    -- The function works even if the var is nil
    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end--]]

local function temporalDiceRollPurchase( purchaser )
    -- We'll use this variable to track whether the player owns the item
    purchaser.hasTemporalDiceRoll = true

    local function teleportToRandomNavArea( ply )
        if not IsValid( ply ) then return end

        local beamStart = ply:WorldSpaceCenter()

        local randomNavArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup( true )
        local randomPos = randomNavArea:GetCenter()

        ply:TeleportTo( randomPos )

        ply:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 85, 40, 0.4, CHAN_STATIC )
        ply:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 85, 100, 1, CHAN_STATIC )
        ply:EmitSound( "physics/concrete/concrete_impact_hard3.wav", 85, 100, 1, CHAN_STATIC )

        local beamEnd = ply:WorldSpaceCenter()

        util.ScreenShake( randomPos, 10, 20, 4, 1000, true )

        local beam = EffectData()
        beam:SetStart( beamStart )
        beam:SetOrigin( beamEnd )
        beam:SetScale( 1.5 )
        util.Effect( "eff_huntersglee_dicebeam", beam, true )

    end

    local timerName = "temporaldiceroll_timer_" .. tostring( purchaser:GetCreationID() )

    timer.Create( timerName, 1, 8, function()
        if not IsValid( purchaser ) then timer.Remove( timerName ) return end
        if purchaser:Health() <= 0 then timer.Remove( timerName ) return end
        if not purchaser.hasTemporalDiceRoll then timer.Remove( timerName ) return end

        local countdown = timer.RepsLeft( timerName )

        if countdown == 0 then
            teleportToRandomNavArea( purchaser )
            purchaser.hasTemporalDiceRoll = false

        else
            GAMEMODE:GivePanic( purchaser, 15 )
            local pitch = 80 + math.abs( countdown - 8 ) * 5
            purchaser:EmitSound( "Chain.ImpactHard", 75, pitch )
            huntersGlee_Announce( { purchaser }, 10, 2, "Rolling in... " .. countdown )

        end
    end )

    purchaser:EmitSound( "ambient/levels/labs/teleport_mechanism_windup5.wav", 85, 110, 0.4, CHAN_STATIC )

    local temporalDiceRollRestore = function( someoneWithTemporalDiceRoll )
        someoneWithTemporalDiceRoll.hasTemporalDiceRoll = nil

    end

    local undoInnate = function( respawner )
        temporalDiceRollRestore( respawner )

    end

    -- This function cleans up the shop item when a new round is started, or the map is cleaned up.
    -- The first variable is timerName because it's the unique identifier for a timer.
    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


hook.Add( "PlayerDeath", "glee_shop_channel666quota", function( _, _, attacker )
    if not attacker:IsPlayer() then return end
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    attacker:SetNW2Bool( "glee_canpurchase_666", true )

end )

hook.Add( "PreCleanupMap", "glee_shop_resetchannel666quota", function()
    for _, ply in ipairs( player.GetAll() ) do
        ply:SetNW2Bool( "glee_canpurchase_666", false )

    end
end )

function channel666Purchase( purchaser )
    purchaser:SetNWBool( "glee_cantalk_tothedead", true )

    local undoInnate = function( respawner )
        respawner:SetNWBool( "glee_cantalk_tothedead", false )

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


local function signalRelayPurchase( purchaser )

    local hookKey = "huntersglee_signalrelay_" .. purchaser:GetCreationID()

    hook.Add( "glee_signalstrength_used", hookKey, function( ply )
        if not IsValid( purchaser ) then hook.Remove( "glee_signalstrength_used", hookKey ) return end
        if ply ~= purchaser then return end
        if not purchaser.hasSignalBoost then hook.Remove( "glee_signalstrength_used", hookKey ) return end

        if purchaser:Health() <= 0 then return end
        if purchaser:Armor() <= 0 then ply:BatteryNag( 1.25 ) return end

        ply:GivePlayerBatteryCharge( -0.25 )

    end )

    hook.Add( "glee_signalstrength_update", hookKey, function( ply, strength, static )
        if not IsValid( purchaser ) then hook.Remove( "glee_signalstrength_update", hookKey ) return end
        if ply ~= purchaser then return end
        if not purchaser.hasSignalBoost then hook.Remove( "glee_signalstrength_update", hookKey ) return end

        if purchaser:Health() <= 0 then return end
        if purchaser:Armor() <= 0 then return end

        return strength + math.random( 35, 45 ), math.Clamp( static, 0, 5 )

    end )

    purchaser.hasSignalBoost = true

    local undoInnate = function( respawner )
        respawner.hasSignalBoost = nil

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


local function ultraLumenFlashlightPurchase( purchaser )

    local hookKey = "huntersglee_ultralumen_" .. purchaser:GetCreationID()

    local function tearDown()
        hook.Remove( "glee_flashlight_poweruse", hookKey )
        hook.Remove( "glee_flashlightstats", hookKey )
        if not IsValid( purchaser ) then return end

        purchaser.hasUltraLumen = nil

    end

    hook.Add( "glee_flashlight_poweruse", hookKey, function( ply, use )
        if not IsValid( purchaser ) then tearDown() return end
        if ply ~= purchaser then return end
        if not purchaser.hasUltraLumen then tearDown() return end

        return use * 1.5

    end )

    hook.Add( "glee_flashlightstats", hookKey, function( ply, alpha, farz, fov )
        if not IsValid( purchaser ) then tearDown() return end
        if ply ~= purchaser then return end
        if not purchaser.hasUltraLumen then tearDown() return end
        if alpha ~= 255 then return end

        farz = farz * 3
        fov = 120
        return farz, fov

    end )

    purchaser.hasUltraLumen = true
    purchaser:Glee_Flashlight( false )

    local undoInnate = function( respawner )
        respawner.hasUltraLumen = nil
        tearDown()

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


local function bombGlandPurchase( purchaser )
    local timerName = "BombGlandTimer_" .. purchaser:GetClass() .. purchaser:EntIndex()

    purchaser.bombGlandThink = function()
        local gland = purchaser:GetWeapon( "termhunt_bombgland" )

        if not IsValid( gland ) then
            purchaser:Give( "termhunt_bombgland" )
            purchaser:SelectWeapon( "termhunt_bombgland" )
            return

        end
    end

    -- Set the timer to repeat the action
    timer.Create( timerName, 0.1, 0, function()
        if IsValid( purchaser ) then
            if purchaser:Health() <= 0 then return end
            purchaser.bombGlandThink()

        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )

        end
    end )

    local undoInnate = function( _ )
        purchaser.oldBombGlandBeats = nil
        timer.Remove( timerName )

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


local function susPurchase( purchaser )

    purchaser.defaultWalkSpeed = purchaser.defaultWalkSpeed or purchaser:GetWalkSpeed()
    purchaser.defaultCrouchSpeedMul = purchaser.defaultCrouchSpeedMul or purchaser:GetCrouchedWalkSpeed()
    local timerName = "SusInnateTimer_" .. purchaser:GetClass() .. purchaser:EntIndex()

    purchaser.doSusInnateFunction = function()

        local myCenter = purchaser:WorldSpaceCenter()

        local traceData = {
            start = myCenter,
            endpos = purchaser:GetPos() + Vector( 0,0,-25 ),
            mask = MASK_SOLID_BRUSHONLY,

        }

        local trace = util.TraceLine( traceData )
        local newSusSpeedMul = nil
        local newSusWalkSpeedMul = nil

        local panicToGive = 1

        if trace.MatType == MAT_VENT or string.find( trace.HitTexture, "vent" ) then
            panicToGive = -10
            newSusSpeedMul = 1
            newSusWalkSpeedMul = 1.5

        else
            panicToGive = 0
            newSusSpeedMul = 1
            newSusWalkSpeedMul = 1

        end

        GAMEMODE:GivePanic( purchaser, panicToGive )

        local oldSusSpeedMul = purchaser.oldSusSpeedMul or 0
        local oldSusWalkSpeedMul = purchaser.oldSusWalkSpeedMul or 0


        if oldSusSpeedMul ~= newSusSpeedMul or oldSusWalkSpeedMul ~= newSusWalkSpeedMul then
            purchaser.oldSusSpeedMul = newSusSpeedMul
            purchaser.oldSusWalkSpeedMul = newSusWalkSpeedMul
            purchaser:SetCrouchedWalkSpeed( newSusSpeedMul )
            purchaser:SetWalkSpeed( purchaser.defaultWalkSpeed * newSusWalkSpeedMul )

        end

    end

    timer.Create( timerName, 0.2, 0, function()
        if IsValid( purchaser ) then
            if purchaser:Health() <= 0 then return end
            purchaser.doSusInnateFunction()

        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )

        end
    end )

    local undoInnate = function( respawner )
        purchaser.oldSusSpeedMul = nil
        respawner:SetWalkSpeed( respawner.defaultWalkSpeed )
        respawner:SetCrouchedWalkSpeed( respawner.defaultCrouchSpeedMul )
        timer.Remove( timerName )

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


local function marcoPoloPurchase( purchaser )
    local timerName = "huntersglee_marcopolo" .. purchaser:GetCreationID()

    local blockHookName = "huntersglee_marcopolo_block_" .. purchaser:GetCreationID()
    hook.Add( "huntersglee_blockscoring", blockHookName, function( ply )
        if not IsValid( ply ) then hook.Remove( "huntersglee_blockscoring", blockHookName ) return end
        if ply == purchaser then return true end

    end )

    local _, unexplored = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
    purchaser.marcoPoloExploredStatuses = {}
    for _, area in ipairs( unexplored ) do
        if not area:IsUnderwater() then
            purchaser.marcoPoloExploredStatuses[area:GetID()] = false

        end
    end
    purchaser.marcopolo_ReservedReward = 0
    purchaser.marcopolo_ToExploreCount = table.Count( purchaser.marcoPoloExploredStatuses )
    purchaser.marcopolo_ExploredCount = 0

    local recipFilterPurchaser = RecipientFilter()
    recipFilterPurchaser:AddPlayer( purchaser )

    timer.Create( timerName, 1, 0, function()
        if not IsValid( purchaser ) then timer.Remove( timerName ) return end
        if not purchaser.marcoPoloExploredStatuses then
            purchaser.glee_NoBpmScore = nil
            timer.Remove( timerName )
            return

        end

        if purchaser:Health() <= 0 then return end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end

        local areasWeTraversed = navmesh.Find( purchaser:GetPos(), 800, 100, 50 )
        local reward = purchaser.marcopolo_ReservedReward

        for _, potentiallyTraversed in ipairs( areasWeTraversed ) do
            local areaId = potentiallyTraversed:GetID()
            local status = purchaser.marcoPoloExploredStatuses[ areaId ]

            -- ply may end up out of original group, if so then keep counting up but stop eventually.
            if status == true then goto marcoPoloWeDoneWithThisArea end

            purchaser.marcoPoloExploredStatuses[ areaId ] = true
            purchaser.marcopolo_ExploredCount = purchaser.marcopolo_ExploredCount + 1
            local ratioWeAt = purchaser.marcopolo_ExploredCount / purchaser.marcopolo_ToExploreCount

            local areaReward = 0

            if ratioWeAt > 1 then
                areaReward = 0
            elseif ratioWeAt > 0.9 then
                areaReward = 10

            elseif ratioWeAt > 0.8 then
                areaReward = 3

            elseif ratioWeAt > 0.5 then
                areaReward = 1.5

            elseif ratioWeAt > 0.25 then
                areaReward = 0.18

            elseif ratioWeAt > 0.1 then
                areaReward = 0.1

            else
                areaReward = 0.02

            end

            reward = reward + areaReward

            if reward > 0 then
                local beam = EffectData()
                beam:SetStart( potentiallyTraversed:GetCenter() )
                beam:SetOrigin( purchaser:GetShootPos() + -vector_up * 35 )
                beam:SetScale( 0.1 + ( areaReward / 2 ) )
                beam:SetMagnitude( 0.3 + ratioWeAt / 2 )
                util.Effect( "eff_marcopolo_communicate", beam, nil, recipFilterPurchaser )

            end

            ::marcoPoloWeDoneWithThisArea::

        end

        if reward >= 1 then
            purchaser:GivePlayerScore( reward )
            purchaser.marcopolo_ReservedReward = 0

        else
            purchaser.marcopolo_ReservedReward = purchaser.marcopolo_ReservedReward + reward

        end
    end )

    local undoInnate = function( _ )
        purchaser.marcoPoloExploredStatuses = nil
        purchaser.marcopolo_ToExploreCount = nil
        purchaser.marcopolo_ExploredCount = nil
        timer.Remove( timerName )
        hook.Remove( "huntersglee_blockscoring", blockHookName )

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


local function ghostCanPurchase( purchaser )
    if IsValid( purchaser.ghostEnt ) then return false, "You're already placing something!\nPlace it, or right click to CANCEL placing it!" end
    return true

end

local function setupPlacable( class, purchaser, itemIdentifier )
    local thing = ents.Create( class )
    thing.itemIdentifier = itemIdentifier
    thing:SetOwner( purchaser )
    thing:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

    return thing

end


local function screamerPurchase( purchaser, itemIdentifier )
    setupPlacable( "screamer_crate", purchaser, itemIdentifier )

end


local function nonScreamerPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_normal_crate", purchaser, itemIdentifier )

end


local function weaponsCratePurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_weapon_crate", purchaser, itemIdentifier )

end


local function undeadBearTrapPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_undead_beartrap", purchaser, itemIdentifier )

end


local function manhackCratePurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_manhack_crate", purchaser, itemIdentifier )

end


local function barrelsPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_barrels", purchaser, itemIdentifier )

end


local function barnaclePurchase( purchaser, itemIdentifier )
    setupPlacable( "placable_barnacle", purchaser, itemIdentifier )

end


local function doorLockerPurchase( purchaser, itemIdentifier )
    setupPlacable( "door_locker", purchaser, itemIdentifier )

end

local function inversionCanPurchase()
    if GAMEMODE:isTemporaryTrueBool( "termhunt_player_swapper_initial" ) then return nil, "Not unlocked yet." end
    if GAMEMODE:isTemporaryTrueBool( "termhunt_player_swapper" ) then return nil, "It is too soon for another inversion to begin." end
    return true, nil

end

local function plySwapperPurchase( purchaser, itemIdentifier )
    setupPlacable( "player_swapper", purchaser, itemIdentifier )

end

local function immortalizerPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_immortalizer", purchaser, itemIdentifier )

end

local function blessingPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_blessing", purchaser, itemIdentifier )

end

local function presserPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_presser", purchaser, itemIdentifier )

end

local function homicidalGleePurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_retribution", purchaser, itemIdentifier )

end

local function termOverchargerPurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_overcharger", purchaser, itemIdentifier )

end

local function applauseCanPurchase( _ )
    if GAMEMODE:isTemporaryTrueBool( "termhunt_thunderous_applause_initial" ) then return nil, "It's too soon for the applause to begin." end
    if GAMEMODE:isTemporaryTrueBool( "termhunt_thunderous_applause" ) then return nil, "Applause must be spaced out. Wait.." end
    return true, nil

end

local function applausePurchase( purchaser, itemIdentifier )
    setupPlacable( "termhunt_thunderous_applause", purchaser, itemIdentifier )

end

local function spawnAnotherHunterCheck( _ )
    local extraData = GAMEMODE.roundExtraData or {}
    local extraHunter = GetGlobal2Entity( "glee_linkedhunter" )
    local validCsideHunter = IsValid( extraHunter ) and extraHunter:Health() > 0
    if IsValid( extraData.extraHunter ) or validCsideHunter then return nil, "There is already a linked hunter." end
    return true, nil

end

local function spawnAnotherHunterCost()
    if GAMEMODE:ClassIsInSpawnPool( "terminator_nextbot_snail_disguised" ) then
        return -150

    else
        return 200

    end
end

hook.Add( "huntersglee_plykilledhunter", "glee_rewardLinkedKills", function( killer, hunter )
    if not hunter.linkedPlayer then return end
    if killer ~= hunter.linkedPlayer then return end
    local reward = 350
    killer:GivePlayerScore( reward )

    huntersGlee_Announce( { killer }, 50, 10, "You feel at peace, a weight has been lifted.\nThe doppleganger is dead...\n+" .. reward .. " score." )

end )

local function additionalHunter( purchaser )

    if not SERVER then return end

    local timerKey = "spawnExtraHunter_" .. purchaser:GetCreationID()
    timer.Create( timerKey, 0.2, 0, function()

        local hunter = GAMEMODE:SpawnHunter( "terminator_nextbot_snail_disguised" )
        if not IsValid( hunter ) then return end

        if hunter.MimicPlayer then
            hunter:MimicPlayer( purchaser )

        end

        SetGlobal2Entity( "glee_linkedhunter", hunter )

        GAMEMODE.roundExtraData.extraHunter = hunter

        hunter.linkedPlayer = purchaser

        if purchaser:Health() <= 0 then
            GAMEMODE:SpectateThing( purchaser, hunter )

        end

        timer.Stop( timerKey )

    end )

    GAMEMODE:CloseShopOnPly( purchaser )

end

local glee_scoretochosentimeoffset_divisor = CreateConVar( "huntersglee_scoretochosentimeoffset_divisor1", "-1", bit.bor( FCVAR_REPLICATED, FCVAR_ARCHIVE ),
"-1 = default, if set bigger, grigori can happen sooner, if smaller, happens later", 0, 100000 )

local defaultDivisor = 10

if SERVER then
    -- offset will update constantly, use nw2
    SetGlobal2Int( "glee_chosen_timeoffset", 0 )
    local nextTimeOffsetNetwork = 0

    hook.Add( "huntersglee_givescore", "glee_chosentrackscore", function( _, scoreGivenRaw )
        if GAMEMODE.roundExtraData.grigoriWasPurchased then return end -- grigori was purchased, patience is OVER

        local scoreGiven = math.abs( scoreGivenRaw )
        local divisor = glee_scoretochosentimeoffset_divisor:GetFloat()
        if divisor <= 0 then
            divisor = defaultDivisor

        end
        local moreTime = scoreGiven / divisor
        moreTime = moreTime / #player.GetAll()

        local startTimeOffset = GAMEMODE.roundExtraData.divineChosen_StartTimeOffset or 0
        startTimeOffset = startTimeOffset + moreTime
        GAMEMODE.roundExtraData.divineChosen_StartTimeOffset = startTimeOffset

        if nextTimeOffsetNetwork < CurTime() then
            nextTimeOffsetNetwork = CurTime() + 1
            SetGlobal2Int( "glee_chosen_timeoffset", startTimeOffset )

        end
    end )
end

local minGrigoriMinutes = 5

local function divineChosenCanPurchase( purchaser )

    -- damn it i dropped my spaghetti ( basically makes sure grigori happens sooner if nobodys buying anything )
    local addedBySpending = GetGlobal2Int( "glee_chosen_timeoffset", 0 ) / 60
    local minutes = minGrigoriMinutes + addedBySpending
    minutes = math.Clamp( minutes, minGrigoriMinutes, 20 ) -- 20 minutes can be real boring

    local offset = 60 * minutes -- get actual offset
    local allowTime = GetGlobalInt( "huntersglee_round_begin_active" ) + offset
    local remaining = allowTime - CurTime()
    local formatted = string.FormattedTime( remaining, "%02i:%02i" )

    local pt1 = "Their patience has ended."
    local block
    if allowTime > CurTime() then
        pt1 = "Presently, their patience lasts " .. formatted .. "."
        block = true

    end

    -- can pass this check if testing
    if block then return isCheats(), pt1 end

    if SERVER then
        GAMEMODE.roundExtraData.divineChosenSpent = GAMEMODE.roundExtraData.divineChosenSpent or {}
        if GAMEMODE.roundExtraData.divineChosenSpent[ purchaser:GetCreationID() ] == true then return nil, "You had your chance." end

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

    hook.Add( "HUDPaint", "huntersglee_divinechosentimelimit", function()
        local me = LocalPlayer()
        if me:GetNW2Bool( "isdivinechosen", false ) ~= true then return end
        local chosenWeap = me:GetWeapon( "termhunt_divine_chosen" )
        if not ( IsValid( chosenWeap ) or me:Health() <= 0 ) then return end

        local noPatienceTime = GetGlobal2Int( "divineChosenPatienceEnds", 0 )
        if noPatienceTime == 0 or noPatienceTime == -2147483648 then return end

        huntersGlee_BlockAnnouncements( me, 5 )

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
                local offset = var * 0.1
                surface.drawShadowedTextBetter( Text, "huntersglee_divineorders", demandFlashing, screenMiddleW, 128 + spacingHeight * offset )
                local time = var * 0.08
                if timeTillNoPatience > -time then return end

            end
        end
    end )

    hook.Add( "huntersglee_cl_displayhint_predeadhints", "glee_chosen_respawnhint", function( me ) -- tell people that respawning is free as grigori
        if not me:GetNW2Bool( "isdivinechosen", false ) then return end
        if me:GetNW2Int( "glee_divineintervetion_respawncount", 0 ) >= 3 then return end

        return true, "Stop wasting time, RESPAWN YOURSELF.\nYou are true DIVINE INTERVENTION."

    end )
end

local function divineChosenPurchase( purchaser )

    purchaser:SetNW2Bool( "isdivinechosen", true )
    SetGlobalBool( "chosenhasarrived", true )

    GAMEMODE.roundExtraData.grigoriWasPurchased = true -- allow chosen patience to stop counting up now

    purchaser.glee_IsDivineChosen = true

    huntersGlee_Announce( player.GetAll(), 500, 15, "The ultimate sacrifice has been made.\nBEWARE OF " .. string.upper( purchaser:Nick() ) )

    local maintainChosenWeapTimer = "divineChosenTimer_" .. purchaser:GetCreationID()

    purchaser.divineChosenThink = function()
        local chosenWeap = purchaser:GetWeapon( "termhunt_divine_chosen" )

        GAMEMODE:GivePanic( purchaser, -25 )

        if not IsValid( chosenWeap ) then
            purchaser.glee_IsDivineChosen = true
            purchaser:Give( "termhunt_divine_chosen" )
            purchaser:SelectWeapon( "termhunt_divine_chosen" )
            return

        end
    end

    -- ensure they got the weap and sure, why not repeat the nw2bool
    timer.Create( maintainChosenWeapTimer, 0.1, 0, function()
        if IsValid( purchaser ) and purchaser.glee_IsDivineChosen then
            purchaser:SetNW2Bool( "isdivinechosen", true )
            if purchaser:Health() <= 0 then return end
            purchaser.divineChosenThink()

        else
            timer.Remove( maintainChosenWeapTimer )
            purchaser:SetNW2Bool( "isdivinechosen", false )
            SetGlobalBool( "chosenhasarrived", false )

        end
    end )

    GAMEMODE.roundExtraData.divinePatienceEnds = CurTime() + 90
    local function isStillGoing()
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE or GAMEMODE:CountWinnablePlayers() <= 0 then return false end
        return true

    end

    local mdlLineBlockerName = "glee_chosen_blockmodellines_" .. purchaser:GetCreationID()
    hook.Add( "glee_block_modellines", mdlLineBlockerName, function( ply )
        if not IsValid( purchaser ) then hook.Remove( "glee_block_modellines", mdlLineBlockerName ) return end
        if ply ~= purchaser then return end
        if not purchaser.glee_IsDivineChosen then hook.Remove( "glee_block_modellines", mdlLineBlockerName ) return end

        return true

    end )

    local blockSpawningNearPlayersHook = "huntersglee_chosen_blocknearply"

    hook.Add( "huntersglee_blockspawn_nearplayers", blockSpawningNearPlayersHook, function( spawner, _ )
        if not purchaser:GetNW2Bool( "isdivinechosen", nil ) then hook.Remove( "huntersglee_blockspawn_nearplayers", blockSpawningNearPlayersHook ) return end
        if spawner ~= purchaser then return end

        return true

    end )
    local increasePatienceHook = "hunterslgee_increasedivinepatience"

    if not GAMEMODE.roundExtraData.createdThePatienceIncreaseHook then
        GAMEMODE.roundExtraData.createdThePatienceIncreaseHook = true
        hook.Add( "PlayerDeath", increasePatienceHook, function( victim, _, _ )
            if victim:GetNW2Bool( "isdivinechosen", nil ) then return end
            if isStillGoing() == false then
                hook.Remove( "PlayerDeath", increasePatienceHook )

            else
                if not GAMEMODE.roundExtraData.divinePatienceEnds then
                    hook.Remove( "PlayerDeath", increasePatienceHook )
                    return

                end
                GAMEMODE.roundExtraData.divinePatienceEnds = math.max( CurTime() + 90, GAMEMODE.roundExtraData.divinePatienceEnds + 40 )

            end
        end )
    end

    local maintainPatienceTimer = "huntersglee_divinepatiencetimer"

    if not timer.Exists( maintainPatienceTimer ) then
        timer.Create( maintainPatienceTimer, 1, 0, function()
            if isStillGoing() == false then
                timer.Remove( maintainPatienceTimer )
                SetGlobal2Int( "divineChosenPatienceEnds", nil )

            else
                SetGlobal2Int( "divineChosenPatienceEnds", GAMEMODE.roundExtraData.divinePatienceEnds )
                if GAMEMODE.roundExtraData.divinePatienceEnds > CurTime() + -5 then return end

                GAMEMODE.roundExtraData.divineChosenSpent = GAMEMODE.roundExtraData.divineChosenSpent or {}
                GAMEMODE.roundExtraData.divineChosenSpent[ purchaser:GetCreationID() ] = true

                for _, potentialChosen in ipairs( player.GetAll() ) do
                    if not potentialChosen.huntersgleeUndoDivineChosen then continue end
                    potentialChosen.huntersgleeUndoDivineChosen()
                    timer.Simple( 0.1, function()
                        if not IsValid( potentialChosen ) then return end
                        if potentialChosen:Health() <= 1 then return end
                        potentialChosen:SetHealth( 1 )

                    end )
                end
            end
        end )
    end

    purchaser.glee_divineChosenResurrect = function()
        local area = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
        local randAreasCenter = area:GetCenter()
        purchaser.unstuckOrigin = randAreasCenter

        purchaser:Resurrect()

        local oldCount = purchaser:GetNW2Int( "glee_divineintervention_respawncount", 0 )
        local newCount = oldCount + 1
        purchaser:SetNW2Int( "glee_divineintervention_respawncount", newCount )

        -- lighting where they spawn
        timer.Simple( 0.1, function()

            purchaser:GodEnable()
            local lightning = ents.Create( "glee_lightning" )
            lightning:SetOwner( purchaser )
            lightning:SetPos( randAreasCenter )
            lightning:SetPowa( 12 )
            lightning:Spawn()

            timer.Simple( 0.5, function()
                purchaser:GodDisable()

            end )
        end )
    end

    purchaser:glee_divineChosenResurrect() -- resurrect them immediately

    if not GAMEMODE.roundExtraData.divineChosenSnapped then
        GAMEMODE.roundExtraData.divineChosenSnapped = true

        timer.Simple( 0.5, function() -- make all spectators watch the first chosen 
            if not IsValid( purchaser ) then return end
            for _, ply in player.Iterator() do
                if not IsValid( ply ) then continue end
                if ply:Health() > 0 then continue end

                GAMEMODE:SpectateThing( ply, purchaser )

            end
        end )
    end

    local function undoInnate()
        purchaser.glee_IsDivineChosen = nil
        purchaser.glee_divineChosenResurrect = nil
        purchaser:SetNW2Bool( "isdivinechosen", false )
        SetGlobalBool( "chosenhasarrived", false )

        purchaser:SetNW2Int( "glee_divineintervention_respawncount", 0 )

        -- cleanup wep stuff
        timer.Remove( maintainChosenWeapTimer )
        local weap = purchaser:GetWeapon( "termhunt_divine_chosen" )
        SafeRemoveEntity( weap )

        -- cleanup the global hooks
        hook.Remove( "huntersglee_blockspawn_nearplayers", blockSpawningNearPlayersHook )
        hook.Remove( "PlayerDeath", increasePatienceHook )

        -- cleanup other global stuff
        timer.Remove( maintainPatienceTimer )
        SetGlobal2Int( "divineChosenPatienceEnds", 0 )

    end

    purchaser.huntersgleeUndoDivineChosen = undoInnate

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end



local function canOpenAccount( purchaser )
    if purchaser:BankHasAccount() then return false, "You've already opened a bank account." end
    return true

end

local function openAccountCost( purchaser )
    if canOpenAccount( purchaser ) then return 1000 end

    local existingAccount = purchaser:BankAccount()
    return existingAccount.funds

end

local function openAccountPurchase( purchaser )
    timer.Simple( 0.05, function()
        if not IsValid( purchaser ) then return end
        purchaser:BankOpenAccount()

    end )
end


local function hasBankAccount( purchaser )
    if not purchaser:BankHasAccount() then return false, "You haven't opened a bank account yet." end
    return true

end


local function bankDepositCost( purchaser )
    return math.Clamp( purchaser:GetScore(), 10, 200 )

end

local function bankDepositDescription()
    local chargePeriod = gleefunc_BankChargePeriod()
    local chargePeriodDays = chargePeriod / 86400
    chargePeriodDays = math.Round( chargePeriodDays, 2 )

    local periodCharge = gleefunc_BankChargePerPeriod()

    local days = "days."
    if chargePeriodDays == 1 then
        days = "day."

    end
    return "Deposit score for another time.\nThe bank has a 10% procesing fee when depositing.\nIdle fees of \"" .. periodCharge .. "\"% of your entire balance, will apply every \"" .. chargePeriodDays .. "\" real-time " .. days

end

local function bankDepositPurchase( purchaser )
    local toDeposit = bankDepositCost( purchaser )
    purchaser:GivePlayerScore( -toDeposit )

    toDeposit = toDeposit * 0.9 -- ten percent processing fee in question
    purchaser:BankDepositScore( toDeposit )

end

local function bankCanWithdraw( purchaser )
    if not purchaser:BankCanDeposit( -gleefunc_BankMinFunds() ) then return false, "Your account is below the withdrawl threshold!!\nIt will be closed when the next idle fee is applied!!!" end
    return true

end

local function bankWithdrawPurchase( purchaser )
    purchaser:BankDepositScore( -gleefunc_BankMinFunds() )
    purchaser:GivePlayerScore( gleefunc_BankMinFunds() )

end



--[[

these are here for demonstration, they are defined in shared
see sh_shopshared.lua for example that shows what every shopitem var does

-- weird ones
GM.ROUND_INVALID    = -1 -- tell people to install a navmesh
GM.ROUND_SETUP      = 0 -- wait until the navmesh has definitely spawned

-- normal ones
GM.ROUND_ACTIVE     = 1 -- death has consequences and score can accumulate
GM.ROUND_INACTIVE   = 2 -- let players run around, buy with discounts
GM.ROUND_LIMBO      = 3 -- just display winners

!!!!SEE sh_shopshared.lua FOR EXAMPLE THAT SHOWS EVERY ITEM VAR'S FUNCTIONALITY!!!!

--]]

local defaultItems = {
    -- reframe gaining score, because i thought it could be fun
    [ "marcopolo" ] = {
        name = "Marco Polo",
        desc = "You gain score for exploring new parts of the map.\nBPM gives no score.\nGains per area explored start out trivial, but as you progress, the rewards become greater.",
        shCost = 25,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
        },
        weight = 180,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = marcoPoloPurchase,
    },
    --flat upgrade
    [ "froglegs" ] = {
        name = "Frog Legged Parkourist",
        desc = "Your legs become frog.\nThe gangly shape of your legs slows you down.\nYou are capable of frog kicking off walls.\nYour shove propels you further.\nYour superior frog geneology permits you to absorb greater falls.\nRibbit.",
        shCost = 350,
        markup = 2,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 120,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = frogLegsPurchase,
    },
    --[[--flat upgrade
    [ "mimicmadness" ] = {
        name = "Prop Hunt",
        desc = "When crouched, you mimic the closest nearby prop.\nThe terminators are fooled from far away but the illusion breaks down since you don't have collisions.",
        shCost = 250,
        markup = 2,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 120,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = mimicMadnessPurchase,
    },]]--
    --flat upgrade
    [ "temporaldiceroll" ] = {
        name = "Roll of the dice.",
        desc = "Roll the temporal dice.\n8 seconds after purchasing, you are teleported to a completely random part of the map",
        shCost = 75,
        markup = 1.5,
        markupPerPurchase = 1,
        cooldown = 90,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 120,
        shPurchaseCheck = shopHelpers.aliveCheck,
        svOnPurchaseFunc = temporalDiceRollPurchase,
    },
    -- flat upgrade
    [ "channel666" ] = {
        name = "Channel 666.",
        desc = "Your radio bridges life and death.\nYou can communicate with the dead, both ways.",
        shCost = 0,
        skullCost = 1,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_ACTIVE,

        },
        weight = 125,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = channel666Purchase,
        shCanShowInShop = shopHelpers.hasMultiplePeople(),
    },
    -- signal boost
    [ "signalrelay" ] = {
        name = "Signal Relay.",
        desc = "Boosts your signal\nConsumes Suit Armor.",
        shCost = 50,
        markup = 2,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = signalRelayPurchase,
    },
    -- flat upgrade
    [ "superiormetabolism" ] = {
        name = "Superior Metabolism.",
        desc = "You've always been different than those around you.\nWhat would hospitalize others for weeks, passed over you in days.\nYou regenerate health as your heart beats.",
        shCost = 200,
        markup = 2,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 80,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = superiorMetabolismPurchase,
    },
    -- wacky ass shit
    [ "bombgland" ] = {
        name = "Bomb Gland.",
        desc = "You accumulate bombs. Drop them with the bomb gland.\nLeft Click for small bombs, Reload for a big bomb.\nRight click to detonate oldest bomb.\nAfter you surpass 4 bombs, there's a chance that ANY damage will explode your undropped bombs.\nIf you die, all your bombs explode.",
        shCost = 50,
        markup = 2,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 85,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = bombGlandPurchase,
    },
    [ "ultralumen" ] = {
        name = "Ultra Lumen 3000.",
        desc = "Scared of the dark?\nWhat if the dark feared YOU!\nThe Ultra Lumen 3000 is perfect for anyone that can't stand darkness, a fraction of the sun's power, in your hands!\nMay increase battery consumption.",
        shCost = 50,
        markup = 2,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = ultraLumenFlashlightPurchase,
    },
    -- flat upgrade
    [ "susimpostor" ] = {
        name = "HVAC Specialist.",
        desc = "From a young age, vents have fascinated you.\nThe \"portals between rooms\", as you call them, have practically raised you.\nYou are scared of the normal world, crouching brings confort, and vents bring freedom from panic.\nYou move very fast while crouching. Even faster in vents.\nYou don't even notice the musty vent smell anymore.",
        shCost = 50,
        markup = 3,
        cooldown = math.huge,
        category = "Innate",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 90,
        shPurchaseCheck = { shopHelpers.aliveCheck },
        svOnPurchaseFunc = susPurchase,
    },
    -- sell out other players/your friends to become alive
    [ "screamcrate" ] = {
        name = "Beaconed Supplies",
        desc = "Supplies with a beacon.\nBetray the others for score.\nCosts 75 to place.\nRefund upon first beacon transmit.",
        shCost = 0,
        markup = 1,
        cooldown = 60,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = -5,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = screamerPurchase,
    },
    -- makes the map worth exploring
    [ "normcrate" ] = {
        name = "Supplies",
        desc = "Supplies without a beacon.\nContains health, armour, rarely a weapon, special ammunition.\nPlace indoors, and far away from players and other supplies, for more score.",
        shCost = 0,
        markup = 1,
        cooldown = 10,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = -4,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = nonScreamerPurchase,
    },
    [ "weapcrate" ] = {
        name = "Crate of Weapons",
        desc = "Supply crate with 5 weapons in it\nPlace indoors, and far away from players and other supplies, for more score.",
        shCost = 0,
        markup = 1,
        cooldown = 55,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = weaponsCratePurchase,
    },
    [ "manhackcrate" ] = {
        name = "Crate with Manhacks",
        desc = "Supply crate with 5 manhacks in it.\nGives score when the manhacks damage stuff.",
        shCost = 0,
        markup = 1,
        cooldown = 80,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 10,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = manhackCratePurchase,
    },
    [ "undeadbeartrap" ] = {
        name = "Beartrap.",
        desc = "Beartrap.\nWhen a player, hunter, steps on it, you get a reward.\nCosts more to place it near the living, and intersecting objects.",
        shCost = 0,
        markup = 1,
        cooldown = 15,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = undeadBearTrapPurchase,
    },
    [ "barrels" ] = {
        name = "Barrels",
        desc = "6 Barrels",
        shCost = 0,
        markup = 1,
        cooldown = 2,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 1,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = barrelsPurchase,
    },
    -- punishes careless movement
    [ "barnacle" ] = {
        name = "Barnacle",
        desc = "Barnacle.\nYou gain 100 score the first time it grabs someone, and 45 score every further second it has someone grabbed.\nCosts more to place in groups, or place too close to players.",
        shCost = 5,
        markup = 1,
        cooldown = 0.5,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 10,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = barnaclePurchase,
    },
    [ "doorlocker" ] = {
        name = "Door Locker",
        desc = "Locks doors, you gain score when something uses it.\n150 score, default.\n250 score if a player fleeing a hunter uses it.\nDon't use your own locked doors.",
        shCost = 5,
        markup = 1,
        cooldown = 0.5,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 10,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = doorLockerPurchase,
    },
    -- money but you're fucked if you revive
    [ "additionalterm" ] = {
        name = "Linked Hunter",
        desc = "Spawn another hunter.\nThey will take on your appearance.\nIf you personally kill it, you will gain 350 score.\nThe newcomer will never lose you, if you regain your life...",
        shCost = spawnAnotherHunterCost,
        markup = 1,
        cooldown = 90,
        category = "Sacrifices",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = -100,
        shPurchaseCheck = { shopHelpers.undeadCheck, spawnAnotherHunterCheck },
        svOnPurchaseFunc = additionalHunter,
        shCanShowInShop = spawnAnotherHunterCanShow,
    },
    [ "presser" ] = {
        name = "Presser",
        desc = "Press things on the map.\nThe more a thing is pressed, the higher it's cost climbs...",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = -4,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = presserPurchase,
    },
    -- people who teamkill get funny consequence
    [ "homicidalglee" ] = {
        name = "Homicidal Glee.",
        desc = "Bring a player's Homicidal Glee to the surface...\nCosts nothing to place, if the player killed you at least once before.\nCan only be placed every 15 seconds.",
        costDecorative = "0 / -200",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 0,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = homicidalGleePurchase,
    },
    -- fun
    [ "termovercharger" ] = {
        name = "Overcharger.",
        desc = "Overcharge a Hunter. Global 3 minute delay between Overcharges.",
        costDecorative = "-450",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 19,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = termOverchargerPurchase,
    },
    -- ultimate stalemate breaker
    [ "temporalinversion" ] = {
        name = "Temporal Inversion",
        desc = "Swaps a player out for their most remote enemy.\nUnlocks after 3 minutes, then a global 3 minute cooldown between uses.",
        costDecorative = "-400",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase, inversionCanPurchase },
        svOnPurchaseFunc = plySwapperPurchase,
    },
    [ "immortalizer" ] = {
        name = "Gift of Immortality",
        desc = "Gift 20 seconds, of true Immortality.\nCosts 200 to gift to hunters, 300 to gift to players.",
        costDecorative = "-200 / -300",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = immortalizerPurchase,
    },
    [ "blessing" ] = {
        name = "A Blessing",
        desc = "2 minutes of health regeneration, and Calm.\nCosts 50 to gift to hunters, 100 to gift to players.",
        costDecorative = "-50 / -100",
        shCost = 0,
        markup = 1,
        cooldown = 5,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase },
        svOnPurchaseFunc = blessingPurchase,
    },
    -- crazy purchase
    [ "thunderousapplause" ] = {
        name = "Thunderous Applause",
        desc = "Let the Living, hear your utmost gratitiude.\nUnlocks after 4 minutes, then a global 4 minute cooldown between uses.",
        costDecorative = "-600",
        shCost = 0,
        markup = 1,
        cooldown = 0,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 20,
        shPurchaseCheck = { shopHelpers.undeadCheck, ghostCanPurchase, applauseCanPurchase },
        svOnPurchaseFunc = applausePurchase,
    },
    -- explosive end to round
    [ "divinechosen" ] = {
        name = "grigori",
        desc = "The ultimate sacrifice.\nThe gods gift you a fraction of their power, to end the hunt.\nRequires \"Patience\" to run dry.",
        shCost = 2000,
        markup = 1,
        cooldown = math.huge,
        category = "Gifts",
        purchaseTimes = {
            GM.ROUND_ACTIVE,
        },
        weight = 40,
        shPurchaseCheck = { shopHelpers.undeadCheck, divineChosenCanPurchase },
        svOnPurchaseFunc = divineChosenPurchase,
    },
    -- reason to rejoin
    [ "bankopenaccount" ] = {
        name = "Bank Account",
        desc = "Open a bank account.",
        simpleCostDisplay = true,
        shCost = openAccountCost,
        cooldown = 0,
        category = "Bank",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 0,
        shPurchaseCheck = { canOpenAccount },
        svOnPurchaseFunc = openAccountPurchase,
    },
    -- reason to rejoin
    [ "bankdeposit" ] = {
        name = "Deposit",
        desc = bankDepositDescription,
        fakeCost = true, -- score removal is handled in svOnPurchaseFunc
        shCost = bankDepositCost,
        cooldown = 0.5,
        category = "Bank",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 100,
        shPurchaseCheck = { hasBankAccount },
        svOnPurchaseFunc = bankDepositPurchase,
    },
    -- reason to rejoin
    [ "bankwithdraw" ] = {
        name = "Withdraw",
        desc = "Withdraw 100 score from your account.",
        fakeCost = true,
        shCost = -100,
        cooldown = 0.5,
        category = "Bank",
        purchaseTimes = {
            GM.ROUND_INACTIVE,
            GM.ROUND_ACTIVE,
        },
        weight = 150,
        shPurchaseCheck = { hasBankAccount, bankCanWithdraw },
        svOnPurchaseFunc = bankWithdrawPurchase,
    },
}

function GM:SetupShopCatalouge()
    for shopItemIdentifier, shopItemTbl in pairs( defaultItems ) do
        -- this is the correct way to add shop items!
        GAMEMODE:addShopItem( shopItemIdentifier, shopItemTbl )

    end

    GAMEMODE.shopIsReadyForItems = true

    -- pls put other shop items in this hook! ty
    ProtectedCall( function() hook.Run( "huntersglee_postshopsetup_shared", nil ) end )

end

function GM:IsShopReadyForItems()
    return self.shopIsReadyForItems

end
