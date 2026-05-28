
local defaultMusicVolume = 0.75
local volumeVar = CreateClientConVar( "huntersglee_musicvolume", "-1", true, false, "Glee music volume, -1 for default, " .. defaultMusicVolume, -1, 1 )

-- All active-sound state lives here; nil means nothing is playing.
local currentSound     = nil
local currentPriority  = 0
local currentTrackName = ""
local loadGen          = 0  -- incremented on every load; callbacks compare to reject stale results

local nextThink      = 0
local THINK_INTERVAL = 1  -- recovery check rate-limit; 1 second of lost audio is acceptable

local function getUserVolume()
    local v = volumeVar:GetFloat()
    return v < 0 and defaultMusicVolume or v

end

local function getEffectiveVol( baseVol )
    return baseVol * ( currentSound and currentSound.distanceMult or 1 ) * getUserVolume()

end

cvars.AddChangeCallback( "huntersglee_musicvolume", function( _, _, _ )
    if not currentSound then return end
    if currentSound.fadeIn.active then return end  -- next Think will pick up the new value naturally
    if currentSound.fade.active   then return end  -- fading out, new sound will get correct volume when it starts
    if not IsValid( currentSound.channel ) then return end
    currentSound.channel:SetVolume( getEffectiveVol( currentSound.vol ) )

end, "huntersglee_musicvolume_update" )

local function startSound( path, pitch, vol, offset, fadeInLength, fadeOutLength, entity, startFadeOutDist, endFadeOutDist )
    if currentSound and IsValid( currentSound.channel ) then
        currentSound.channel:Stop()

    end

    loadGen = loadGen + 1
    local myGen = loadGen

    currentSound = {
        channel          = nil,
        path             = path,
        pitch            = pitch,
        vol              = vol,
        startTime        = SysTime() - offset,
        fade             = { active = false, startTime = 0, startVol = 0, duration = 0 },
        fadeIn           = { active = false, startTime = 0, duration  = 0 },
        fadeInLength     = fadeInLength,
        fadeOutLength    = fadeOutLength,
        pending          = nil,
        entity           = entity           or nil,
        startFadeOutDist = startFadeOutDist or 0,
        endFadeOutDist   = endFadeOutDist   or 0,
        distanceMult     = 1,
    }

    -- sound.PlayFile finds sounds relative to the garrysmod folder
    local realPath = path
    if not string.StartWith( path, "sound/" ) then
        realPath = "sound/" .. path

    end

    -- channel won't be valid for a couple frames while the sound loads
    nextThink = SysTime() + THINK_INTERVAL

    sound.PlayFile( realPath, "noblock noplay", function( channel, errNum, _errStr )
        if errNum and errNum ~= 0 then return end
        if not IsValid( channel )   then return end
        if loadGen ~= myGen then
            channel:Stop()
            return

        end

        currentSound.channel = channel
        if offset > 0 then channel:SetTime( offset ) end
        channel:SetPlaybackRate( pitch / 100 )

        if fadeInLength > 0 then
            channel:SetVolume( 0 )
            currentSound.fadeIn = {
                active    = true,
                startTime = SysTime(),
                duration  = fadeInLength,
            }

        else
            channel:SetVolume( getEffectiveVol( vol ) )

        end

        channel:Play()

    end )
end

local function endCurrentSong()
    if currentSound and IsValid( currentSound.channel ) then currentSound.channel:Stop() end
    currentSound = nil

end

local function stopAndClear()
    endCurrentSong()
    currentPriority  = 0
    currentTrackName = ""
    loadGen          = loadGen + 1  -- invalidate any in-flight load

end

local function beginFade( path, pitch, vol, fadeInLength, fadeOutLength, entity, startFadeOutDist, endFadeOutDist )
    if not currentSound or not IsValid( currentSound.channel ) then
        startSound( path, pitch, vol, 0, fadeInLength, fadeOutLength, entity, startFadeOutDist, endFadeOutDist )
        return

    end

    -- Reset fade timer from current volume; if a fade is already running this restarts the countdown
    currentSound.fade = {
        active    = true,
        startTime = SysTime(),
        startVol  = currentSound.channel:GetVolume(),
        duration  = fadeOutLength,
    }
    currentSound.pending = {
        path             = path,
        pitch            = pitch,
        vol              = vol,
        fadeInLength     = fadeInLength,
        fadeOutLength    = fadeOutLength,
        entity           = entity,
        startFadeOutDist = startFadeOutDist,
        endFadeOutDist   = endFadeOutDist,
    }

end

hook.Add( "Think", "glee_music_think", function()
    if not currentSound then return end
    local now = SysTime()

    -- Distance falloff for entity-bound sounds (runs every frame)
    if currentSound.entity then
        if not IsValid( currentSound.entity ) then
            stopAndClear()
            return

        end

        local ply = LocalPlayer()
        if IsValid( ply ) then
            local dist  = ply:GetPos():Distance( currentSound.entity:GetPos() )
            local range = math.max( currentSound.endFadeOutDist - currentSound.startFadeOutDist, 1 )
            local t     = math.Clamp( ( dist - currentSound.startFadeOutDist ) / range, 0, 1 )
            currentSound.distanceMult = 1 - t

        end
    end

    -- Fade-in: ramps volume up after a new sound begins (runs every frame)
    if currentSound.fadeIn.active then
        local progress = math.Clamp( ( now - currentSound.fadeIn.startTime ) / currentSound.fadeIn.duration, 0, 1 )

        if IsValid( currentSound.channel ) then
            currentSound.channel:SetVolume( getEffectiveVol( currentSound.vol ) * progress )

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
            local p = currentSound.pending
            endCurrentSong()
            if p then
                startSound( p.path, p.pitch, p.vol, 0, p.fadeInLength, p.fadeOutLength, p.entity, p.startFadeOutDist, p.endFadeOutDist )

            end
        end

        return  -- skip recovery check while fading

    end

    -- Update entity-based volume each frame during steady state
    if currentSound.entity and IsValid( currentSound.channel ) and not currentSound.fadeIn.active then
        currentSound.channel:SetVolume( getEffectiveVol( currentSound.vol ) )

    end

    -- Recovery check (rate-limited)
    if now < nextThink then return end
    nextThink = now + THINK_INTERVAL

    -- keep playing thru stopsound calls
    if not IsValid( currentSound.channel ) then
        local offset = now - currentSound.startTime
        startSound( currentSound.path, currentSound.pitch, currentSound.vol, offset, 0, 0, currentSound.entity, currentSound.startFadeOutDist, currentSound.endFadeOutDist )
        return

    end

    local soundState = currentSound.channel:GetState()

    if soundState == GMOD_CHANNEL_STOPPED then
        -- Distinguish natural end from unexpected stop
        local expectedPos = now - currentSound.startTime
        local len         = currentSound.channel:GetLength()

        if len > 0 and expectedPos < len - 1 then
            -- Stopped before the track ended; restart from estimated position
            startSound( currentSound.path, currentSound.pitch, currentSound.vol, expectedPos, 0, 0, currentSound.entity, currentSound.startFadeOutDist, currentSound.endFadeOutDist )

        else
            -- Natural end (or indeterminate length); clear currentSound
            stopAndClear()

        end

    elseif soundState == GMOD_CHANNEL_STALLED then
        currentSound.channel:Play()

    end
end )

local developer = GetConVar( "developer" )

local function readOverrideTable()
    local count = net.ReadUInt( 8 )
    local t = {}
    for i = 1, count do
        t[i] = net.ReadString()
    end
    return t

end

net.Receive( "glee_playmusic", function()
    local trackName     = net.ReadString()
    local path          = net.ReadString()
    local pitch         = net.ReadFloat()
    local vol           = net.ReadFloat()
    local fadeInLength  = net.ReadFloat()
    local fadeOutLength = net.ReadFloat()
    local priority      = net.ReadUInt( 16 )
    local neverOverrides  = readOverrideTable()
    local alwaysOverrides = readOverrideTable()
    local hasEntity     = net.ReadBool()
    local entity, startFadeOutDist, endFadeOutDist
    if hasEntity then
        entity           = net.ReadEntity()
        startFadeOutDist = net.ReadFloat()
        endFadeOutDist   = net.ReadFloat()

    end

    -- neverOverrides: this incoming track refuses to replace the named currently-playing track
    for _, blockedName in ipairs( neverOverrides ) do
        if blockedName == currentTrackName then return end

    end

    -- alwaysOverrides: this incoming track forces a replace regardless of priority
    local forcePlay = false
    for _, overrideName in ipairs( alwaysOverrides ) do
        if overrideName == currentTrackName then
            forcePlay = true
            break

        end
    end

    if not forcePlay and priority < currentPriority then return end

    currentPriority  = priority
    currentTrackName = trackName

    if developer:GetBool() then
        permaPrint( "GLEE: playing " .. path .. " (track: " .. trackName .. ") priority " .. priority )

    end

    beginFade( path, pitch, vol, fadeInLength, fadeOutLength, entity, startFadeOutDist, endFadeOutDist )

end )

net.Receive( "glee_stopmusic", function()
    if developer:GetBool() then
        permaPrint( "GLEE: stopping all music" )

    end
    stopAndClear()

end )

net.Receive( "glee_stopmusic_trackpart", function()
    local trackPart = net.ReadString()
    if developer:GetBool() then
        permaPrint( "GLEE: stopping music with track part " .. trackPart .. "..." )

    end
    if not string.find( currentTrackName, trackPart ) then return end
    if developer:GetBool() then
        permaPrint( "GLEE: match found, stopping current track " .. currentTrackName )

    end
    stopAndClear()

end )