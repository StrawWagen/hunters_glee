
hook.Add( "huntersglee_round_into_active", "glee_spawnset_startsound", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local startSound = spawnSet.roundStartSound
    if startSound == "" then return end

    GAMEMODE:PlaySoundOnEveryPlayer( startSound )

end )

hook.Add( "huntersglee_round_into_limbo", "glee_spawnset_endsound", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local endSound = spawnSet.roundEndSound
    if endSound == "" then return end

    GAMEMODE:PlaySoundOnEveryPlayer( endSound )

end )
