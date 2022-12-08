AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_targetid.lua" )
AddCSLuaFile( "shoppinggui.lua" )

include( "shared.lua" )
include( "lib/sv_termfuncs.lua" )
include( "sv_navpatcher.lua" )
include( "sv_player.lua" )

local SpawnTypes = { 
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
}

CreateConVar( "termhunt_spawneroverridecount", 0, bit.bor( FCVAR_NOTIFY, FCVAR_ARCHIVE ), "Overrides how many terminators will spawn, 0 for automatic count. Above 5 WILL lag.", 0, 32 )

GM.termHunt_roundStartTime = math.huge
GM.termHunt_roundBegunTime = math.huge
GM.termHunt_navmeshCheckTime = math.huge
GM.termHunt_NextThink = math.huge
validNavarea = validNavarea or NULL

GM.hasNavmesh       = nil
GM.godmode          = nil
GM.canRespawn       = nil
GM.canScore         = nil
GM.doProxChat       = nil
GM.termHunt_hunters = {}
GM.deadPlayers      = {}


function GM:SetRoundState( state )
    SetGlobalInt( "termhunt_roundstate", state )
end

function GM:Think()
    local cur = CurTime()
    GAMEMODE:managePlayerSpectating()
    GAMEMODE:manageServersideCountOfBeats()
    if GAMEMODE.termHunt_NextThink < cur then return end
    GAMEMODE.termHunt_NextThink = cur + 0.1

    local patchingDone = 0
    local players = player.GetAll()
    if #players == 0 then return end -- empt
    for _, ply in ipairs( players ) do
        GAMEMODE:refreshPlyDamageModel( ply )
        if patchingDone < 4 then -- this could be expensive so dont do it for everyone
            patchingDone = patchingDone + 1
            GAMEMODE:navPatchingThink( ply )
        end
    end

    local displayTime = nil
    local displayName = nil
    local currState = GAMEMODE:RoundState()
    if currState == GAMEMODE.INVALID then
        if not GAMEMODE.invalidStart then
            GAMEMODE.invalidStart = cur
            PrintMessage( HUD_PRINTCENTER, "NO NAVMESH!\nGo install or generate one!" )
        end
        displayName = "You have spent this long without a navmesh... "
        displayTime = GAMEMODE:getRemaining( cur, GAMEMODE.invalidStart )
    end 
    if currState == GAMEMODE.ROUND_SETUP then -- wait like 5 seconds before the game session starts
        if GAMEMODE.termHunt_navmeshCheckTime < cur then
            GAMEMODE.termHunt_navmeshCheckTime = math.huge
            local HasNav = GAMEMODE:initDependenciesCheck()
            if HasNav ~= true then
                GAMEMODE:SetRoundState( GAMEMODE.INVALID )
            else
                GAMEMODE:removePorters() -- remove teleporters
                GAMEMODE:SetRoundState( GAMEMODE.ROUND_INACTIVE )
                GAMEMODE.termHunt_roundStartTime = cur + 30
            end
            if game.SinglePlayer() then
                GAMEMODE.termHunt_roundStartTime = cur + 70
                GAMEMODE.isBadSingleplayer = true
            end
        else
            displayName = "--- "
            displayTime = 0
            GAMEMODE.godmode    = true
            GAMEMODE.doProxChat = false
            GAMEMODE.canRespawn = true
            GAMEMODE.canScore   = false
        end
    end
    if currState == GAMEMODE.ROUND_INACTIVE then --round is waiting to begin
        if GAMEMODE.termHunt_roundStartTime < cur then
            GAMEMODE:roundStart() --
            GAMEMODE.isBadSingleplayer = nil --display that message once!
        else
            if GAMEMODE.isBadSingleplayer then 
                PrintMessage( HUD_PRINTCENTER, "This gamemode is at it's best in a local-server/peer-to-peer session!\nCurrently singleplayer. Expect the terminators to get easily stuck." )
            end
            GAMEMODE.godmode    = true
            GAMEMODE.doProxChat = false
            GAMEMODE.canRespawn = true
            GAMEMODE.canScore   = false
        end
        displayName = "Getting ready "
        displayTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundStartTime, cur )
    end
    if currState == GAMEMODE.ROUND_LIMBO then --look at what happened during the round
        if GAMEMODE.limboEnd < cur then 
            GAMEMODE:beginSetup()
        else
            GAMEMODE.godmode    = true
            GAMEMODE.doProxChat = false
            GAMEMODE.canRespawn = false
            GAMEMODE.canScore   = false
        end
        displayName = "--- "
        displayTime = 0
    end
    if currState == GAMEMODE.ROUND_ACTIVE then -- THE HUNT BEGINS
        local aliveCount = GAMEMODE:countAlive( players )
        nobodyAlive = aliveCount == 0
        if nobodyAlive then
            GAMEMODE:roundEnd()
        else
            local nextSpawn = GAMEMODE.nextTermSpawn or 0
            if nextSpawn < cur then -- this is probably laggy so dont do it every tick
                GAMEMODE.nextTermSpawn = cur + 0.2
                local maxHunters = GAMEMODE:getMaxHunters()
                local aliveTermsCount = 0
                for _, curr in ipairs( GAMEMODE.termHunt_hunters ) do
                    if IsValid( curr ) and curr:Health() > 0 then
                        aliveTermsCount = aliveTermsCount + 1 
                    end
                end
                if aliveTermsCount < math.floor( maxHunters ) then
                    GAMEMODE:spawnHunter()
                end
            end
            GAMEMODE.godmode    = false
            GAMEMODE.doProxChat = true
            GAMEMODE.canRespawn = false
            GAMEMODE.canScore   = true
        end
        displayName = "Hunting... "
        displayTime = GAMEMODE:getRemaining( GAMEMODE.termHunt_roundBegunTime, cur )
    end

    GAMEMODE:calculateBPM( cur )

    if displayTime then
        SetGlobalInt( "TERMHUNTER_PLAYERTIMEVALUE", displayTime )
    end
    if displayName then 
        SetGlobalString( "TERMHUNTER_PLAYERVALUENAME", displayName )
    end
end

function GM:getMaxHunters()
    local var = GetConVar( "termhunt_spawneroverridecount" )
    local overrideCount = math.Clamp( var:GetInt(), 0, 64 )
    overrideCount = math.Round( overrideCount ) 
    if overrideCount > 0 then return overrideCount end
    local plyCount = #player.GetAll()
    local plyCountWeighted = plyCount * 0.75
    return math.Clamp( plyCountWeighted, 2, 5 )
end

function GM:spawnHunter() 
    local pos = validNavarea:GetCenter()
    local ply = table.Random( player.GetAll() )
    if IsValid( ply ) then 
        pos = ply:GetPos()
    end  
    local spawnDist = math.random( 8000, 9000 ) -- random variation
    local spawnPos = GAMEMODE:getFurthestConnectedNav( pos, spawnDist ) 
    if not isvector( spawnPos ) then return end
    spawnPos = spawnPos + Vector( 0,0,10 )
    local checkPos = spawnPos + Vector( 0,0,50 )
    local invalid = nil
    for _, pos in ipairs( GAMEMODE:allPlayerShootPositions() ) do
        if GAMEMODE:posCanSee( pos, checkPos ) then
            invalid = true
            break 
        elseif pos:DistToSqr( checkPos ) < 800^2 then -- dist check!
            invalid = true
            break 
        end
    end

    if invalid then return end
    
    --debugoverlay.Cross( spawnPos, 50, 20, Color( 0,0,255 ), true )

    if isvector( spawnPos ) then
        local Hunter = ents.Create( "sb_advanced_nextbot_terminator_hunter" )
        if IsValid( Hunter ) then 
            Hunter:SetPos( spawnPos )
            Hunter:Spawn()
            print( Hunter )
            table.insert( GAMEMODE.termHunt_hunters, Hunter )
        end
    end
end

function GM:roundStart()
    GAMEMODE.termHunt_roundStartTime = math.huge
    GAMEMODE.termHunt_roundBegunTime = CurTime()
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_ACTIVE )

    for _, ply in ipairs(player.GetAll()) do
        ply:SetFrags( 0 )
        ply:SetDeaths( 0 )
    end
end

function GM:roundEnd()
    for _, hunter in pairs(GAMEMODE.termHunt_hunters) do
        SafeRemoveEntity( hunter )
    end
    local plyCount = #player.GetAll()
    local timeAdd = math.Clamp( plyCount * 2, 1, 15 ) -- give time for discussion
    GAMEMODE.termHunt_hunters = {}
    GAMEMODE.limboEnd = CurTime() + 20
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_LIMBO )
    GAMEMODE.deadPlayers = {}
    timer.Simple( engine.TickInterval(), function()
        local winner = GAMEMODE:calculateWinner()
        local totalScore = GAMEMODE:calculateTotalScore()

        SetGlobalBool( "termHuntDisplayWinners", true )
        SetGlobalInt( "termHuntTotalScore", totalScore )

        SetGlobalEntity( "termHuntWinner", winner )
        SetGlobalInt( "termHuntWinnerScore", winner:Frags() )
    end )
end

function GM:beginSetup()

    for _, ply in ipairs( player.GetAll() ) do
        GAMEMODE:unspectatifyPlayer( ply )
        
    end

    GAMEMODE.blockCleanupSetup = true -- no infinite loops please!
    game.CleanUpMap( false, { "env_fire", "entityflame", "_firesmoke" } )
    GAMEMODE.blockCleanupSetup = nil

    SetGlobalBool( "termHuntDisplayWinners", false )
    GAMEMODE.termHunt_roundStartTime = CurTime() + 20
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_INACTIVE )
end


function GM:alivePlayersOrAll( plys )
    local plyFinal = {}
    if GAMEMODE:countAlive( plys ) > 0 then
        for _, ply in pairs( plys ) do
            if ply:Alive() then
                table.insert( plyFinal, ply )
            end
        end
    else
        plyFinal = plys
    end
    return plyFinal
end

function GM:calculateTotalScore()
    local plyFinal = player.GetAll()
    local totalScore = 0
    for _, ply in ipairs( plyFinal ) do
        totalScore = totalScore + ply:Frags() 
    end
    return totalScore
end
function GM:calculateWinner()
    local plyFinal = player.GetAll()
    table.sort( plyFinal, function( a, b )
        if a:Frags() > b:Frags() then 
            return true
        else
            return false
        end
    end )
    local winner = plyFinal[1]
    return winner
end


function GM:navmeshCheck()
    local out = NULL 
    for _, spawnClass in ipairs( SpawnTypes ) do
        spawns = ents.FindByClass( spawnClass )
        for _, spawnEnt in ipairs( spawns ) do
            local result = GAMEMODE:getNearestPosOnNav( spawnEnt:GetPos() )
            if result.area then
                if result.area:IsValid() then
                    out = result.area
                    break
                end
            end
        end
        if out ~= NULL then 
            break 
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

function GM:removePorters() -- it was either do this, or make the terminator use teleporters, this is easier. 
    local teleporters = ents.FindByClass( "trigger_teleport" )
    for _, porter in ipairs( teleporters ) do
        SafeRemoveEntity( porter )
    end
end

function GM:removeBlockers() -- mess up doors on door heavy maps
    local doors = ents.FindByClass( "prop_door_rotating" )
    for _, door in ipairs( doors ) do
        if door:GetInternalVariable( "m_bLocked" ) ~= true then continue end
        if not GAMEMODE:doorIsUsable( door ) then continue end

        local areaIsBig = nil
        local area = GAMEMODE:getNearestNavFloor( door:WorldSpaceCenter() )

        if area and area:IsValid() then 
            -- door is creating blocked flag on huge areas, probably breaking pathing
            local surfaceArea = area:GetSizeX() * area:GetSizeY()
            areaIsBig = surfaceArea > 2500

        end

        if math.random( 0, 100 ) > 50 and not areaIsBig then continue end 

        door:Fire( "Unlock" )

    end
end

function GM:concmdSetup()
    RunConsoleCommand( "mp_falldamage", 1 )
end

function GM:EntityTakeDamage( dmgTarg, dmg )
    local attacker = dmg:GetAttacker()
    local areBothPlayers = dmgTarg:IsPlayer() and attacker:IsPlayer()  
    if areBothPlayers then
        dmg:ScaleDamage( 0.25 )
    end
end

function GM:TermHuntSetup()

    GAMEMODE.termHunt_roundStartTime = math.huge
    GAMEMODE.termHunt_roundBegunTime = math.huge
    GAMEMODE.termHunt_navmeshCheckTime = math.huge
    GAMEMODE.termHunt_NextThink = CurTime() + 0.1
    GAMEMODE.termHunt_hunters = {}

    SetGlobalBool( "termHuntDisplayWinners", false )

    for _, ply in ipairs( player.GetAll() ) do
        ply:SetFrags( 0 )
    end

    print( "init" )
    GAMEMODE:SetRoundState( GAMEMODE.ROUND_SETUP )
    GAMEMODE.termHunt_navmeshCheckTime = CurTime() + 5

end

--function GM:PlayerUse( ply, ent )
--    print( ply,ent )
--end

--blab