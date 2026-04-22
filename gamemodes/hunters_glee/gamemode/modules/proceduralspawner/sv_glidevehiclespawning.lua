
if engine.ActiveGamemode() ~= "hunters_glee" then return end

if not Glide then return end

local vec_down = Vector( 0, 0, -1 )

terminator_Extras.collected = false
local glideClasses = {}
local glideVehicleTypes = {}

local alwaysTooBig = {
    ["glide_gtav_blimp"] = true,
    ["glide_gtav_blimp2"] = true,
    ["glide_gtav_avenger"] = true,

}

local function collect()
    terminator_Extras.collected = true

    local function Validate( t )
        if type( t ) ~= "table" then return false end
        if type( t.ClassName ) ~= "string" then return false end
        if type( t.GlideCategory ) ~= "string" then return false end

        return true
    end

    local i = 0

    for _, data in pairs( scripted_ents.GetList() ) do
        local t = data.t

        if Validate( t ) and t.GlideCategory and not alwaysTooBig[t.ClassName] then
            i = i + 1
            glideClasses[i] = t.ClassName
            glideVehicleTypes[t.ClassName] = t.VehicleType

        end
    end

    print( "GLEE: found " .. #glideClasses .. " glide vehicles to spawn..." )

end

if not terminator_Extras.collected then -- auto re fresh
    collect()

end

hook.Add( "InitPostEntity", "glee_collect_glide_vehicles", function()
    collect()

end )

local extraFlagsForVehicleTypes = {
    UNDEFINED = nil,
    CAR = GAMEMODE.NavEFlags.HIGH_CEILING,
    MOTORCYCLE = nil,
    HELICOPTER = GAMEMODE.NavEFlags.LOCALE_RUNWAY,
    PLANE = GAMEMODE.NavEFlags.LOCALE_RUNWAY,
    TANK = GAMEMODE.NavEFlags.HIGH_CEILING,
    BOAT = GAMEMODE.NavEFlags.LOCALE_BEACH
}

local gm_goldencitySky = 531714625
local vehiclesPerGoldencity = 4
local bite = 1

local surfaceAreaPerVehicle = gm_goldencitySky / vehiclesPerGoldencity

-- so they're in different spots between rounds
local vehiclePlacedAreas = {}

-- for maintaining the desired count
local spawnedGlideVehicles = {}

local minVehAreaSize = 250

hook.Add( "glee_blockjeepspawning", "glee_glide_blockjeeps", function() return true end )

-- replace jeep spawning system with glide vehicle pool spawning
hook.Add( "glee_navpatcher_finish", "glee_spawnaglideifwewant", function()

    if not GAMEMODE.VehiclesThisRound then GAMEMODE.VehiclesThisRound = 0 end

    if GAMEMODE.navmeshUnderSkySurfaceArea < surfaceAreaPerVehicle then return end -- only spawn on maps with lots of space under the sky

    -- determine max vehicles for this map
    local vehiclesOnThisMap = GAMEMODE.navmeshUnderSkySurfaceArea / surfaceAreaPerVehicle
    vehiclesOnThisMap = vehiclesOnThisMap - bite

    if vehiclesOnThisMap < 0.75 then return end

    vehiclesOnThisMap = math.floor( vehiclesOnThisMap )

    hook.Add( "huntersglee_round_into_active", "glee_vehiclesthisroundcounter", function()
        GAMEMODE.VehiclesThisRound = math.Rand( vehiclesOnThisMap * 0.1, vehiclesOnThisMap * 1 )

    end )

    print( "Maintaining " .. math.Round( vehiclesOnThisMap ) .. " active glide vehicles for map " .. game.GetMap() )

    local nextVehicleSpawnCheck = 0

    hook.Add( "glee_sv_validgmthink_active", "glee_add_glide_vehicle_jobs", function()
        if nextVehicleSpawnCheck > CurTime() then return end

        -- current live count
        local liveCount = 0
        for ent in pairs( spawnedGlideVehicles ) do
            if not IsValid( ent ) then continue end
            liveCount = liveCount + 1

        end
        if liveCount >= GAMEMODE.VehiclesThisRound then
            nextVehicleSpawnCheck = CurTime() + GAMEMODE:ScaledGenericSpawnerRate( 45 )
            return

        end

        local livePly = GAMEMODE:anAlivePlayer()
        if not IsValid( livePly ) then return end

        local function markAreaUsed( pos )
            local placedArea = GAMEMODE:getNearestNav( pos, 500 )
            if not IsValid( placedArea ) then return end
            vehiclePlacedAreas[placedArea] = true
            for _, area in ipairs( placedArea:GetAdjacentAreas() ) do
                if not IsValid( area ) then continue end
                vehiclePlacedAreas[area] = true

            end
        end

        local function spawnGlideVehicleAt( className, pos )
            local areaWeSpawnedOn = GAMEMODE:getNearestNav( pos, 500 )
            if not IsValid( areaWeSpawnedOn ) then return false end
            local areaSize = math.min( areaWeSpawnedOn:GetSizeX(), areaWeSpawnedOn:GetSizeY() )

            local veh = ents.Create( className )
            if not IsValid( veh ) then return false end
            veh:SetPos( pos )
            veh:SetAngles( Angle( 0, math.random( 0, 360 ), 0 ) )
            veh:Spawn()

            if veh:GetModelRadius() > areaSize / 2.5 then
                SafeRemoveEntity( veh )
                glideClasses[className] = nil
                print( "GLEE: glide vehicle " .. className .. " is too big! not gonna spawn it." )
                return false

            end
            veh:DropToFloor()
            spawnedGlideVehicles[veh] = true

            veh:CallOnRemove( "glee_glidevehicle_cleanup", function()
                spawnedGlideVehicles[veh] = nil

            end )

            markAreaUsed( pos )
            return true

        end

        local minAreaSize = math.random( minVehAreaSize, 550 )
        local offsetFromGround = Vector( 0, 0, minAreaSize / 2 )
        local hull = Vector( minAreaSize, minAreaSize, minAreaSize * 0.75 ) / 4

        local theTrace = {
            mins = -hull,
            maxs = hull,
            mask = MASK_SOLID,
        }

        local classWeWillSpawn = table.Random( glideClasses )
        if not classWeWillSpawn then return end -- lol this is technically possible

        local vehicleType = glideVehicleTypes[classWeWillSpawn]
        local extraFlagsRequired = extraFlagsForVehicleTypes[vehicleType]

        local vehicleJob = {}
        vehicleJob.jobsName = "glide_vehicle"

        vehicleJob.glideClassToSpawn = classWeWillSpawn
        vehicleJob.posFindingOrigin = livePly:GetPos()
        vehicleJob.spawnRadius = 16000
        vehicleJob.originIsDefinitive = false
        vehicleJob.sortForNearest = false
        vehicleJob.extraFlagsWhitelist = extraFlagsRequired
        vehicleJob.areaFilteringFunction = function( spawnJob, area )
            if vehiclePlacedAreas[area] then return end
            if area:IsBlocked() then return end
            if area:IsUnderwater() then return end

            -- cant fit the trace
            if area:GetSizeX() < minAreaSize then return end
            if area:GetSizeY() < minAreaSize then return end

            -- dont place in occupied areas
            local start = spawnJob:posDerivingFunc( area )[1]
            theTrace.start = start
            theTrace.endpos = start

            local trResult = util.TraceHull( theTrace )

            if trResult.Hit or trResult.StartSolid then return end

            return true

        end
        vehicleJob.hideFromPlayers = true
        vehicleJob.posDerivingFunc = function( _, area )
            return { area:GetCenter() + offsetFromGround }

        end
        vehicleJob.maxPositionsForScoring = 200
        vehicleJob.posScoringBudget = 500
        vehicleJob.posScoringFunction = function( _, toCheckPos, budget )
            -- get nook score, the more nooked the point is, the bigger the score.
            -- makes it prefer to spawn indoors 
            local nookScore = terminator_Extras.GetNookScore( toCheckPos )

            -- too close to players!
            local nearest, distSqr = GAMEMODE:nearestAlivePlayer( toCheckPos )
            local tooClose = 750 + vehicleJob.spawnRadius / math.Rand( 4, 6 )

            if nearest and distSqr < tooClose^2 then
                nookScore = nookScore / 2

            end

            if nookScore >= 3 then
                entsNearby = ents.FindInSphere( toCheckPos, minAreaSize / 2 )
                local count = 0
                for _, ent in ipairs( entsNearby ) do
                    if IsValid( ent ) and ent:IsSolid() and IsValid( ent:GetPhysicsObject() ) then
                        count = count + 1

                    end
                end
                if count >= 1 then
                    nookScore = 3 + -count

                end
            end

            budget = budget + - 1
            return nookScore

        end
        vehicleJob.onPosFoundFunction = function( spawnJob, bestPosition )
            -- check again
            theTrace.start = bestPosition
            theTrace.endpos = bestPosition

            local trResult = util.TraceHull( theTrace )

            if trResult.Hit or trResult.StartSolid then
                return false

            end

            local downOffs = ( minAreaSize * 1.25 )
            local quickTrace = util.QuickTrace( bestPosition, vec_down * downOffs )
            if not quickTrace.HitWorld then
                return false

            end

            return spawnGlideVehicleAt( vehicleJob.glideClassToSpawn, bestPosition )

        end

        GAMEMODE:addProceduralSpawnJob( vehicleJob )
        nextVehicleSpawnCheck = CurTime() + GAMEMODE:ScaledGenericSpawnerRate( 30 )

    end )
end )
