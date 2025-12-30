if CLIENT then

    local LocalPlayer = LocalPlayer

    -- cache panic so we aren't calling getnwfloat
    local clPanic = nil
    function doPanicDistort( scale )
        local refractAmount = scale / 12000
        if scale <= 25 then return end
        local overlayMaterial = "models/props_c17/fisheyelens"
        DrawMaterialOverlay( overlayMaterial, refractAmount )

    end

    hook.Add( "RenderScreenspaceEffects", "huntersglee_panicmessupview", function()
        if not clPanic or clPanic <= 0 then return end
        if LocalPlayer():Health() <= 0 then return end
        doPanicDistort( clPanic )

    end )

    local panicTimer = "huntersglee_panicmanagethinkclient" -- no backup for restarting this
    timer.Create( panicTimer, 0.2, 0, function()
        local ply = LocalPlayer()
        if not IsValid( ply ) then return end
        clPanic = ply:GetNWFloat( "huntersglee_panic", 0 )

    end )

elseif SERVER then
    function GM:GetPanic( ply )
        if not IsValid( ply ) then return 0 end
        return ply:GetNWFloat( "huntersglee_panic", 0 )

    end
    function GM:GivePanic( ply, newPanic )
        if not newPanic or newPanic == 0 then return end
        if not IsValid( ply ) then return end

        local panic = self:GetPanic( ply )
        panic = math.Clamp( panic + newPanic, 0, 1000 )

        ply:SetNWFloat( "huntersglee_panic", panic )

        return true

    end
    function GM:SetPanic( ply, newPanic )
        if not newPanic then return end
        if not IsValid( ply ) then return end
        ply:SetNWFloat( "huntersglee_panic", newPanic )

        return true

    end

    -- create a panic source
    -- radius is how far it affects
    -- strength is how much panic it gives when below 25% of radius, ramps down beyond that
    function GM:PanicSource( pos, strength, radius )
        local nearby = ents.FindInSphere( pos, radius )
        local maxPanicGrace = radius * 0.25
        local radiusFinal = radius - maxPanicGrace
        for _, ent in ipairs( nearby ) do
            if not ent:IsPlayer() then continue end
            local dist = ent:WorldSpaceCenter():Distance( pos )
            local distNormalized = dist / radiusFinal
            local distInverted = math.Clamp( 1.25 - distNormalized, 0, 1 )

            local panicAmount = strength * distInverted
            if panicAmount < 1 then continue end

            self:GivePanic( ent, panicAmount )

        end
    end

    local fleeDist = 1500
    local maxPanic = 115

    function GM:PanicThinkSV( ply )
        local panic = self:GetPanic( ply )
        local panicDrain = 0.5

        local plysHealth = ply:Health()

        if plysHealth <= 0 then
            panic = 0

        elseif plysHealth <= 20 then
            panicDrain = 0.25

        end

        local underwater = ply:WaterLevel() >= 3

        -- stagger
        if ( ply.nextPanicBigThink or 0 ) < CurTime() then
            ply.nextPanicBigThink = CurTime() + math.Rand( 2.5, 2.6 )

            local increasing = ( ply.huntersGleeOldPanicAtSound or panic ) < panic
            local panicSpeedPenaltyMul = nil
            local doPanicSound = nil
            local panicSoundPitch = nil
            local panicSoundHitch = nil

            local currModel = ply:GetModel() -- simplest, most reliable way i can think to do this
            if ply.panicLastModel ~= currModel then
                if ply.panicLastModel then
                    ply.screamMaxPanicFleeSounds = nil
                    ply.screamMaxPanicSounds = nil
                    ply.screamPanicSounds = nil
                    ply.panicIsFemale = self:IsModelFemale( ply )

                end
                ply.panicLastModel = currModel

            end

            if panic >= maxPanic then -- scream loud, resets panic
                local hookResult = hook.Run( "huntersglee_blockpanicreset", ply, panic )
                local canResetPanic = not underwater and hookResult ~= true
                local didScream

                -- sounds that play when player is chased by scary enemy, in a group of other players
                if ply.screamMaxPanicFleeSounds and #ply.screamMaxPanicFleeSounds < 1 then
                    ply.screamMaxPanicFleeSounds = nil

                end
                if not ply.screamMaxPanicFleeSounds then
                    ply.screamMaxPanicFleeSounds = self:GetCorrectShuffledSoundsForModel( ply, "panicReleaseScreamsChased" )
                    ply.screamMaxPanicFleeSounds = self:GenderizeSounds( ply, ply.screamMaxPanicFleeSounds )

                end

                -- play these otherwise
                if ply.screamMaxPanicSounds and #ply.screamMaxPanicSounds < 1 then
                    ply.screamMaxPanicSounds = nil

                end
                if not ply.screamMaxPanicSounds then
                    ply.screamMaxPanicSounds = self:GetCorrectSoundsForModel( ply, "panicReleaseScreams" )
                    ply.screamMaxPanicSounds = self:GenderizeSounds( ply, ply.screamMaxPanicSounds )

                end

                local screamSound
                local validScreamSounds = ply.screamMaxPanicSounds and #ply.screamMaxPanicSounds >= 1

                local chaser = ply.huntersGleeHunterThatCanSeePly
                local validScreamFleeSounds = ply.screamMaxPanicFleeSounds and #ply.screamMaxPanicFleeSounds >= 1
                local doFleeSound = validScreamFleeSounds and IsValid( chaser ) and ( ply.nextFleePanicSound or 0 ) < CurTime() and self:GetBotScaryness( ply, chaser ) >= 0.95
                local fleeingGroup

                if doFleeSound then
                    local myPos = ply:GetShootPos()
                    local theirDistToMe = chaser:GetPos():Distance( myPos )
                    doFleeSound = theirDistToMe < fleeDist
                    local cutoff = math.max( theirDistToMe, 750 )

                    fleeingGroup = {}
                    for _, nearPly in player.Iterator() do
                        if nearPly == ply then continue end
                        if nearPly:Health() <= 0 then continue end
                        if nearPly:GetShootPos():Distance( myPos ) > cutoff then continue end
                        table.insert( fleeingGroup, nearPly )

                    end
                    doFleeSound = #fleeingGroup >= math.random( 1, 4 )

                end
                if doFleeSound then
                    -- sillier way
                    screamSound = table.remove( ply.screamMaxPanicFleeSounds, 1 )
                    ply.nextFleePanicSound = CurTime() + math.random( 5, 10 )
                    for _, fleeingPly in ipairs( fleeingGroup ) do
                        fleeingPly.nextFleePanicSound = CurTime() + math.random( 10, 5 )

                    end
                    didScream = true

                elseif validScreamSounds then
                    -- silly way to vary the sound between max panics
                    screamSound = table.remove( ply.screamMaxPanicSounds, 1 )
                    ply.nextFleePanicSound = CurTime() + math.random( 5, 10 )

                    didScream = true

                end
                if didScream then
                    ply:ViewPunch( AngleRand() * 0.3 )
                    ply:DoAnimationEvent( ACT_FLINCH_PHYSICS )

                    if canResetPanic then -- reset panic with a scream
                        panic = 50
                        ply:EmitSound( screamSound, 130, math.Rand( 99, 106 ), 1, CHAN_VOICE )

                    else -- let panic get overflown, we just take little bites
                        panic = panic + -25

                    end
                else
                    if canResetPanic then -- screaming releases panic better than this
                        panic = panic - ( panic / 3 )

                    else
                        panic = panic + -25

                    end
                end
                panicSpeedPenaltyMul = 2

            elseif panic >= 75 and increasing then -- scream softly, removes a bit of panic
                if ply.screamPanicSounds and #ply.screamPanicSounds < 1 then
                    ply.screamPanicSounds = nil

                end

                if not ply.screamPanicSounds then
                    ply.screamPanicSounds = self:GetCorrectSoundsForModel( ply, "panicReleaseScreams" )
                    ply.screamPanicSounds = self:GenderizeSounds( ply, ply.screamPanicSounds )

                end
                local validScreamPanicSounds = ply.screamPanicSounds and #ply.screamPanicSounds >= 1
                if validScreamPanicSounds then
                    local screamSound = table.remove( ply.screamPanicSounds, math.random( 1, #ply.screamPanicSounds ) )
                    if screamSound and not underwater then
                        ply:EmitSound( screamSound, 88, 100, 1, CHAN_VOICE )

                    end
                    ply:ViewPunch( AngleRand() * 0.05 )
                    panic = panic + -10

                end
                panicSpeedPenaltyMul = 0.6

            end

            local baseSoundPitch = ply.panicIsFemale and 110 or 100

            if panic >= 25 and increasing then -- breathing sound
                doPanicSound = true
                panicSoundPitch = ( baseSoundPitch - 10 ) + ( panic * 0.4 )
                ply:ViewPunch( AngleRand() * 0.005 )

                panicSpeedPenaltyMul = 0.45

            elseif panic >= 25 and not increasing then -- trigger the hitch/lower pitch breathing sound
                doPanicSound = true
                panicSoundHitch = true -- hitch when going from increasing to not increasing
                panicSoundPitch = baseSoundPitch - 20

                panicSpeedPenaltyMul = 0.25

            end
            -- deep breaths
            if doPanicSound and not underwater then
                local breathVolume = 0.6
                if not ply.huntersglee_panicSound then
                    local filter = ply.fleeSoundFilter
                    if not filter then
                        -- wonder if i dont have to remake these
                        filter = RecipientFilter()
                        filter:AddPlayer( ply )
                        ply.fleeSoundFilter = filter
                    end
                    ply.huntersglee_panicSound = CreateSound( ply, "player/breathe1.wav", filter )

                end
                -- hitch in the breathing, like you held it for a second
                -- sounds better than having pitch just lower instantly
                if panicSoundHitch and ply.huntersglee_panicSound:GetPitch() ~= panicSoundPitch then
                    ply.huntersglee_panicSound:Stop()
                    timer.Simple( 0.3, function()
                        if not IsValid( ply ) then return end
                        if not ply.huntersglee_panicSound then return end
                        ply.huntersglee_panicSound:PlayEx( breathVolume, panicSoundPitch )

                    end )
                elseif not ply.huntersglee_panicSound:IsPlaying() then
                    ply.huntersglee_panicSound:PlayEx( breathVolume, panicSoundPitch )

                end
                ply.huntersglee_panicSound:ChangePitch( panicSoundPitch, 0.1 )

            elseif ply.huntersglee_panicSound ~= nil and ply.huntersglee_panicSound:IsPlaying() then
                ply.huntersglee_panicSound:FadeOut( 1 )

            end

            if panicSpeedPenaltyMul then
                ply:DoSpeedModifier( "panic", -panic * panicSpeedPenaltyMul )

            end

            ply.huntersGleeOldPanicAtSound = panic

        end

        panic = math.Clamp( panic + -panicDrain, 0, 1000 )
        -- we are adding decimals to ints, but it works for some reason?
        -- changed to nwfloat
        ply:SetNWFloat( "huntersglee_panic", panic )

    end

    local panicTimer = "huntersglee_panicmanagethinkserver"
    function GM:DoPanicThinkTimer( timerName )
        timer.Create( timerName, 0.2, 0, function()
            for _, ply in ipairs( player.GetAll() ) do
                self:PanicThinkSV( ply )

            end
        end )
    end

    GM:DoPanicThinkTimer( panicTimer )

    -- backup in case the timer errs!
    hook.Add( "huntersglee_round_into_active", "huntersglee_startpanicthinking", function()
        if not timer.Exists( panicTimer ) then
            GAMEMODE:DoPanicThinkTimer( panicTimer )

        end
    end )

    hook.Add( "PlayerDeath", "glee_panic_stopbreathingsnd", function( victim )
        GAMEMODE:SetPanic( victim, 0 )
        if victim.huntersglee_panicSound == nil or not victim.huntersglee_panicSound:IsPlaying() then return end
        victim.huntersglee_panicSound:Stop()
        victim:EmitSound( "common/null.wav", 75, 100, 1, CHAN_VOICE )
        victim.nextFleePanicSound = nil

    end )

    hook.Add( "PostEntityTakeDamage", "glee_paniconplydamage", function( victim, damage, took )
        if not took then return end
        if not victim:IsPlayer() then return end
        local panic = damage:GetDamage() / 10
        if victim:Health() < 25 then
            panic = panic * 2
            panic = math.Clamp( panic, 45, 100 )

        end
        if victim:IsOnFire() and damage:IsDamageType( DMG_BURN ) then
            panic = panic * 2

        end
        GAMEMODE:GivePanic( victim, panic )

    end )

    hook.Add( "termhunt_plyescapestuck", "glee_unstuck_panic", function( ply, stuckPos, freedPos ) -- lol
        GAMEMODE:GivePanic( ply, stuckPos:Distance( freedPos ) / 3 )

    end )

    local function resetPanicSounds( ply, hardReset )
        timer.Simple( 0, function()
            if not IsValid( ply ) then return end
            local model = ply:GetModel()
            local oldModel = ply.glee_Panic_OldModel
            if hardReset or ( oldModel and model ~= oldModel ) then
                ply.screamMaxPanicFleeSounds = nil
                ply.screamMaxPanicSounds = nil
                ply.screamPanicSounds = nil

            end
            ply.glee_Panic_OldModel = model

        end )
    end

    hook.Add( "PreCleanupMap", "glee_panic_resetsounds", function()
        for _, ply in player.Iterator() do
            resetPanicSounds( ply, hardReset )

        end
    end )

    hook.Add( "PlayerSpawn", "glee_panic_resetsounds", function( ply )
        resetPanicSounds( ply )

    end )
end