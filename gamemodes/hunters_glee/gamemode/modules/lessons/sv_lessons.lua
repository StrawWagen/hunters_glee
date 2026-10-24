
-- The server's mirror of what each client says it has learned. A client set, see sv_clientsets
local lessons = GM:CreateClientSet( "lessons" )

function GM:HasLearnedLesson( ply, lessonName )
    return lessons:Has( ply, lessonName )

end

-- Returns true only the first time, same as the clientside one
function GM:LearnLesson( ply, lessonName )
    return lessons:Add( ply, lessonName )

end

-- clear tutorial for all online players
-- and everyone who spawns in
concommand.Add( "glee_test_tutorial", function( caller )
    if IsValid( caller ) and not caller:IsSuperAdmin() then return end

    hook.Run( "glee_test_tutorial" )

    lessons:ResetFor( player.GetAll() )

    hook.Add( "glee_full_load", "glee_test_tutorial", function( ply )
        timer.Simple( 1, function()
            if not IsValid( ply ) then return end
            lessons:ResetFor( { ply } )

        end )
    end )

end, nil, "Reset the glee tutorial, for everyone" )
