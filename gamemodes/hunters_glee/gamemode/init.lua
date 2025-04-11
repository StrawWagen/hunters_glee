-- ADDCS
AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "modules/cl_souls.lua" )
AddCSLuaFile( "modules/cl_targetid.lua" )
AddCSLuaFile( "modules/cl_scoreboard.lua" )
AddCSLuaFile( "modules/cl_obfuscation.lua" )
AddCSLuaFile( "modules/cl_fallingwind.lua" )
AddCSLuaFile( "modules/cl_killfeedoverride.lua" )

AddCSLuaFile( "modules/battery/cl_battery.lua" )
AddCSLuaFile( "modules/bpm/cl_bpm.lua" )
AddCSLuaFile( "modules/cl_spectateflashlight.lua" )
AddCSLuaFile( "modules/thirdpersonflashlight/cl_flashlight.lua" )
AddCSLuaFile( "modules/firsttimeplayers/cl_firsttimeplayers.lua" )

AddCSLuaFile( "cl_shopstandards.lua" )
AddCSLuaFile( "cl_shoppinggui.lua" )

AddCSLuaFile( "sh_player.lua" )
AddCSLuaFile( "sh_shopshared.lua" )
AddCSLuaFile( "sh_shopitems.lua" )

-- SHARED INCLUDES
AddCSLuaFile( "modules/sh_panic.lua" )
AddCSLuaFile( "modules/sh_banking.lua" )
AddCSLuaFile( "modules/sh_tempbools.lua" )
AddCSLuaFile( "modules/sh_danceslowdown.lua" )
AddCSLuaFile( "modules/sh_playerdrowning.lua" )
AddCSLuaFile( "modules/sh_detecthunterkills.lua" )
AddCSLuaFile( "modules/battery/sh_battery.lua" )
AddCSLuaFile( "modules/spawnset/cl_spawnsetvote.lua" )
AddCSLuaFile( "modules/spawnset/sh_spawnpoolutil.lua" )
AddCSLuaFile( "modules/spawnset/sh_spawnsetcontent.lua" )
AddCSLuaFile( "modules/unsandboxing/sh_unsandboxing.lua" )
AddCSLuaFile( "modules/signalstrength/cl_signalstrength.lua" )

-- SV
include( "lib/sv_termfuncs.lua" )
include( "shared.lua" )
include( "sv_player.lua" )
include( "sv_playercommunication.lua" )

include( "modules/sv_modelspeaking.lua" )
include( "modules/sv_deathsounds.lua" )

include( "modules/sv_unstucker.lua" )
include( "modules/sv_wallkick.lua" )
include( "modules/sv_speedhandler.lua" )
include( "modules/sv_navmeshgroups.lua" )
include( "modules/sv_navpatcher.lua" )
include( "modules/sv_doorbash.lua" )
include( "modules/sv_goomba.lua" )
include( "modules/sv_mapvote.lua" )
include( "modules/sv_seeding_rewarder.lua" )
include( "modules/sv_skullmanager.lua" )
include( "modules/sv_hunterspawner.lua" )
include( "modules/spawnset/sv_spawnsetvote.lua" )
include( "modules/spawnset/sv_spawnsetsounds.lua" )
include( "modules/firsttimeplayers/sv_firsttimeplayers.lua" )

include( "modules/battery/sv_battery.lua" )
include( "modules/thirdpersonflashlight/sv_flashlight.lua" )

include( "modules/proceduralspawner/sv_proceduralspawner.lua" )
include( "modules/proceduralspawner/sv_genericspawner.lua" )
include( "modules/proceduralspawner/sv_cratespawner.lua" )
include( "modules/proceduralspawner/sv_beartrapspawner.lua" )
include( "modules/proceduralspawner/sv_jeepspawner.lua" )

include( "modules/weapondropper/sv_weapondropper.lua" )
include( "modules/signalstrength/sv_signalstrength.lua" )

util.AddNetworkString( "glee_witnesseddeathconfirm" )
util.AddNetworkString( "glee_resetplayershopcooldowns" )
util.AddNetworkString( "glee_sendshopcooldowntoplayer" )
util.AddNetworkString( "glee_invalidateshopcooldown" )
util.AddNetworkString( "glee_confirmpurchase" )
util.AddNetworkString( "glee_followedsomething" )
util.AddNetworkString( "glee_followednexthing" )
util.AddNetworkString( "glee_switchedspectatemodes" )
util.AddNetworkString( "glee_stoppedspectating" )
util.AddNetworkString( "glee_dropcurrentweapon" )
util.AddNetworkString( "glee_closetheshop" )
util.AddNetworkString( "glee_roundstate" )
util.AddNetworkString( "glee_sendtruesoullocations" )

resource.AddFile( "materials/vgui/hud/glee_skullpickup.vmt" )
resource.AddFile( "materials/vgui/hud/heartbeat.png" )
resource.AddFile( "materials/vgui/hud/gleefulldata.png" )
resource.AddFile( "materials/vgui/hud/gleenodata.png" )
resource.AddFile( "materials/vgui/hud/deadshopicon.png" )

resource.AddSingleFile( "sound/53937_meutecee_trumpethit07.wav" )
resource.AddSingleFile( "sound/418788_name_heartbeat_single.wav" )
resource.AddSingleFile( "sound/209578_zott820_cash-register-purchase.wav" )
resource.AddSingleFile( "sound/482735__copyc4t__cartoon-long-throw.wav" )

resource.AddWorkshop( "2848253104" ) -- gamemode
resource.AddWorkshop( "2944078031" ) -- bot/model

local GM = GM or GAMEMODE

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

GM.roundStartAfterNavCheck      = 75
GM.roundStartNormal             = 60
GM.IsReallyHuntersGlee          = true

local CurTime = CurTime

-- gamemode starts up, starts 5 second countdown to navmesh check.
-- also happens after hard map cleanup
function GM:TermHuntSetup()
    self.waitingOnNavoptimizerGen       = nil
    -- do greedy patch once per session
    self.HuntersGleeDoneTheGreedyPatch  = self.HuntersGleeDoneTheGreedyPatch or nil
    self.playerIsWaitingForPatch        = nil
    self.ValidNavarea                   = self.ValidNavarea or NULL

    self.termHunt_roundStartTime        = math.huge
    self.termHunt_roundBegunTime        = math.huge
    self.termHunt_navmeshCheckTime      = math.huge
    self.termHunt_NextThink             = CurTime()

    self.doNotUseMapSpawns              = nil -- used in sv_players
    self.hasNavmesh                     = nil
    self.blockPvp                       = nil
    self.canRespawn                     = nil
    self.canScore                       = nil
    self.doProxChat                     = nil -- used in playercomms
    self.glee_Hunters                   = {}
    self.deadPlayers                    = {}
    self.roundScore                     = {}
    self.roundExtraData                 = {} -- helper tbl that is reset on round end

    self.nextStateTransmit              = 0

    -- just in case!
    hook.Remove( "Think", "glee_DoGreedyPatchThinkHook" )
    SetGlobalBool( "termHuntDisplayWinners", false )
    game.SetTimeScale( 1 )

    for _, ply in ipairs( player.GetAll() ) do
        ply:ResetScore()

    end

    print( "GLEE: init" )
    self:SetRoundState( self.ROUND_SETUP )
    self.termHunt_navmeshCheckTime = CurTime() + 5

    hook.Run( "huntersglee_round_beginsetup" )

end


function GM:RoundStateRepeat() -- make sure this doesnt get too out of sync
    if self.nextStateTransmit > CurTime() then return end
    local currState = self:RoundState() or GM.ROUND_INVALID
    self:SetRoundState( currState )
    self.nextStateTransmit = CurTime() + 0.25

end

function GM:SetRoundState( state )
    SetGlobalInt( "glee_roundstate", state )

    net.Start( "glee_roundstate", false )
        net.WriteInt( state, 8 )
    net.Send( player.GetAll() )

end

function GM:RoundState()
    return GetGlobalInt( "glee_roundstate", 0 )

end

-- gamemode brains

function GM:Think()
    local cur = CurTime()
    self:managePlayerSpectating()
    self:manageServersideCountOfBeats()

    if self.termHunt_NextThink > cur then return end
    self.termHunt_NextThink = cur + 0.1

    local currState = self:RoundState()

    local players = player.GetAll()
    if self:handleEmptyServer( currState, players ) == true then return end

    if self:handleGenerating( currState ) == true then return end

    -- see sv_player
    -- see sv_navpatcher
    -- see sv_playerdrowning
    -- see player_termrunner
    -- see sv_zproceduralspawner
    -- see battery/sv_battery
    -- see sv_darknessfear
    -- see sv_thirdpersonflashlight
    hook.Run( "glee_sv_validgmthink", players, currState, cur )

    local displayTime = nil
    local displayName = nil
    if currState == self.ROUND_INVALID then

        if not self.invalidStart then
            self.invalidStart = SysTime()

        end

        local dedi = game.IsDedicated()

        if not dedi and NAVOPTIMIZER_tbl and superIncrementalGeneration then
            local cheats = GetConVar( "sv_cheats" ):GetBool()
            if cheats then
                huntersGlee_Announce( player.GetAll(), 1000, 5, "Incrementally generating navmesh via Navmesh Optimizer..." )

            else
                huntersGlee_Announce( player.GetAll(), 100, 1, "NO NAVMESH.\nNavmesh Optimizer detected, run console command 'SV_CHEATS 1' for automatic navmesh generation." )

            end

            if cheats and not self.waitingOnNavoptimizerGen then
                self:GenerateANavmeshPls()
            end
        elseif not dedi then
            huntersGlee_Announce( player.GetAll(), 1000, 1, "NO NAVMESH!\nInstall or generate yourself a navmesh!" )

        end

        displayName = "You have spent this long without a navmesh... "
        displayTime = self:getRemaining( SysTime(), self.invalidStart )

    end
    if currState == self.ROUND_SETUP then -- wait like 5 seconds before the game session starts
        if self.termHunt_navmeshCheckTime < cur then
            self:setupFinish()

        else
            displayName = "--- "
            displayTime = 0
            self.blockPvp   = true
            self.doProxChat = false
            self.canRespawn = true
            self.canScore   = false

        end
    end
    if currState == self.ROUND_INACTIVE then --round is waiting to begin

        local doPatchingText = nil

        if self.termHunt_roundStartTime < cur then
            if self.HuntersGleeDoneTheGreedyPatch then
                self:roundStart() --
                self.isBadSingleplayer = nil --display that message once!

            else
                -- let the patcher be a bit more laggy
                self.playerIsWaitingForPatch = true
                doPatchingText = true

            end
        else
            if self.isBadSingleplayer then
                huntersGlee_Announce( players, 1000, 1, "This gamemode is at it's best when started with at least 2 player slots.\nThat doesn't mean you need 2 people!\nJust click the green \"Single Player\" and choose another option!" )

            end
            self.blockPvp   = true
            self.doProxChat = false
            self.canRespawn = true
            self.canScore   = false

            hook.Run( "glee_sv_validgmthink_inactive", players, currState, cur )

        end
        if doPatchingText then
            displayName = "Please wait, navmesh is being patched... "
            displayTime = self:getRemaining( self.termHunt_roundStartTime, cur )

        else
            displayName = "Getting ready "
            displayTime = self:getRemaining( self.termHunt_roundStartTime, cur )

        end
    end
    if currState == self.ROUND_LIMBO then --look at what happened during the round
        if self.limboEnd < cur then
            hook.Run( "huntersglee_round_leave_limbo" )
            self:beginSetup()

        else
            self.blockPvp   = true
            self.doProxChat = false
            self.canRespawn = false
            self.canScore   = false

        end
        displayName = "--- "
        displayTime = 0

    end
    if currState == self.ROUND_ACTIVE then -- THE HUNT BEGINS
        local aliveCount = self:CountWinnablePlayers()
        local waitingForAFirstTimePlayer = self:WaitingForAFirstTimePlayer( players )

        nobodyAlive = aliveCount == 0

        if nobodyAlive then
            self:roundEnd()

        elseif not waitingForAFirstTimePlayer then
            self.blockPvp   = false
            self.doProxChat = true
            self.canRespawn = false
            self.canScore   = true

            hook.Run( "glee_sv_validgmthink_active", players, currState, cur )

        end
        displayName = "Hunting... "
        displayTime = self:getRemaining( self.termHunt_roundBegunTime, cur )

    end

    local newState = self:RoundState()
    if newState ~= currState then
        hook.Run( "glee_roundstatechanged", currState, newState )

    end

    self:calculateBPM( cur, players )
    self:RoundStateRepeat()

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
    if self:countAlive( plys ) > 0 then
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
    return self.roundScore[ply:GetCreationID()] or 0

end

function GM:calculateTotalScore()
    local plyFinal = player.GetAll()
    local totalScore = 0
    for _, ply in ipairs( plyFinal ) do
        local theirScore = self:plysRoundScore( ply )
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
    for _, spawnClass in ipairs( self.SpawnTypes ) do
        spawns = ents.FindByClass( spawnClass )
        for _, spawnEnt in ipairs( spawns ) do
            local result = self:getNearestPosOnNav( spawnEnt:GetPos() )
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
        local result = self:getNearestPosOnNav( vector_origin, 20000 )
        if result.area and result.area:IsValid() then
            out = result.area

        end
    end

    return out

end

function GM:initDependenciesCheck()
    self.ValidNavarea = self:navmeshCheck()

    SetGlobalBool( "termHuntDisplayWinners", false )
    self.hasNavmesh = self.ValidNavarea:IsValid() and navmesh.IsLoaded()
    return self.hasNavmesh

end

--- some coroutine stuff
local getGroupsInPlayCheck = 0
local groupsInPlay = {}
local correctGroupsCor = nil

local function huntersAreInCorrectGroupsFunc()
    if getGroupsInPlayCheck < CurTime() then
        getGroupsInPlayCheck = CurTime() + 15
        table.Empty( groupsInPlay )
        groupsInPlay = GAMEMODE:GetNavmeshGroupsWithPlayers()

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

        if not GAMEMODE:GetGroupThatNavareaExistsIn( huntersNav, groupsInPlay ) then
            table.insert( huntersNotInPlay, hunter )

        end
    end

    for _, hunterNotInPlay in ipairs( huntersNotInPlay ) do
        local incorrectGroupCount = hunterNotInPlay.glee_IncorrectGroupCount or 0
        if not IsValid( hunterNotInPlay ) then continue end

        local battling = hunterNotInPlay.TerminatorNextBot and IsValid( hunterNotInPlay:GetEnemy() )
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
local abs_Local = math.abs
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

-- do the navmesh patching
-- involves adding areas under doors, windows, and then finding sections of navmesh that are separate from the biggest section, then linking them back up to it.
function GM:SetupTheLargestGroupsNStuff()

    -- navmesh groups need to be at least 40% the size of the largest one to be considered "playable"
    self.biggestGroupsRatio = 0.4
    self.GreedyPatchCouroutine = nil

    if self.HuntersGleeNeedsRepatching then
        self.HuntersGleeDoneTheGreedyPatch = nil
        self.HuntersGleeNeedsRepatching = nil

    end

    hook.Add( "Think", "glee_DoGreedyPatchThinkHook", function()
        local patchResult = nil
        if not self.HuntersGleeDoneTheGreedyPatch and not game.SinglePlayer() then

            if not self.GreedyPatchCouroutine then
                self:speakAsHuntersGlee( "Beginning greedy navpatcher process..." )

            end

            self.GreedyPatchCouroutine = self.GreedyPatchCouroutine or coroutine.create( self.DoGreedyPatch )

            local maxTime = 0.01
            -- dedi server can eat the perf
            if game.IsDedicated() then
                maxTime = 0.04

            elseif self.playerIsWaitingForPatch then
                maxTime = 0.02

            end

            local oldTime = SysTime()
            while abs_Local( oldTime - SysTime() ) < maxTime and self.GreedyPatchCouroutine and coroutine_status( self.GreedyPatchCouroutine ) ~= "dead" do
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

        hook.Remove( "Think", "glee_DoGreedyPatchThinkHook" )

    end )
end

local upOffset = Vector( 0, 0, 25 )

function GM:removePorters() -- it was either do this, or make the terminator use teleporters, this is easier. 
    local teleporters = ents.FindByClass( "trigger_teleport" )
    for _, porter in ipairs( teleporters ) do

        -- do a bunch of checks to see if porter just teleports between the same, big navmesh group.
        local portersPos = porter:WorldSpaceCenter()
        local portersArea = self:getNearestNav( portersPos, 1000 )
        if not portersArea or not portersArea.IsValid or not portersArea:IsValid() then SafeRemoveEntity( porter ) continue end

        local portersPosFloored = self:getFloor( portersPos )
        if not portersArea:IsVisible( portersPosFloored + upOffset ) then SafeRemoveEntity( porter ) continue end

        local portersGroup = self:GetGroupThatNavareaExistsIn( portersArea, self.biggestNavmeshGroups )
        if not portersGroup then SafeRemoveEntity( porter ) continue end

        local portersVals = porter:GetKeyValues()
        local targetsName = portersVals[ "target" ]
        local destTbl = ents.FindByName( targetsName )

        for _, dest in ipairs( destTbl ) do
            if not IsValid( dest ) then SafeRemoveEntity( porter ) break end
            local destPos = dest:WorldSpaceCenter()
            local area = self:getNearestNav( destPos, 1000 )
            if not area or not area.IsValid or not area:IsValid() then SafeRemoveEntity( porter ) break end

            local destPosFloored = self:getFloor( destPos )
            if not area:IsVisible( destPosFloored + upOffset ) then SafeRemoveEntity( porter ) break end

            local exitsGroup = self:GetGroupThatNavareaExistsIn( area, self.biggestNavmeshGroups )
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
            local area = self:getNearestNavFloor( door:WorldSpaceCenter() )

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


do
    local wasEmpty = true

    -- nukes all the hunters if there's nobody to hunt
    function GM:handleEmptyServer( currState, players )
        local empt = #players == 0
        if empt and ( currState == self.ROUND_ACTIVE or currState == self.ROUND_LIMBO ) then
            -- bots are expensive, save cpu power pls
            print( "Empty server!\nRemoving bots..." )
            self:roundEnd()
            self:beginSetup()
            return true

        elseif empt and game.IsDedicated() and not self.waitingOnNavoptimizerGen and navmesh.GetNavAreaCount() <= 0 and NAVOPTIMIZER_tbl and GetConVar( "sv_cheats" ):GetBool() then
            print( "GLEE: Automatically generating navmesh & optimizing with Navmesh Optimizer" )
            self:GenerateANavmeshPls()

        elseif empt then -- empty
            hook.Run( "huntersglee_emptyserver", wasEmpty )
            wasEmpty = true
            return true

        end
        wasEmpty = false

        return nil
    end
end

-- nukes all the hunters if navmesh is generating
local navmesh_IsGenerating = navmesh.IsGenerating
local navmeshMightBeGeneratingUntil = nil

function GM:handleGenerating( currState )

    local generating = self.waitingOnNavoptimizerGen or navmesh_IsGenerating()

    -- give the generator a bit of leeway
    if not generating and navmeshMightBeGeneratingUntil and navmeshMightBeGeneratingUntil > CurTime() then
        return true

    elseif generating and ( currState == self.ROUND_ACTIVE or currState == self.ROUND_LIMBO ) then
        print( "Navmesh generation detected, rebuilding." )
        self:roundEnd()
        self:beginSetup()
        self.biggestNavmeshGroups = nil
        return true

    elseif generating then
        navmeshMightBeGeneratingUntil = CurTime() + 10
        return true

    end

    -- got past, probably done
    if navmeshMightBeGeneratingUntil then
        navmeshMightBeGeneratingUntil = nil
        self.HuntersGleeNeedsRepatching = true
        RunConsoleCommand( "gmod_admin_cleanup" )

    end
    return nil

end

function GM:GenerateANavmeshPls()
    self.waitingOnNavoptimizerGen = true
    timer.Simple( 1, function()
        superIncrementalGeneration( nil, true, true )
    end )

    -- when generation is done
    hook.Add( "navoptimizer_done_gencheapexpanded", "glee_detectrealnavgenfinish", function()
        huntersGlee_Announce( player.GetAll(), 1001, 5, "Navmesh generation complete, optimizing..." )
        timer.Simple( 1, function()
            RunConsoleCommand( "navmesh_globalmerge_auto" )

        end )
        hook.Remove( "navoptimizer_done_gencheapexpanded", "glee_detectrealnavgenfinish" )

    end )

    -- when optimizing is done
    hook.Add( "navoptimizer_done_globalmerge", "glee_detectrealnavgenfinish", function()
        hook.Remove( "navoptimizer_done_globalmerge", "glee_detectrealnavgenfinish" )
        if game.IsDedicated() then
            navmesh.Save()
            print( "GLEE: Saved navmesh." )

        end
    end )
end

function GM:RemoveHunters()
    if self.glee_Hunters then
        for _, hunter in ipairs( self.glee_Hunters ) do
            SafeRemoveEntity( hunter )
        end
        self.glee_Hunters = {}

    end
end

-- from where people can buy stuff with discounts, to the hunt
function GM:roundStart()
    hook.Run( "huntersglee_round_pre_into_active" )

    self.termHunt_roundStartTime = math.huge
    self.termHunt_roundBegunTime = CurTime()
    self:SetRoundState( self.ROUND_ACTIVE )
    self.roundScore = nil
    self.roundScore = {}
    self.roundExtraData = nil
    self.roundExtraData = {}

    SetGlobalEntity( "termHuntWinner", NULL )
    SetGlobalInt( "termHuntWinnerSkulls", 0 )

    for _, ply in ipairs( player.GetAll() ) do
        ply:SetDeaths( 0 )
    end

    hook.Run( "huntersglee_round_into_active" )

    SetGlobalInt( "huntersglee_round_begin_active", math.Round( CurTime() ) )

end

-- from hunting into displaying score
function GM:roundEnd()
    local plyCount = #player.GetAll()
    local timeAdd = math.Clamp( plyCount * 0.7, 1, 15 ) -- give time for discussion
    self.limboEnd = CurTime() + 18 + timeAdd

    self.deadPlayers = {}
    self:SetRoundState( self.ROUND_LIMBO )
    timer.Simple( engine.TickInterval(), function()
        if plyCount <= 0 then return end

        local winner = self:calculateWinner()
        local totalScore = self:calculateTotalScore()

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
    self:RemoveHunters()
    for _, ply in ipairs( player.GetAll() ) do
        ply.realRespawn = true -- wipe all shop attributes
        ply.shopItemCooldowns = {} -- reset wep cooldowns
        ply.isTerminatorHunterKiller = nil -- dont have this persist thru rounds
        ply:ResetSkulls()
        self:ensureNotSpectating( ply )

    end

    self.blockCleanupSetup = true -- no infinite loops please!
    game.CleanUpMap( false, { "env_fire", "entityflame", "_firesmoke" } )
    self.blockCleanupSetup = nil

    SetGlobalBool( "termHuntDisplayWinners", false )
    self.termHunt_roundStartTime = CurTime() + self.roundStartNormal
    self:SetRoundState( self.ROUND_INACTIVE )
    timer.Simple( 2, function()
        self:TeleportRoomCheck()
    end )

    hook.Run( "huntersglee_round_into_inactive" )

end

-- navmesh is not loaded at initialize so we wait
-- from the 5 second countdown to the first buying period
function GM:setupFinish()
    self.termHunt_navmeshCheckTime = math.huge
    local HasNav = self:initDependenciesCheck()
    if HasNav ~= true then
        self:SetRoundState( self.ROUND_INVALID )

    else
        self:SetupTheLargestGroupsNStuff()
        self:removeBlockers()
        self:SetRoundState( self.ROUND_INACTIVE )

        local var = GetConVar( "sv_cheats" )
        local time = self.roundStartAfterNavCheck
        if var:GetBool() == true then
            time = time / 4

        end

        self.termHunt_roundStartTime = CurTime() + time

    end
    if game.SinglePlayer() then
        self.termHunt_roundStartTime = CurTime() + self.roundStartAfterNavCheck
        self.isBadSingleplayer = true

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