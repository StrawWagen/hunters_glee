
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
            { -- played first evac of a round
                maxDifficulty = 75,
                snd = "hunters_glee/music/VACANT/8.23.GleeExp2.ogg",
            },
            { -- played second evac of a round
                maxDifficulty = 75,
                snd = "hunters_glee/music/VACANT/__more_glee.ogg",
            },
            { -- played if difficulty is above 75, so if evac is late or difficulty is being bumped
                minDifficulty = 75,
                maxDifficulty = 150,
                snd = "hunters_glee/music/VACANT/8.23.GleeExp3.ogg",
            },
            { -- ditto
                minDifficulty = 75,
                snd = "hunters_glee/music/VACANT/HARD_EAS_gori_scuffle.ogg",
            },
            {
                minDifficulty = 150,
                snd = "hunters_glee/music/VACANT/8.24.to_noone.ogg",
            },
            {
                minDifficulty = 150,
                snd = "hunters_glee/music/VACANT/8.22.theGLEE.ogg",
            },
            {
                minDifficulty = 200,
                snd = "hunters_glee/music/COMPAKT/COMPAKT_Operating_Systems_09_Operator.mp3",
            },
        },
        priority = 0,
        fadeInLength = 1,
    },
    highIntensity = {
        sounds = {
            {
                maxDifficulty = 100,
                snd = "hunters_glee/music/VACANT/clocklore.mp3",
            },
            {
                minDifficulty = 50,
                maxDifficulty = 200,
                snd = "hunters_glee/music/VACANT/8.23.GleeExp3.ogg",
            },
            {
                minDifficulty = 100,
                snd = "hunters_glee/music/COMPAKT/COMPAKT_Operating_Systems_05_Busy-Noisy.mp3",
            },
            {
                minDifficulty = 100,
                snd = "hunters_glee/music/VACANT/8.22.theGLEE.ogg",
            },
        },
        priority = 0,
    },
    grigoriArrival = {
        sounds = {
            {
                snd = "hunters_glee/music/VACANT/gorihaunt2.ogg",
            },
        },
        priority = 0,
    },
    roundEarlyStart = {
        sounds = {
            {
                snd = "hunters_glee/music/VACANT/wmrs.ogg",
            },
            {
                minDifficulty = 50,
                snd = "hunters_glee/music/VACANT/wmrs-crowbar.ogg",
            },
            {
                minDifficulty = 100,
                snd = "hunters_glee/music/VACANT/roundstart2.ogg",
            },
        },
        priority = 0,
    },
    roundEnd = {
        sounds   = {
            {
                snd = "hunters_glee/music/VACANT/gleeroundendhoot6simple.ogg",
            }
        },
        priority = 0,
    },
    roundWin = {
        sounds   = {
            {
                snd = "hunters_glee/music/VACANT/qutedeath-re.ogg",
            }
        },
        priority = 50,
    },
    roundPerfectWin = {
        sounds = {
            {
                maxDifficulty = 150,
                snd = "hunters_glee/music/VACANT/8.25.GleeFree-Early.ogg",
            },
            {
                minDifficulty = 100,
                snd = "hunters_glee/music/VACANT/ROOT_ESTRANGE.ogg",
            }
        },
        priority = 1000,
    },
    mapvoteMusic = {
        sounds   = {
            {
                maxDifficulty = 75,
                snd = "hunters_glee/music/VACANT/wkc-rtv.ogg",
            },
            {
                minDifficulty = 75,
                maxDifficulty = 100,
                snd = "hunters_glee/music/VACANT/loop1-rtv.ogg",
            },
            {
                minDifficulty = 75,
                snd = "hunters_glee/music/VACANT/SEWERSiN.mp3",
            },
        },
        priority = 5000,
        randomOrder = true,
    },
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

    local currDiff = self:GetCurrWaveDifficulty()

    local sounds = trackData.sounds

    local path
    local count = 0

    -- Cycle round-robin through the track list so the same song never plays twice in a row,
    -- but skip entries that don't fit the current difficulty.
    -- The loop limit stops us spinning forever if nothing in the list matches.
    while not path and count < #sounds do
        count = count + 1
        local index = GAMEMODE.soundtrackIndices[name] or 1
        GAMEMODE.soundtrackIndices[name] = ( index % #sounds ) + 1

        local picked = sounds[index]

        local minDiff = picked.minDifficulty
        if minDiff and currDiff < minDiff then continue end

        local maxDiff = picked.maxDifficulty
        if maxDiff and currDiff > maxDiff then continue end

        path = picked.snd
        break

    end

    return path, trackData

end

function GM:IsPathASoundTrack( path )
    return string.StartsWith( path, "tracks/" )

end