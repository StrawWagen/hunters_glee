local GM = GM or GAMEMODE

function GM:MusicInitialThink()
    self.GobbledMusicTracks = nil
    self.musicTracks        = {}
    self.soundtrackIndices  = {}

    local musicFiles = file.Find( "glee_music/*.lua", "LUA" )
    for _, name in ipairs( musicFiles ) do
        local prefix = string.sub( name, 1, 3 )
        if prefix ~= "sv_" then
            ErrorNoHaltWithStack( "GLEE: Invalid music file prefix '" .. prefix .. "' in " .. name .. "\nNeeds to be sv_" )
            continue
        end

        -- CompileFile, not include, so saving a track file doesn't autorefresh the whole gamemode
        ProtectedCall( function( n ) CompileFile( "glee_music/" .. n )() end, name )
    end

    local count = table.Count( self.musicTracks )
    permaPrint( "GLEE: Gobbled " .. count .. " music tracks..." )

    self.GobbledMusicTracks = true
    hook.Run( "glee_post_musicgobble" )

end


-- Skips the whole track rather than erroring, an error here would drop every other track in the file.
local function isTrackValid( name, data )
    local valid = true
    for index, entry in ipairs( data.sounds ) do
        if not isstring( entry.snd ) then
            ErrorNoHaltWithStack( "GLEE: Music track '" .. name .. "' sound #" .. index .. " has no 'snd' path, skipping track" )
            valid = false

        end
    end
    return valid

end

function GM:GobbleMusicTracks( tracks )
    for name, data in pairs( tracks ) do
        if not isTrackValid( name, data ) then continue end
        self.musicTracks[name] = data

    end

    -- Alert, should only happen if something misuses the gobbler or if files are being re-run for dev testing.
    if self.GobbledMusicTracks then
        permaPrint( "GLEE: !!!!!!!!!! Gobbled music tracks late, you must run gmod_admin_cleanup to apply the changes !!!!!!!!!!!" )

    end
end