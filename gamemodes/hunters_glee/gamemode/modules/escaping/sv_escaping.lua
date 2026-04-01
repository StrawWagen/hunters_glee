
local defaultScorePerEscapedRider = 500
local scorePerRiderCvar = CreateConVar( "glee_score_perescaped_rider", -1, FCVAR_ARCHIVE, "How much score to give per escaped rider. Set to -1 to use the default of " .. defaultScorePerEscapedRider )

local GAMEMODE = GAMEMODE or GM

hook.Add( "glee_ply_escaped", "glee_escapersinkillfeed", function( picker )
    local inflic = "glee_escapeicon"
    if not GAMEMODE.SendDeathNotice then return end
    GAMEMODE:SendDeathNotice( picker, inflic, nil, 0 )

end )

local function potentialEscapersCount()
    local escapablePlyCount = 0
    for _, ply in player.Iterator() do
        if ply:Alive() and ply:GetNWInt( "glee_spectateteam", 0 ) == GAMEMODE.TEAM_PLAYING then
            escapablePlyCount = escapablePlyCount + 1

        end
    end

    return escapablePlyCount

end

local function allRidersOf( vehicle )
    local riders = {}
    local unexplored = { vehicle }
    local explored = {}
    -- recursively find all riders
    while #unexplored > 0 do
        local current = table.remove( unexplored, 1 )
        for _, child in ipairs( current:GetChildren() ) do
            if explored[child] then continue end
            explored[child] = true

            if not IsValid( child ) then continue end
            if child:IsPlayer() and child:Alive() then
                table.insert( riders, child )
                table.insert( unexplored, child )

            else
                table.insert( unexplored, child )

            end
        end
    end
    return riders

end

function GM:escapifyVehicle( vehicle )
    local driver = vehicle:GetDriver()
    local riders = allRidersOf( vehicle )
    local actualRidersNoDriver = {}
    local riderCount = 0
    for _, rider in ipairs( riders ) do
        GAMEMODE:escapifyPlayer( rider )
        if rider ~= driver then
            riderCount = riderCount + 1
            table.insert( actualRidersNoDriver, rider )

        end
    end

    if riderCount > 0 then
        local scorePerRider = scorePerRiderCvar:GetInt()
        if scorePerRider < 0 then
            scorePerRider = defaultScorePerEscapedRider

        end
        local increase = riderCount * scorePerRider
        driver:GivePlayerScore( increase )

        huntersGlee_Announce( actualRidersNoDriver, 1000, 8, "You've escaped!\nYou can finally leave this all behind, thanks to...\n" .. driver:Nick() )
        local sOrNoS = riderCount == 1 and "" or "s"
        huntersGlee_Announce( { driver }, 1000, 8, "You helped " .. riderCount .. " soul" .. sOrNoS .. " escape...\n+" .. increase .. " Score." )

    else
        local escapablePlyCount = potentialEscapersCount()
        if escapablePlyCount > 1 then
            huntersGlee_Announce( { driver }, 1000, 8, "You've escaped!\nBut who did you leave behind?" )

        else
            huntersGlee_Announce( { driver }, 1000, 8, "You've escaped!\nYou can finally leave this all behind..." )

        end
    end

    SafeRemoveEntity( vehicle )

end


GAMEMODE.glee_EscapableVehicles = GAMEMODE.glee_EscapableVehicles or {}

hook.Add( "PlayerEnteredVehicle", "glee_findescapablevehicles", function( _driver, vehicle )
    local trueVehicle = vehicle
    local parent = vehicle:GetParent()

    while IsValid( parent ) and parent.GetDriver do
        trueVehicle = parent
        parent = trueVehicle:GetParent()

    end

    if GAMEMODE.glee_EscapableVehicles[trueVehicle] then return end

    trueVehicle.glee_oldPhysicsCollide = trueVehicle.PhysicsCollide
    trueVehicle.PhysicsCollide = function( self, data, phys )
        if data.TheirSurfaceProps ~= 76 then -- we hit non-skybox! (default_silent) 
            return self:glee_oldPhysicsCollide( data, phys )

        end
        if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then return end
        GAMEMODE:escapifyVehicle( self )

    end
    GAMEMODE.glee_EscapableVehicles[trueVehicle] = true
    trueVehicle:CallOnRemove( function()
        GAMEMODE.glee_EscapableVehicles[trueVehicle] = nil

    end )
end )
