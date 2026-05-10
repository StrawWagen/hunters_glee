
util.AddNetworkString( "glee_sendsolidsound" )
util.AddNetworkString( "glee_stopsolidsounds" )

local DEFAULT_FADE_IN  = 0
local DEFAULT_FADE_OUT = 0.5

function GM:SendSolidSound( path, data )

    local initialPath = path

    if self:IsPathASoundTrack( path ) then
        local trackData
        path, trackData = GAMEMODE:GetASoundTrack( string.sub( path, 8 ) )
        data = table.Copy( trackData )  -- avoid mutating trackData

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
        net.WriteUInt( data.priority, 16 )
    net.Broadcast()

end

function GM:StopAllSolidSounds()
    net.Start( "glee_stopsolidsounds" )
    net.Broadcast()

end

function GM:StopSolidSoundsFor( ply )
    net.Start( "glee_stopsolidsounds" )
    net.Send( ply )

end

local soundTracks = {
    heliEvac = {
        sounds = {
            "hunters_glee/music/VACANT/8.23.GleeExp2.ogg", -- played first evac of a round
            "hunters_glee/music/VACANT/8.24.to_noone.ogg", -- played second evac of a round, then goes back to track no. 1
        },
        randomOrder = true,
        priority = 0,
        fadeInLength = 1,
    },
    roundEarlyStart = {
        sounds = { "hunters_glee/music/VACANT/roundstart2.ogg", },
        priority = 0,
    },
    roundEnd = {
        sounds   = { "hunters_glee/music/VACANT/gleeroundendhoot6simple.ogg" },
        priority = 0,
    },
    roundWin = {
        sounds   = { "hunters_glee/music/VACANT/qutedeath.mp3" },
        priority = 50,
    },
    roundPerfectWin = {
        sounds   = { "hunters_glee/music/VACANT/8.25.ToWishToGlee.ogg" },
        priority = 1000,
    },
    mapvoteMusic = {
        sounds   = { "hunters_glee/music/VACANT/SEWERSiN.mp3" },
        priority = 0,
    }
}

-- shuffle ones with .randomOrder
hook.Add( "huntersglee_round_into_active", "glee_randomizesoundtracks", function()
    for _, trackData in ipairs( soundTracks ) do
        if not trackData.randomOrder then continue end
        table.Shuffle( trackData.sounds )

    end
end )

function GM:GetASoundTrack( name )
    local trackData = soundTracks[name]
    if not trackData then return end

    GAMEMODE.soundtrackIndices = GAMEMODE.soundtrackIndices or {}

    local index = GAMEMODE.soundtrackIndices[name] or 1
    local path  = trackData.sounds[index]

    GAMEMODE.soundtrackIndices[name] = ( index % #trackData.sounds ) + 1

    return path, trackData

end

function GM:IsPathASoundTrack( path )
    return string.StartsWith( path, "tracks/" )

end