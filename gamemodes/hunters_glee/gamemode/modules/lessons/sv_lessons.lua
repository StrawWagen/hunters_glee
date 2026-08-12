
-- The server's mirror of what each client says it has learned. Lives on the player for the
-- session only, never saved, and a client could claim anything, so keep it to hints.
-- One netmessage carries both directions, since the pool is finite:
--   to the server, mode 1 is a count then that many lesson names
--   to the client, mode 1 is a single lesson name, mode 2 is forget everything
util.AddNetworkString( "glee_lessons" )

net.Receive( "glee_lessons", function( _, ply )
    -- the client already batches a burst of learns into one send, so this only has to stop
    -- a client sending faster than that
    local nextSync = ply.glee_LessonsNextSync or 0
    if nextSync > CurTime() then return end

    ply.glee_LessonsNextSync = CurTime() + 0.01

    local mode = net.ReadUInt( 4 )
    if mode ~= 1 then return end

    -- the client sends its whole set every time, so this replaces rather than merges.
    -- a lost sync then corrects itself on the next one, and an empty set arrives as a reset
    local learned = {}

    local count = net.ReadUInt( 12 )
    for _ = 1, count do
        learned[net.ReadString()] = true

    end

    ply.glee_LearnedLessons = learned

end )

function GM:HasLearnedLesson( ply, lessonName )
    local learned = ply.glee_LearnedLessons
    if not learned then return end
    return learned[lessonName]

end

-- Returns true only the first time, same as the clientside one.
-- The client stores it too, and its next sync is what keeps this from being overwritten.
function GM:LearnLesson( ply, lessonName )
    local learned = ply.glee_LearnedLessons or {}
    if learned[lessonName] then return false end

    net.Start( "glee_lessons" )
        net.WriteUInt( 1, 4 )
        net.WriteString( lessonName )

    net.Send( ply )

    learned[lessonName] = true
    ply.glee_LearnedLessons = learned

    return true

end

-- clear tutorial for all online players
-- and everyone who spawns in
concommand.Add( "glee_reset_tutorial", function( caller )
    if IsValid( caller ) and not caller:IsSuperAdmin() then return end

    hook.Run( "glee_reset_tutorial" )

    net.Start( "glee_lessons" )
        net.WriteUInt( 2, 4 )

    net.Send( player.GetAll() )

    hook.Add( "glee_full_load", "glee_reset_tutorial", function( ply )
        timer.Simple( 1, function()
            if not IsValid( ply ) then return end
            net.Start( "glee_lessons" )
                net.WriteUInt( 2, 4 )

            net.Send( ply )

        end )
    end )

    for _, ply in player.Iterator() do
        ply.glee_LearnedLessons = nil

    end

end, nil, "Reset the glee tutorial, for everyone" )