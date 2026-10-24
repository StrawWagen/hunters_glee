
-- Lessons, replaces the pile of cl_huntersgleehint_ convars. A client set, see cl_clientsets

local day = 86400
local week = day * 7
local tooOldTime = week * 4

local lessons = GM:CreateClientSet( "lessons", { fileName = "lessondata.json", expireAfter = tooOldTime } )

-- These two take ( lessonName ) or ( ply, lessonName ), if you've already gotten LocalPlayer.
-- do NOT PASS OTHER PLAYERS, we're on client!!!
-- LearnLesson returns true only the first time, so a hint can show itself and mark itself
-- learned in the one call.
function GM:HasLearnedLesson( plyOrName, lessonName )
    if isstring( plyOrName ) then
        lessonName = plyOrName

    end
    return lessons:Has( lessonName )

end

function GM:LearnLesson( plyOrName, lessonName )
    if isstring( plyOrName ) then
        lessonName = plyOrName

    end
    return lessons:Add( lessonName )

end

concommand.Add( "glee_test_printlearnedlessons", function()
    if not lessons.keys then
        permaPrint( "GLEE: lessons haven't loaded yet" )
        return

    end
    PrintTable( lessons.keys )

end )
