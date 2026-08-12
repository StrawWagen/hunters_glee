
-- Lessons, replaces the pile of cl_huntersgleehint_ convars.
-- The client owns this and the server only mirrors what it's told, so nothing that matters
-- should depend on it.
-- Every save restamps the whole file, so the set only expires once a player has been away
-- for tooOldTime, and then all of it goes at once.

local day = 86400
local week = day * 7
local tooOldTime = week * 2

local defaultDir = GM.DataFileDirectory
local defaultLessonDataName = defaultDir .. "/lessondata.json"

-- keys that live alongside the lessons but aren't lessons, skipped when saving and syncing
local specialLessons = {
    _savedTime = true,
}

function GM:SaveLessonData()
    local lessons = LocalPlayer().glee_LearnedLessons
    lessons._savedTime = os.time()

    if not file.Exists( defaultDir, "DATA" ) then
        file.CreateDir( defaultDir )

    end
    for name, learned in pairs( lessons ) do
        if specialLessons[name] then continue end
        if learned ~= true then ErrorNoHalt( name, "IS NOT TRUE!!!!" ) end

    end
    file.Write( defaultLessonDataName, util.TableToJSON( lessons, true ) )

end

-- Writes at most once every 5 seconds, pass force to write anyway.
-- A throttled save is dropped rather than queued, which is what the ShutDown flush at the
-- bottom of this file exists to catch.
function GM:RequestLessonDataSave( force )
    local ply = LocalPlayer()
    local nextSave = ply.glee_NextLessonSave or 0
    if not force and nextSave > CurTime() then return end

    ply.glee_NextLessonSave = CurTime() + 5

    self:SaveLessonData()

end

function GM:LoadLessonData()
    if not file.Exists( defaultLessonDataName, "DATA" ) then return end

    local existingLessonFile = file.Read( defaultLessonDataName, "DATA" )
    if not existingLessonFile then return end

    local lessons = util.JSONToTable( existingLessonFile )
    if not lessons or not lessons._savedTime then return end

    local sinceLastSaved = os.time() - lessons._savedTime
    if sinceLastSaved > tooOldTime then return end

    return lessons

end

function GM:LazySyncLessons()
    -- repeatedly override the old timer until there's a break in learning
    timer.Create( "glee_lessons_synctimer", 0.01, 1, function()
        local lessons = LocalPlayer().glee_LearnedLessons
        if not lessons then return end

        local toSend = {}
        local count = 0
        for name, _ in pairs( lessons ) do
            if specialLessons[name] then continue end
            count = count + 1
            toSend[count] = name

        end

        -- always the whole set, even when it's empty. the server replaces what it has with
        -- this, so an empty send is how a reset reaches it
        net.Start( "glee_lessons" )
            net.WriteUInt( 1, 4 )

            net.WriteUInt( count, 12 )
            for _, name in ipairs( toSend ) do
                net.WriteString( name )

            end
        net.SendToServer()

    end )
end

function GM:LessonDataInit()
    local lessons
    local savedLessons = self:LoadLessonData()
    if savedLessons then
        lessons = savedLessons
        -- the sync is on a timer, so it reads glee_LearnedLessons after the assignment below
        self:LazySyncLessons()

    else
        lessons = {}

    end

    LocalPlayer().glee_LearnedLessons = lessons

    return lessons

end

-- These two take ( lessonName ) or ( ply, lessonName ), if you've already gotten LocalPlayer.
-- do NOT PASS OTHER PLAYERS, we're on client!!!
-- LearnLesson returns true only the first time, so a hint can show itself and mark itself
-- learned in the one call.
function GM:HasLearnedLesson( plyOrName, lessonName )
    if isstring( plyOrName ) then
        lessonName = plyOrName
        plyOrName = nil

    end
    local ply = plyOrName or LocalPlayer()
    local learned = ply.glee_LearnedLessons
    if not learned then return end

    -- can return for specialLessons, but im fine with that
    return learned[lessonName]

end

function GM:LearnLesson( plyOrName, lessonName )
    if isstring( plyOrName ) then
        lessonName = plyOrName
        plyOrName = nil

    end
    local ply = plyOrName or LocalPlayer()
    local learned = ply.glee_LearnedLessons
    if not learned then
        learned = {}
        ply.glee_LearnedLessons = learned

    end
    if learned[lessonName] then return false end

    learned[lessonName] = true

    self:RequestLessonDataSave()
    self:LazySyncLessons()

    return true

end

-- from the server, 1 is one lesson to learn, 2 is forget everything.
-- note the same modes mean different payloads going the other way, see sv_lessons
net.Receive( "glee_lessons", function()
    local theInt = net.ReadUInt( 4 )
    local isReset = theInt == 2
    local ply = LocalPlayer()
    if isReset then
        if not ply.glee_LearnedLessons then return end
        table.Empty( ply.glee_LearnedLessons )
        GAMEMODE:RequestLessonDataSave( true )
        GAMEMODE:LazySyncLessons()

    else
        -- the server taught this one, so it already knows, no sync back
        local learned = ply.glee_LearnedLessons
        if not learned then
            learned = {}
            ply.glee_LearnedLessons = learned

        end
        local toLearn = net.ReadString()
        if learned[toLearn] then return end
        learned[toLearn] = true

        GAMEMODE:RequestLessonDataSave()

    end
end )



hook.Add( "InitPostEntity", "glee_lessons_init", function()
    terminator_Extras.glee_hasLoadedLessons = true
    GAMEMODE:LessonDataInit()

end )

-- the flag is only ever set inside that hook, so this branch is the autorefresh path,
-- where InitPostEntity has long since fired and won't fire again
if terminator_Extras.glee_hasLoadedLessons then
    local lessons = GAMEMODE:LessonDataInit()
    permaPrint( "GLEE: Lessons Autorefresh, loaded " .. table.Count( lessons ) .. " lessons from " .. defaultLessonDataName )

end

-- a learn made inside the save throttle never reached the disk, so catch it on the way out.
-- outside that window the last learn's save already went through, nothing is pending
-- this is super rare code
hook.Add( "ShutDown", "glee_lessons_flush", function()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local nextSave = ply.glee_NextLessonSave or 0
    if nextSave < CurTime() then return end

    GAMEMODE:RequestLessonDataSave( true )

end )