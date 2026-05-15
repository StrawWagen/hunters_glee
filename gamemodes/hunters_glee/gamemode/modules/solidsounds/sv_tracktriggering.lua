
local function playSpawnSetSound( field )
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local snd = spawnSet[field]
    if snd == "" then return end

    GAMEMODE:SendSolidSound( snd )

end

hook.Add( "huntersglee_round_tenseconds_before_active", "glee_spawnset_earlystartsound", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()
    if spawnSet.roundStartSound ~= "" then return end -- let the roundStartSound take priority

    playSpawnSetSound( "roundEarlyStartSound" )

end )

hook.Add( "huntersglee_round_into_active", "glee_spawnset_startsound", function()
    playSpawnSetSound( "roundStartSound" )

end )

hook.Add( "glee_post_set_spawnset", "glee_spawnset_startsound", function() -- when spawnset is set within the 1min grace after round starts
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    playSpawnSetSound( "roundStartSound" )

end )

hook.Add( "huntersglee_round_into_limbo", "glee_spawnset_endsound", function()
    if GAMEMODE.roundExtraData.everyoneEscaped then
        playSpawnSetSound( "roundPerfectWinSound" )

    elseif GAMEMODE.roundExtraData.someoneEscaped then
        playSpawnSetSound( "roundWinSound" )

    else
        timer.Simple( 0.5, function()
            playSpawnSetSound( "roundEndSound" )

        end )
    end
end )

hook.Add( "huntersglee_wave_wiped", "glee_spawnset_wavewipedsound", function()
    local waveData = GAMEMODE.waveExtraData
    local waveSize = waveData.waveSize
    if waveSize <= 2 then return end
    if waveData.realKillCount < waveSize / 2 then return end -- dont play if the wave despawned itself

    local aliveCount = GAMEMODE:countWinnablePlayers()
    if aliveCount <= 0 then return end

    local everyoneCount = player.GetCount()
    if aliveCount > everyoneCount / 4 then return end -- only play if 1/4 or less players are alive

    playSpawnSetSound( "quarterAliveWaveWipedSound" )

end )