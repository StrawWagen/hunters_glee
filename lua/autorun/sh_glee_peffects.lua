
terminator_Extras = terminator_Extras or {}

local TYPE_FROMENT = 1
local TYPE_ATPOS = 2

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
            local recipFilter = RecipientFilter()
            recipFilter:AddPAS( ent:WorldSpaceCenter() )
            net.Start( "glee_peffect_play" )
                net.WriteUInt( TYPE_FROMENT, 4 )
                net.WriteString( effString )
                net.WriteEntity( ent )
            net.Send( recipFilter )

        end )
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

        else
            local effString = net.ReadString()
            local pos = net.ReadVector()

            ParticleEffect( effString, pos, Angle( 0, 0, 0 ) )

        end
    end )
end
