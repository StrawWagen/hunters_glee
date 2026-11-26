
terminator_Extras = terminator_Extras or {}

local TYPE_FROMENT = 1
local TYPE_ATPOS = 2
local TYPE_EFFECT = 3

if SERVER then
    util.AddNetworkString( "glee_peffect_play" )
    AddCSLuaFile()

end


-- only precache particles on load if gamemode is glee

local precached
local function doPrecache()
    precached = true
    game.AddParticles( "particles/glee/glee_ghostly_ectoplasm.pcf" )
    PrecacheParticleSystem( "glee_ghostly_ectoplasm" )

    game.AddParticles( "particles/glee/glee_ghostly_ectoplasm_subtle.pcf" )
    PrecacheParticleSystem( "glee_ghostly_ectoplasm_subtle" )

    game.AddParticles( "particles/glee/glee_gland_explosion_big.pcf" )
    PrecacheParticleSystem( "glee_gland_explosion_big" )

    game.AddParticles( "particles/glee/glee_gland_explosion_small.pcf" )
    PrecacheParticleSystem( "glee_gland_explosion_small" )

    game.AddParticles( "particles/glee/glee_divineintervention_spawn.pcf" )
    PrecacheParticleSystem( "glee_divineintervention_spawn" )

    game.AddParticles( "particles/glee/glee_taucannon_explosion.pcf" )
    PrecacheParticleSystem( "glee_taucannon_explosion" )

    game.AddParticles( "particles/glee/glee_atm_burrow.pcf" )
    PrecacheParticleSystem( "glee_atm_burrow_pebbles" )
    PrecacheParticleSystem( "glee_atm_burrow_breach" )

    game.AddParticles( "particles/glee/glee_ghostly_blessing_world.pcf" ) -- healing orbs follow bones in this one
    PrecacheParticleSystem( "glee_ghostly_blessing_world" )
    game.AddParticles( "particles/glee/glee_ghostly_blessing_firstperson.pcf" )
    PrecacheParticleSystem( "glee_ghostly_blessing_firstperson" )

    game.AddParticles( "particles/glee/glee_infernal_skeleton_death.pcf" )
    PrecacheParticleSystem( "glee_infernal_skeleton_death" )

end
if engine.ActiveGamemode() == "hunters_glee" then
    doPrecache()

end

if SERVER then
    function terminator_Extras.DoPFXAtPos( effString, pos )
        if not precached then doPrecache() end
        timer.Simple( 0, function()
            local recipFilter = RecipientFilter()
            recipFilter:AddPAS( pos )
            net.Start( "glee_peffect_play" )
                net.WriteUInt( TYPE_ATPOS, 4 )
                net.WriteString( effString )
                net.WriteVector( pos )
            net.Send( recipFilter )

        end )
    end
    function terminator_Extras.DoPFXFromEnt( effString, ent )
        if not precached then doPrecache() end
        timer.Simple( 0, function()
            if not IsValid( ent ) then return end
            local recipFilter = RecipientFilter()
            recipFilter:AddPAS( ent:WorldSpaceCenter() )
            net.Start( "glee_peffect_play" )
                net.WriteUInt( TYPE_FROMENT, 4 )
                net.WriteString( effString )
                net.WriteEntity( ent )
            net.Send( recipFilter )

        end )
    end

    -- server sent util.Effects go out as temp entities, dropped past the per tick cap or on packet loss
    -- this plays one on every client over a reliable net message instead, ONLY use this for moments that can't be missed
    -- optional data keys are named after the CEffectData setters, eg { magnitude = 2 }
    -- TODO: only origin and magnitude are sent, effects reading normal, angles, entity, scale, radius, etc get defaults
    local reliableEffectDefaults = {
        magnitude = 0, -- matches a fresh EffectData()
    }
    function terminator_Extras.DoReliableEffect( effName, origin, data )
        if not precached then doPrecache() end
        data = data or reliableEffectDefaults
        net.Start( "glee_peffect_play" )
            net.WriteUInt( TYPE_EFFECT, 4 )
            net.WriteString( effName )
            net.WriteVector( origin )
            net.WriteFloat( data.magnitude or reliableEffectDefaults.magnitude )
        net.Broadcast()

    end
else
    net.Receive( "glee_peffect_play", function()
        if not precached then doPrecache() end
        local readType = net.ReadUInt( 4 )
        if readType == TYPE_FROMENT then
            local effString = net.ReadString()
            local ent = net.ReadEntity()
            if not IsValid( ent ) then return end

            ent:CreateParticleEffect( effString, 0 )

        elseif readType == TYPE_ATPOS then
            local effString = net.ReadString()
            local pos = net.ReadVector()

            ParticleEffect( effString, pos, Angle( 0, 0, 0 ) )

        elseif readType == TYPE_EFFECT then
            local effName = net.ReadString()
            local fx = EffectData()
            fx:SetOrigin( net.ReadVector() )
            fx:SetMagnitude( net.ReadFloat() )
            util.Effect( effName, fx )

        end
    end )
end
