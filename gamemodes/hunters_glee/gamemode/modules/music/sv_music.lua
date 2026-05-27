
util.AddNetworkString( "glee_playmusic" )
util.AddNetworkString( "glee_stopmusic" )
util.AddNetworkString( "glee_stopmusic_track" )

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

function GM:SendMusic( path, data )
    local initialPath = path
    local trackName   = ""

    if self:IsPathAMusicTrack( path ) then
        local name = string.sub( path, 8 )
        local resolvedPath, trackData = self:GetAMusicTrack( name )
        if not resolvedPath then error( "glee_music: invalid track: " .. initialPath ) end
        path      = resolvedPath
        trackName = name
        data      = table.Copy( trackData )  -- avoid mutating trackData

    end

    data = data or {}
    broadcastMusic( trackName, path, data )

end


function GM:GetAMusicTrack( name )
    local trackData = self.musicTracks[name]
    if not trackData then return nil, nil end

    self.soundtrackIndices = self.soundtrackIndices or {}

    local currDiff = self:GetCurrWaveDifficulty()
    local sounds   = trackData.sounds
    local path
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

        path = picked.snd

    end

    return path, trackData

end


-- Shuffle randomOrder tracks at the start of each round.
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

function GM:StopMusicTrack( trackName )
    net.Start( "glee_stopmusic_track" )
        net.WriteString( trackName )
    net.Broadcast()

end

function GM:StopMusicTrackFor( ply, trackName )
    net.Start( "glee_stopmusic_track" )
        net.WriteString( trackName )
    net.Send( ply )

end

function GM:IsPathAMusicTrack( path )
    return string.StartsWith( path, "tracks/" )

end