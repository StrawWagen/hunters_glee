
local function playDeathSound( victim, dmg )
    if not IsValid( victim ) then return end

    local pickedSound = GAMEMODE:GetRandModelLine( victim, "death" )
    if not pickedSound then return end

    local lvl = 78
    if dmg:IsFallDamage() then
        lvl = 90

    end

    sound.Play( pickedSound, victim:GetShootPos(), lvl, math.Rand( 99, 101 ) )

end

hook.Add( "PlayerShouldTakeDamage", "glee_deathsounds", function( ply )
    ply.glee_DeathSounds_WasSpeaking = ply:IsSpeaking()

end )

hook.Add( "CanPlayerSuicide", "glee_deathsounds", function( ply )
    ply.glee_DeathSounds_WasSpeaking = ply:IsSpeaking()

end )

hook.Add( "DoPlayerDeath", "glee_deathsounds", function( ply, _, dmg )
    if not ply.glee_DeathSounds_WasSpeaking then -- they're already screaming
        playDeathSound( ply, dmg )

    end
    ply.glee_DeathSounds_WasSpeaking = nil

end )