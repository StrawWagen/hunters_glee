
local defaultMusicVolume = 0.75
local volumeVar = CreateClientConVar( "huntersglee_musicvolume", "-1", true, false, "Glee music volume, -1 for default, " .. defaultMusicVolume, -1, 1 )

-- All active-sound state lives here; nil means nothing is playing.
local state           = nil
local currentPriority = 0
local loadGen         = 0  -- incremented on every load; callbacks compare to reject stale results

local lastThinkTime  = 0
local THINK_INTERVAL = 1  -- recovery check rate-limit; 1 second of lost audio is acceptable

cvars.AddChangeCallback( "huntersglee_musicvolume", function( _, _, newVal )
    if not state then return end

    local volume = tonumber( newVal ) or defaultMusicVolume
    if volume < 0 then volume = defaultMusicVolume end

    if state.fadeIn.active then
        state.fadeIn.targetVol = state.vol * volume

    elseif IsValid( state.channel ) and not state.fade.active then
        state.channel:SetVolume( state.vol * volume )

    end

end, "huntersglee_musicvolume_update" )

local function startSound( path, pitch, vol, offset, fadeInLength )
    if state and IsValid( state.channel ) then
        state.channel:Stop()
    end

    loadGen = loadGen + 1
    local myGen = loadGen

    state = {
        channel   = nil,
        path      = path,
        pitch     = pitch,
        vol       = vol,
        startTime = CurTime() - offset,
        fade      = { active = false, startTime = 0, startVol = 0, duration = 0 },
        fadeIn    = { active = false, startTime = 0, duration  = 0, targetVol = 0 },
        pending   = nil,
    }

    -- sound.PlayFile paths are relative to garrysmod/, but tracks are stored relative to garrysmod/sound/
    sound.PlayFile( "sound/" .. path, "noblock", function( channel, errNum, _errStr )
        if errNum and errNum ~= 0 then return end
        if not IsValid( channel )  then return end
        if loadGen ~= myGen then
            channel:Stop()
            return
        end

        state.channel = channel
        if offset > 0 then channel:SetTime( offset ) end
        channel:SetPlaybackRate( pitch / 100 )

        local volume = volumeVar:GetFloat()
        if volume < 0 then volume = defaultMusicVolume end
        local targetVol = vol * volume

        if fadeInLength > 0 then
            channel:SetVolume( 0 )
            state.fadeIn = {
                active    = true,
                startTime = CurTime(),
                duration  = fadeInLength,
                targetVol = targetVol,
            }
        else
            channel:SetVolume( targetVol )
        end

        channel:Play()
    end )
end

local function stopAndClear()
    if state and IsValid( state.channel ) then state.channel:Stop() end
    state           = nil
    currentPriority = 0
    loadGen         = loadGen + 1  -- invalidate any in-flight load
end

local function beginFade( path, pitch, vol, fadeOutLength, fadeInLength )
    if not state or not IsValid( state.channel ) then
        startSound( path, pitch, vol, 0, fadeInLength )
        return
    end

    -- Reset fade timer from current volume; if a fade is already running this restarts the countdown
    state.fade = {
        active    = true,
        startTime = CurTime(),
        startVol  = state.channel:GetVolume(),
        duration  = fadeOutLength,
    }
    state.pending = {
        path   = path,
        pitch  = pitch,
        vol    = vol,
        fadeIn = fadeInLength,
    }
end

hook.Add( "Think", "glee_solidsound_think", function()
    if not state then return end
    local now = CurTime()

    -- Fade-in: ramps volume up after a new sound begins (runs every frame)
    if state.fadeIn.active then
        local progress = math.Clamp( ( now - state.fadeIn.startTime ) / state.fadeIn.duration, 0, 1 )

        if IsValid( state.channel ) then
            state.channel:SetVolume( state.fadeIn.targetVol * progress )
        end

        if progress >= 1 then
            state.fadeIn.active = false
        end
    end

    -- Fade-out: ramps volume down, then starts pending sound (runs every frame)
    if state.fade.active then
        local progress = math.Clamp( ( now - state.fade.startTime ) / state.fade.duration, 0, 1 )

        if IsValid( state.channel ) then
            state.channel:SetVolume( state.fade.startVol * ( 1 - progress ) )
        end

        if progress >= 1 then
            local pending = state.pending
            stopAndClear()
            if pending then
                startSound( pending.path, pending.pitch, pending.vol, 0, pending.fadeIn )
            end
        end

        return  -- skip recovery check while fading
    end

    -- Recovery check (rate-limited)
    if now - lastThinkTime < THINK_INTERVAL then return end
    lastThinkTime = now

    if not IsValid( state.channel ) then
        -- Channel was externally invalidated (e.g. stopsound) while we still expect music
        local offset = now - state.startTime
        startSound( state.path, state.pitch, state.vol, offset, 0 )
        return
    end

    local chanState = state.channel:GetState()

    if chanState == GMOD_CHANNEL_STOPPED then
        -- Distinguish natural end from unexpected stop
        local expectedPos = now - state.startTime
        local len         = state.channel:GetLength()

        if len > 0 and expectedPos < len - 1 then
            -- Stopped before the track ended; restart from estimated position
            startSound( state.path, state.pitch, state.vol, expectedPos, 0 )
        else
            -- Natural end (or indeterminate length); clear state
            stopAndClear()
        end

    elseif chanState == GMOD_CHANNEL_STALLED then
        state.channel:Play()
    end
end )

net.Receive( "glee_sendsolidsound", function()
    local path          = net.ReadString()
    local pitch         = net.ReadFloat()
    local vol           = net.ReadFloat()
    local fadeInLength  = net.ReadFloat()
    local fadeOutLength = net.ReadFloat()
    local priority      = net.ReadInt( 16 )

    if priority < currentPriority then return end
    currentPriority = priority

    beginFade( path, pitch, vol, fadeOutLength, fadeInLength )
end )

net.Receive( "glee_stopsolidsounds", function()
    stopAndClear()
end )