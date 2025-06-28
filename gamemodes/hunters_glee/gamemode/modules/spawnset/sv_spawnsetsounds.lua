
local function playStartSound()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local startSound = spawnSet.roundStartSound
    if startSound == "" then return end

    local dsp = spawnSet.roundStartSoundDSP

    GAMEMODE:PlaySoundOnEveryPlayer( startSound, nil, nil, dsp )

end

local function playEndSound()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local endSound = spawnSet.roundEndSound
    if endSound == "" then return end

    local dsp = spawnSet.roundEndSoundDSP

    GAMEMODE:PlaySoundOnEveryPlayer( endSound, nil, nil, dsp )

end


hook.Add( "huntersglee_round_into_active", "glee_spawnset_startsound", function()
    playStartSound()

end )

hook.Add( "glee_post_set_spawnset", "glee_spawnset_startsound", function() -- when spawnset is set within the 1min grace after round starts
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    playStartSound()

end )

hook.Add( "huntersglee_round_into_limbo", "glee_spawnset_endsound", function()
    playEndSound()

end )
