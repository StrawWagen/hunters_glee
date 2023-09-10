-- officially announce modding support
-- change workshop icon
-- add gifs to workshop page

-- placables need to use run on key -- done
-- boot player from shop when they buy a placable -- done
-- door locker is fucked -- done
-- make beacon supplies simpler -- done
-- wasd kicks out of spectate -- done

-- radio draw channel instead of ammo
-- flares are SUPER LAGGYYYYY

-- standardize +- placable hud stuff
-- barrels sweet spot?
-- dead people can hear alive global?
-- give notifs when people break your crates/barrels?



local thwaps = {
    Sound( "physics/body/body_medium_impact_hard3.wav" ),
    Sound( "physics/body/body_medium_impact_hard2.wav" ),
    Sound( "physics/body/body_medium_break2.wav" ),

}

--local white = Color( 255,255,255 )

local gunCock = Sound( "items/ammo_pickup.wav" )
local function loadoutConfirm( ply, Count )
    for _ = 0, Count do
        ply:EmitSound( gunCock, 60, math.random( 90, 110 ) )

    end
end

local function playRandomSound( ent, sounds, level, pitch, channel )
    if not channel then
        channel = CHAN_STATIC
    end
    local soundName = sounds[math.random( #sounds )]

    ent:EmitSound( soundName, level, pitch, 1, channel )

end


local function unUndeadCheck( purchaser )
    if purchaser:Health() <= 0 then return false, "You must be alive to purchase this." end
    return true, ""

end

local function undeadCheck( purchaser )
    if purchaser:Health() > 0 then return false, "You must be dead to purchase this." end
    return true, ""

end

local sv_cheats = GetConVar( "sv_cheats" ) 

local function isCheats()
    return sv_cheats:GetBool()

end

local function hasMultiplePeople()
    if #player.GetAll() <= 1 then return end
    return true

end

local reviver = "termhunt_reviver"

local function revivePurchase( purchaser )
    local weap = purchaser:GetWeapon( reviver )
    local hasWeap = IsValid( weap )

    if hasWeap then
        weap:AddResurrect()
        weap:AddResurrect()

    else
        weap = purchaser:Give( reviver, false )
        weap:AddResurrect()
        loadoutConfirm( purchaser, 2 )

    end
end


local beartrap = "termhunt_weapon_beartrap"

local function beartrapPurchase( purchaser )
    local weap = purchaser:GetWeapon( beartrap )
    local hasWeap = IsValid( weap )

    if hasWeap then
        weap:Charge()
        weap:Charge()
        weap:Charge()
        weap:Charge()
        weap:Charge()
        weap:Charge()

        loadoutConfirm( purchaser, 1 )

    else
        purchaser:Give( beartrap, false )
        loadoutConfirm( purchaser, 1 )
        timer.Simple( 0.1, function()
            if not IsValid( purchaser ) then return end
            weap = purchaser:GetWeapon( beartrap )
            if not IsValid( weap ) then return end
            weap:Charge()
            weap:Charge()
            weap:Charge()
            weap:Charge()
            weap:Charge()
            weap:Charge()

        end )

    end
end


local medkit = "termhunt_medkit"

local function medkitPurchase( purchaser )
    local weap = purchaser:GetWeapon( medkit )
    local hasWeap = IsValid( weap )

    if hasWeap then
        weap:HealJuice( 200 )

    else
        purchaser:Give( medkit, false )
        loadoutConfirm( purchaser, 1 )

    end
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

local function bloodDonorPurchase( purchaser )
    local scoreGiven, remainingHealth = bloodDonorCalc( purchaser )

    GAMEMODE:Bleed( purchaser, scoreGiven )

    purchaser:GivePlayerScore( scoreGiven )

    purchaser:SetHealth( remainingHealth )

    for _ = 0, 2 do
        playRandomSound( purchaser, thwaps, 75, math.random( 100, 120 ) )

    end
end


local awfulKneeSounds = {
    "npc/barnacle/neck_snap1.wav",
    "npc/barnacle/barnacle_crunch2.wav",
    "physics/body/body_medium_break4.wav",

}

local function badkneesPurchase( purchaser )
    -- save the old jump power so we can restore it later
    purchaser.kneesOriginalJumpPower = purchaser.kneesOriginalJumpPower or purchaser:GetJumpPower()
    purchaser:SetJumpPower( purchaser.kneesOriginalJumpPower * 0.70 )
    -- we'll use this variable to track whether the player owns the item
    purchaser.hasBadKnees = true

    -- create a unique hook name for multiplayer compatibility
    local hookName = "huntersglee_badknees_" .. tostring( purchaser:GetCreationID() )

    hook.Add( "GetFallDamage", hookName, function( ply, speed )
        if not IsValid( purchaser ) then hook.Remove( "GetFallDamage", hookName ) return end
        if ply ~= purchaser then return end
        if not ply.hasBadKnees then hook.Remove( "GetFallDamage", hookName ) return end

        for count = 1, 4 do
            local soundP = awfulKneeSounds[ math.random( 1, #awfulKneeSounds ) ]
            ply:EmitSound( soundP, 70, math.random( 70, 80 + count * 4 ), 1, CHAN_STATIC )

        end

        return speed

    end )

    -- do this so we can run code when the purchaser jumps
    hook.Add( "KeyPress", hookName, function( ply, key )
        if not IsValid( purchaser ) then hook.Remove( "KeyPress", hookName ) return end
        if ply ~= purchaser then return end
        if key ~= IN_JUMP then return end

        if not ply.hasBadKnees then hook.Remove( "KeyPress", hookName ) return end

        if not ply:OnGround() then return end
        if ply:WaterLevel() >= 3 then return end

        GAMEMODE:GivePanic( ply, 10 )
        ply:TakeDamage( 3, game.GetWorld(), game.GetWorld() )

        for count = 1, math.random( 1, 3 ) do
            local soundP = awfulKneeSounds[ math.random( 1, #awfulKneeSounds ) ]
            ply:EmitSound( soundP, 70, math.random( 110, 120 + count * 4 ), 1, CHAN_STATIC )

        end
    end )


    -- this function undoes what we do
    local badkneesRestore = function( someoneWithBadKnees )
        someoneWithBadKnees:SetJumpPower( someoneWithBadKnees.kneesOriginalJumpPower )
        -- remove this variable so the hooks delete themselves 
        someoneWithBadKnees.hasBadKnees = nil

    end

    local undoInnate = function( respawner )
        badkneesRestore( respawner )

    end

    -- this function cleans up the shop item when a new round is started, or the map is cleaned up.
    -- the first variable is nil because it's usually a unique identifier for a timer, and this hop item doesn't use one.
    -- the function works even if the var is nil
    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

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
        personWhoHasFrogLegs:doSpeedModifier( "froglegs", -100 )
        personWhoHasFrogLegs.canWallkick = true
        personWhoHasFrogLegs.parkourForce = 1.25

    end

    -- This function undoes what we do
    local function frogLegsRestore( personWhoHasFrogLegs )
        personWhoHasFrogLegs:doSpeedModifier( "froglegs", nil )
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

        dmg = dmg * 1.5 -- if we get past the check, punish player

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

local function mimicMadnessPurchase( purchaser )
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
            theMimicPropOnTop:SetBodyGroups( nearestProp:GetBodyGroups() )
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

            if ply:Alive() then
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

            if firstJump or not purchaser:Alive() or mimicWithBustedProp then
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

end

local function temporalDiceRollPurchase( purchaser )
    -- We'll use this variable to track whether the player owns the item
    purchaser.hasTemporalDiceRoll = true

    local function teleportToRandomNavArea( ply )
        if not IsValid( ply ) then return end

        local beamStart = ply:WorldSpaceCenter()

        local randomNavArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
        local randomPos = randomNavArea:GetCenter()

        ply:SetPos( randomPos )
        ply:unstuckFullHandle()

        ply:EmitSound( "ambient/levels/labs/electric_explosion3.wav", 85, 40, 0.4, CHAN_STATIC )
        ply:EmitSound( "ambient/levels/labs/electric_explosion5.wav", 85, 100, 1, CHAN_STATIC )
        ply:EmitSound( "physics/concrete/concrete_impact_hard3.wav", 85, 100, 1, CHAN_STATIC )

        local beamEnd = ply:WorldSpaceCenter()

        util.ScreenShake( randomPos, 10, 20, 4, 1000 )

        local beam = EffectData()
        beam:SetStart( beamStart )
        beam:SetOrigin( beamEnd )
        beam:SetScale( 1.5 )
        util.Effect( "eff_huntersglee_dicebeam", beam, true )

    end

    local timerName = "temporaldiceroll_timer_" .. tostring( purchaser:GetCreationID() )

    timer.Create( timerName, 1, 8, function()
        if not IsValid( purchaser ) then timer.Remove( timerName ) return end
        if not purchaser:Alive() then timer.Remove( timerName ) return end
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

function channel666Check( purchaser )
    if not purchaser:GetNW2Bool( "glee_canpurchase_666", false ) then
        return false, "Pure souls cannot purchase this.\nYou must sin...\nMurder when it lasts, will suffice."

    end

    return true

end

function channel666Purchase( purchaser )
    purchaser:SetNWBool( "glee_cantalk_tothedead", true )

    local undoInnate = function( respawner )
        respawner:SetNWBool( "glee_cantalk_tothedead", false )

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


if SERVER then
    util.AddNetworkString( "huntersglee_blindnessdefine" )

end

if CLIENT then
    local _LocalPlayer          = LocalPlayer
    local _ScrW                 = ScrW
    local _ScrH                 = ScrH
    local surface_SetDrawColor  = surface.SetDrawColor
    local surface_DrawRect      = surface.DrawRect
    local util_PointContents    = util.PointContents

    net.Receive( "huntersglee_blindnessdefine", function()
        local blindState = net.ReadBool()
        LocalPlayer().glee_IsBlind = blindState

    end )

    local function IsBlind()
        if _LocalPlayer().glee_IsBlind ~= true then return end
        if _LocalPlayer():GetNWBool( "huntersglee_shouldbeblind", nil ) ~= true then return end
        if _LocalPlayer():Health() <= 0 then return end

        return true

    end

    hook.Add( "PreDrawHUD", "huntersglee_blindnessitem", function()
        -- spaghetti but im paranoid of someone exploiting this to blind everyone
        if not IsBlind() then return end

        local alpha = 230

        if bit.band( util_PointContents( _LocalPlayer():GetShootPos() ), CONTENTS_WATER )  ~= 0 then
            alpha = 255

        end

        surface_SetDrawColor( 0, 0, 0, alpha )
        surface_DrawRect( -_ScrW() * 0.5, -_ScrH() * 0.5, _ScrW(), _ScrH() )

    end )

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

    hook.Add( "PostDraw2DSkyBox", "huntersglee_blindness_overridesky", function()
        -- spaghetti but im paranoid of someone exploiting this to blind everyone
        if not IsBlind() then return end

        render.OverrideDepthEnable( true, false ) -- ignore Z to prevent drawing over 3D skybox

        -- Start 3D cam centered at the origin
        cam.Start3D( vecZero, EyeAngles() )
            for _, tiltedVec in ipairs( tiltedVecs ) do
                render.SetMaterial( skyOverrideMat )
                render.DrawQuadEasy( skyOverridePos, tiltedVec, 32000, 32000, skyOverrideColor, 0 )

            end
        cam.End3D()

        render.OverrideDepthEnable( false, false )

    end )

    local blindnessFog = function( scale )
        -- spaghetti but im paranoid of someone exploiting this to blind everyone
        if not IsBlind() then return end

        scale = scale or 0.9

        render.FogMode( MATERIAL_FOG_LINEAR )
        render.FogStart( 50 * scale )
        render.FogEnd( 200 * scale )
        render.FogMaxDensity( 1 )
        render.FogColor( 0,0,0 )

        return true

    end

    hook.Add( "SetupWorldFog", "huntersglee_blindnessfog_world", blindnessFog )
    hook.Add( "SetupSkyboxFog", "huntersglee_blindnessfog_skybox", blindnessFog )

end

local function blindnessPurchase( purchaser )

    local sendBlindnessDefine = function( blinder, bool )
        if bool == nil then return end
        net.Start( "huntersglee_blindnessdefine" )
        net.WriteBool( bool )
        net.Send( blinder )
        blinder:SetNWBool( "huntersglee_shouldbeblind", bool )

    end

    sendBlindnessDefine( purchaser, true )

    local undoInnate = function( respawner )
        sendBlindnessDefine( respawner, false )

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end

local function hypochondriacPurchase( purchaser )
    local hookName = "glee_hypochondriac_panicdamage_" .. purchaser:GetCreationID()

    local sendHypochondriacDefine = function( hypochondriac, bool )
        if bool == nil then return end
        hypochondriac:SetNWBool( "huntersglee_ishypochondriac", bool )

    end

    hook.Add( "EntityTakeDamage", hookName, function( victim, dmgInfo )
        if victim ~= purchaser then return end
        if not IsValid( purchaser ) then hook.Remove( "EntityTakeDamage", hookName ) return end
        if not purchaser:GetNWBool( "huntersglee_ishypochondriac", bool ) then hook.Remove( "EntityTakeDamage", hookName ) return end

        if purchaser:Health() <= 0 then return end

        local damageDone = dmgInfo:GetDamage()

        GAMEMODE:GivePanic( purchaser, damageDone * 4 )

    end )

    sendHypochondriacDefine( purchaser, true )

    local undoInnate = function( respawner )
        sendHypochondriacDefine( respawner, false )

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end

local function deafnessPurchase( purchaser )
    purchaser.glee_IsDeaf = true

    local timerName = "huntersglee_DeafnessInnateTimer_" .. purchaser:GetClass() .. purchaser:EntIndex()

    local function giveDeaf()
        purchaser:SetDSP( 31 )

    end
    local function unDeafInternal()
        purchaser:SetDSP( 1 )

    end
    local function unDeaf()
        unDeafInternal()
        purchaser.glee_IsDeaf = false

    end

    timer.Create( timerName, 1, 0, function()
        if IsValid( purchaser ) then
            if not purchaser.glee_IsDeaf then timer.Remove( timerName ) return end
            if purchaser:Health() <= 0 then unDeafInternal() return end
            giveDeaf()

        else
            timer.Remove( timerName )

        end
    end )

    giveDeaf()

    local undoInnate = function( respawner )
        unDeaf()

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


local function superiorMetabolismPurchase( purchaser )
    purchaser.oldRegenerationScore = purchaser.realHeartBeats

    local timerName = "supMetabolismTimer_" .. purchaser:GetClass() .. purchaser:EntIndex()

    local doSuperiorMetabolismThink = function()
        local currBeats = purchaser.realHeartBeats
        local oldBeats = purchaser.oldRegenerationScore

        if currBeats ~= oldBeats then
            purchaser.oldRegenerationScore = purchaser.realHeartBeats
            if currBeats <= oldBeats then return end -- wtf?

            local amount = 1

            local newHealth = math.Clamp( purchaser:Health() + amount, 0, purchaser:GetMaxHealth() )
            purchaser:SetHealth( newHealth )

        end
    end

    -- Set the timer to repeat the sound
    timer.Create( timerName, 0.05, 0, function()
        if IsValid( purchaser ) then
            if purchaser:Health() <= 0 then return end
            doSuperiorMetabolismThink()

        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )

        end
    end )

    local undoInnate = function( _ )
        timer.Remove( timerName )
        purchaser.oldRegenerationScore = nil

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


local function marathonRunnerPurchase( purchaser )
    local timerName = "marathonRunnerTimer_" .. purchaser:GetClass() .. purchaser:EntIndex()

    local doRunnerThink = function()
        local myCenter = purchaser:WorldSpaceCenter()
        local calustrophobiaNookScore = 1
        local nooking = terminator_Extras.GetNookScore( myCenter )

        if nooking < 3.2 then
            calustrophobiaNookScore = nooking / 200

        else
            calustrophobiaNookScore = nooking / 2

        end

        purchaser.calustrophobiaNookScore = calustrophobiaNookScore
        local panicToGive = 0
        local doGive

        if ( purchaser.nextClaustrophobiaInc or 0 ) < CurTime() then
            purchaser.nextClaustrophobiaInc = CurTime() + 1

            doGive = true

        end

        if nooking > 5.2 then
            panicToGive = panicToGive + 12

        elseif nooking > 4.5 then
            panicToGive = panicToGive + 8

        elseif nooking >= 3 then
            panicToGive = panicToGive + 3 -- don't decrease!

        elseif nooking < 3 then
            panicToGive = panicToGive + -1

        elseif nooking < 2.5 then
            panicToGive = panicToGive + -5

        end

        if doGive then
            GAMEMODE:GivePanic( purchaser, panicToGive )

        end
        -- end claustrophobia

        local speedBoost = 100
        speedBoost = math.Clamp( speedBoost + -( panicToGive * 40 ), -150, 150 )
        purchaser:doSpeedModifier( "marathonrunner", speedBoost )

    end

    local hookName = tostring( purchaser:GetCreationID() ) .. "claustrophobiainnate"
    hook.Add( "termhunt_scaleaddedbpm", hookName, function( plyGettinBPM, lastScale )

        if plyGettinBPM ~= purchaser then return end

        if not purchaser.calustrophobiaNookScore then return end

        return lastScale * purchaser.calustrophobiaNookScore

    end )

    -- Set the timer to repeat the sound
    timer.Create( timerName, 0.05, 0, function()
        if IsValid( purchaser ) then
            if purchaser:Health() <= 0 then return end
            doRunnerThink()

        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )

        end
    end )

    local undoInnate = function( _ )
        timer.Remove( timerName )
        purchaser:doSpeedModifier( "marathonrunner", nil )
        hook.Remove( "termhunt_scaleaddedbpm", hookName )
        purchaser.nextClaustrophobiaInc = nil
        purchaser.calustrophobiaNookScore = nil --calus strophobia moment

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

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


local function coldbloodedPurchase( purchaser )
    local timerName = "ColdBloodedTimer_" .. purchaser:GetClass() .. purchaser:GetCreationID()

    purchaser.doSpeedMod = function()
        local BPM = purchaser:GetNWInt( "termHuntPlyBPM" ) or 60
        local usefulBPM = BPM - 85
        usefulBPM = usefulBPM * 3.1

        purchaser:doSpeedModifier( "coldblooded", usefulBPM )

    end

    timer.Create( timerName, 0.1, 0, function()
        if IsValid( purchaser ) then
            if purchaser:Health() <= 0 then return end
            purchaser.doSpeedMod()

        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )

        end
    end )

    local undoInnate = function( respawner )
        respawner:doSpeedModifier( "coldblooded", nil )
        timer.Remove( timerName )

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end


local function chameleonCanPurchase( purchaser )
    if purchaser.hasChameleon then return false, "You already have this gene." end
    return true

end

local function chameleonPurchase( purchaser )
    local chameleonColor = function( toColor )
        toColor:Fire( "alpha", 20, 0 )
        toColor:SetRenderMode( RENDERMODE_TRANSALPHA )

    end
    local chameleonColorRestore = function( toColor )
        toColor:Fire( "alpha", 255, 0 )
        toColor:SetRenderMode( RENDERMODE_NORMAL )

    end

    local timerName = "glee_chameleonensurecolor_" .. purchaser:GetCreationID()
    timer.Create( timerName, 0.1, 0, function()
        if not purchaser then timer.Remove( timerName ) return end
        if not IsValid( purchaser ) then timer.Remove( timerName ) return end
        if not purchaser.hasChameleon then timer.Remove( timerName ) return end
        if purchaser.gleeIsMimic then return end
        if purchaser:Health() <= 0 then return end
        if purchaser:GetColor().a == 20 then return end

        chameleonColor( purchaser )

    end )

    chameleonColor( purchaser )

    purchaser.hasChameleon = true

    local undoInnate = function( respawner )
        respawner.hasChameleon = nil
        chameleonColorRestore( respawner )

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )
end


local function juggernautPurchase( purchaser )
    purchaser.isJuggernaut = true
    local applyNaut = function()
        local currentHealthRatio = purchaser:Health() / purchaser:GetMaxHealth()

        local newMaxHealth = 500
        local newHealth = newMaxHealth * currentHealthRatio

        purchaser:SetMaxHealth( newMaxHealth )
        purchaser:SetHealth( newHealth )

        purchaser:doSpeedClamp( "juggernautclamp", 0 ) -- speed cannot go higher

    end

    local hookKey1 = "huntersglee_shop_juggernaut_reapply" .. purchaser:GetCreationID()

    local hookEnd1 = function()
        hook.Remove( "PlayerSpawn", hookKey1 )

    end

    hook.Add( "PlayerSpawn", hookKey1, function( spawned )
        timer.Simple( 0.1, function()
            if not IsValid( spawned ) then return end
            if not IsValid( purchaser ) then hookEnd1() return end
            if spawned ~= purchaser then return end
            if not purchaser.isJuggernaut then hookEnd1() return end

            applyNaut()

        end )
    end )

    local hookKey2 = "huntersglee_shop_juggernaut_clomping" .. purchaser:GetCreationID()

    local hookEnd2 = function()
        hook.Remove( "PlayerFootstep", hookKey1 )

    end

    hook.Add( "PlayerFootstep", hookKey2, function( ply, _, foot ) 
        if ply ~= purchaser then return end
        if not ply.isJuggernaut then hookEnd2() return end
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
        local volume = 0.2 + ( velLeng / 400 )
        ply:EmitSound( stepSnd, 90, pitch, volume, CHAN_AUTO )
        ply:EmitSound( "npc/headcrab_poison/ph_wallhit2.wav", 90, math.random( 70,90 ), 0.6, CHAN_STATIC )

        return true

    end )

    applyNaut()

    local undoInnate = function( respawner )
        respawner:doSpeedClamp( "juggernautclamp", nil )
        respawner.isJuggernaut = nil
        hookEnd1()
        hookEnd2()

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end

local slipSound = Sound( "482735__copyc4t__cartoon-long-throw.wav" )

local function greasyHandsPurchase( purchaser )

    purchaser.glee_hasGreasyHands = true

    local hookKey1 = "huntersglee_shop_greasyhands_swap" .. purchaser:GetCreationID()
    local timerName = "huntersglee_shop_greasyhands_firing" .. purchaser:GetCreationID()

    local function passesTheBpmTest( ply, added )
        added = added or 0
        return ply:GetNWInt( "termHuntPlyBPM" ) > math.random( 59, 300 + added )

    end

    local function dropWeaponFunny( wep )
        purchaser:EmitSound( slipSound, 78, math.random( 100, 110 ), 0.9 )
        timer.Simple( 0.1, function()
            if not IsValid( purchaser ) then return end
            if not IsValid( wep ) then return end
            if not purchaser:HasWeapon( wep:GetClass() ) then return end
            -- zamn u never know what can happen in 0.1 seconds....
            purchaser:DropWeaponKeepAmmo( wep )

        end )
    end

    hook.Add( "PlayerSwitchWeapon", hookKey1, function( swapper, _, newWeapon )
        if swapper ~= purchaser then return end
        if not purchaser.glee_hasGreasyHands then hook.Remove( hookKey1 ) return end
        if purchaser:Health() <= 0 then return end

        if passesTheBpmTest( purchaser ) or purchaser.glee_greasyhands_queuedDrop then
            if not purchaser:CanDropWeaponKeepAmmo( newWeapon ) then
                purchaser.glee_greasyhands_queuedDrop = true
                return

            end
            purchaser.glee_greasyhands_queuedDrop = nil
            dropWeaponFunny( newWeapon )

        end
    end )

    timer.Create( timerName, 0.75, 0, function()
        if not IsValid( purchaser ) then timer.Remove( timerName ) return end
        if not purchaser.glee_hasGreasyHands then timer.Remove( timerName ) return end
        if purchaser:Health() <= 0 then return end

        if not purchaser:KeyDown( IN_ATTACK ) and not purchaser:KeyDown( IN_ATTACK2 ) then return end

        local wep = purchaser:GetActiveWeapon()

        if not purchaser:CanDropWeaponKeepAmmo( wep ) then return end
        if not passesTheBpmTest( purchaser, 100 ) then return end

        dropWeaponFunny( wep )

    end )

    local undoInnate = function( respawner )
        hook.Remove( hookKey1 )
        timer.Stop( timerName )
        respawner.glee_hasGreasyHands = nil
        respawner.glee_greasyhands_queuedDrop = nil

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


sound.Add( {
    name = "horrific_backpack_scream",
    channel = CHAN_STATIC,
    level = 150,
    sound = "npc/scanner/combat_scan1.wav"
} )

local function PlayRepeatingSound( self, soundPath, soundDuration )

    local backpackEveryoneFilter = RecipientFilter()
    backpackEveryoneFilter:AddAllPlayers()
    backpackEveryoneFilter:RemovePlayer( self ) -- don't deafen our user pls

    self.horrificSound = CreateSound( self, soundPath, backpackEveryoneFilter )

    -- Create a unique timer name for this entity
    local timerName = "SoundTimer_" .. self:GetClass() .. self:EntIndex()

    self.doSound = function( soundPlayer )
        soundPlayer.horrificSound:Stop()
        soundPlayer.horrificSound:PlayEx( 0.7, math.random( 120, 130 ) )

        sound.EmitHint( SOUND_COMBAT, soundPlayer:GetPos(), 20000, 1, soundPlayer )

        soundPlayer:EmitSound( soundPath, 120, math.random( 140, 150 ), 1, CHAN_STATIC )

        util.ScreenShake( soundPlayer:GetPos(), 1, 20, 0.1, 1000 )
        local obj = soundPlayer:GetPhysicsObject()
        if not obj then return end
        obj:ApplyForceCenter( VectorRand() * obj:GetMass() * 100 )
        obj:ApplyTorqueCenter( VectorRand() * obj:GetMass() * 100 )

    end

    self:doSound( soundPath )

    -- Set the timer to repeat the sound
    timer.Create( timerName, soundDuration, 0, function()
        if IsValid( self ) then
            if self:Health() <= 0 then return end
            -- Only play the sound if the entity is still valid
            self:doSound( soundPath )
        else
            -- If the entity is no longer valid, stop the timer
            timer.Remove( timerName )
        end
    end )

    return timerName

end

local function screamingBackpackPurchase( purchaser )
    local timerName = PlayRepeatingSound( purchaser, "horrific_backpack_scream", 15 )

    local undoInnate = function( _ )
        timer.Remove( timerName )
    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end

local function marcoPoloPurchase( purchaser )
    local timerName = "huntersglee_marcopolo" .. purchaser:GetCreationID()

    purchaser:SetNWBool( "termHuntBlockScoring2", true )

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
        purchaser:SetNWBool( "termHuntBlockScoring2", false )
        purchaser.marcoPoloExploredStatuses = nil
        purchaser.marcopolo_ToExploreCount = nil
        purchaser.marcopolo_ExploredCount = nil
        timer.Remove( timerName )

    end

    GAMEMODE:PutInnateInProperCleanup( timerName, undoInnate, purchaser )

end

local function posCanSee( startPos, endPos )
    local trData = {
        start = startPos,
        endpos = endPos,
        mask = MASK_SOLID_BRUSHONLY,
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

local nextWitnessRecieve = 0

net.Receive( "glee_witnesseddeathconfirm", function()
    if nextWitnessRecieve > CurTime() then return end
    nextWitnessRecieve = CurTime() + 0.01
    local witnessing = net.ReadEntity()

    if witnessing == LocalPlayer() then return end

    if not posCanSee( LocalPlayer():GetShootPos(), witnessing:GetShootPos() ) then return end

    timer.Simple( 1.50, function()
        if not IsValid( LocalPlayer() ) then return end
        LocalPlayer():EmitSound( "ambient/atmosphere/thunder3.wav", 75, 65, 1, CHAN_STATIC )

    end )
end )

local function witnessPurchase( purchaser )

    -- set enemy.attackConfirmedBlock to true to block attacks

    purchaser.AttackConfirmed = function( gettingAttacked, attacker )
        if not attacker or not gettingAttacked then return end
        if GAMEMODE.roundExtraData.witnessed == true then return end
        if attacker:GetEnemy() ~= gettingAttacked then return end
        if not terminator_Extras.posCanSee( attacker:GetShootPos(), gettingAttacked:GetShootPos(), MASK_SOLID_BRUSHONLY ) then return end

        local count = 0

        local purchaseShootPos = gettingAttacked:GetShootPos()
        for _, ply in ipairs( player.GetAll() ) do
            if terminator_Extras.posCanSee( ply:GetShootPos(), purchaseShootPos, MASK_SOLID_BRUSHONLY ) then
                count = count + 1

            end
        end

        if count <= 1 then -- player only sees themself
            local nextInvalidWitness = gettingAttacked.nextInvalidWitness or 0
            if nextInvalidWitness > CurTime() then return end -- don't spam
            gettingAttacked.nextInvalidWitness = CurTime() + 1
            gettingAttacked:EmitSound( "ambient/machines/thumper_hit.wav", 90, 80, 0.5 )
            gettingAttacked:EmitSound( "weapons/fx/nearmiss/bulletltor07.wav", 90, 80, 0.3 )
            huntersGlee_Announce( { gettingAttacked }, 5, 5, "There is nobody to witness your fate..." )
            return

        end

        -- do score early for instant feedback
        local score = 0
        local witnessing = {}
        purchaseShootPos = gettingAttacked:GetShootPos()

        for _, ply in ipairs( player.GetAll() ) do
            if ply == gettingAttacked then continue end
            if terminator_Extras.posCanSee( purchaseShootPos, ply:GetShootPos(), MASK_SOLID_BRUSHONLY ) then
                table.insert( witnessing, ply )
                score = score + 250
                GAMEMODE:GivePanic( ply, 50 ) -- terrifying
            end
        end

        huntersGlee_Announce( witnessing, 10, 15, "YOU WITNESS " .. string.upper( gettingAttacked:Name() ) )

        -- s OR not s
        SorNotS = ""
        SorNotSOpp = "S"

        if #witnessing > 1 then
            SorNotS = "S"
            SorNotSOpp = ""

        end
        huntersGlee_Announce( { gettingAttacked }, 15, 15, #witnessing .. " SOUL" .. SorNotS .. " BARE" .. SorNotSOpp .. " WITNESS TO YOUR FATE" )

        score = math.Clamp( score, 0, math.huge )

        gettingAttacked:GivePlayerScore( score )

        gettingAttacked.attackConfirmedBlock = true
        attacker.OverrideShootAtThing = gettingAttacked

        GAMEMODE.roundExtraData.witnessed = true
        gettingAttacked.preWitnessDamageMult = gettingAttacked.termhuntDamageMult
        gettingAttacked.termhuntDamageMult = 0

        util.ScreenShake( gettingAttacked:GetPos(), 0.5, 20, 3, 5000 )
        gettingAttacked:EmitSound( "ambient/machines/thumper_hit.wav", 150, 40, 0.5 )
        game.SetTimeScale( 0.2 )

        timer.Simple( 0.45, function()
            attacker:WeaponPrimaryAttack()
            gettingAttacked:EmitSound( "weapons/fx/nearmiss/bulletltor07.wav", 150, 40, 0.3 )

        end )

        timer.Simple( 0.5, function()
            GAMEMODE:Bleed( gettingAttacked, math.huge )

            gettingAttacked.termhuntDamageMult = 100
            game.SetTimeScale( 0.4 )
            util.ScreenShake( gettingAttacked:GetPos(), 10, 0.1, 3, 5000 )
            for _ = 0, 4 do
                playRandomSound( gettingAttacked, thwaps, 150, math.random( 20, 40 ) )

            end

            net.Start( "glee_witnesseddeathconfirm" )
            net.WriteEntity( gettingAttacked )
            net.Broadcast()

            local damage = DamageInfo()
            damage:SetDamage( 5000000 )
            damage:SetDamagePosition( gettingAttacked:WorldSpaceCenter() )
            damage:SetDamageForce( terminator_Extras.dirToPos( attacker:GetShootPos(), gettingAttacked:GetShootPos() ) * 200000000 )
            damage:SetAttacker( attacker )
            damage:SetInflictor( attacker )
            damage:SetDamageType( DMG_CLUB )
            gettingAttacked:TakeDamageInfo( damage )

            gettingAttacked.attackConfirmedBlock = nil

        end )
        timer.Simple( 2, function()
            attacker.OverrideShootAtThing = nil
            gettingAttacked.termhuntDamageMult = gettingAttacked.preWitnessDamageMult
            game.SetTimeScale( 1 )

        end )
    end

    local undoInnate = function( respawner )
        respawner.AttackConfirmed = nil

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


if SERVER then
    util.AddNetworkString( "huntersglee_sixthsensedefine" )

end

if CLIENT then
    local _LocalPlayer  = LocalPlayer
    local _CurTime      = CurTime
    local _IsValid      = IsValid

    net.Receive( "huntersglee_sixthsensedefine", function()
        local senseState = net.ReadBool()
        LocalPlayer().sixthSenseState = senseState

    end )

    local function HasSixthSense()
        if _LocalPlayer().sixthSenseState ~= true then return end
        if _LocalPlayer():GetNWBool( "huntersglee_hassixthsense", nil ) ~= true then return end
        if _LocalPlayer():Health() <= 0 then return end

        return true

    end

    local function sortForClosestTo( sortPos, stuffToSort )
        if #stuffToSort <= 1 then return stuffToSort end
        table.sort( stuffToSort, function( a, b )
            if not _IsValid( b ) then return end
            if not _IsValid( a ) then return end
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

    local armor = {}
    local slams = {}
    local medkits = {}
    local hunters = {}
    local players = {}
    local bearTraps = {}
    local scoreBalls = {}
    local itemCrates = {}

    local sixthSenseStuff = {}

    local nextCache = 0
    local nextSort = 0

    hook.Add( "HUDPaint", "huntersglee_sixthsenseitem", function()
        if not HasSixthSense() then return end
        local curTime = CurTime()
        local me = _LocalPlayer()

        -- big find!
        if nextCache < curTime then
            nextCache = curTime + 5

            armor = ents.FindByClass( "item_battery" )
            slams = ents.FindByClass( "npc_tripmine" )

            medkits = ents.FindByClass( "item_healthkit" )
            table.Add( medkits, ents.FindByClass( "item_healthvial" ) )

            players = ents.FindByClass( "player" )
            hunters = ents.FindByClass( "sb_advanced_nextbot_terminator_hunter_*" )

            bearTraps = ents.FindByClass( "termhunt_bear_trap" )

            scoreBalls = ents.FindByClass( "termhunt_score_pickup" )
            itemCrates = ents.FindByClass( "item_item_crate" )

        -- sort em and filter for stuff we actually care bout
        elseif nextSort < curTime then
            nextSort = curTime + 0.5

            table.Empty( sixthSenseStuff )

            local myPos = me:GetPos()

            if me:Armor() < me:GetMaxArmor() then
                table.Add( sixthSenseStuff, armor )

            end
            if me:Health() < me:GetMaxHealth() then
                table.Add( sixthSenseStuff, medkits )

            end
            table.Add( sixthSenseStuff, slams )
            table.Add( sixthSenseStuff, hunters )
            table.Add( sixthSenseStuff, players )
            table.Add( sixthSenseStuff, bearTraps )
            table.Add( sixthSenseStuff, scoreBalls )
            table.Add( sixthSenseStuff, itemCrates )

            sixthSenseStuff = sortForClosestTo( myPos, sixthSenseStuff )

        end

        local myPos = me:GetShootPos()
        local shown = 0

        for _, sensed in ipairs( sixthSenseStuff ) do
            if shown > 25 then return end
            if not _IsValid( sensed ) then continue end
            if sensed == me then continue end

            local sensedPos = sensed:WorldSpaceCenter()
            local distance = sensedPos:Distance( myPos )

            if distance > maxDistance then break end

            local reversedDistance = maxDistance - distance
            reversedDistance = math.abs( reversedDistance )

            local unknownAlphaBite = 0 -- make stuff have less alpha when we dont see it for a while
            local oldPos = sensed.sixthSenseOldPos or sensedPos
            local randomScale = distance / 50
            if sensed:IsDormant() then
                sensed.glee_sixthsense_wasdormant = true
                sensedPos = oldPos
                randomScale = randomScale * 0.75

                local lastRealSeen = sensed.glee_sixthsense_lastRealSeen or 0
                if lastRealSeen ~= 0 then
                    timeSinceLastSeen = curTime - lastRealSeen
                    unknownAlphaBite = timeSinceLastSeen / 90

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

            if sensed:GetNW2Bool( "isdivinechosen", nil ) then
                if sensed:Health() <= 0 then continue end
                sixthSenseColor = sixthSenseHunter
                spriteSize = 200

            elseif classOfSensed == "termhunt_bear_trap" or classOfSensed == "npc_tripmine" then
                if distance > 2000 then continue end
                sixthSenseColor = sixthSenseHunter

                local terror = reversedDistance + -( maxDistance * 0.8 )
                terror = terror / 2
                terror = terror^1.04

                spriteSize = terror

            elseif sensed:IsNPC() or sensed:IsNextBot() and not ( suspicious and not sensed.glee_sixthsense_revealed and math.random( 0, 300 ) < distance ) then
                if sensed:Health() <= 0 then continue end
                sixthSenseColor = sixthSenseHunter

                local overwhelmingTerror = reversedDistance + -( maxDistance * 0.75 )
                overwhelmingTerror = math.max( overwhelmingTerror, 1 )
                overwhelmingTerror = overwhelmingTerror^1.16

                randomScale = randomScale + overwhelmingTerror / 18
                spriteSize = 150 + overwhelmingTerror
                if suspicious then
                    sensed.glee_sixthsense_revealed = true

                end

            elseif sensed:IsPlayer() or suspicious then
                if sensed:Health() <= 0 then continue end
                sixthSenseColor = sixthSensePlayer
                spriteSize = 100

            end

            local newPos = sensedPos + ( VectorRand() * randomScale )
            local posSmoothed = ( newPos * 0.08 ) + ( oldPos * 0.92 )
            local imprecisePos = posSmoothed
            sensed.sixthSenseOldPos = posSmoothed

            local pos2d = imprecisePos:ToScreen()
            local opaqueWhenClose = ( ( reversedDistance / maxDistance ) * 2 ) + -unknownAlphaBite

            -- this is laggy but it gives the intended effect
            local sixthSenseColorNew = Color( sixthSenseColor.r * opaqueWhenClose, sixthSenseColor.g * opaqueWhenClose, sixthSenseColor.b * opaqueWhenClose )
            local centeringOffset = -spriteSize / 2

            local texturedQuadStructure = {
                texture = surface.GetTextureID( "sprites/light_glow02_add_noz" ),
                color   = sixthSenseColorNew,
                x 	= pos2d.x + centeringOffset,
                y 	= pos2d.y + centeringOffset,
                w 	= spriteSize,
                h 	= spriteSize
            }

            draw.TexturedQuad( texturedQuadStructure )

            shown = shown + 1

        end
    end )
end

local function sixthSensePurchase( purchaser )
    local hookId = "huntersglee_sixthsense" .. purchaser:GetCreationID()

    local sendSixthSenseDefine = function( purchaser, bool )
        if bool == nil then return end
        net.Start( "huntersglee_sixthsensedefine" )
        net.WriteBool( bool )
        net.Send( purchaser )
        purchaser:SetNWBool( "huntersglee_hassixthsense", true )

    end

    local function shopItemRemove()
        hook.Remove( "terminator_spotenemy", hookId )
        hook.Remove( "terminator_loseenemy", hookId )
        if not IsValid( purchaser ) then return end
        sendSixthSenseDefine( purchaser, false )
        purchaser.glee_nextSixthSenseSpottedSound = nil
        purchaser.glee_hasSixthSense = nil

    end

    local function hookAdd()
        purchaser.glee_hasSixthSense = true
        hook.Add( "terminator_spotenemy", hookId, function( term, spotted )
            if not IsValid( purchaser ) then shopItemRemove() return end
            if spotted ~= purchaser then return end
            if not purchaser.glee_hasSixthSense then shopItemRemove() return end

            local nextSound = purchaser.glee_nextSixthSenseSpottedSound or 0
            if nextSound > CurTime() then return end

            purchaser.glee_nextSixthSenseSpottedSound = CurTime() + 30

            local distance = purchaser:GetPos():Distance( term:GetPos() )

            if distance > 800 then
                purchaser:EmitSound( "physics/metal/metal_barrel_impact_hard3.wav", 75, 80, 0.6, CHAN_STATIC )
                purchaser:EmitSound( "ambient/atmosphere/city_truckpass1.wav", 75, 70, 1, CHAN_STATIC )

                GAMEMODE:GivePanic( purchaser, 15 )

                huntersGlee_Announce( { purchaser }, 5, 10, "Your sixth sense strains... Something is terribly wrong..." )

            else
                purchaser:EmitSound( "physics/wood/wood_plank_impact_hard5.wav", 75, 50, 0.6, CHAN_STATIC )
                purchaser:EmitSound( "plats/rackstop1.wav", 75, 70, 0.6, CHAN_STATIC )
                GAMEMODE:GivePanic( purchaser, 40 )

                huntersGlee_Announce( { purchaser }, 5, 10, "MOVE!" )

            end

        end )
        hook.Add( "terminator_enemythink", hookId, function( term, theThingWhoIsEnemy )
            if not IsValid( purchaser ) then shopItemRemove() return end
            if theThingWhoIsEnemy ~= purchaser then return end
            if not theThingWhoIsEnemy.glee_hasSixthSense then shopItemRemove() return end

            local nextSound = theThingWhoIsEnemy.glee_nextSixthSenseSpottedSound or 0
            if nextSound > CurTime() then -- keep increasing this so that the sound hit isn't spammed during chases
                theThingWhoIsEnemy.glee_nextSixthSenseSpottedSound = CurTime() + 10

            end

            local nextSixthSenseTrackingPanic = theThingWhoIsEnemy.glee_nextSixthSenseTrackingPanic or 0
            if nextSixthSenseTrackingPanic > CurTime() then return end

            theThingWhoIsEnemy.glee_nextSixthSenseTrackingPanic = CurTime() + 1

            local distance = term:GetPos():Distance( theThingWhoIsEnemy:GetPos() )

            if distance < 500 then
                GAMEMODE:GivePanic( theThingWhoIsEnemy, 16 )

            elseif distance < 1000 or term.IsSeeEnemy then
                GAMEMODE:GivePanic( theThingWhoIsEnemy, 8 )

            end
        end )
    end

    hookAdd()
    sendSixthSenseDefine( purchaser, true )

    local undoInnate = function( _ )
        shopItemRemove()

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end


local function lockpickCanPurchase( purchaser )
    if purchaser:HasWeapon( "termhunt_lockpick" ) then return false, "You already have a lockpick." end
    return true
end

local function lockpickPurchase( purchaser )
    purchaser:Give( "termhunt_lockpick" )

    loadoutConfirm( purchaser, 1 )

end


hook.Add( "PlayerSpawn", "huntersglee_blockzoom", function( ply, _ )
    local canZoom = false
    if ply:GetNW2Bool( "huntersglee_canzoom", nil ) == true then
        canZoom = true

    end

    ply:SetCanZoom( canZoom )

end )

local function zoomPurchase( purchaser )
    local setCanZoom2 = function( user, canZoom )
        if canZoom == false then
            user:StopZooming()

        end
        user:SetCanZoom( canZoom )
        user:SetNW2Bool( "huntersglee_canzoom", canZoom )

    end

    setCanZoom2( purchaser, true )

    local undoInnate = function( respawner )
        setCanZoom2( respawner, false )

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

    loadoutConfirm( purchaser, 1 )

end


hook.Add( "PlayerSwitchFlashlight", "huntersglee_blockflashlight", function( ply, _ )
    if ply:GetNW2Bool( "huntersglee_flashlight", nil ) ~= true then return false end
    return true

end )

local function flashlightPurchase( purchaser )
    local setFlashlight = function( user, flashbool )
        if flashbool == false then
            user:Flashlight( false )

        end
        user:SetNW2Bool( "huntersglee_flashlight", flashbool )

    end

    setFlashlight( purchaser, true )

    local undoInnate = function( respawner )
        setFlashlight( respawner, false )

    end

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

    loadoutConfirm( purchaser, 1 )

end


local function loadoutPurchase( purchaser )
    purchaser:GiveAmmo( 96,   "Pistol",         true )
    purchaser:GiveAmmo( 96,   "SMG1",         true )
    purchaser:GiveAmmo( 24,    "Buckshot",     true )
    purchaser:GiveAmmo( 16,    "357",             true )

    purchaser:Give( "weapon_pistol" )
    purchaser:Give( "weapon_smg1" )
    purchaser:Give( "weapon_shotgun" )
    purchaser:Give( "weapon_357" )

    loadoutConfirm( purchaser, 4 )

end


local function ar2Purchase( purchaser )

    local ar2 = purchaser:GetWeapon( "weapon_ar2" )
    if IsValid( ar2 ) then
        purchaser:GiveAmmo( 3,    "AR2AltFire",         true )
        purchaser:GiveAmmo( 156,   "AR2",         true )

    else
        purchaser:GiveAmmo( 2,    "AR2AltFire",         true )
        purchaser:GiveAmmo( 96,   "AR2",         true )

        purchaser:Give( "weapon_ar2" )

    end

    loadoutConfirm( purchaser, 1 )

end


local function gravityGunCanPurchase( purchaser )
    local gravgun = purchaser:GetWeapon( "weapon_physcannon" )
    if IsValid( gravgun ) then return false, "You aready have a Gravity Gun!" end
    return true

end

local function gravityGunPurchase( purchaser )
    purchaser:Give( "weapon_physcannon" )

    loadoutConfirm( purchaser, 1 )

end


local function nailerPurchase( purchaser )
    local nailer = purchaser:GetWeapon( "termhunt_weapon_hammer" )
    if IsValid( nailer ) then
        nailer:Charge()

    else
        purchaser:Give( "termhunt_weapon_hammer" )

    end
    loadoutConfirm( purchaser, 1 )

end


local function slamsPurchase( purchaser )
    purchaser:GiveAmmo( 14,    "slam",         true )

    purchaser:Give( "weapon_slam" )

    loadoutConfirm( purchaser, 2 )

end


local function flaregunPurchase( purchaser )
    if purchaser:HasWeapon( "termhunt_aeromatix_flare_gun" ) then
        purchaser:GiveAmmo( 2,    "GLEE_FLAREGUN_PLAYER",         true )

    else
        purchaser:Give( "termhunt_aeromatix_flare_gun" )

    end

    loadoutConfirm( purchaser, 2 )

end


local function ghostCanPurchase( purchaser )
    if IsValid( purchaser.ghostEnt ) then return false, "You're already placing something!\nPlace it, or right click to CANCEL placing it!" end
    return true

end


local function screamerPurchase( purchaser, itemIdentifier )
    local crate = ents.Create( "screamer_crate" )
    crate.itemIdentifier = itemIdentifier
    crate:SetOwner( purchaser )
    crate:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function nonScreamerPurchase( purchaser, itemIdentifier )
    local crate = ents.Create( "termhunt_normal_crate" )
    crate.itemIdentifier = itemIdentifier
    crate:SetOwner( purchaser )
    crate:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function weaponsCratePurchase( purchaser, itemIdentifier )
    local crate = ents.Create( "termhunt_weapon_crate" )
    crate.itemIdentifier = itemIdentifier
    crate:SetOwner( purchaser )
    crate:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function manhackCratePurchase( purchaser, itemIdentifier )
    local crate = ents.Create( "termhunt_manhack_crate" )
    crate.itemIdentifier = itemIdentifier
    crate:SetOwner( purchaser )
    crate:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function barrelsPurchase( purchaser, itemIdentifier )
    local barrels = ents.Create( "termhunt_barrels" )
    barrels.itemIdentifier = itemIdentifier
    barrels:SetOwner( purchaser )
    barrels:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function barnaclePurchase( purchaser, itemIdentifier )
    local barnacle = ents.Create( "placable_barnacle" )
    barnacle.itemIdentifier = itemIdentifier
    barnacle:SetOwner( purchaser )
    barnacle:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end


local function doorLockerPurchase( purchaser, itemIdentifier )
    local doorLocker = ents.Create( "door_locker" )
    doorLocker.itemIdentifier = itemIdentifier
    doorLocker:SetOwner( purchaser )
    doorLocker:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end

local function inversionCanPurchase( _ )
    if GAMEMODE:isTemporaryTrueBool( "terhunt_player_swapper" ) then return nil, "It is too soon for another inversion to begin." end
    return true, nil

end

local function plySwapperPurchase( purchaser, itemIdentifier )
    local playerSwapper = ents.Create( "player_swapper" )
    playerSwapper.itemIdentifier = itemIdentifier
    playerSwapper:SetOwner( purchaser )
    playerSwapper:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end

local function immortalizerPurchase( purchaser, itemIdentifier )
    local immortalizer = ents.Create( "termhunt_immortalizer" )
    immortalizer.itemIdentifier = itemIdentifier
    immortalizer:SetOwner( purchaser )
    immortalizer:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end

local function conduitCanPurchase( _ )
    if GAMEMODE:isTemporaryTrueBool( "terhunt_divine_conduit" ) then return nil, "It is too soon for another conduit to be opened." end
    return true, nil

end

local function conduitPurchase( purchaser, itemIdentifier )
    local conduit = ents.Create( "termhunt_divine_conduit" )
    conduit.itemIdentifier = itemIdentifier
    conduit:SetOwner( purchaser )
    conduit:Spawn()

    GAMEMODE:CloseShopOnPly( purchaser )

end

local function divineInterventionCost( purchaser )
    if purchaser:GetNW2Bool( "isdivinechosen", false ) == true then return 10 end
    if GetGlobalBool( "chosenhasarrived", false ) == true then return 200 end
    return 100

end

local function divineInterventionPos()

    local plys = GAMEMODE:returnWinnableInTable( player.GetAll() )

    if #plys <= 0 then
        local randomNavArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
        return randomNavArea:GetCenter()

    end

    local randomValidPos = nil
    local chosenResurrectAnchor
    for count = 1, 12 do
        chosenResurrectAnchor = table.Random( plys )
        randomValidPos = GAMEMODE:GetNearbyWalkableArea( chosenResurrectAnchor, chosenResurrectAnchor:GetPos(), count )

        if randomValidPos then break end

    end

    if randomValidPos and isvector( randomValidPos ) then
        return randomValidPos, chosenResurrectAnchor

    else
        local randomNavArea = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
        return randomNavArea:GetCenter()

    end

end

local function divineIntervention( purchaser )

    if not SERVER then return end
    if not purchaser.Resurrect then return end

    timer.Simple( 1, function()
        if not purchaser then return end
        if purchaser:Health() > 0 then return end

        if purchaser:GetNW2Bool( "isdivinechosen", false ) == true and purchaser.glee_divineChosenResurrect then

            purchaser:glee_divineChosenResurrect()
            return

        end

        local interventionPos, anchor = divineInterventionPos()

        if IsValid( anchor ) then
            huntersGlee_Announce( { purchaser }, 20, 10, "Respawned next to " .. anchor:Name() )

        end

        purchaser.resurrectPos = interventionPos
        purchaser:Resurrect()

        sound.EmitHint( SOUND_COMBAT, interventionPos, 8000, 1, purchaser )

        termHunt_ElectricalArcEffect( purchaser, interventionPos, Vector( 0, 0, 1 ), 4 )

    end )

    GAMEMODE:CloseShopOnPly( purchaser )

end

local function spawnAnotherHunterCheck( _ )
    local extraData = GAMEMODE.roundExtraData or {}
    local extraHunter = GetGlobal2Entity( "glee_linkedhunter" )
    local validCsideHunter = IsValid( extraHunter ) and extraHunter:Health() > 0
    if IsValid( extraData.extraHunter ) or validCsideHunter then return nil, "There is already a linked hunter." end
    return true, nil

end

hook.Add( "huntersglee_plykilledhunter", "glee_rewardLinkedKills", function( killer, hunter )
    if not hunter.linkedPlayer then return end
    if killer ~= hunter.linkedPlayer then return end
    local reward = 350
    killer:GivePlayerScore( reward )

    huntersGlee_Announce( { killer }, 50, 15, "You feel at peace, a weight has been lifted.\nThe doppleganger is dead...\n+" .. reward .. " score." )

end )

local function additionalHunter( purchaser )

    if not SERVER then return end

    local timerKey = "spawnExtraHunter_" .. purchaser:GetCreationID()
    timer.Create( timerKey, 0.2, 0, function()

        local spawned, hunter = GAMEMODE:spawnHunter( "sb_advanced_nextbot_terminator_hunter_snail_disguised" )
        if spawned ~= true then return end

        if hunter.MimicPlayer then
            hunter:MimicPlayer( purchaser )

        end

        SetGlobal2Entity( "glee_linkedhunter", hunter )

        GAMEMODE.roundExtraData.extraHunter = hunter

        hunter.linkedPlayer = purchaser

        if purchaser:Health() <= 0 then
            purchaser:SetObserverMode( OBS_MODE_CHASE )
            purchaser:SpectateEntity( hunter )

        end

        timer.Stop( timerKey )

    end )

    GAMEMODE:CloseShopOnPly( purchaser )

end

local glee_scoretochosentimeoffset_divisor = CreateConVar( "huntersglee_scoretochosentimeoffset_divisor", "6", bit.bor( FCVAR_REPLICATED, FCVAR_ARCHIVE ), "smaller means grigori time goes up faster. bigger, means slower", 0, 100000 )
local glee_chosenkillsrequired = CreateConVar( "huntersglee_chosenkillsrequired", "2", bit.bor( FCVAR_REPLICATED, FCVAR_ARCHIVE ), "how many hunters one must kill to get grigori", 0, 100000 )

if SERVER then
    -- offset will update constantly, use nw2
    SetGlobal2Int( "glee_chosen_timeoffset", 0 )
    local nextTimeOffsetNetwork = 0

    hook.Add( "huntersglee_givescore", "glee_chosentrackscore", function( _, scoreGivenRaw )
        local scoreGiven = math.abs( scoreGivenRaw )
        local moreTime = scoreGiven / glee_scoretochosentimeoffset_divisor:GetFloat()
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

local function divineChosenCanPurchase( purchaser )

    -- damn it i dropped my spaghetti
    local minutes = 10 + ( GetGlobal2Int( "glee_chosen_timeoffset", 0 ) / 60 )
    minutes = math.Clamp( minutes, 0, 20 )
    local offset = 60 * minutes
    local timeToAllow = GetGlobalInt( "huntersglee_round_begin_active" ) + offset
    local remaining = timeToAllow - CurTime()
    local formatted = string.FormattedTime( remaining, "%02i:%02i" )

    local huntersKilled = purchaser:HuntersKilled()

    local pt1 = "Their patience has ended."
    local pt2 = "\nYou've killed enough hunters."
    local block
    if timeToAllow > CurTime() then
        pt1 = "Presently, their patience lasts " .. formatted .. "."
        block = true

    end
    if huntersKilled < glee_chosenkillsrequired:GetInt() then
        if huntersKilled <= 0 then
            pt2 = "\nYou haven't killed any hunters."

        else
            pt2 = "\nYou've only killed " .. tostring( huntersKilled ) .. "."

        end
        block = true

    end

    if block then return nil, pt1 .. pt2 end

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
        size = 40,
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
        if not ( IsValid( chosenWeap ) or not me:Alive() ) then return end

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
end

local function divineChosenPurchase( purchaser )

    purchaser:SetNW2Bool( "isdivinechosen", true )
    SetGlobalBool( "chosenhasarrived", true )
    purchaser.glee_IsDivineChosen = true

    huntersGlee_Announce( player.GetAll(), 500, 35, "The ultimate sacrifice has been made.\nBEWARE OF " .. string.upper( purchaser:Name() ) )

    local maintainChosenWeapTimer = "divineChosenTimer_" .. purchaser:GetCreationID()

    purchaser.divineChosenThink = function()
        local chosenWeap = purchaser:GetWeapon( "termhunt_divine_chosen" )

        GAMEMODE:GivePanic( ply, -25 )

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
            purchaser:SetNW2Bool( "isdivinechosen", nil )
            SetGlobalBool( "chosenhasarrived", nil )

        end
    end )

    GAMEMODE.roundExtraData.divinePatienceEnds = CurTime() + 90
    local function isStillGoing()
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE or GAMEMODE:CountWinnablePlayers() <= 0 then return false end
        return true

    end

    local blockSpawningNearPlayersHook = "huntersglee_chosen_blocknearply"

    hook.Add( "huntersglee_blockspawn_nearplayers", blockSpawningNearPlayersHook, function( spawner, _ )
        if not purchaser:GetNW2Bool( "isdivinechosen", nil ) then hook.Remove( "huntersglee_blockspawn_nearplayers", blockSpawningNearPlayersHook ) return end
        if spawner ~= purchaser then return end

        return true

    end )
    local increasePatienceHook = "hunterslgee_increasedivinepatience"

    if not GAMEMODE.roundExtraData.createdThePatienceIncreaseHook then
        GAMEMODE.roundExtraData.createdThePatienceIncreaseHook = true
        hook.Add( "PlayerDeath", increasePatienceHook, function( victim, inflictor, attacker )
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
                        potentialChosen:SetHealth( 1 )

                    end )
                end
            end
        end )
    end

    purchaser.glee_divineChosenResurrect = function()
        local area = GAMEMODE:GetAreaInOccupiedBigGroupOrRandomBigGroup()
        local randAreasCenter = area:GetCenter()
        purchaser.resurrectPos = randAreasCenter

        purchaser:Resurrect()

        -- lighting where they spawn
        timer.Simple( 0.1, function()
            local placeholder = ents.Create( "prop_physics" )
            placeholder:SetPos( randAreasCenter )
            placeholder:SetModel( "models/Gibs/HGIBS.mdl" )
            placeholder:Spawn()
            placeholder:GetPhysicsObject():EnableMotion( false )
            placeholder:SetNotSolid( true )
            placeholder:SetNoDraw( true )
            SafeRemoveEntityDelayed( placeholder, 0.1 )

            purchaser:GodEnable()
            termHunt_PowafulLightning( owner, placeholder, randAreasCenter + vector_up * 10, 12 )

            timer.Simple( 0.5, function()
                purchaser:GodDisable()

            end )
        end )
    end

    purchaser:glee_divineChosenResurrect()

    local function undoInnate()
        purchaser.glee_IsDivineChosen = nil
        purchaser.glee_divineChosenResurrect = nil
        purchaser:SetNW2Bool( "isdivinechosen", nil )
        SetGlobalBool( "chosenhasarrived", nil )

        -- cleanup wep stuff
        timer.Remove( maintainChosenWeapTimer )
        local weap = purchaser:GetWeapon( "termhunt_divine_chosen" )
        SafeRemoveEntity( weap )

        -- cleanup the global hooks
        hook.Remove( "huntersglee_blockspawn_nearplayers", blockSpawningNearPlayersHook )
        hook.Remove( "PlayerDeath", increasePatienceHook )

        -- cleanup other global stuff
        timer.Remove( maintainPatienceTimer )
        SetGlobal2Int( "divineChosenPatienceEnds", nil )

    end

    purchaser.huntersgleeUndoDivineChosen = undoInnate

    GAMEMODE:PutInnateInProperCleanup( nil, undoInnate, purchaser )

end

--[[

these are here for demonstration, they are defined in shared
see sh_shopshared.lua for example that shows what every shopitem var does

-- weird ones
GM.INVALID          = -1 -- tell people to install a navmesh
GM.ROUND_SETUP      = 0 -- wait until the navmesh has definitely spawned

-- normal ones
GM.ROUND_ACTIVE     = 1 -- death has consequences and score can accumulate
GM.ROUND_INACTIVE   = 2 -- let players run around and prevent death
GM.ROUND_LIMBO      = 3 -- just display winners

--]]

function GM:SetupShopCatalouge()
    local defaultItems = {
        [ "score" ] = {
            name = "Score",
            desc = "Free score, Cheat!",
            cost = -1000,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            purchaseFunc = function() end,
            canShowInShop = isCheats,
        },
        -- lets people mess with locked rooms
        [ "lockpick" ] = {
            name = "Lockpick",
            desc = "Lockpick, for doors.\nCan also open things like crates, ( relatively ) quietly.",
            cost = 15,
            markup = 6,
            cooldown = 10,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            purchaseCheck = unUndeadCheck, lockpickCanPurchase,
            purchaseFunc = lockpickPurchase,
        },
        [ "fullloadout" ] = {
            name = "Loadout",
            desc = "Guns.",
            cost = 15,
            markup = 4,
            markupPerPurchase = 0.25,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            purchaseCheck = unUndeadCheck,
            purchaseFunc = loadoutPurchase,
        },
        [ "slams" ] = {
            name = "Slams",
            desc = "Some slams, 17 to be exact.",
            cost = 80,
            markup = 2,
            markupPerPurchase = 0.25,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            purchaseCheck = unUndeadCheck,
            purchaseFunc = slamsPurchase,
        },
        [ "flaregun" ] = {
            name = "Flaregun",
            desc = "Flaregun.\n+ 2 flares.",
            cost = 40,
            markup = 1.25,
            markupPerPurchase = 0.25,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            purchaseCheck = unUndeadCheck,
            purchaseFunc = flaregunPurchase,
        },
        [ "nailer" ] = {
            name = "Nailer",
            desc = "Nail things together!\nNailing is rather loud.",
            cost = 40,
            markup = 3,
            markupPerPurchase = 0.5,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = nailerPurchase,
        },
        -- terminator doesnt like taking damage from this, will save your ass
        [ "ar2" ] = {
            name = "Ar2",
            desc = "Ar2 + Balls.\nAr2 balls can save you in a pinch.",
            cost = 75,
            markup = 2,
            markupPerPurchase = 0.5,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -100,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = ar2Purchase,
        },
        [ "gravitygun" ] = {
            name = "Gravity Gun",
            desc = "Gravity Gun",
            cost = 60,
            markup = 2,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 1,
            purchaseCheck = { unUndeadCheck, gravityGunCanPurchase },
            purchaseFunc = gravityGunPurchase,
        },
        -- keeps the rounds going
        [ "revivekit" ] = {
            name = "Revive Kit",
            desc = "Revives dead players.\nYou gain 175 score per resurrection.",
            cost = 30,
            markup = 1.5,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -100,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = revivePurchase,
            canShowInShop = hasMultiplePeople,
        },
        -- funny bear trap
        [ "beartrap" ] = {
            name = "Six Beartraps",
            desc = "Traps players, Terminators can easily overpower them.",
            cost = 80,
            markup = 2,
            markupPerPurchase = 0.25,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 0,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = beartrapPurchase,
        },
        -- make player comfort cost score
        [ "flashlight" ] = {
            name = "Flashlight",
            desc = "Illuminate your world.",
            cost = 10,
            markup = 4,
            cooldown = math.huge,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = flashlightPurchase,
        },
        -- make player comfort cost score
        [ "binoculars" ] = {
            name = "Binoculars",
            desc = "See things far away by pressing your Suit Zoom key.",
            cost = 8,
            markup = 4,
            cooldown = math.huge,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            purchaseCheck = unUndeadCheck,
            purchaseFunc = zoomPurchase,
        },
        -- heal jooce
        [ "healthkit" ] = {
            name = "Medkit",
            desc = "Heals.\nYou gain score for healing players.\nHealing yourself is unweildy and slow.",
            cost = 30,
            markup = 3,
            markupPerPurchase = 0.25,
            cooldown = 0.25,
            category = "Items",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -100,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = medkitPurchase,
        },
        -- this is to give the noobs in a lobby a huge score boost, also it's cool
        [ "witnessme" ] = {
            name = "Witness Me.",
            desc = "You die instantly to hunters if you have any witnesses.\nDead players can bear witness\nGain 250 score per witness.\nOnly happens once per round.",
            cost = 40,
            markup = 1.5,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -100,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = witnessPurchase,
            canShowInShop = hasMultiplePeople,
        },
        [ "screamingbackpack" ] = {
            name = "Beacon",
            desc = "A beacon.\nThe hunters will never lose you for long.",
            cost = -100,
            markup = 0.25,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = screamingBackpackPurchase,
        },
        -- Risk vs reward.
        [ "blooddonor" ] = {
            name = "Donate Blood.",
            desc = "Donate blood for score.",
            cost = bloodDonorCost,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = { unUndeadCheck, bloodDonorCanPurchase },
            purchaseFunc = bloodDonorPurchase,
        },
        -- flat DOWNGRADE
        [ "blindness" ] = {
            name = "Legally Blind.",
            desc = "Become unable to see more than a few feet ahead.",
            cost = -150,
            markup = 0.2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = blindnessPurchase,
        },
        -- flat downgrade
        [ "badknees" ] = {
            name = "62 year old knees.",
            desc = "62 years of living a sedentary lifestyle.\nJumping hurts, and is relatively useless.\nFall damage is lethal.",
            cost = -120,
            markup = 0.25,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = badkneesPurchase,
        },
        -- hilarious downgrade
        [ "greasyhands" ] = {
            name = "Greasy Hands.",
            desc = "Eating greasy food all your life,\nyour hands... adapted to their new, circumstances...\nUnder stress, the grease flows like a faucet.",
            cost = -120,
            markup = 0.25,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -90,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = greasyHandsPurchase,
        },
        [ "hypochondriac" ] = {
            name = "Hypochondriac.",
            desc = "You are extremely receptive to pain.",
            cost = -50,
            markup = 0.2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -80,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = hypochondriacPurchase,
        },
        [ "deafness" ] = {
            name = "Hard of hearing.",
            desc = "You can barely hear a thing!",
            cost = -65,
            markup = 0.25,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -80,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = deafnessPurchase,
        },
        [ "sixthsense" ] = {
            name = "Sixth Sense.",
            desc = "You gain a sixth sense.\nYou innately know where things are.\nBut the sixth sense can be overwhelming.\nPanic will mount as the hunters close in.",
            cost = 225,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 80,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = sixthSensePurchase,
        },
        -- reframe gaining score, because i thought it could be fun
        [ "marcopolo" ] = {
            name = "Marco Polo",
            desc = "You gain score for exploring new parts of the map.\nBPM gives no score.\nGains per area explored start out trivial, but as you progress, the rewards become greater.",
            cost = 25,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
            },
            weight = 180,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = marcoPoloPurchase,
        },
        -- flat upgrade
        [ "juggernaut" ] = {
            name = "Juggernaut",
            desc = "Attain a new level of physique.\nYour footsteps are loud and bulky.\nYou cannot move quicker with augmentations\nMax 500 health.",
            cost = 225,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 120,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = juggernautPurchase,
        },
        --flat upgrade
        [ "froglegs" ] = {
            name = "Frog Legged Parkourist",
            desc = "Your legs become frog.\nThe gangly shape of your legs slows you down.\nYou are capable of frog kicking off walls.\nYour shove propels you further.\nYour superior frog geneology permits you to absorb greater falls.\nRibbit.",
            cost = 300,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 120,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = frogLegsPurchase,
        },
        --flat upgrade
        [ "mimicmadness" ] = {
            name = "Prop Hunt",
            desc = "When crouched, you mimic the closest nearby prop.\nThe terminators are fooled from far away but the illusion breaks down since you don't have collisions.",
            cost = 200,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 120,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = mimicMadnessPurchase,
        },
        --flat upgrade
        [ "temporaldiceroll" ] = {
            name = "Roll of the dice.",
            desc = "Roll the temporal dice.\n8 seconds after purchasing, you are teleported to a completely random part of the map",
            cost = 75,
            markup = 1.5,
            markupPerPurchase = 1,
            cooldown = 90,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 120,
            purchaseCheck = unUndeadCheck,
            purchaseFunc = temporalDiceRollPurchase,
        },
        --flat upgrade
        [ "channel666" ] = {
            name = "Channel 666.",
            desc = "Your radio bridges life and death.\nSpeak to the dead.",
            cost = 100,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,

            },
            weight = 120,
            purchaseCheck = { unUndeadCheck, channel666Check },
            purchaseFunc = channel666Purchase,
            canShowInShop = hasMultiplePeople,
        },
        -- Risk vs reward.
        [ "invisserum" ] = {
            name = "Chameleon Gene",
            desc = "Become nearly invisible, does not apply to your weapons, or flashlight.",
            cost = 300,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 85,
            purchaseCheck = { unUndeadCheck, chameleonCanPurchase },
            purchaseFunc = chameleonPurchase,
        },
        -- flat upgrade
        [ "coldblooded" ] = {
            name = "Cold Blooded.",
            desc = "Your top speed is linked to your heartrate.",
            cost = 225,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 80,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = coldbloodedPurchase,
        },
        -- flat upgrade
        [ "superiormetabolism" ] = {
            name = "Superior Metabolism.",
            desc = "You've always been different than those around you.\nWhat would hospitalize others for weeks, passed over you in days.\nYou regenerate health as your heart beats.",
            cost = 225,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 80,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = superiorMetabolismPurchase,
        },
        -- arguably worse version of cold blooded 
        [ "marathonrunner" ] = {
            name = "Claustrophobic Marathonner.",
            desc = "You live to run, every day, a new marathon.\nYour body, a paragon of speed, your mind however...\nGoing indoors is alien, terrifying to you.\nThe interior spaces destroy your momentum, panic mounts, slowing you down.",
            cost = 150,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 85,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = marathonRunnerPurchase,
        },
        -- wacky ass shit
        [ "bombgland" ] = {
            name = "Bomb Gland.",
            desc = "You accumulate bombs. Drop them with the bomb gland.\nLeft Click for small bombs, Reload for a big bomb.\nRight click to detonate oldest bomb.\nAfter you surpass 4 bombs, there's a chance that ANY damage will explode your undropped bombs.\nIf you die, all your bombs explode.",
            cost = 75,
            markup = 2,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 85,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = bombGlandPurchase,
        },
        -- flat upgrade
        [ "susimpostor" ] = {
            name = "HVAC Specialist.",
            desc = "From a young age, vents have fascinated you.\nThe \"portals between rooms\", as you call them, have practically raised you.\nYou are scared of the normal world, crouching brings confort, and vents bring freedom from panic.\nYou move very fast while crouching. Even faster in vents.\nYou don't even notice the musty vent smell anymore.",
            cost = 50,
            markup = 4,
            cooldown = math.huge,
            category = "Innate",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 90,
            purchaseCheck = { unUndeadCheck },
            purchaseFunc = susPurchase,
        },
        -- sell out other players/your friends to become alive
        [ "screamcrate" ] = {
            name = "Beaconed Supplies",
            desc = "Supplies with a beacon.\nBetray the others for score.\nCosts 75 to place.\nRefund upon first beacon transmit.",
            cost = 0,
            markup = 1,
            cooldown = 60,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -5,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = screamerPurchase,
        },
        -- makes the map worth exploring
        [ "normcrate" ] = {
            name = "Supplies",
            desc = "Supplies without a beacon.\nContains health or armour, and rarely a weapon, or some smg / ar2 grenades.\nPlace indoors, and far away from players and other supplies, for more score.",
            cost = 0,
            markup = 1,
            cooldown = 10,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 1,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = nonScreamerPurchase,
        },
        [ "weapcrate" ] = {
            name = "Crate of weapons",
            desc = "Supply crate with 4 weapons in it\nPlace indoors, and far away from players and other supplies, for more score.",
            cost = 0,
            markup = 1,
            cooldown = 55,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 1,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = weaponsCratePurchase,
        },
        [ "manhackcrate" ] = {
            name = "Crate With Manhacks",
            desc = "Supply crate with 5 manhacks in it.\nGives score when the manhacks damage stuff.",
            cost = 0,
            markup = 1,
            cooldown = 80,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 10,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = manhackCratePurchase,
        },
        [ "barrels" ] = {
            name = "Barrels",
            desc = "6 Barrels",
            cost = 0,
            markup = 1,
            cooldown = 20,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 1,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = barrelsPurchase,
        },
        -- punishes careless movement
        [ "barnacle" ] = {
            name = "Barnacle",
            desc = "Barnacle.\nYou gain 100 score the first time it grabs someone, and 45 score every further second it has someone grabbed.\nCosts more to place in groups, or place too close to players.",
            cost = 5,
            markup = 1,
            cooldown = 0.5,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 10,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = barnaclePurchase,
        },
        [ "doorlocker" ] = {
            name = "Door locker",
            desc = "Locks doors, you gain score when something uses it.\n150 score, default.\n250 score if a player fleeing a hunter uses it.\nDon't use your own locked doors.",
            cost = 5,
            markup = 1,
            cooldown = 0.5,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 10,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = doorLockerPurchase,
        },
        -- lets dead people take the initiative
        [ "resurrection" ] = {
            name = "Divine intervention",
            desc = "Resurrect yourself.",
            cost = divineInterventionCost,
            markup = 1,
            markupPerPurchase = 0.25,
            cooldown = 1,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -200,
            purchaseCheck = undeadCheck,
            purchaseFunc = divineIntervention,
        },
        -- lets dead people get a revive but they're fucked
        [ "additionalhunter" ] = {
            name = "Linked hunter",
            desc = "Spawn another hunter.\nThey will take on your appearance.\nIf you personally kill it, you will gain 350 score.\nThe newcomer will never lose you, if you regain your life...",
            cost = -150,
            markup = 1,
            cooldown = 80,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = -100,
            purchaseCheck = { undeadCheck, spawnAnotherHunterCheck },
            purchaseFunc = additionalHunter,
        },
        -- ultimate stalemate breaker
        [ "temporalinversion" ] = {
            name = "Temporal Inversion",
            desc = "Swaps a player out for their most remote enemy.\nCosts 400 to place.\nGlobal 3 minute delay between placing.",
            cost = 0,
            markup = 1,
            cooldown = 5,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 20,
            purchaseCheck = { undeadCheck, ghostCanPurchase, inversionCanPurchase },
            purchaseFunc = plySwapperPurchase,
        },
        [ "immortalizer" ] = {
            name = "Gift of Immortality",
            desc = "Gift 15 seconds, of true Immortality.\nCosts 300 to gift to players, 150 to gift to hunters.",
            cost = 0,
            markup = 1,
            cooldown = 5,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 20,
            purchaseCheck = { undeadCheck, ghostCanPurchase },
            purchaseFunc = immortalizerPurchase,
        },
        -- crazy purchase
        [ "divineconduit" ] = {
            name = "Divine conduit",
            desc = "Convey the will of the gods.\nCosts 600 to place.\nGlobal 4 minute delay between placing.",
            cost = 0,
            markup = 1,
            cooldown = 0,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 20,
            purchaseCheck = { undeadCheck, ghostCanPurchase, conduitCanPurchase },
            purchaseFunc = conduitPurchase,
        },
        -- explosive end to round
        [ "divinechosen" ] = {
            name = "grigori",
            desc = "The ultimate sacrifice.\nThe gods gift you a fraction of their power, to end the hunt.\nRequires \"Patience\" to run dry, and 2 hunters be dead in your name.",
            cost = 1500,
            markup = 1,
            cooldown = math.huge,
            category = "Undead",
            purchaseTimes = {
                GAMEMODE.ROUND_INACTIVE,
                GAMEMODE.ROUND_ACTIVE,
            },
            weight = 40,
            purchaseCheck = { divineChosenCanPurchase, undeadCheck },
            purchaseFunc = divineChosenPurchase,
        },
    }

    local defaultCategories = { -- sorted by numbers stored in indexes
        [ "Items" ] = 1,
        [ "Innate" ] = 2,
        [ "Undead" ] = 3,

    }

    for shopCategoryName, shopCategoryPriority in pairs( defaultCategories ) do
        GAMEMODE:addShopCategory( shopCategoryName, shopCategoryPriority )

    end

    for shopItemIdentifier, shopItemTbl in pairs( defaultItems ) do
        GAMEMODE:addShopItem( shopItemIdentifier, shopItemTbl )

    end

    GAMEMODE.shopIsReadyForItems = true

    -- pls put other shop items in this hook! ty
    ProtectedCall( function() hook.Run( "huntersglee_postshopsetup_shared", nil ) end )

end

function GM:IsShopReadyForItems()
    return self.shopIsReadyForItems

end