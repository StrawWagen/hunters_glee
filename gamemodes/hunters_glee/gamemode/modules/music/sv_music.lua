
util.AddNetworkString( "glee_playmusic" )
util.AddNetworkString( "glee_stopmusic" )
util.AddNetworkString( "glee_stopmusic_trackpart" )

local DEFAULT_FADE_IN  = 0
local DEFAULT_FADE_OUT = 0.5

local function writeOverrideTable( t )
    t = t or {}
    net.WriteUInt( #t, 8 )
    for _, name in ipairs( t ) do
        net.WriteString( name )

    end
end

local function broadcastMusic( trackName, path, data, recipients )
    data.pitch         = data.pitch         or 100
    data.vol           = data.vol           or 1
    data.fadeInLength  = data.fadeInLength  or DEFAULT_FADE_IN
    data.fadeOutLength = data.fadeOutLength or DEFAULT_FADE_OUT
    data.priority      = data.priority      or 0

    net.Start( "glee_playmusic" )
        net.WriteString( trackName )
        net.WriteString( path )
        net.WriteString( data.author or "" )
        net.WriteFloat(  data.pitch )
        net.WriteFloat(  data.vol )
        net.WriteFloat(  data.fadeInLength )
        net.WriteFloat(  data.fadeOutLength )
        net.WriteUInt(   data.priority, 16 )
        writeOverrideTable( data.neverOverrides )
        writeOverrideTable( data.alwaysOverrides )
        local hasEntity = IsValid( data.entity )
        net.WriteBool( hasEntity )
        if hasEntity then
            net.WriteEntity( data.entity )
            net.WriteFloat( data.startFadeOutDist or 500 )
            net.WriteFloat( data.endFadeOutDist   or 1500 )

        end
    if recipients then
        net.Send( recipients )

    else
        net.Broadcast()

    end

end

--[[---------------------------------------------------------
    GM:SendMusic
    @desc Plays music for everyone, eg GAMEMODE:SendMusic( "tracks/gunshipBattle" )
    @param path: A track, "tracks/NAME", a stopper, "tracks/stopper/NAME", or a raw sound path.
    @param data: Optional. For raw paths, the sound's settings, like a track's fields in sv_default_tracks.
    For tracks, only these are read, and only for this one send.
    .trackOverrides, fields that replace the track's own.
    .trackAdditions, lists added onto the track's own, eg { neverOverrides = { "gunshipBattle" } }
--]]---------------------------------------------------------
function GM:SendMusic( path, data )
    local initialPath = path
    local trackName   = ""
    -- stop current track if it's name can be found in the path
    if self:IsPathATrackStopper( path ) then -- tracks/stopper/NAME
        local trackPart = string.sub( path, 16 )
        self:StopMusicTrackPart( trackPart )
        return

    -- if it's a music track, resolve it to a path and data
    elseif self:IsPathAMusicTrack( path ) then -- tracks/NAME
        local name = string.sub( path, 8 )
        local resolvedPath, trackData, author = self:GetAMusicTrack( name )
        if not resolvedPath then
            if self.musicTracks[name] then
                error( "glee_music: track \"" .. name .. "\" has no sounds for difficulty " .. self:GetCurrWaveDifficulty() )

            end

            local validNames = table.GetKeys( self.musicTracks )
            table.sort( validNames )
            print( "glee_music: valid tracks are..." )
            for _, validName in ipairs( validNames ) do
                print( "    tracks/" .. validName )

            end
            error( "glee_music: invalid track: " .. initialPath )

        end
        local trackOverrides = data and data.trackOverrides
        local trackAdditions = data and data.trackAdditions
        path      = resolvedPath
        trackName = name
        data      = table.Copy( trackData )  -- avoid mutating trackData
        data.author = author

        if trackOverrides then
            for key, value in pairs( trackOverrides ) do
                data[key] = value

            end
        end
        -- after the overrides, so an overridden list can still be added to
        if trackAdditions then
            for key, additions in pairs( trackAdditions ) do
                -- a copy, an overridden list is the caller's table
                local list = table.Copy( data[key] or {} )
                data[key] = list
                for _, addition in ipairs( additions ) do
                    table.insert( list, addition )

                end
            end
        end
    end

    data = data or {}
    broadcastMusic( trackName, path, data )

end


-- our own music sits in a folder named after who made it, hunters_glee/music/VACANT/...
local function authorFromPath( path )
    return string.match( path, "hunters_glee/music/([^/]+)/" )

end

function GM:GetAMusicTrack( name )
    local trackData = self.musicTracks[name]
    if not trackData then return nil, nil end

    self.soundtrackIndices = self.soundtrackIndices or {}

    local currDiff = self:GetCurrWaveDifficulty()
    local sounds   = trackData.sounds
    local path
    local author
    local checked  = 0

    -- Cycle round-robin through the list, skipping entries that don't fit the current difficulty.
    -- The loop limit stops us spinning forever if nothing in the list matches.
    while not path and checked < #sounds do
        checked = checked + 1
        local index = self.soundtrackIndices[name] or 1
        self.soundtrackIndices[name] = ( index % #sounds ) + 1

        local picked = sounds[index]
        if picked.minDifficulty and currDiff < picked.minDifficulty then continue end
        if picked.maxDifficulty and currDiff > picked.maxDifficulty then continue end

        path   = picked.snd
        author = picked.author or authorFromPath( path )

    end

    return path, trackData, author

end


-- Shuffle randomOrder tracks at the start of each round.
-- Only the order is random, GetAMusicTrack still plays them round robin, so each send is a different song.
hook.Add( "huntersglee_round_into_active", "glee_randomize_music_tracks", function()
    if not GAMEMODE.musicTracks then return end
    for _, trackData in pairs( GAMEMODE.musicTracks ) do
        if not trackData.randomOrder then continue end
        if #trackData.sounds <= 1   then continue end
        table.Shuffle( trackData.sounds )

    end
end )

hook.Add( "huntersglee_round_firstsetup", "glee_music_gobble", function()
    GAMEMODE:MusicInitialThink()

end )


function GM:StopAllMusic()
    net.Start( "glee_stopmusic" )
    net.Broadcast()

end

function GM:StopMusicFor( ply )
    net.Start( "glee_stopmusic" )
    net.Send( ply )

end

function GM:StopMusicTrackPart( trackPart )
    net.Start( "glee_stopmusic_trackpart" )
        net.WriteString( trackPart )
    net.Broadcast()

end

function GM:StopMusicTrackPartFor( ply, trackPart )
    net.Start( "glee_stopmusic_trackpart" )
        net.WriteString( trackPart )
    net.Send( ply )

end

function GM:IsPathATrackStopper( path )
    return string.StartsWith( path, "tracks/stopper/" )

end

function GM:IsPathAMusicTrack( path )
    return string.StartsWith( path, "tracks/" )

end