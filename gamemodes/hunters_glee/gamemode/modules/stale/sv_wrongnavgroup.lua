
-- Removes hunters stuck on a piece of navmesh no player is on, they can never reach anyone

--- some coroutine stuff
local getGroupsInPlayCheck = 0
local groupsInPlay = {}
local correctGroupsCor = nil

local function huntersAreInCorrectGroupsFunc()
    if getGroupsInPlayCheck < CurTime() then
        getGroupsInPlayCheck = CurTime() + 15
        table.Empty( groupsInPlay )
        groupsInPlay = GAMEMODE:GetNavmeshGroupsWithPlayers( true )

    end

    if #groupsInPlay <= 0 then coroutine.yield( "done" ) return end

    local hunters = {}
    for _, hunter in ipairs( GAMEMODE.glee_Hunters ) do
        if IsValid( hunter ) and hunter:Health() > 0 then
            table.insert( hunters, hunter )

        end
    end

    local huntersNotInPlay = {}
    for _, hunter in ipairs( hunters ) do
        coroutine.yield()
        if not IsValid( hunter ) then continue end
        local huntersNav = hunter.TerminatorNextBot and hunter:GetTrueCurrentNavArea() or GAMEMODE:getNearestNav( hunter:GetPos(), 1000 )

        if not GAMEMODE:GetGroupThatNavareaExistsIn( huntersNav, groupsInPlay, true ) then
            table.insert( huntersNotInPlay, hunter )

        end
    end

    for _, hunterNotInPlay in ipairs( huntersNotInPlay ) do
        local incorrectGroupCount = hunterNotInPlay.glee_IncorrectGroupCount or 0
        if not IsValid( hunterNotInPlay ) then continue end

        -- flyers are nowhere near the navmesh, so they're never in play
        local battling = GAMEMODE:IsHunterBattling( hunterNotInPlay )
        local pathing = hunterNotInPlay.TerminatorNextBot and hunterNotInPlay:GetPath() and hunterNotInPlay:GetPath():GetLength() > 500
        if battling or pathing then
            hunterNotInPlay.glee_IncorrectGroupCount = nil

        elseif incorrectGroupCount > 50 then
            SafeRemoveEntity( hunterNotInPlay )

        else
            hunterNotInPlay.glee_IncorrectGroupCount = incorrectGroupCount + 1
            --debugoverlay.Cross( hunterNotInPlay:GetPos(), 100, 10, color_white, true )

        end
    end

    coroutine.yield( "done" )

end

-- silly localization
local SysTime = SysTime
local math_abs = math.abs
local coroutine_status = coroutine.status
local coroutine_resume = coroutine.resume
local nextGroupCheckStart = 0

hook.Add( "glee_sv_validgmthink_active", "glee_checkhunters_areinvalidgroups", function()
    if not correctGroupsCor then
        if nextGroupCheckStart < CurTime() then
            correctGroupsCor = coroutine.create( huntersAreInCorrectGroupsFunc )
            nextGroupCheckStart = CurTime() + 5

        end

    elseif coroutine_status( correctGroupsCor ) ~= "dead" then
        local oldTime = SysTime()
        local noErrors, result = nil
        while math_abs( oldTime - SysTime() ) < 0.0002 and not result and coroutine_status( correctGroupsCor ) ~= "dead" do
            noErrors, result = coroutine_resume( correctGroupsCor )
            if noErrors == false then ErrorNoHaltWithStack( result ) break end

        end
        if result == "done" then
            correctGroupsCor = nil

        end
    else
        correctGroupsCor = nil

    end
end )
