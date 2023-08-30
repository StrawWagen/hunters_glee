if CLIENT then
    -- cache panic so we aren't calling getnwint
    local clPanic = nil
    function doPanicDistort( scale )
        local refractAmount = scale / 10000
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
        clPanic = LocalPlayer():GetNWInt( "huntersglee_panic", 0 )

    end )

elseif SERVER then
    local defaultPanicSounds = {
        "vo/npc/male01/pain07.wav",
        "vo/npc/male01/no01.wav",
        "vo/npc/male01/no02.wav",

    }

    function GM:GetPanic( ply )
        if not IsValid( ply ) then return 0 end
        return ply:GetNWInt( "huntersglee_panic", 0 )

    end
    function GM:GivePanic( ply, newPanic )
        if not newPanic or newPanic == 0 then return end
        if not IsValid( ply ) then return end

        local panic = GAMEMODE:GetPanic( ply )
        panic = math.Clamp( panic + newPanic, 0, 1000 )

        ply:SetNWInt( "huntersglee_panic", panic )

        return true

    end

    function GM:PanicThinkSV( ply )
        local panic = GAMEMODE:GetPanic( ply )

        if ply:Health() <= 0 then
            panic = 0
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

            if panic >= 100 then
                -- keeps building
                if not underwater then
                    panic = 50

                end

                -- silly way to vary the sound between max panics
                -- sounded repetitive to have the same sound play over and over and over
                if ply.screamPanicSounds and #ply.screamPanicSounds < 1 then
                    ply.screamPanicSounds = nil

                end

                ply.screamPanicSounds = ply.screamPanicSounds or table.Copy( defaultPanicSounds )

                local screamSound = table.remove( ply.screamPanicSounds, 1 )
                ply:ViewPunch( AngleRand() * 0.3 )
                if not underwater then
                    ply:EmitSound( screamSound, 130, math.Rand( 99, 106 ), 1, CHAN_STATIC )

                end
                panicSpeedPenaltyMul = 1

            elseif panic >= 75 and increasing then
                local screamSound = "vo/npc/male01/pain0" .. math.random( 7, 9 ) .. ".wav"
                if not underwater then
                    ply:EmitSound( screamSound, 88, 100, 1, CHAN_STATIC )

                end
                ply:ViewPunch( AngleRand() * 0.01 )
                panicSpeedPenaltyMul = 0.6

            end

            if panic >= 25 and increasing then
                doPanicSound = true
                panicSoundPitch = 90 + ( panic * 0.4 )
                ply:ViewPunch( AngleRand() * 0.005 )

                panicSpeedPenaltyMul = 0.45

            elseif panic >= 25 and not increasing then
                doPanicSound = true
                panicSoundHitch = true
                panicSoundPitch = 80

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
                ply:doSpeedModifier( "panic", -panic * panicSpeedPenaltyMul )

            end

            ply.huntersGleeOldPanicAtSound = panic

        end

        panic = math.Clamp( panic + -0.5, 0, 1000 )
        -- we are adding decimals to ints, but it works for some reason?
        ply:SetNWInt( "huntersglee_panic", panic )

    end

    local panicTimer = "huntersglee_panicmanagethinkserver"
    function GM:DoPanicThinkTimer( timerName )
        timer.Create( timerName, 0.2, 0, function()
            for _, ply in ipairs( player.GetAll() ) do
                GAMEMODE:PanicThinkSV( ply )

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
end