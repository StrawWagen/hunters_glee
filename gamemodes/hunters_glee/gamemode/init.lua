AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "modules/cl_targetid.lua" )
AddCSLuaFile( "modules/cl_scoreboard.lua" )
AddCSLuaFile( "modules/cl_obfuscation.lua" )
AddCSLuaFile( "modules/cl_killfeedoverride.lua" )

AddCSLuaFile( "modules/battery/cl_battery.lua" )
AddCSLuaFile( "modules/cl_spectateflashlight.lua" )

AddCSLuaFile( "shoppinggui.lua" )
AddCSLuaFile( "sh_shopshared.lua" )
AddCSLuaFile( "sh_shopitems.lua" )

AddCSLuaFile( "modules/sh_panic.lua" )
AddCSLuaFile( "modules/sh_banking.lua" )
AddCSLuaFile( "modules/sh_tempbools.lua" )
AddCSLuaFile( "modules/sh_danceslowdown.lua" )
AddCSLuaFile( "modules/sh_playerdrowning.lua" )
AddCSLuaFile( "modules/battery/sh_battery.lua" )
AddCSLuaFile( "modules/sh_detecthunterkills.lua" )

include( "lib/sv_termfuncs.lua" )
include( "autorun/server/sv_wallkick.lua" )
include( "shared.lua" )
include( "sv_player.lua" )
include( "sv_playercommunication.lua" )
include( "modules/sv_speedhandler.lua" )
include( "modules/sv_navpatcher.lua" )
include( "modules/sv_doorbash.lua" )
include( "modules/sv_mapvote.lua" )
include( "modules/sv_zcratespawner.lua" )
include( "modules/sv_zproceduralspawner.lua" )
include( "modules/sv_weapondropper.lua" )
include( "modules/sv_seeding_rewarder.lua" )
include( "modules/sv_skullmanager.lua" )
include( "modules/sv_zbeartrapspawner.lua" )
include( "modules/sv_hunterspawner.lua" )
include( "modules/battery/sv_battery.lua" )

util.AddNetworkString( "glee_witnesseddeathconfirm" )
util.AddNetworkString( "glee_resetplayershopcooldowns" )
util.AddNetworkString( "glee_sendshopcooldowntoplayer" )
util.AddNetworkString( "glee_invalidateshopcooldown" )
util.AddNetworkString( "glee_confirmpurchase" )
util.AddNetworkString( "glee_followedsomething" )
util.AddNetworkString( "glee_followednexthing" )
util.AddNetworkString( "glee_switchedspectatemodes" )
util.AddNetworkString( "glee_stoppedspectating" )
util.AddNetworkString( "glee_closetheshop" )

resource.AddFile( "materials/vgui/hud/glee_skullpickup.vmt" )

resource.AddSingleFile( "sound/53937_meutecee_trumpethit07.wav" )
resource.AddSingleFile( "sound/418788_name_heartbeat_single.wav" )
resource.AddSingleFile( "sound/209578_zott820_cash-register-purchase.wav" )
resource.AddSingleFile( "sound/482735__copyc4t__cartoon-long-throw.wav" )

resource.AddWorkshop( "2848253104" )
resource.AddWorkshop( "2944078031" )

GM.SpawnTypes = {
    "info_player_deathmatch",
    "info_player_combine",
    "info_player_rebel",
    "info_player_counterterrorist",
    "info_player_terrorist",
    "info_player_axis",
    "info_player_allies",
    "gmod_player_start",
    "info_player_start",
    "info_player_teamspawn",
    "info_player_human",
    "info_player_undead",
    "info_player_zombie",
}

-- do greedy patch once per session
GM.HuntersGleeDoneTheGreedyPatch = GM.HuntersGleeDoneTheGreedyPatch or nil

GM.IsReallyHuntersGlee = true

GM.termHunt_roundStartTime = math.huge
GM.termHunt_roundBegunTime = math.huge
GM.termHunt_navmeshCheckTime = math.huge
GM.termHunt_NextThink = math.huge
validNavarea = validNavarea or NULL

GM.doNotUseMapSpawns    = nil
GM.hasNavmesh           = nil
GM.blockpvp             = nil
GM.canRespawn           = nil
GM.canScore             = nil
GM.doProxChat           = nil
GM.termHunt_hunters     = {}
GM.deadPlayers          = {}
GM.roundScore           = {}
GM.roundExtraData       = {}

GM.roundStartAfterNavCheck  = 40
GM.roundStartNormal         = 40

GM.nextStateTransmit = 0
GM.startedNavmeshGeneration = nil

local _CurTime = CurTime

function GM:RoundStateRepeat() -- "fixes" problems with state syncing
    if GAMEMODE.nextStateTransmit > _CurTime() then return end
    GAMEMODE:SetRoundState( GAMEMODE:RoundState() )
    GAMEMODE.nextStateTransmit = _CurTime() + 1

end

function GM:SetRoundState( state )
    SetGlobal2Int( "termhunt_roundstate", state )
    GAMEMODE.nextStateTransmit = _CurTime() + 1

end

-- gamemode brains

function GM:Think()
    local cur = _CurTime()
    GAMEMODE:managePlayerSpectating()
    GAMEMODE:manageServersideCountOfBeats()

    if GAMEMODE.termHunt_NextThink > cur then return end
    GAMEMODE.termHunt_NextThink = cur + 0.1

    local currState = GAMEMODE:RoundState()

    local players = player.GetAll()
    if GAMEMODE:handleEmptyServer( currState, players ) == true then return end

    if GAMEMODE:handleGenerating( currState ) == true then return end

    -- see sv_player
    -- see sv_navpatcher
    -- see sv_playerdrowning
    -- see player_termrunner
    -- see sv_zproceduralspawner
    -- see battery/sv_battery
    -- see sv_darknessfear
    hook.Run( "glee_sv_validgmthink", players, currState, cur )

    local displayTime = nil
    local displayName = nil
    if currState == GAMEMODE.INVALID then
        if not GAMEMODE.invalidStart then
            GAMEMODE.invalidStart = cur

        end

        if #players <= 1 and not game.IsDedicated() then
            huntersGlee_Announce( player.GetAll(), 1000, 1, "NO NAVMESH!\nInstall or generate yourself a navmesh!" )

        end

        displayName = "You have spent this long without a navmesh... "
        displayTime = GAMEMODE:getRemaining( cur, GAMEMODE.invalidStart )
    end
    if currState == GAMEMODE.ROUND_SETUP then -- wait like 5 seconds before the game session starts
        if GAMEMODE.termHunt_navmeshCheckTime < cur then
            GAMEMODE:setupFinish()

        else
            displayName = "--- "
            displayTime = 0
            GAMEMODE.blockpvp   = true
            GAMEMODE.doProxChat = false
            GAMEMODE.canRespawn = true
            GAMEMODE.canScore   = false

        end
    end
    if currState == GAMEMODE.ROUND_INACTIVE then --round is waiting to begin
        if GAMEMODE.termHunt_roundStartTime < cur and GAMEMODE.HuntersGleeDoneTheGreedyPatch then
            GAMEMODE:roundStart() --
            GAMEMODE.isBadSingleplayer = nil --display that message once!

        else
            if GAMEMODE.isBadSingleplayer then
                huntersGlee_Announce( players, 1000, 1, "This gamemode is at it's best when started with at least 2 player slots.\nThat doesn't mean you need 2 people!\nJust click the green \"Single Player\" and choose another option!" )

            end
            GAMEMODE.blockpvp   = true
            GAMEMODE.doProxChat = false
            GAMEMODE.canRespawn = true
            GAMEMODE.canScore   = false

            hook.Run( "glee_sv_validgmthink_inactive", players, currState, cur )

        end
        displayName = "Getting ready "
        displayTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundStartTime, cur )

    end
    if currState == GAMEMODE.ROUND_LIMBO then --look at what happened during the round
        if GAMEMODE.limboEnd < cur then
            GAMEMODE:beginSetup()

        else
            GAMEMODE.blockpvp   = true
            GAMEMODE.doProxChat = false
            GAMEMODE.canRespawn = false
            GAMEMODE.canScore   = false

        end
        displayName = "--- "
        displayTime = 0

    end
    if currState == GAMEMODE.ROUND_ACTIVE then -- THE HUNT BEGINS
        local aliveCount = GAMEMODE:CountWinnablePlayers()

        nobodyAlive = aliveCount == 0

        if nobodyAlive then
            GAMEMODE:roundEnd()

        else
            GAMEMODE.blockpvp   = false
            GAMEMODE.doProxChat = true
            GAMEMODE.canRespawn = false
            GAMEMODE.canScore   = true

            hook.Run( "glee_sv_validgmthink_active", players, currState, cur )

        end
        displayName = "Hunting... "
        displayTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )

    end

    local newState = GAMEMODE:RoundState()
    if newState ~= currState then
        hook.Run( "glee_roundstatechanged", currState, newState )

    end

    GAMEMODE:calculateBPM( cur, players )
    GAMEMODE:RoundStateRepeat()

    if displayTime then
        SetGlobalInt( "TERMHUNTER_PLAYERTIMEVALUE", displayTime )

    end
    -- this often desyncs, not really a big problem tho
    if displayName then
        SetGlobalString( "TERMHUNTER_PLAYERVALUENAME", displayName )

    end
end

function GM:alivePlayersOrAll( plys )
    local plyFinal = {}
    if GAMEMODE:countAlive( plys ) > 0 then
        for _, ply in pairs( plys ) do
            if ply:Health() > 0 then
                table.insert( plyFinal, ply )

            end
        end
    else
        plyFinal = plys

    end
    return plyFinalroundScore

end

function GM:plysRoundScore( ply )
    return GAMEMODE.roundScore[ply:GetCreationID()] or 0

end

function GM:calculateTotalScore()
    local plyFinal = player.GetAll()
    local totalScore = 0
    for _, ply in ipairs( plyFinal ) do
        local theirScore = GAMEMODE:plysRoundScore( ply )
        totalScore = totalScore + theirScore

    end
    return totalScore

end

function GM:calculateWinner()
    local players = player.GetAll()

    local playersWithSkullCounts = {}

    for _, ply in ipairs( players ) do
        local skulls = ply:GetSkulls()
        local plysAtCount = playersWithSkullCounts[skulls] or {}

        table.insert( plysAtCount, ply )

        playersWithSkullCounts[skulls] = plysAtCount

    end

    local biggestCount = table.maxn( playersWithSkullCounts )
    local bestPlayers = playersWithSkullCounts[ biggestCount ]
    local bestPlayer
    local tieBroken = false
    -- break ties with score count
    if #bestPlayers > 1 then
        local bestScore = -math.huge
        tieBroken = true
        for _, ply in ipairs( bestPlayers ) do
            local currPlysScore = ply:GetScore()
            if currPlysScore > bestScore then
                bestPlayer = ply
                bestScore = currPlysScore

            end
        end
    else
        bestPlayer = bestPlayers[1]

    end

    local winner = bestPlayer
    return winner, tieBroken

end

-- get navarea nearby a spawnpoint
function GM:navmeshCheck()
    local out = NULL
    for _, spawnClass in ipairs( GAMEMODE.SpawnTypes ) do
        spawns = ents.FindByClass( spawnClass )
        for _, spawnEnt in ipairs( spawns ) do
            local result = GAMEMODE:getNearestPosOnNav( spawnEnt:GetPos() )
            if result.area and result.area:IsValid() then
                out = result.area
                break

            end
        end
        if out ~= NULL then
            break

        end
    end

    if out == NULL then
        local result = GAMEMODE:getNearestPosOnNav( vector_origin, 20000 )
        if result.area and result.area:IsValid() then
            out = result.area

        end
    end

    return out

end

function GM:initDependenciesCheck()
    validNavarea = GAMEMODE:navmeshCheck()

    SetGlobalBool( "termHuntDisplayWinners", false )
    GAMEMODE.hasNavmesh = validNavarea:IsValid() and navmesh.IsLoaded()
    return GAMEMODE.hasNavmesh

end

--- some coroutine stuff
local getGroupsInPlayCheck = 0
local groupsInPlay = {}
local correctGroupsCor = nil

local function huntersAreInCorrectGroupsFunc()
    if getGroupsInPlayCheck < _CurTime() then
        getGroupsInPlayCheck = _CurTime() + 15
        table.Empty( groupsInPlay )
        groupsInPlay = GAMEMODE:GetNavmeshGroupsWithPlayers()

    end

    if #groupsInPlay <= 0 then coroutine.yield( "done" ) return end

    local hunters = {}
    for _, hunter in ipairs( GAMEMODE.termHunt_hunters ) do
        if IsValid( hunter ) and hunter:Health() > 0 then
            table.insert( hunters, hunter )

        end
    end

    local huntersNotInPlay = {}
    for _, hunter in ipairs( hunters ) do
        coroutine.yield()
        if not IsValid( hunter ) then continue end
        local huntersNav = hunter:GetTrueCurrentNavArea() or hunter:GetCurrentNavArea()

        if not GAMEMODE:GetGroupThatNavareaExistsIn( huntersNav, groupsInPlay ) then
            table.insert( huntersNotInPlay, hunter )

        end
    end

    for _, hunterNotInPlay in ipairs( huntersNotInPlay ) do
        local incorrectGroupCount = hunterNotInPlay.glee_IncorrectGroupCount or 0
        if not IsValid( hunterNotInPlay ) then continue end

        local battling = hunterNotInPlay.GetEnemy and IsValid( hunterNotInPlay:GetEnemy() )
        local pathing = hunterNotInPlay:GetPath() and hunterNotInPlay:GetPath():GetLength() > 500
        if battling or pathing then
            hunterNotInPlay.glee_IncorrectGroupCount = nil

        elseif incorrectGroupCount > 100 then
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
local abs_Local = math.abs
local coroutine_status = coroutine.status
local coroutine_resume = coroutine.resume

hook.Add( "glee_sv_validgmthink_active", "glee_checkhunters_areinvalidgroups", function()
    if not correctGroupsCor then
        correctGroupsCor = coroutine.create( huntersAreInCorrectGroupsFunc )

    elseif coroutine_status( correctGroupsCor ) ~= "dead" then
        local oldTime = SysTime()
        local noErrors, result = nil
        while abs_Local( oldTime - SysTime() ) < 0.0002 and not result and coroutine_status( correctGroupsCor ) ~= "dead" do
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

-- remove this if file was saved
hook.Remove( "Think", "doGreedyPatchThinkHook" )

-- do the navmesh patching
-- involves adding areas under doors, windows, and then finding sections of navmesh that are separate from the biggest section, then linking them back up to it.
function GM:SetupTheLargestGroupsNStuff()

    -- navmesh groups need to be at least 40% the size of the largest one to be considered "playable"
    self.biggestGroupsRatio = 0.4
    self.GreedyPatchCouroutine = nil

    hook.Add( "Think", "doGreedyPatchThinkHook", function()
        local patchResult = nil
        if not self.HuntersGleeDoneTheGreedyPatch and not game.SinglePlayer() then

            if not self.GreedyPatchCouroutine then
                self:speakAsHuntersGlee( "Beginning greedy navpatcher process..." )

            end

            self.GreedyPatchCouroutine = self.GreedyPatchCouroutine or coroutine.create( self.DoGreedyPatch )

            local oldTime = SysTime()
            while abs_Local( oldTime - SysTime() ) < 0.01 and self.GreedyPatchCouroutine and coroutine_status( self.GreedyPatchCouroutine ) ~= "dead" do
                patchResult, curError = coroutine_resume( self.GreedyPatchCouroutine, self )

                if curError and curError ~= "done" then ErrorNoHaltWithStack( curError ) break end

            end
        end

        -- if patch result does not equal nil, then wait
        if ( self.GreedyPatchCouroutine and patchResult ~= nil ) then return end

        self.navmeshGroups = self:GetConnectedNavAreaGroups( navmesh.GetAllNavAreas() )
        self.biggestNavmeshGroups = self:FilterNavareaGroupsForGreaterThanPercent( self.navmeshGroups, self.biggestGroupsRatio )

        self:removePorters() -- remove teleporters that cross navmesh groups, or lead to non-navmeshed spots

        -- fix maps with separate spawn rooms w/ teleporters
        self:TeleportRoomCheck()

        hook.Remove( "Think", "doGreedyPatchThinkHook" )

    end )
end

function GM:removePorters() -- it was either do this, or make the terminator use teleporters, this is easier. 
    local teleporters = ents.FindByClass( "trigger_teleport" )
    for _, porter in ipairs( teleporters ) do

        -- do a bunch of checks to see if porter just teleports between the same, big navmesh group.
        local portersPos = porter:WorldSpaceCenter()
        local portersArea = GAMEMODE:getNearestNav( portersPos, 1000 )
        if not portersArea or not portersArea.IsValid or not portersArea:IsValid() then SafeRemoveEntity( porter ) continue end

        local portersPosFloored = GAMEMODE:getFloor( portersPos )
        if not portersArea:IsVisible( portersPosFloored ) then SafeRemoveEntity( porter ) continue end

        local portersGroup = GAMEMODE:GetGroupThatNavareaExistsIn( portersArea, GAMEMODE.biggestNavmeshGroups )
        if not portersGroup then SafeRemoveEntity( porter ) continue end

        local portersVals = porter:GetKeyValues()
        local targetsName = portersVals[ "target" ]
        local destTbl = ents.FindByName( targetsName )

        for _, dest in ipairs( destTbl ) do
            if not IsValid( dest ) then SafeRemoveEntity( porter ) break end
            local destPos = dest:WorldSpaceCenter()
            local area = GAMEMODE:getNearestNav( destPos, 1000 )
            if not area or not area.IsValid or not area:IsValid() then SafeRemoveEntity( porter ) break end

            local destPosFloored = GAMEMODE:getFloor( destPos )
            if not area:IsVisible( destPosFloored ) then SafeRemoveEntity( porter ) break end

            local exitsGroup = GAMEMODE:GetGroupThatNavareaExistsIn( area, GAMEMODE.biggestNavmeshGroups )
            if not exitsGroup then SafeRemoveEntity( porter ) break end

            if exitsGroup ~= portersGroup then SafeRemoveEntity( porter ) break end

        end
    end
end

function GM:removeBlockers() -- mess up locked doors on door heavy maps
    local doors = ents.FindByClass( "prop_door_rotating" )
    for _, door in ipairs( doors ) do
        door:SetKeyValue( "returndelay", "-1" )

    end
    if #doors > 30 then
        for _, door in ipairs( doors ) do
            if door:GetInternalVariable( "m_bLocked" ) ~= true then continue end
            if not util.doorIsUsable( door ) then continue end -- door is decor

            local areaIsBig = nil
            local area = GAMEMODE:getNearestNavFloor( door:WorldSpaceCenter() )

            if area and area:IsValid() then
                -- door is creating blocked flag, unlock it!
                local maxSize = math.max( area:GetSizeX(), area:GetSizeY() )
                areaIsBig = maxSize > 26

            end

            if not areaIsBig then continue end

            door:Fire( "Unlock" )

        end
    end
end

-- nukes all the hunters if there's nobody to hunt
function GM:handleEmptyServer( currState, players )
    if #players == 0 and currState == GAMEMODE.ROUND_ACTIVE then
        -- bots are expensive, save cpu power pls
        print( "Empty server!\nRemoving bots..." )
        GAMEMODE:roundEnd()
        return true

    elseif #players == 0 then -- empty
        hook.Run( "huntersglee_emptyserver" )
        return true

    end
    return nil

end

-- nukes all the hunters if navmesh is generating
local navmesh_IsGenerating = navmesh.IsGenerating
local navmeshMightBeGeneratingUntil = nil

function GM:handleGenerating( currState )
    local generating = navmesh_IsGenerating()

    -- give the generator a bit of leeway
    if not generating and navmeshMightBeGeneratingUntil and navmeshMightBeGeneratingUntil > _CurTime() then
        return true

    elseif generating and currState == GAMEMODE.ROUND_ACTIVE then
        print( "Generating navmesh!\nRemoving bots..." )
        GAMEMODE:roundEnd()
        GAMEMODE.biggestNavmeshGroups = nil
        return true

    elseif generating then
        navmeshMightBeGeneratingUntil = _CurTime() + 15
        return true

    end
    if navmeshMightBeGeneratingUntil then
        navmeshMightBeGeneratingUntil = nil
        GAMEMODE.HuntersGleeDoneTheGreedyPatch = nil
        RunConsoleCommand( "gmod_admin_cleanup" )

    end
    return nil

end

-- from where people can buy stuff with discounts, to the hunt
function GM:roundStart()
    GAMEMODE.termHunt_roundStartTime = math.huge
    GAMEMODE.termHunt_roundBegunTime = _CurTime()
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_ACTIVE )
    GAMEMODE.roundScore = nil
    GAMEMODE.roundScore = {}
    GAMEMODE.roundExtraData = nil
    GAMEMODE.roundExtraData = {}

    SetGlobalEntity( "termHuntWinner", NULL )
    SetGlobalInt( "termHuntWinnerSkulls", 0 )

    for _, ply in ipairs( player.GetAll() ) do
        ply:SetDeaths( 0 )
    end

    hook.Run( "huntersglee_round_into_active" )

    SetGlobalInt( "huntersglee_round_begin_active", math.Round( _CurTime() ) )

end

-- from hunting into displaying score
function GM:roundEnd()
    local plyCount = #player.GetAll()
    local timeAdd = math.Clamp( plyCount * 0.7, 1, 15 ) -- give time for discussion
    GAMEMODE.limboEnd = _CurTime() + 18 + timeAdd

    GAMEMODE.deadPlayers = {}
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_LIMBO )
    timer.Simple( engine.TickInterval(), function()
        if plyCount <= 0 then return end

        local winner = GAMEMODE:calculateWinner()
        local totalScore = GAMEMODE:calculateTotalScore()

        SetGlobalBool( "termHuntDisplayWinners", true )
        SetGlobalInt( "termHuntTotalScore", math.Round( totalScore ) )

        if winner:GetSkulls() <= 0 then
            SetGlobalEntity( "termHuntWinner", NULL )
            SetGlobalInt( "termHuntWinnerSkulls", 0 )
            return

        end

        SetGlobalEntity( "termHuntWinner", winner )
        SetGlobalInt( "termHuntWinnerSkulls", winner:GetSkulls() )

    end )

    hook.Run( "huntersglee_round_into_limbo" )

end

-- from the part where finest prey & total score is displayed, into setup where people can buy stuff with discounts
function GM:beginSetup()
    if GAMEMODE.termHunt_hunters then
        for _, hunter in pairs( GAMEMODE.termHunt_hunters ) do
            SafeRemoveEntity( hunter )
        end
        GAMEMODE.termHunt_hunters = {}

    end
    for _, ply in ipairs( player.GetAll() ) do
        ply.realRespawn = true -- wipe all shop attributes
        ply.shopItemCooldowns = {} -- reset wep cooldowns
        ply.isTerminatorHunterKiller = nil -- dont have this persist thru rounds
        ply:ResetSkulls()
        GAMEMODE:ensureNotSpectating( ply )

    end

    GAMEMODE.blockCleanupSetup = true -- no infinite loops please!
    game.CleanUpMap( false, { "env_fire", "entityflame", "_firesmoke" } )
    GAMEMODE.blockCleanupSetup = nil

    SetGlobalBool( "termHuntDisplayWinners", false )
    GAMEMODE.termHunt_roundStartTime = _CurTime() + GAMEMODE.roundStartNormal
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_INACTIVE )
    timer.Simple( 2, function()
        GAMEMODE:TeleportRoomCheck()
    end )

    hook.Run( "huntersglee_round_into_inactive" )

end

-- gamemode starts up, starts 5 second countdown to navmesh check.
function GM:TermHuntSetup()
    GAMEMODE.termHunt_roundStartTime = math.huge
    GAMEMODE.termHunt_roundBegunTime = math.huge
    GAMEMODE.termHunt_navmeshCheckTime = math.huge
    GAMEMODE.termHunt_NextThink = _CurTime() + 0.1
    GAMEMODE.termHunt_hunters = {}
    GAMEMODE.roundScore = {}
    GAMEMODE.roundExtraData = {}

    SetGlobalBool( "termHuntDisplayWinners", false )

    game.SetTimeScale( 1 )

    for _, ply in ipairs( player.GetAll() ) do
        ply:ResetScore()
    end

    print( "init" )
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_SETUP )
    GAMEMODE.termHunt_navmeshCheckTime = _CurTime() + 5

    hook.Run( "huntersglee_round_beginsetup" )

end

-- navmesh is not loaded at initialize so we wait
-- from the 5 second countdown to the first buying period
function GM:setupFinish()
    GAMEMODE.termHunt_navmeshCheckTime = math.huge
    local HasNav = GAMEMODE:initDependenciesCheck()
    if HasNav ~= true then
        GAMEMODE:SetRoundState( GAMEMODE.INVALID )
        GAMEMODE.startedNavmeshGeneration = nil

    else
        GAMEMODE:SetupTheLargestGroupsNStuff()
        -- removeporters was moved to the above function
        if GAMEMODE.biggestNavmeshGroups then
            GAMEMODE:removePorters()

        end
        GAMEMODE:removeBlockers()
        GAMEMODE:SetRoundState( GAMEMODE.ROUND_INACTIVE )

        local var = GetConVar( "sv_cheats" )
        local time = GAMEMODE.roundStartAfterNavCheck
        if var:GetBool() == true then
            time = time / 4

        end

        GAMEMODE.termHunt_roundStartTime = _CurTime() + time

    end
    if game.SinglePlayer() then
        GAMEMODE.termHunt_roundStartTime = _CurTime() + GAMEMODE.roundStartAfterNavCheck
        GAMEMODE.isBadSingleplayer = true

    end

    hook.Run( "huntersglee_round_into_inactive" )
    hook.Run( "huntersglee_round_firstsetup" )

end

function GM:concmdSetup()
    RunConsoleCommand( "mp_falldamage", "1" )
    RunConsoleCommand( "ai_disabled", "0" )
    RunConsoleCommand( "ai_ignoreplayers", "0" )

end

--[[
function GM:PlayerUse( ply, ent )
    print( ent:GetClass() )
end
--]]