
local volumeVar = CreateClientConVar( "glee_music_volume", "1", true, false, "Glee music volume" )

local currentChannel  = nil
local currentPath     = nil
local currentPitch    = 100
local currentVol      = 1
local soundStartTime  = 0   -- CurTime() minus seek offset, so ( CurTime() - soundStartTime ) = expected playback position

local lastThinkTime   = 0
local THINK_INTERVAL  = 1 -- slow thinks, actually manages the songs

local fadeDuration    = 0.5  -- set per-fade from server; default matches DEFAULT_FADE_OUT
local fadeActive      = false
local fadeStartTime   = 0
local fadeStartVol    = 0
local pendingPath     = nil
local pendingPitch    = nil
local pendingVol      = nil
local pendingFadeIn   = 0

local fadeInActive    = false
local fadeInStartTime = 0
local fadeInDuration  = 0
local fadeInTargetVol = 0

local loadGeneration  = 0  -- incremented on every new load request; callbacks compare against it to avoid applying stale results

local function startSound( path, pitch, vol, offset, fadeInLength )
    if IsValid( currentChannel ) then
        currentChannel:Stop()
        currentChannel = nil

    end

    loadGeneration = loadGeneration + 1
    local myGen    = loadGeneration

    soundStartTime = CurTime() - offset
    currentPath    = path
    currentPitch   = pitch
    currentVol     = vol

    sound.PlayFile( currentPath, "noblock", function( channel, errNum, _errStr )
        local errored = ( errNum and errNum ~= 0 )
        if errored then return end

        if not IsValid( channel ) then return end

        if loadGeneration ~= myGen then
            channel:Stop()
            return

        end

        currentChannel = channel
        if offset > 0 then channel:SetTime( offset ) end
        local playbackRate = pitch / 100
        channel:SetPlaybackRate( playbackRate )

        local targetVol = vol * volumeVar:GetFloat()
        if fadeInLength > 0 then
            channel:SetVolume( 0 )
            fadeInActive    = true
            fadeInStartTime = CurTime()
            fadeInDuration  = fadeInLength
            fadeInTargetVol = targetVol
        else
            channel:SetVolume( targetVol )
        end

        channel:Play()

    end )
end

local function stopAndClear()
    if IsValid( currentChannel ) then currentChannel:Stop() end
    currentChannel = nil
    currentPath    = nil
    loadGeneration = loadGeneration + 1  -- invalidate any in-flight load

end

local function beginFade( path, pitch, vol, fadeOutLength, fadeInLength )
    if not IsValid( currentChannel ) then
        startSound( path, pitch, vol, 0, fadeInLength )
        return

    end

    -- If a fade is already running, just redirect its target
    pendingFadeIn = fadeInLength
    fadeStartVol  = currentChannel:GetVolume()
    fadeStartTime = CurTime()
    fadeDuration  = fadeOutLength
    fadeActive    = true
    pendingPath   = path
    pendingPitch  = pitch
    pendingVol    = vol

end

hook.Add( "Think", "glee_solidsound_think", function()
    local now = CurTime()

    -- Fade-in runs every frame (volume ramp up after a new sound starts)
    if fadeInActive then
        local progress = math.Clamp( ( now - fadeInStartTime ) / fadeInDuration, 0, 1 )

        if IsValid( currentChannel ) then
            currentChannel:SetVolume( fadeInTargetVol * progress )
        end

        if progress >= 1 then
            fadeInActive = false
        end

    end

    -- Fade-out runs every frame
    if fadeActive then
        local progress = math.Clamp( ( now - fadeStartTime ) / fadeDuration, 0, 1 )

        if IsValid( currentChannel ) then
            currentChannel:SetVolume( fadeStartVol * ( 1 - progress ) )

        end

        -- fade is done, kill the sound
        if progress >= 1 then
            stopAndClear()
            fadeActive = false
            if pendingPath then
                startSound( pendingPath, pendingPitch, pendingVol, 0, pendingFadeIn )
                pendingPath  = nil
                pendingPitch = nil
                pendingVol   = nil

            end
        end

        return  -- skip recovery check while fading

    end

    -- Recovery check is rate-limited; 1 second of lost audio is acceptable
    if now - lastThinkTime < THINK_INTERVAL then return end
    lastThinkTime = now

    if not currentPath then return end

    if not IsValid( currentChannel ) then
        -- Channel was externally invalidated (e.g. stopsound) while we still expect music
        local offset = now - soundStartTime
        startSound( currentPath, currentPitch, currentVol, offset, 0 )
        return

    end

    local state = currentChannel:GetState()

    if state == GMOD_CHANNEL_STOPPED then
        -- Distinguish natural end from unexpected stop
        local expectedPos = now - soundStartTime
        local len         = currentChannel:GetLength()

        local stoppedPrematurely = len > 0 and expectedPos < len - 1
        if stoppedPrematurely then
            -- Stopped before the track ended; restart from estimated position
            startSound( currentPath, currentPitch, currentVol, expectedPos, 0 )

        else
            -- Natural end (or indeterminate length); clear state
            stopAndClear()

        end
    elseif state == GMOD_CHANNEL_STALLED then
        currentChannel:Play()

    end
end )

net.Receive( "glee_sendsolidsound", function()
    local path  = net.ReadString()
    if not string.StartsWith( path, "sound/" ) then
        -- "Unlike other sound functions and structures, the path is relative to garrysmod/ instead of garrysmod/sound/"
        path = "sound/" .. path

    end
    local pitch         = net.ReadFloat()
    local vol           = net.ReadFloat()
    local _dsp          = net.ReadFloat()  -- no DSP equivalent in PlayFile; read to keep buffer aligned
    local fadeInLength  = net.ReadFloat()
    local fadeOutLength = net.ReadFloat()

    beginFade( path, pitch, vol, fadeOutLength, fadeInLength )

end )

net.Receive( "glee_stopsolidsounds", function()
    stopAndClear()
    fadeActive   = false
    fadeInActive = false
end )