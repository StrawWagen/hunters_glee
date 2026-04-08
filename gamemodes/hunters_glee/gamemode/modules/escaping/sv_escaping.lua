
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
    local riderLookup = {}
    local explored = {}

    local function recurse( ent )
        if explored[ent] or not IsValid( ent ) then return end

        if ent.GetDriver then
            local rider = ent:GetDriver()

            if not riderLookup[rider] and IsValid( rider ) and rider:IsPlayer() and rider:Alive() then
                riderLookup[rider] = true
                table.insert( riders, rider )

            end
        end

        for _, child in pairs( ent:GetChildren() ) do
            recurse( child )

        end
    end

    recurse( vehicle )

    local rappellers = vehicle.glee_stuffRappellingOffMe
    if rappellers then
        for rappeler, _ in pairs( rappellers ) do
            if not IsValid( rappeler ) then continue end
            if not rappeler:Alive() then continue end
            if not rappeler:IsPlayer() then continue end
            if riderLookup[rappeller] then continue end

            riderLookup[rappeller] = true
            table.insert( riders, rappeler )

        end
    end

    return riders

end

local textDisplayDuration = 4

function GM:escapifyVehicle( vehicle )
    local driver
    if vehicle.GetDriver then
        driver = vehicle:GetDriver()

    end
    local riders = allRidersOf( vehicle )
    local actualRidersNoDriver = {}
    local riderCount = 0

    if #riders <= 0 then return end

    local delayUntil = CurTime() + textDisplayDuration + 0.15
    GAMEMODE:DelayRoundEndingUntil( delayUntil )

    for _, rider in ipairs( riders ) do
        GAMEMODE:escapifyPlayer( rider )
        if rider ~= driver then
            riderCount = riderCount + 1
            table.insert( actualRidersNoDriver, rider )

        end
    end

    if riderCount > 0 then
        if IsValid( driver ) then
            huntersGlee_AnnounceDramatic( actualRidersNoDriver, 1000, textDisplayDuration, "You've escaped!\nYou can finally leave this all behind, thanks to...\n" .. driver:Nick() )

            local scorePerRider = scorePerRiderCvar:GetInt()
            if scorePerRider < 0 then
                scorePerRider = defaultScorePerEscapedRider

            end
            local increase = riderCount * scorePerRider
            driver:GivePlayerScore( increase )

            local sOrNoS = riderCount == 1 and "" or "s"
            huntersGlee_AnnounceDramatic( { driver }, 1000, textDisplayDuration, "You helped " .. riderCount .. " soul" .. sOrNoS .. " escape...\n+" .. increase .. " Score." )

        else
            local escapablePlyCount = potentialEscapersCount()
            if escapablePlyCount > 1 then
                huntersGlee_AnnounceDramatic( riders, 1000, textDisplayDuration, "You've escaped!\nBut who did you leave behind?" )

            else
                huntersGlee_AnnounceDramatic( riders, 1000, textDisplayDuration, "You've escaped!\nYou can finally leave this all behind..." )

            end
        end
    else
        local escapablePlyCount = potentialEscapersCount()
        if escapablePlyCount > 1 then
            huntersGlee_AnnounceDramatic( { driver }, 1000, textDisplayDuration, "You've escaped!\nBut who did you leave behind?" )

        else
            huntersGlee_AnnounceDramatic( { driver }, 1000, textDisplayDuration, "You've escaped!\nYou can finally leave this all behind..." )

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

hook.Add( "glee_rescueheliescape", "glee_escapeviarescueheli", function( heli )
    if not IsValid( heli ) then return end
    GAMEMODE:escapifyVehicle( heli )

end )