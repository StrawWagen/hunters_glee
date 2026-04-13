
local function playStartSound()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local startSound = spawnSet.roundStartSound
    if startSound == "" then return end

    local dsp = spawnSet.roundStartSoundDSP

    GAMEMODE:SendSolidSound( startSound, { dsp = dsp } )

end

local function playEndSound()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local endSound = spawnSet.roundEndSound
    if endSound == "" then return end

    GAMEMODE:SendSolidSound( endSound )

end

local function playWinSound()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local winSound = spawnSet.roundWinSound
    if winSound == "" then return end

    GAMEMODE:SendSolidSound( winSound )

end

local function playPerfectWinSound()
    local _, spawnSet = GAMEMODE:GetSpawnSet()

    local perfectWinSound = spawnSet.roundPerfectWinSound
    if perfectWinSound == "" then return end

    GAMEMODE:SendSolidSound( perfectWinSound )

end


hook.Add( "huntersglee_round_into_active", "glee_spawnset_startsound", function()
    playStartSound()


end )

hook.Add( "glee_post_set_spawnset", "glee_spawnset_startsound", function() -- when spawnset is set within the 1min grace after round starts
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
    playStartSound()

end )

hook.Add( "huntersglee_round_into_limbo", "glee_spawnset_endsound", function()
    local everyoneEscaped = true
    local someoneEscaped = false
    for _, ply in player.Iterator() do
        local hasEscaped = ply:HasEscaped()
        if hasEscaped then
            someoneEscaped = true

        else
            everyoneEscaped = false

        end

    end
    if everyoneEscaped then
        playPerfectWinSound()

    elseif someoneEscaped then
        playWinSound()

    else
        playEndSound()

    end
end )
