local GAMEMODE = GAMEMODE or GM
GAMEMODE.isSkyOnMap = GAMEMODE.isSkyOnMap or nil
GAMEMODE.highestZ = GAMEMODE.highestZ or nil
GAMEMODE.areasUnderSky = GAMEMODE.areasUnderSky or nil

local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield

local function AreaOrLadderGetAdjacentAreas( areaOrLadder )
    local adjacents = {}
    if not areaOrLadder then return adjacents end
    if areaOrLadder.GetTop then -- is ladder
        table.Add( adjacents, areaOrLadder:GetBottomArea() )
        table.Add( adjacents, areaOrLadder:GetTopForwardArea() )
        table.Add( adjacents, areaOrLadder:GetTopBehindArea() )
        table.Add( adjacents, areaOrLadder:GetTopRightArea() )
        table.Add( adjacents, areaOrLadder:GetTopLeftArea() )

    else
        adjacents = table.Add( areaOrLadder:GetAdjacentAreas(), areaOrLadder:GetLadders() )

    end
    return adjacents

end

--funcs for making sure people dont fucking end up in "map teleport rooms"
local function updateCorners( area, corners )

    local id

    -- north westy
    id = 0
    local NWCorner = corners[id]
    local NWCorner2 = area:GetCorner( id )

    if NWCorner2.y < NWCorner.y then
        corners[id].y = NWCorner2.y
        corners[id].z = NWCorner2.z

    end
    if NWCorner2.x < NWCorner.x then
        corners[id].x = NWCorner2.x
        corners[id].z = NWCorner2.z

    end

    -- find most north easty corner
    id = 1
    local NECorner = corners[id]
    local NECorner2 = area:GetCorner( id )

    if NECorner2.y < NECorner.y then
        corners[id].y = NECorner2.y
        corners[id].z = NECorner2.z

    end
    if NECorner2.x > NECorner.x then
        corners[id].x = NECorner2.x
        corners[id].z = NECorner2.z

    end

    -- find most south easty corner
    id = 2
    local SECorner = corners[id]
    local SECorner2 = area:GetCorner( id )

    if SECorner2.y > SECorner.y then
        corners[id].y = SECorner2.y
        corners[id].z = SECorner2.z

    end
    if SECorner2.x > SECorner.x then
        corners[id].x = SECorner2.x
        corners[id].z = SECorner2.z

    end

    -- find most south westy corner
    id = 3
    local SWCorner = corners[id]
    local SWCorner2 = area:GetCorner( id )

    if SWCorner2.y > SWCorner.y then
        corners[id].y = SWCorner2.y
        corners[id].z = SWCorner2.z

    end
    if SWCorner2.x < SWCorner.x then
        corners[id].x = SWCorner2.x
        corners[id].z = SWCorner2.z

    end

    return true

end

function GM:GetConnectedNavAreaGroups( navAreas )
    hook.Run( "glee_connectedgroups_begin", navAreas )

    local groups = {}
    local groupCorners = {}

    -- create a table to keep track of which navareas have been visited
    local visited = {}

    -- iterate over each navarea in the array
    for _, navArea in ipairs( navAreas ) do
        hook.Run( "glee_connectedgroups_visit", navArea )

        -- check if the navarea has been visited
        if not visited[navArea] then
            -- the navarea has not been visited, so create a new group for it
            local group = {}

            -- add the navarea to the group
            table.insert( group, navArea )

            local defaultCorner = navArea:GetCenter()
            local currBestCorners = {
                [0] = Vector( defaultCorner.x, defaultCorner.y, defaultCorner.z ), -- these just being defaultCorner caused so many problems, i love vectors! 
                [1] = Vector( defaultCorner.x, defaultCorner.y, defaultCorner.z ),
                [2] = Vector( defaultCorner.x, defaultCorner.y, defaultCorner.z ),
                [3] = Vector( defaultCorner.x, defaultCorner.y, defaultCorner.z )

            }

            -- mark the navarea as visited
            visited[navArea] = true

            -- find all connected navareas and add them to the group
            local queue = {}
            table.insert( queue, navArea )

            while #queue > 0 do
                local currentNavArea = table.remove( queue, 1 )
                local currentIsLadder = currentNavArea.GetTop
                for _, connectedNavArea in ipairs( AreaOrLadderGetAdjacentAreas( currentNavArea ) ) do
                    if visited[connectedNavArea] then continue end
                    local handlingLadder = currentIsLadder or connectedNavArea.GetTop

                    if not handlingLadder then
                        local connectedBothWays = connectedNavArea:IsConnected( currentNavArea ) and currentNavArea:IsConnected( connectedNavArea )
                        if not connectedBothWays then continue end

                        local eitherIsUnderwater = currentNavArea:IsUnderwater() or connectedNavArea:IsUnderwater()
                        local tooFarVertical = math.abs( currentNavArea:ComputeAdjacentConnectionHeightChange( connectedNavArea ) ) > 50 and not eitherIsUnderwater
                        if tooFarVertical then continue end

                    end

                    -- mark the connected navarea as visited
                    visited[connectedNavArea] = true
                    -- add the connected navarea to the queue to be processed
                    table.insert( queue, connectedNavArea )

                    -- ladders dont go in the groups, just connect them to eachother
                    if connectedNavArea.GetTop then continue end

                    updateCorners( connectedNavArea, currBestCorners )

                    -- add the connected navarea to the group
                    table.insert( group, connectedNavArea )

                end
            end
            -- add the group to the list of groups
            table.insert( groups, group )
            table.insert( groupCorners, currBestCorners )

            --[[
                local red = Color( 255, 0, 0 )
                debugoverlay.Line( currBestCorners[0], currBestCorners[1], 5, red, true )
                debugoverlay.Line( currBestCorners[1], currBestCorners[2], 5, red, true )
                debugoverlay.Line( currBestCorners[2], currBestCorners[3], 5, red, true )
                debugoverlay.Line( currBestCorners[3], currBestCorners[0], 5, red, true )
            --]]

        end
    end

    -- finally, sort all the groups by size, smallest first
    table.sort( groups, function( a, b )
        return #a < #b

    end )

    hook.Run( "glee_connectedgroups_end", groups )

    return groups, groupCorners, navAreas

end

-- take the return of GM:FindPotentialLinkagesBetweenNavAreaGroups( groups, maxLinksPerGroup ) as an input
-- go thru all potential links and link the valid ones
    -- valid links are less than 200 squared apart

function GM:GetLargestGroupOfNavareas( groups )
    local largestGroup = nil

    for _, group in ipairs( groups ) do
        if largestGroup == nil or #group > #largestGroup then
            largestGroup = group

        end
    end
    return largestGroup

end

function GM:FilterNavareaGroupsForGreaterThanPercent( groups, targetPercent )
    -- find the largest group
    local largestGroup = GAMEMODE:GetLargestGroupOfNavareas( groups )

    -- discard groups that are less than targetPercent the size of the largest group
    local finalGroups = {}
    for _, group in ipairs( groups ) do
        if #group >= targetPercent * #largestGroup then
            table.insert( finalGroups, group )
        end
    end

    return finalGroups
end


-- find a navarea center that is on biggest navmesh groups, and is close ish to a spawnpoint.

function GM:FindValidNavAreaCenter( navAreaGroups )
    -- create an array to store the navarea centers
    local navAreaCenters = {}
    -- all this to pick a random spawn to sort to
    local spawns = {}
    for _, spawnEntClass in ipairs( GAMEMODE.SpawnTypes ) do
        local currentSpawns = ents.FindByClass( spawnEntClass )
        if #currentSpawns <= 0 then continue end
        for _, spawn in ipairs( currentSpawns ) do
            table.insert( spawns, spawn )
        end
    end
    -- find a random spawnpoint
    local randomSpawn
    local randomSpawnInd = math.random( 1, #spawns )
    for _ = 1, 10 do
        randomSpawn = spawns[ randomSpawnInd ]
        if IsValid( randomSpawn ) then break end

    end

    -- choose a random navarea group
    local group = navAreaGroups[ math.random( #navAreaGroups ) ]

    -- add a random sample of 30 navarea centers to the array
    for _ = 1, 150 do
        if #navAreaCenters > 30 then break end
        -- choose a random navarea from the group
        local navArea = group[ math.random( #group ) ]
        if not IsValid( navArea ) then continue end

        if navArea:IsUnderwater() then continue end

        -- add the center of the navarea to the array
        table.insert( navAreaCenters, navArea:GetCenter() )
    end

    -- sort the navarea centers using their distance to the confirmed walkable navarea
    -- this way people should very rarely end up behind playerclips 
    table.sort( navAreaCenters, function( a, b )
        return a:DistToSqr( randomSpawn:GetPos() ) < b:DistToSqr( randomSpawn:GetPos() )
    end )

    return navAreaCenters[1]
end

-- used for checking if player is in big groups
function GM:NavAreaExistsInGroups( navArea, navAreaGroups )
    -- iterate over each navarea group
    for _, group in ipairs( navAreaGroups ) do
        -- check if the navarea is in the group
        for _, navAreaInGroup in ipairs( group ) do
            if navAreaInGroup == navArea then
                -- the navarea is in the group, so return true
                return true

            end
        end
    end
    -- the navarea is not in any of the groups, so return false
    return false

end

-- used for finding out WHICH group player is in
function GM:GetGroupThatNavareaExistsIn( navArea, navAreaGroups, yieldable )
    -- iterate over each navarea group
    if istable( navAreaGroups ) then
        for _, group in ipairs( navAreaGroups ) do
            if yieldable then
                coroutine_yield()

            end
            if istable( group ) then
                -- check if the navarea is in the group
                for _, navAreaInGroup in ipairs( group ) do
                    if navAreaInGroup == navArea then
                        -- the navarea is in the group, so return true
                        return group

                    end
                end
            end
        end
    end
end

-- will return an underwater area if all of them are underwater
local function areaThatIsntUnderwater( areas )
    local bestArea = nil
    local clone = table.Copy( areas )

    for _ = 1, #clone do
        bestArea = table.remove( clone, math.random( 1, #clone ) )
        if not bestArea:IsUnderwater() then break end

    end
    return bestArea

end

-- get navarea to teleport to that isnt boring
function GM:GetAreaInOccupiedBigGroupOrRandomBigGroup( noUnderWater )

    local bigGroups = GAMEMODE.biggestNavmeshGroups
    local firstPly = GAMEMODE:anotherAlivePlayer()
    local firstPlysNavarea
    local bigGroupThatSomeoneIsIn

    -- dont do any group people are in, just pick one group
    if IsValid( firstPly ) then
        -- big check, don't use cache
        firstPlysNavarea = navmesh.GetNearestNavArea( firstPly:GetPos(), false, 8000, false, true, -2 )
        bigGroupThatSomeoneIsIn = GAMEMODE:GetGroupThatNavareaExistsIn( firstPlysNavarea, bigGroups )

    end

    if bigGroupThatSomeoneIsIn then
        local area = bigGroupThatSomeoneIsIn[math.random( 1, #bigGroupThatSomeoneIsIn )]

        if noUnderWater and area:IsUnderwater() then
            area = areaThatIsntUnderwater( bigGroupThatSomeoneIsIn )

        end
        return area, bigGroupThatSomeoneIsIn

    -- main person is not in a big group, just pick one with hunters in it
    else
        local hunterRef
        for _, hunter in ipairs( GAMEMODE.glee_Hunters ) do
            if IsValid( hunter ) then
                hunterRef = hunter
                break

            end
        end
        if not hunterRef then goto getareainbigoroccupiedFail end
        local firstHuntersArea = navmesh.GetNearestNavArea( hunterRef:GetPos(), false, 8000, false, true, -2 )
        local bigGroupThatHunterIsIn = GAMEMODE:GetGroupThatNavareaExistsIn( firstHuntersArea, bigGroups )

        if not bigGroupThatHunterIsIn then goto getareainbigoroccupiedFail end


        local area = bigGroupThatHunterIsIn[math.random( 1, #bigGroupThatHunterIsIn )]

        if noUnderWater and area:IsUnderwater() then
            area = areaThatIsntUnderwater( bigGroupThatHunterIsIn )

        end
        return area, bigGroupThatHunterIsIn

    end

    -- nope, hunters aren't in big groups either, just a random area in a random big group
    ::getareainbigoroccupiedFail::

    local randBigGroup = bigGroups[ math.random( 1, #bigGroups ) ]
    local randAreaInRandGroup = randBigGroup[ math.random( 1, #randBigGroup ) ]

    if noUnderWater and randAreaInRandGroup:IsUnderwater() then
        randAreaInRandGroup = areaThatIsntUnderwater( randBigGroup )

    end

    return randAreaInRandGroup, randBigGroup

end

function GM:GetNavmeshGroupsWithPlayers( yieldable )
    local bigGroups = GAMEMODE.biggestNavmeshGroups
    local alivePlayers = GAMEMODE:getAlivePlayers()

    if #alivePlayers <= 0 then return end

    local groupsWithPlayers = {}
    local doneGroups = {}

    for _, alivePly in ipairs( alivePlayers ) do
        if yieldable then
            coroutine_yield()

        end
        if not IsValid( alivePly ) then continue end
        local alivePlysNav, _ = alivePly:GetNavAreaData()
        if not IsValid( alivePlysNav ) then continue end
        local bigGroupThatSomeoneIsIn = GAMEMODE:GetGroupThatNavareaExistsIn( alivePlysNav, bigGroups )

        if not bigGroupThatSomeoneIsIn then continue end
        if doneGroups[ #bigGroupThatSomeoneIsIn ] then continue end

        -- this can theoretically break, but i know it's very, very unlikely
        doneGroups[ #bigGroupThatSomeoneIsIn ] = true
        table.insert( groupsWithPlayers, bigGroupThatSomeoneIsIn )

    end
    return groupsWithPlayers

end


-- check if this map has all spawns in a separate room
function GM:TeleportRoomCheck()
    if not GAMEMODE.biggestNavmeshGroups or not GAMEMODE.navmeshGroups then
        GAMEMODE.navmeshGroups = GAMEMODE:GetConnectedNavAreaGroups( navmesh.GetAllNavAreas() )
        GAMEMODE.biggestNavmeshGroups = GAMEMODE:FilterNavareaGroupsForGreaterThanPercent( GAMEMODE.navmeshGroups, GAMEMODE.biggestGroupsRatio or 0.4 )

    end

    local doReset = nil
    local reason = ""

    -- randomly force people to spawn on one of the other "big groups"
    local forceReset = #GAMEMODE.biggestNavmeshGroups > 1 and math.random( 0, 100 ) > ( 100 / #GAMEMODE.biggestNavmeshGroups )

    for _, ply in ipairs( player.GetAll() ) do
        -- dont use cache here because its rarely called
        local plysNearestNav = GAMEMODE:getNearestNav( ply:GetPos(), 200 )
        if forceReset then
            doReset = true
            reason = "Map has other areas...\nShuffling..."

        elseif not plysNearestNav or not plysNearestNav.IsValid then
            doReset = true
            reason = "Someone was off the navmesh...\nRespawning..."

        else
            local moveType = ply:GetMoveType()
            if moveType ~= MOVETYPE_NOCLIP and not GAMEMODE:NavAreaExistsInGroups( plysNearestNav, GAMEMODE.biggestNavmeshGroups ) then
                doReset = true
                reason = "Someone is outside the biggest parts of the map!\nReturning..."
            end
        end
        if doReset then
            break
        end
    end
    if doReset then
        GAMEMODE.doNotUseMapSpawns = true
        for _, plyGettinRespawned in ipairs( player.GetAll() ) do
            plyGettinRespawned:KillSilent()

        end
        print( reason ) -- log it
        huntersGlee_Announce( player.GetAll(), 1, 5, reason )

    end
end


local function areasSurfaceArea( area )
    return area:GetSizeX() * area:GetSizeY()

end

-- navmesh understanding stuff
local function reset()
    GAMEMODE.isSkyOnMap = false
    GAMEMODE.areasUnderSky = {}
    GAMEMODE.highestZ = -math.huge
    GAMEMODE.highestAreaZ = -math.huge
    GAMEMODE.navmeshTotalSurfaceArea = 0
    GAMEMODE.navmeshUnderSkySurfaceArea = 0

end
hook.Add( "InitPostEntity", "glee_baseline_navdata", reset )

hook.Add( "glee_connectedgroups_begin", "glee_reset_navdata", reset )

local centerOffset = Vector( 0, 0, 25 )

hook.Add( "glee_connectedgroups_visit", "glee_precache_skydata", function( area )
    local areasCenter = area:GetCenter()
    local underSky, hitPos = GAMEMODE:IsUnderSky( areasCenter + centerOffset )
    if underSky then
        GAMEMODE.isSkyOnMap = true
        GAMEMODE.areasUnderSky[ area ] = true
        GAMEMODE.navmeshUnderSkySurfaceArea = GAMEMODE.navmeshUnderSkySurfaceArea + areasSurfaceArea( area )

    end

    local currHitZ = hitPos.z
    if currHitZ > GAMEMODE.highestZ then
        GAMEMODE.highestZ = currHitZ

    end

    local currAreaZ = areasCenter.z
    if currAreaZ > GAMEMODE.highestAreaZ then
        GAMEMODE.highestAreaZ = currAreaZ

    end
end )

hook.Add( "glee_connectedgroups_visit", "glee_precache_navsurfacearea", function( area )
    local areasSurface = areasSurfaceArea( area )
    GAMEMODE.navmeshTotalSurfaceArea = GAMEMODE.navmeshTotalSurfaceArea + areasSurface

end )