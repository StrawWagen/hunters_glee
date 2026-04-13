
local defaultMusicVolume = 0.75
local volumeVar = CreateClientConVar( "huntersglee_musicvolume", "-1", true, false, "Glee music volume, -1 for default, " .. defaultMusicVolume, -1, 1 )

-- All active-sound state lives here; nil means nothing is playing.
local currentSound    = nil
local currentPriority = 0
local loadGen         = 0  -- incremented on every load; callbacks compare to reject stale results

local nextThink  = 0
local THINK_INTERVAL = 1  -- recovery check rate-limit; 1 second of lost audio is acceptable

cvars.AddChangeCallback( "huntersglee_musicvolume", function( _, _, newVal )
    if not currentSound then return end

    local volume = tonumber( newVal ) or defaultMusicVolume
    if volume < 0 then volume = defaultMusicVolume end

    if currentSound.fadeIn.active then
        currentSound.fadeIn.targetVol = currentSound.vol * volume

    elseif IsValid( currentSound.channel ) and not currentSound.fade.active then
        currentSound.channel:SetVolume( currentSound.vol * volume )

    end

end, "huntersglee_musicvolume_update" )

local function startSound( path, pitch, vol, offset, fadeInLength, fadeOutLength )
    if currentSound and IsValid( currentSound.channel ) then
        currentSound.channel:Stop()

    end

    loadGen = loadGen + 1
    local myGen = loadGen

    currentSound = {
        channel   = nil,
        path      = path,
        pitch     = pitch,
        vol       = vol,
        startTime = CurTime() - offset,
        fade      = { active = false, startTime = 0, startVol = 0, duration = 0 },
        fadeIn    = { active = false, startTime = 0, duration  = 0, targetVol = 0 },
        fadeInLength = fadeInLength,
        fadeOutLength = fadeOutLength,
        pending   = nil,

    }

    -- check sound.PlayFile
    -- it finds sounds relative to garrysmod folder
    local realPath = path
    if not string.StartWith( path, "sound/" ) then
        realPath = "sound/" .. path

    end

    -- channel won't be invalid for a couple frames as the sound loads
    nextThink = CurTime() + THINK_INTERVAL

    sound.PlayFile( realPath, "noblock", function( channel, errNum, _errStr )
        if errNum and errNum ~= 0 then return end
        if not IsValid( channel )  then return end
        if loadGen ~= myGen then
            channel:Stop()
            return

        end

        currentSound.channel = channel
        if offset > 0 then channel:SetTime( offset ) end
        channel:SetPlaybackRate( pitch / 100 )

        local volume = volumeVar:GetFloat()
        if volume < 0 then volume = defaultMusicVolume end
        local targetVol = vol * volume

        if currentSound.fadeInLength > 0 then
            channel:SetVolume( 0 )
            currentSound.fadeIn = {
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

local function endCurrentSong()
    if currentSound and IsValid( currentSound.channel ) then currentSound.channel:Stop() end
    currentSound    = nil

end

local function stopAndClear()
    endCurrentSong()
    currentPriority = 0
    loadGen         = loadGen + 1  -- invalidate any in-flight load

end

local function beginFade( path, pitch, vol, fadeInLength, fadeOutLength )
    if not currentSound or not IsValid( currentSound.channel ) then
        startSound( path, pitch, vol, 0, fadeInLength, fadeOutLength )
        return

    end

    -- Reset fade timer from current volume; if a fade is already running this restarts the countdown
    currentSound.fade = {
        active    = true,
        startTime = CurTime(),
        startVol  = currentSound.channel:GetVolume(),
        duration  = fadeOutLength,
    }
    currentSound.pending = {
        path   = path,
        pitch  = pitch,
        vol    = vol,
        fadeInLength = fadeInLength,
        fadeOutLength = fadeOutLength,
    }

end

hook.Add( "Think", "glee_solidsound_think", function()
    if not currentSound then return end
    local now = CurTime()

    -- Fade-in: ramps volume up after a new sound begins (runs every frame)
    if currentSound.fadeIn.active then
        local progress = math.Clamp( ( now - currentSound.fadeIn.startTime ) / currentSound.fadeIn.duration, 0, 1 )

        if IsValid( currentSound.channel ) then
            currentSound.channel:SetVolume( currentSound.fadeIn.targetVol * progress )

        end

        if progress >= 1 then
            currentSound.fadeIn.active = false

        end
    end

    -- Fade-out: ramps volume down, then starts pending sound (runs every frame)
    if currentSound.fade.active then
        local progress = math.Clamp( ( now - currentSound.fade.startTime ) / currentSound.fade.duration, 0, 1 )

        if IsValid( currentSound.channel ) then
            currentSound.channel:SetVolume( currentSound.fade.startVol * ( 1 - progress ) )

        end

        if progress >= 1 then
            local pending = currentSound.pending
            endCurrentSong()
            if pending then
                startSound( pending.path, pending.pitch, pending.vol, 0, pending.fadeInLength, pending.fadeOutLength )

            end
        end

        return  -- skip recovery check while fading

    end

    -- Recovery check (rate-limited)
    if now < nextThink then return end
    nextThink = now + THINK_INTERVAL

    -- keep playing thru stopsound calls
    if not IsValid( currentSound.channel ) then
        local offset = now - currentSound.startTime
        startSound( currentSound.path, currentSound.pitch, currentSound.vol, offset, 0 )
        return

    end

    local soundState = currentSound.channel:GetState()

    if soundState == GMOD_CHANNEL_STOPPED then
        -- Distinguish natural end from unexpected stop
        local expectedPos = now - currentSound.startTime
        local len         = currentSound.channel:GetLength()

        if len > 0 and expectedPos < len - 1 then
            -- Stopped before the track ended; restart from estimated position
            startSound( currentSound.path, currentSound.pitch, currentSound.vol, expectedPos, 0 )

        else
            -- Natural end (or indeterminate length); clear currentSound
            stopAndClear()

        end

    elseif soundState == GMOD_CHANNEL_STALLED then
        currentSound.channel:Play()

    end
end )

net.Receive( "glee_sendsolidsound", function()
    local path          = net.ReadString()
    local pitch         = net.ReadFloat()
    local vol           = net.ReadFloat()
    local fadeInLength  = net.ReadFloat()
    local fadeOutLength = net.ReadFloat()
    local priority      = net.ReadUInt( 16 )

    if priority < currentPriority then return end
    currentPriority = priority

    beginFade( path, pitch, vol, fadeInLength, fadeOutLength )

end )

net.Receive( "glee_stopsolidsounds", function()
    stopAndClear()

end )