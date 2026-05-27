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

        ProtectedCall( function( n ) include( "glee_music/" .. n ) end, name )
    end

    local count = table.Count( self.musicTracks )
    print( "GLEE: Gobbled " .. count .. " music tracks..." )

    self.GobbledMusicTracks = true
    hook.Run( "glee_post_musicgobble" )

end


function GM:GobbleMusicTracks( tracks )
    for name, data in pairs( tracks ) do
        self.musicTracks[name] = data

    end

    -- Alert, should only happen if something misuses the gobbler or if files are being re-run for dev testing.
    if self.GobbledMusicTracks then
        print( "GLEE: !!!!!!!!!! Gobbled music tracks late, you must run gmod_admin_cleanup to apply the changes !!!!!!!!!!!" )

    end
end