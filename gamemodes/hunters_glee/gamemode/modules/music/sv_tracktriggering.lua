
local function playSpawnSetSound( field )
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local snd = spawnSet[field]
    if snd == "" then return end

    GAMEMODE:SendMusic( snd )

end

hook.Add( "huntersglee_round_tenseconds_before_active", "glee_spawnset_earlystartsound", function()
    local _, spawnSet = GAMEMODE:GetSpawnSet()
    -- backwards compat
    -- only play early start if roundStartSound is unset
    if spawnSet.roundStartSound ~= "" then return end

    playSpawnSetSound( "roundEarlyStartSound" )

end )

hook.Add( "huntersglee_round_into_active", "glee_spawnset_startsound", function()
    playSpawnSetSound( "roundStartSound" )

end )

hook.Add( "glee_post_new_spawnset", "glee_spawnset_startsound", function() -- when spawnset is set within the 1min grace after round starts
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

-- TODO: more ways for highIntensitySound to be played

hook.Add( "huntersglee_wave_wiped", "glee_spawnset_wavewipedsound", function()
    local waveData = GAMEMODE.waveExtraData
    local waveSize = waveData.waveSize
    if waveSize <= 2 then return end
    if waveData.realKillCount < waveSize / 2 then return end -- dont play if the wave despawned itself

    local aliveCount = GAMEMODE:countWinnablePlayers()
    if aliveCount <= 0 then return end

    local everyoneCount = player.GetCount()
    if aliveCount > everyoneCount / 4 then return end -- only play if 1/4 or less players are alive

    playSpawnSetSound( "highIntensitySound" )

end )

-- plays when we go from 0 grigori to 1
hook.Add( "huntersglee_grigori_arrival", "glee_spawnset_grigoriarrival", function()
    playSpawnSetSound( "grigoriArrivalSound" )

end )

-- plays first time there's at least 2 grigori on the map
hook.Add( "huntersglee_second_grigori_arrival", "glee_spawnset_second_grigoriarrival", function()
    playSpawnSetSound( "secondGrigoriArrivalSound" )

end )

hook.Add( "huntersglee_grigori_failure", "glee_spawnset_grigorifailure", function()
    playSpawnSetSound( "noMoreGrigoriSound" )

end )