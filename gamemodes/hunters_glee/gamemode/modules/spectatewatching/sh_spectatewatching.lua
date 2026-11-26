
-- Hands free spectating, for the dead who've put the controls down.
-- Start here, then cl_watchscorer.lua picks who to watch, and cl_watchcamera.lua flies the camera.
-- It all runs on the client, flying the player's own free roam body with made up input.
-- It starts on its own when they leave the controls alone in free roam, or when GM:StartSpectateWatching starts it.
-- The server also teleports them when the camera picks someone too far away to see.

local idleToWatch = 15 -- seconds without input in free roam before watching starts on its own. Defaults, see the convars
local idleInVoid = 1 -- the same, while in a wall or the void, there's nothing to see there
local teleportCooldown = 2 -- seconds between one player's teleports


--[[ Movement, exact speeds for the camera ]]

-- The stock spectator movement only does walk, run and sprint, with its own acceleration, so the camera couldn't ease.
-- Commands carrying this impulse are the camera's, their move values are a world velocity, used as is.
-- Shared, the client predicts its own movement with the same code, or it'd be corrected every tick.
-- Both hooks run for every player every tick, everyone else is turned away by the first line
local watchImpulse = 154 -- unused by the engine
GM.SpectateWatchingImpulse = watchImpulse
local maxWatchSpeed = 3000 -- a hand made command can't fling anyone further than this

local entMeta = FindMetaTable( "Entity" )
local plyMeta = FindMetaTable( "Player" )
local cmdMeta = FindMetaTable( "CUserCmd" )
local mvMeta = FindMetaTable( "CMoveData" )

local watchVels = setmetatable( {}, { __mode = "k" } ) -- this command's velocity, for players whose command is the camera's
local spareVels = setmetatable( {}, { __mode = "k" } ) -- one Vector per player, reused, nothing allocated per tick

hook.Add( "SetupMove", "glee_spectatewatching_move", function( ply, mv, cmd )
    if cmdMeta.GetImpulse( cmd ) ~= watchImpulse then
        if watchVels[ply] then
            watchVels[ply] = nil

        end
        return

    end
    if entMeta.Health( ply ) > 0 or plyMeta.GetObserverMode( ply ) ~= OBS_MODE_ROAMING then
        watchVels[ply] = nil
        return

    end

    local vel = spareVels[ply]
    if not vel then
        vel = Vector()
        spareVels[ply] = vel

    end
    vel:SetUnpacked( cmdMeta.GetForwardMove( cmd ), cmdMeta.GetSideMove( cmd ), cmdMeta.GetUpMove( cmd ) )

    local speedSqr = vel:LengthSqr()
    if speedSqr > maxWatchSpeed * maxWatchSpeed then
        vel:Mul( maxWatchSpeed / math.sqrt( speedSqr ) )

    end

    watchVels[ply] = vel
    mvMeta.SetVelocity( mv, vel )

end )

-- nothing collides, the camera keeps itself out of walls
hook.Add( "Move", "glee_spectatewatching_move", function( ply, mv )
    local vel = watchVels[ply]
    if not vel then return end

    mvMeta.SetOrigin( mv, mvMeta.GetOrigin( mv ) + vel * FrameTime() )
    return true

end )

if SERVER then
    util.AddNetworkString( "glee_triggerspectatewatching" )
    util.AddNetworkString( "glee_spectatewatching_teleport" )
    util.AddNetworkString( "glee_spectatewatching_teleported" )

    --[[---------------------------------------------------------
        GM:StartSpectateWatching
        @desc Starts hands free spectating on ply's client. Any input stops it.
        @param ply: The dead player to ask.
        @return: None
    --]]---------------------------------------------------------
    function GM:StartSpectateWatching( ply )
        net.Start( "glee_triggerspectatewatching" )
        net.Send( ply )

    end

    local deadLandingHeight = Vector( 0, 0, 64 ) -- death positions are on the floor

    -- Only ever to someone new, so the camera can't keep hopping to the same person
    net.Receive( "glee_spectatewatching_teleport", function( _, ply )
        local target = net.ReadEntity()
        if not IsValid( target ) or not target:IsPlayer() or target == ply then return end
        if ply.termHuntTeam == GAMEMODE.TEAM_PLAYING then return end
        if ply:Health() > 0 then return end
        if ply:GetObserverMode() ~= OBS_MODE_ROAMING then return end
        if ply.glee_WatchTeleportedTo == target then return end

        local cur = CurTime()
        if ( ply.glee_NextWatchTeleport or 0 ) > cur then return end

        if target:Health() > 0 then
            if not GAMEMODE:MoveSpectatorTo( ply, target ) then return end

        else
            local died = GAMEMODE.deadPlayers[target:GetCreationID()]
            if not died then return end
            ply:SetPos( died.pos + deadLandingHeight )

        end

        ply.glee_WatchTeleportedTo = target
        ply.glee_NextWatchTeleport = cur + teleportCooldown

        -- the camera snaps to here, its smoothed aim and velocity belong to the old spot
        net.Start( "glee_spectatewatching_teleported" )
        net.WriteVector( ply:GetPos() )
        net.Send( ply )

    end )

    -- each death starts with nobody teleported to
    hook.Add( "PlayerDeath", "glee_spectatewatching_forgetteleport", function( died )
        died.glee_WatchTeleportedTo = nil

    end )

elseif CLIENT then

    -- read by cl_watchscorer.lua and cl_watchcamera.lua, each keeps its own bool
    CreateClientConVar( "huntersglee_debug_spectatewatching", 0, false, false, "Draw the watching camera's targets, spots and aim. Needs developer 1", 0, 1 )

    local enabledVar = CreateClientConVar( "cl_huntersglee_spectatewatch", 1, true, false,
        "Become transfixed when you're dead and AFK? A camera takes over watching for you", 0, 1 )
    local idleToWatchVar = CreateClientConVar( "cl_huntersglee_spectatewatch_afktime", -1, true, false,
        "Seconds dead and AFK in free roam before you become transfixed, -1 for default, " .. idleToWatch, -1 )
    local idleInVoidVar = CreateClientConVar( "cl_huntersglee_spectatewatch_afktime_void", -1, true, false,
        "The same, while you're in a wall or the void, -1 for default, " .. idleInVoid, -1 )

    local function settingOr( var, default )
        local setting = var:GetFloat()
        return setting < 0 and default or setting

    end

    local LocalPlayer = LocalPlayer
    local CurTime = CurTime

    local watching = false
    local drove = false -- the camera's driven since it started, so leaving free roam was them, see the CreateMove hook
    local lastInputTime = 0
    local lastButtons = 0
    local lastAngles -- the view the command ended with last time, theirs or the camera's

    -- ramped, started on its own, the camera's grip tightens slowly, see GM:SpectateWatchingRamp
    local function startWatching( ramped )
        watching = true
        drove = false
        GAMEMODE:SpectateWatchingStarted( ramped )

    end

    local function startIfIdle( me )
        if not enabledVar:GetBool() then return end

        local idleFor = CurTime() - lastInputTime
        local openTime = settingOr( idleToWatchVar, idleToWatch )
        local voidTime = settingOr( idleInVoidVar, idleInVoid )
        if idleFor < math.min( openTime, voidTime ) then return end
        if me:Health() > 0 or me:GetObserverMode() ~= OBS_MODE_ROAMING then return end

        local needed = terminator_Extras.glee_IsInWall( me:EyePos() ) and voidTime or openTime
        if idleFor < needed then return end

        startWatching( true )

    end

    -- One hook, their input first, read before the camera writes its own.
    -- Any input at all is them being there: a new button press, moving, or the view turning off where it was left.
    -- Holding a button isn't, holding tab to look at the scores is still AFK.
    -- Buttons are never the camera's business, the server acts on them. One that has it spectate someone leaves free roam, ending this
    hook.Add( "CreateMove", "glee_spectatewatching", function( cmd )
        local buttons = cmd:GetButtons()
        local pressed = bit.band( buttons, bit.bnot( lastButtons ) ) ~= 0
        lastButtons = buttons

        local moved = cmd:GetForwardMove() ~= 0 or cmd:GetSideMove() ~= 0 or cmd:GetUpMove() ~= 0
        local looked = lastAngles ~= nil and cmd:GetViewAngles() ~= lastAngles

        if pressed or moved or looked then
            lastInputTime = CurTime()

        end

        local me = LocalPlayer()
        if watching then
            local roaming = me:GetObserverMode() == OBS_MODE_ROAMING
            if me:Health() > 0 or not enabledVar:GetBool() or ( drove and not roaming ) then
                watching = false

            -- not roaming yet, the trigger can land before the server's switch to free roam does
            elseif roaming then
                drove = true
                if GAMEMODE:SpectateWatchingDrive( cmd ) then
                    watching = false -- they've taken back control

                end
            end
        else
            startIfIdle( me )

        end

        lastAngles = cmd:GetViewAngles()

    end )

    --[[---------------------------------------------------------
        GM:StartSpectateWatching
        @desc Starts hands free spectating for the local player, unless they've turned it off.
            Their input comes through on top, pushing hard enough takes back control, see GM:SpectateWatchingDrive.
        @return: None
    --]]---------------------------------------------------------
    function GM:StartSpectateWatching()
        if not enabledVar:GetBool() then return end
        local me = LocalPlayer()
        if not IsValid( me ) then return end -- the server's ask can land before we've loaded in, being idle starts it soon enough
        if me:Health() > 0 then return end
        if watching then return end

        startWatching()

    end

    function GM:IsSpectateWatching()
        return watching

    end
    net.Receive( "glee_triggerspectatewatching", function()
        GAMEMODE:StartSpectateWatching()

    end )

    net.Receive( "glee_spectatewatching_teleported", function()
        GAMEMODE:SpectateWatchingTeleported( net.ReadVector() )

    end )
end