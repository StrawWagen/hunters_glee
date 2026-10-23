local GAMEMODE = GAMEMODE or GM
GAMEMODE.isSkyOnMap = GAMEMODE.isSkyOnMap or nil
GAMEMODE.highestZ = GAMEMODE.highestZ or nil

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

function GM:BuildNavAreaReverseMap( groups )
    local map = {}
    for _, group in ipairs( groups ) do
        for _, navAreaInGroup in ipairs( group ) do
            map[navAreaInGroup] = group

        end
    end
    GAMEMODE.biggestNavmeshGroupsByArea = map

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
        randomSpawn = spawns[randomSpawnInd]
        if IsValid( randomSpawn ) then break end

    end

    -- choose a random navarea group
    local group = navAreaGroups[math.random( #navAreaGroups )]

    -- add a random sample of 30 navarea centers to the array
    for _ = 1, 150 do
        if #navAreaCenters > 30 then break end
        -- choose a random navarea from the group
        local navArea = group[math.random( #group )]
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
    if not istable( navAreaGroups ) then return end

    if navAreaGroups == GAMEMODE.biggestNavmeshGroups and GAMEMODE.biggestNavmeshGroupsByArea then
        return GAMEMODE.biggestNavmeshGroupsByArea[navArea]

    end

    -- fallback
    for _, group in ipairs( navAreaGroups ) do
        if yieldable then
            coroutine_yield()

        end
        if istable( group ) then
            for _, navAreaInGroup in ipairs( group ) do
                if navAreaInGroup == navArea then
                    return group

                end
            end
        end
    end
end

-- groups aren't rebuilt, so areas removed since they were built are NULL in them
-- with noUnderWater, falls back to an underwater area if all are underwater. nil if none are valid
local function randomValidArea( areas, noUnderWater )
    local area = areas[math.random( 1, #areas )]
    if IsValid( area ) and not ( noUnderWater and area:IsUnderwater() ) then return area end

    local clone = terminator_Extras.tableCopySimple( areas )
    local underwaterArea

    for remaining = #clone, 1, -1 do
        local pick = math.random( 1, remaining )
        area = clone[pick]
        clone[pick] = clone[remaining]

        if IsValid( area ) then
            if not noUnderWater or not area:IsUnderwater() then return area end
            underwaterArea = area

        end
    end
    return underwaterArea

end

function GM:GetRandomGroup( groups )
    return groups[math.random( 1, #groups )]

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
        local area = randomValidArea( bigGroupThatSomeoneIsIn, noUnderWater )
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


        local area = randomValidArea( bigGroupThatHunterIsIn, noUnderWater )
        return area, bigGroupThatHunterIsIn

    end

    -- nope, hunters aren't in big groups either, just a random area in a random big group
    ::getareainbigoroccupiedFail::

    local randBigGroup = bigGroups[math.random( 1, #bigGroups )]
    local randAreaInRandGroup = randomValidArea( randBigGroup, noUnderWater )
    return randAreaInRandGroup, randBigGroup

end

-- matches ALL flags in the mask
function GM:GetAreasInOccupiedGroupWithEFlag( flagMask )
    local allWithFlags = self:GetAreasWithEFlags( flagMask )
    if #allWithFlags <= 0 then return {} end

    local bigGroups = GAMEMODE.biggestNavmeshGroups
    if not bigGroups or #bigGroups <= 0 then
        local allWithFlagsSafe = terminator_Extras.tableCopySimple( allWithFlags )
        return allWithFlagsSafe

    end

    local _, occupiedGroup = self:GetAreaInOccupiedBigGroupOrRandomBigGroup()

    local groupLookup = {}
    for _, groupArea in ipairs( occupiedGroup ) do
        groupLookup[groupArea] = true

    end

    local result = {}
    for _, flagArea in ipairs( allWithFlags ) do
        if groupLookup[flagArea] then
            table.insert( result, flagArea )

        end
    end

    return result

end

function GM:GetNavmeshGroupsWithPlayers( yieldable )
    local bigGroups = GAMEMODE.biggestNavmeshGroups
    local alivePlayers = GAMEMODE:getAlivePlayers()

    if #alivePlayers <= 0 then return { GAMEMODE:GetRandomGroup( bigGroups ) } end

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
        if doneGroups[#bigGroupThatSomeoneIsIn] then continue end

        -- this can theoretically break, but i know it's very, very unlikely
        doneGroups[#bigGroupThatSomeoneIsIn] = true
        table.insert( groupsWithPlayers, bigGroupThatSomeoneIsIn )

    end
    return groupsWithPlayers

end


-- check if this map has all spawns in a separate room
function GM:TeleportRoomCheck()
    if not GAMEMODE.biggestNavmeshGroups or not GAMEMODE.navmeshGroups then
        GAMEMODE.navmeshGroups = GAMEMODE:GetConnectedNavAreaGroups( navmesh.GetAllNavAreas() )
        GAMEMODE.biggestNavmeshGroups = GAMEMODE:FilterNavareaGroupsForGreaterThanPercent( GAMEMODE.navmeshGroups, GAMEMODE.biggestGroupsRatio or 0.4 )
        GAMEMODE:BuildNavAreaReverseMap( GAMEMODE.biggestNavmeshGroups )

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
        permaPrint( reason ) -- log it
        huntersGlee_Announce( player.GetAll(), 1, 5, reason )

    end
end
