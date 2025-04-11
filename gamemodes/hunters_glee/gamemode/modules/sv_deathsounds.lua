
local function playDeathSound( victim )
    if not IsValid( victim ) then return end

    local pickedSound = GAMEMODE:GetRandModelLine( victim, "death" )

    sound.Play( pickedSound, victim:GetShootPos(), 90, 100 )

end

hook.Add( "PlayerShouldTakeDamage", "glee_deathsounds", function( ply )
    ply.glee_DeathSounds_WasSpeaking = ply:IsSpeaking()

end )

hook.Add( "CanPlayerSuicide", "glee_deathsounds", function( ply )
    ply.glee_DeathSounds_WasSpeaking = ply:IsSpeaking()

end )

hook.Add( "DoPlayerDeath", "glee_deathsounds", function( ply )
    if not ply.glee_DeathSounds_WasSpeaking then -- they're already screaming
        playDeathSound( ply )

    end
    ply.glee_DeathSounds_WasSpeaking = nil

end )