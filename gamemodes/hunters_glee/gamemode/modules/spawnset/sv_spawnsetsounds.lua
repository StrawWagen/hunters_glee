
hook.Add( "huntersglee_round_into_active", "glee_spawnset_startsound", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local startSound = spawnSet.roundStartSound
    if startSound == "" then return end

    GAMEMODE:PlaySoundOnEveryPlayer( startSound )

end )

hook.Add( "glee_post_set_spawnset", "glee_spawnset_startsound", function() -- when spawnset is set within the 1min grace after round starts
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
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
