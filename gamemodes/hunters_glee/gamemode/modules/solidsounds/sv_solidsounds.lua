
util.AddNetworkString( "glee_sendsolidsound" )
util.AddNetworkString( "glee_stopsolidsounds" )

local DEFAULT_FADE_IN  = 0
local DEFAULT_FADE_OUT = 0.5

function GM:SendSolidSound( path, data )

    local initialPath = path

    if string.StartsWith( path, "tracks/" ) then
        local trackData
        path, trackData = GAMEMODE:GetASoundTrack( string.sub( path, 8 ) )
        data = data or trackData
    end

    if not path then error( "invalid track: " .. initialPath ) end

    data = data or {}
    data.pitch         = data.pitch or 100
    data.vol           = data.vol or 1
    data.fadeInLength  = data.fadeInLength or DEFAULT_FADE_IN
    data.fadeOutLength = data.fadeOutLength or DEFAULT_FADE_OUT
    data.priority      = data.priority or 0
    net.Start( "glee_sendsolidsound" )
        net.WriteString( path )
        net.WriteFloat( data.pitch )
        net.WriteFloat( data.vol )
        net.WriteFloat( data.fadeInLength )
        net.WriteFloat( data.fadeOutLength )
        net.WriteInt( data.priority, 16 )
    net.Broadcast()

end

function GM:StopAllSolidSounds()
    net.Start( "glee_stopsolidsounds" )
    net.Broadcast()

end

local soundTracks = {
    heliEvac = {
        sounds = {
            "hunters_glee/music/8.23.GleeExp2.ogg",
            "hunters_glee/music/8.24.to_noone.ogg",
        },
        priority = 0,
    },
    roundEnd = {
        sounds   = { "hunters_glee/music/gleeroundendhoot6simple.ogg" },
        priority = 0,
    },
    roundWin = {
        sounds   = { "hunters_glee/music/qutedeath.mp3" },
        priority = 0,
    },
    roundPerfectWin = {
        sounds   = { "hunters_glee/music/8.25.ToWishToGlee.ogg" },
        priority = 0,
    }
}

function GM:GetASoundTrack( name )
    local trackDef = soundTracks[name]
    if not trackDef then return end

    GAMEMODE.soundtrackIndices = GAMEMODE.soundtrackIndices or {}

    local index = GAMEMODE.soundtrackIndices[name] or 1
    local path  = trackDef.sounds[index]

    GAMEMODE.soundtrackIndices[name] = ( index % #trackDef.sounds ) + 1

    return path, { priority = trackDef.priority or 0 }

end