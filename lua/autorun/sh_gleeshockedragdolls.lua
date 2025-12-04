
-- copied from energy zamb

local function shockRagdoll( ragdoll )
    if not IsValid( ragdoll ) then return end

    local duration = math.Rand( 3, 5 )
    local step = duration / 100
    local endTime = CurTime() + duration
    local timerName = "glee_shockragdoll_" .. math.random( 1, 1000000 )

    -- wake up physics so impulses actually move it
    local count = ragdoll.GetPhysicsObjectCount and ragdoll:GetPhysicsObjectCount() or 0
    for i = 0, count - 1 do
        local phys = ragdoll:GetPhysicsObjectNum( i )
        if IsValid( phys ) then phys:Wake() end

    end

    ragdoll.sparkEffectChance = math.random( 80, 120 )

    timer.Create( timerName, step, 0, function()
        if not IsValid( ragdoll ) then timer.Remove( timerName ) return end

        local timeLeft = endTime - CurTime()
        if timeLeft <= 0 then timer.Remove( timerName ) return end

        ragdoll.sparkEffectChance = ragdoll.sparkEffectChance - 1
        if math.random( 0, 100 ) > ragdoll.sparkEffectChance then return end

        local frac = math.Clamp( timeLeft / duration, 0, 1 )
        local force = 600 * frac + 100 -- start stronger, taper off

        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local phys = ragdoll:GetPhysicsObjectNum( i )

            if not IsValid( phys ) then continue end
            local dir = VectorRand()
            phys:ApplyForceCenter( dir * force )
            phys:ApplyForceOffset( -dir * force, phys:GetPos() + dir * 5 )

            if math.random( 0, 400 ) > ragdoll.sparkEffectChance then continue end
            local eff = EffectData()
            eff:SetOrigin( phys:GetPos() )
            eff:SetRadius( 2 )
            eff:SetMagnitude( math.Rand( 0.1, 0.5 ) )
            eff:SetScale( math.Rand( 0.1, 1.5 ) )
            util.Effect( "Sparks", eff )

        end
    end )
end

if SERVER then
    hook.Add( "CreateEntityRagdoll", "glee_shockragdoll_hook", function( ent, ragdoll )
        if not IsValid( ent ) then return end
        if not ent:GetNW2Bool( "glee_recentlyStruckByLightning", false ) then return end

        if not IsValid( ragdoll ) then return end
        shockRagdoll( ragdoll )

    end )
else
    hook.Add( "CreateClientsideRagdoll", "glee_shockragdoll_hook", function( ent, ragdoll )
        if not IsValid( ent ) then return end
        if not ent:GetNW2Bool( "glee_recentlyStruckByLightning", false ) then return end

        if not IsValid( ragdoll ) then return end
        shockRagdoll( ragdoll )

    end )
end