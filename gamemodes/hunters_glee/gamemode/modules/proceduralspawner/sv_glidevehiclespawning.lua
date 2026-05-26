
if not Glide then return end

local vec_down = Vector( 0, 0, -1 )

local GAMEMODE = GAMEMODE or GM

terminator_Extras.collected = false
local glideClasses = {}
local sizesPerClass = {}
local glideVehicleTypes = {}

local alwaysTooBig = {
    ["glide_gtav_blimp"] = true,
    ["glide_gtav_blimp2"] = true,
    ["glide_gtav_avenger"] = true,

}

local cheats = GetConVar( "sv_cheats" )

local function debugPrint( ... )
    if not cheats:GetBool() then return end
    permaPrint( ... )

end

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
            glideVehicleTypes[t.ClassName] = scripted_ents.GetMember( t.ClassName, "VehicleType" ) -- VehicleType is on glide_base_x ents

        end
    end

    permaPrint( "GLEE: found " .. #glideClasses .. " glide vehicles to spawn..." )

end

if not terminator_Extras.collected then -- auto re fresh
    collect()

end

hook.Add( "InitPostEntity", "glee_collect_glide_vehicles", function()
    collect()

end )

local vTypes = Glide.VEHICLE_TYPE

local extraFlagsForVehicleTypes = {
    [vTypes.UNDEFINED] = nil,
    [vTypes.CAR] = GAMEMODE.NavEFlags.HIGH_CEILING,
    [vTypes.MOTORCYCLE] = nil,
    [vTypes.HELICOPTER] = GAMEMODE.NavEFlags.LOCALE_RUNWAY,
    [vTypes.PLANE] = GAMEMODE.NavEFlags.LOCALE_RUNWAY,
    [vTypes.TANK] = GAMEMODE.NavEFlags.HIGH_CEILING,
    [vTypes.BOAT] = GAMEMODE.NavEFlags.LOCALE_BEACH,

}

local gm_goldencitySky = 531714625
local vehiclesPerGoldencity = 4
local bite = 1

local surfaceAreaPerVehicle = gm_goldencitySky / vehiclesPerGoldencity

-- so they're in different spots between rounds
local vehiclePlacedAreas = {}

-- for maintaining the desired count
local spawnedGlideVehicles = {}

local minVehAreaSize = 75

hook.Add( "glee_blockjeepspawning", "glee_glide_blockjeeps", function() return true end )

-- replace jeep spawning system with glide vehicle pool spawning
hook.Add( "glee_navpatcher_finish", "glee_spawnaglideifwewant", function()

    if not GAMEMODE.glideSpawner_VehiclesThisRound then GAMEMODE.glideSpawner_VehiclesThisRound = 0 end

    if not GAMEMODE.isSkyOnMap then return end

    -- determine max vehicles for this map
    local vehiclesOnThisMap = GAMEMODE.navmeshUnderSkySurfaceArea / surfaceAreaPerVehicle
    vehiclesOnThisMap = vehiclesOnThisMap - bite

    if #GAMEMODE:GetAreasWithEFlags( GAMEMODE.NavEFlags.LOCALE_BEACH ) > 4 then
        if vehiclesOnThisMap < 0.75 then
            GAMEMODE.glideSpawner_SpawnGlideBoatsOnly = true

        end
        vehiclesOnThisMap = math.max( vehiclesOnThisMap, math.Rand( 0.5, 1.5 ) )

    end

    if vehiclesOnThisMap < 0.75 then return end -- only spawn on maps with lots of space under the sky

    vehiclesOnThisMap = math.floor( vehiclesOnThisMap )

    hook.Add( "huntersglee_round_into_active", "glee_vehiclesthisroundcounter", function()
        local roundCount = math.Rand( vehiclesOnThisMap * 0.1, vehiclesOnThisMap )
        GAMEMODE.glideSpawner_VehiclesThisRound = math.max( roundCount, 1 )

    end )

    permaPrint( "Maintaining " .. math.Round( vehiclesOnThisMap ) .. " active glide vehicles for map " .. game.GetMap() )

    local nextVehicleSpawnCheck = 0

    hook.Add( "glee_sv_validgmthink_active", "glee_add_glide_vehicle_jobs", function()
        if nextVehicleSpawnCheck > CurTime() then return end

        -- current live count
        local liveCount = 0
        for ent in pairs( spawnedGlideVehicles ) do
            if not IsValid( ent ) then continue end
            liveCount = liveCount + 1

        end
        if liveCount >= GAMEMODE.glideSpawner_VehiclesThisRound then
            nextVehicleSpawnCheck = CurTime() + GAMEMODE:ScaledGenericSpawnerRate( 45 )
            return

        else -- dont think too fast
            nextVehicleSpawnCheck = CurTime() + GAMEMODE:ScaledGenericSpawnerRate( 5 )

        end

        local livePly = GAMEMODE:anAlivePlayer()
        if not IsValid( livePly ) then return end

        local classWeWillSpawn
        if GAMEMODE.glideSpawner_SpawnGlideBoatsOnly then
            for _, class in RandomPairs( glideClasses ) do
                local vType = glideVehicleTypes[class]
                if vType ~= vTypes.BOAT then continue end
                classWeWillSpawn = class
                break

            end
        else
            classWeWillSpawn = table.Random( glideClasses )

        end
        if not classWeWillSpawn then return end -- lol this is technically possible

        -- new spots every round
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

            local size = veh:GetModelRadius()
            sizesPerClass[className] = size

            local sizeTarget
            if glideVehicleTypes[className] == vTypes.BOAT then
                sizeTarget = areaSize

            else
                sizeTarget = areaSize / 2.5

            end

            if size > sizeTarget then
                SafeRemoveEntity( veh )
                if size > 500 then
                    glideClasses[className] = nil
                    sizesPerClass[className] = nil
                    debugPrint( "GLEE: glide vehicle " .. className .. " is too big (" .. size .. ")! never gonna spawn it, size target was " .. sizeTarget )

                else
                    debugPrint( "GLEE: glide vehicle " .. className .. " (" .. size .. "), was oversize, size target was " .. sizeTarget )

                end
                return false

            end
            veh:DropToFloor()
            spawnedGlideVehicles[veh] = true

            veh:CallOnRemove( "glee_glidevehicle_cleanup", function()
                spawnedGlideVehicles[veh] = nil

            end )

            hook.Run( "glee_onspawned_glidevehicle", veh )

            markAreaUsed( pos )
            return true

        end

        local minAreaSize = sizesPerClass[classWeWillSpawn] or minVehAreaSize
        local offsetFromGround = Vector( 0, 0, minAreaSize / 2 )
        local hull = Vector( minAreaSize, minAreaSize, minAreaSize * 0.75 ) / 4

        local theTrace = {
            mins = -hull,
            maxs = hull,
            mask = MASK_SOLID,
        }

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
