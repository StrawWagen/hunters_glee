
util.AddNetworkString( "glee_sendsolidsound" )
util.AddNetworkString( "glee_stopsolidsounds" )

local DEFAULT_FADE_IN  = 0
local DEFAULT_FADE_OUT = 0.5

function GM:SendSolidSound( path, data )
    data = data or {}
    data.pitch         = data.pitch or 100
    data.vol           = data.vol or 1
    data.dsp           = data.dsp or 0
    data.fadeInLength  = data.fadeInLength or DEFAULT_FADE_IN
    data.fadeOutLength = data.fadeOutLength or DEFAULT_FADE_OUT
    net.Start( "glee_sendsolidsound" )
        net.WriteString( path )
        net.WriteFloat( data.pitch )
        net.WriteFloat( data.vol )
        net.WriteFloat( data.dsp )
        net.WriteFloat( data.fadeInLength )
        net.WriteFloat( data.fadeOutLength )
    net.Broadcast()

end

function GM:StopAllSolidSounds()
    net.Start( "glee_stopsolidsounds" )
    net.Broadcast()

end

local soundTracks = {
    heliEvac = {
        "hunters_glee/music/8.23.GleeExp2.ogg",
        "hunters_glee/music/8.24.to_noone.ogg",

    }
}

function GM:GetASoundTrack( name )
    local roundsTracks = GAMEMODE.soundtracksSequential
    if not roundsTracks then
        GAMEMODE.soundtracksSequential = {}
        roundsTracks = GAMEMODE.soundtracksSequential

    end

    local tracksToPlay = roundsTracks[name]
    if not tracksToPlay or #tracksToPlay == 0 then
        local allTracks = soundTracks[name]
        if not allTracks then return end

        tracksToPlay = table.Copy( allTracks )
        roundsTracks[name] = tracksToPlay

    end

    local track = table.remove( tracksToPlay, 1 )

    return track

end