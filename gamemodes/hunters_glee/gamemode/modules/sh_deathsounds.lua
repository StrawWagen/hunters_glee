
local function handleSnd( ent, ragdoll )
    if not ent:IsPlayer() then return end

    local lvl = ent:GetNW2Int( "glee_deathsoundlvl", 78 )
    local deathSound = ent:GetNW2String( "glee_deathsound", "" )

    if deathSound and deathSound ~= "" then
        ragdoll:EmitSound( deathSound, lvl, math.Rand( 99, 101 ), 1, CHAN_AUTO )
        ragdoll:CallOnRemove( "glee_stopdeathsounds", function( removedRagdoll )
            removedRagdoll:StopSound( deathSound )

        end )

    end
end

if SERVER then
    local function setupDeathSndPlaying( ply, dmg )
        if not IsValid( ply ) then return end

        local pickedSound = GAMEMODE:GetRandModelLine( ply, "death" )
        if not pickedSound then
            ply:SetNW2String( "glee_deathsound", "" )
            return

        end

        local lvl = 78
        if dmg:IsFallDamage() then
            lvl = 90

        end

        ply:SetNW2Int( "glee_deathsoundlvl", lvl )
        ply:SetNW2String( "glee_deathsound", pickedSound )

    end

    hook.Add( "PlayerShouldTakeDamage", "glee_deathsounds", function( ply )
        ply.glee_DeathSounds_WasSpeaking = ply:IsSpeaking()

    end )

    hook.Add( "CanPlayerSuicide", "glee_deathsounds", function( ply )
        ply.glee_DeathSounds_WasSpeaking = ply:IsSpeaking()

    end )

    hook.Add( "DoPlayerDeath", "glee_deathsounds", function( ply, _, dmg )
        if not ply.glee_DeathSounds_WasSpeaking then -- they're already screaming
            setupDeathSndPlaying( ply, dmg )

        end
        ply.glee_DeathSounds_WasSpeaking = nil

    end )

    hook.Add( "PlayerSpawn", "glee_resetdeathsounds", function( ply )
        ply:SetNW2Bool( "glee_needsdeathsound", false )

    end )

    hook.Add( "CreateEntityRagdoll", "glee_deathsounds", function( ... ) -- just in case
        handleSnd( ... )

    end )

else
    hook.Add( "CreateClientsideRagdoll", "glee_deathsounds", function( ... )
        handleSnd( ... )

    end )
end
