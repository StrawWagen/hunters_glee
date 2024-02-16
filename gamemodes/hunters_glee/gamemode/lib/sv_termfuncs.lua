local coroutine_running = coroutine.running
local coroutine_yield = coroutine.yield

local minusFiveHundred = Vector( 0,0,-500 )
local minusOne = Vector( 0,0,-500 )

function GM:getFloor( pos )
    local Dat = {
        start = pos,
        endpos = pos + minusFiveHundred,
        mask = MASK_NPCWORLDSTATIC
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return pos end
    return Trace.HitPos, Trace
end

-- other cool function
function GM:getNearestNav( pos, distance )
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + minusFiveHundred,
        mask = MASK_NPCWORLDSTATIC
    }
    local Trace = util.TraceLine( Dat )
    if Trace.HitNonWorld then
        local isFunc = string.StartWith( Trace.Entity:GetClass(), "func_" )
        if not isFunc then return NULL end
    end
    local navArea = navmesh.GetNearestNavArea( pos, false, distance, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea

end

function GM:getNearestNavFloor( pos, distance, dropDistance )
    if not pos then return NULL end
    distance = distance or 2000
    dropDistance = dropDistance or distance
    local offset = minusOne * distance
    local Dat = {
        start = pos,
        endpos = pos + offset,
        mask = MASK_NPCWORLDSTATIC
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, distance, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea

end

-- cool function that lets us find nearest point on nav
function GM:getNearestPosOnNav( pos, distance )
    local distIn = distance or 2000
    local result = { pos = nil, area = NULL }
    if not pos then return result end
    local navFound = GAMEMODE:getNearestNav( pos, distIn )
    if not navFound then return result end
    if not navFound:IsValid() then return result end
    result = { pos = navFound:GetClosestPointOnArea( pos ), area = navFound }
    return result

end

local ladderOffset = 800000

local function AreaOrLadderGetID( areaOrLadder )
    if not areaOrLadder then return end
    if areaOrLadder.GetTop then
        -- never seen a navmesh with 800k areas
        return areaOrLadder:GetID() + ladderOffset

    else
        return areaOrLadder:GetID()

    end
end

local function getNavAreaOrLadderById( areaOrLadderID )
    local area = navmesh.GetNavAreaByID( areaOrLadderID )
    if area then
        return area

    end
    local ladder = navmesh.GetNavLadderByID( areaOrLadderID + -ladderOffset )
    if ladder then
        return ladder

    end
end

local function AreaOrLadderGetCenter( areaOrLadder )
    if not areaOrLadder then return end
    if areaOrLadder.GetTop then
        return ( areaOrLadder:GetTop() + areaOrLadder:GetBottom() ) / 2

    else
        return areaOrLadder:GetCenter()

    end
end

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

-- iterative function that finds connected area with the best score
-- areas with highest return from scorefunc are selected
-- areas that return 0 score from scorefunc are ignored
-- returns the best scoring area if it's further than dist or no other options exist
function GM:findValidNavResult( data, start, radius, scoreFunc, noMoreOptionsMin )
    local pos = nil
    local res = nil
    local cur = nil
    if isvector( start ) then
        pos = start
        res = GAMEMODE:getNearestPosOnNav( pos )
        cur = res.area

    elseif start and start.IsValid and start:IsValid() then
        pos = AreaOrLadderGetCenter( start )
        cur = start

    end
    if not cur or not cur:IsValid() then return nil, NULL, nil end
    local curId = AreaOrLadderGetID( cur )

    noMoreOptionsMin = noMoreOptionsMin or 8

    local opened = { [curId] = true }
    local closed = {}
    local openedSequential = {}
    local closedSequential = {}
    local distances = { [curId] = AreaOrLadderGetCenter( cur ):Distance( pos ) }
    local scores = { [curId] = 1 }
    local opCount = 0
    local isLadder = {}

    if cur.GetTop then
        isLadder[curId] = true

    end

    while not table.IsEmpty( opened ) do
        local bestScore = 0
        local bestArea = nil

        for _, currOpenedId in ipairs( openedSequential ) do
            local myScore = scores[currOpenedId]

            if isnumber( myScore ) and myScore > bestScore then
                bestScore = myScore
                bestArea = currOpenedId

            end
        end
        if not bestArea then
            _, bestArea = table.Random( opened )

        end

        opCount = opCount + 1

        local areaId = bestArea
        opened[areaId] = nil
        closed[areaId] = true
        -- table.removebyvalue fucking crashes the session
        for key, value in ipairs( openedSequential ) do
            if value == areaId then
                table.remove( openedSequential, key )
            end
        end
        table.insert( closedSequential, areaId )

        local area = getNavAreaOrLadderById( areaId )
        local myDist = distances[areaId]
        local noMoreOptions = #openedSequential == 1 and #closedSequential >= noMoreOptionsMin

        if noMoreOptions or opCount >= 300 then
            local _,bestClosedAreaId = table.Random( closed )
            local bestClosedScore = 0

            for _, currClosedId in ipairs( closedSequential ) do
                local currClosedScore = scores[currClosedId]

                if isnumber( currClosedScore ) and currClosedScore > bestClosedScore and isLadder[ currClosedId ] ~= true then
                    bestClosedScore = currClosedScore
                    bestClosedAreaId = currClosedId

                end
            end
            local bestClosedArea = navmesh.GetNavAreaByID( bestClosedAreaId )
            return bestClosedArea:GetCenter(), bestClosedArea, nil

        elseif myDist > radius and not area.GetTop then
            return area:GetCenter(), area, true

        end

        local adjacents = AreaOrLadderGetAdjacentAreas( area )

        for _, adjArea in ipairs( adjacents ) do
            local adjID = AreaOrLadderGetID( adjArea )

            if not closed[adjID] then

                local theScore = 0
                if area.GetTop or adjArea.GetTop then
                    -- just let the algorithm pass through this
                    theScore = scores[areaId]

                else
                    theScore = scoreFunc( data, area, adjArea )

                end
                if theScore <= 0 then continue end

                local adjDist = AreaOrLadderGetCenter( area ):Distance( AreaOrLadderGetCenter( adjArea ) )
                local distance = myDist + adjDist

                distances[adjID] = distance
                scores[adjID] = theScore
                opened[adjID] = true

                if adjArea.GetTop then
                    isLadder[adjID] = true

                end

                table.insert( openedSequential, adjID )

            end
        end
    end
end

local fiftyPowerOfTwo = 50^2
local vec12kZ = Vector( 0, 0, 12000 )
local vecNeg1K = Vector( 0, 0, -1000 )

function GM:IsUnderSky( pos )
    -- get the sky
    local skyTraceDat = {
        start = pos,
        endpos = pos + vec12kZ,
        mask = CONTENTS_SOLID,
    }
    local skyTraceResult = util.TraceLine( skyTraceDat )

    if skyTraceResult.HitSky then
        return true, skyTraceResult.HitPos

    elseif not skyTraceResult.Hit then
        return true, skyTraceResult.HitPos

    end
end

function GM:IsUnderDisplacement( pos )

    -- get the sky
    local firstTraceDat = {
        start = pos,
        endpos = pos + vec12kZ,
        mask = MASK_SOLID_BRUSHONLY,
    }
    local firstTraceResult = util.TraceLine( firstTraceDat )

    -- go back down
    local secondTraceDat = {
        start = firstTraceResult.HitPos,
        endpos = pos,
        mask = MASK_SOLID_BRUSHONLY,
    }
    local secondTraceResult = util.TraceLine( secondTraceDat )
    if secondTraceResult.HitTexture ~= "**displacement**" then return nil, nil end

    -- final check to make sure
    local thirdTraceDat = {
        start = pos,
        endpos = pos + vecNeg1K,
        mask = MASK_SOLID_BRUSHONLY,
    }
    local thirdTraceResult = util.TraceLine( thirdTraceDat )
    local isANestedDisplacement = thirdTraceResult.HitTexture == "**displacement**" and secondTraceResult.HitPos:DistToSqr( thirdTraceResult.HitPos ) > fiftyPowerOfTwo

    if thirdTraceResult.Hit and thirdTraceResult.HitTexture ~= "TOOLS/TOOLSNODRAW" and not isANestedDisplacement then return nil, true end -- we are probably under a displacement

    -- we are DEFINITely under one
    return true, nil

end

local underDisplacementOffset = Vector()

-- check the actual pos + visible spots nearby to truly know if a point is under a displacement
-- rather expensive! but it works!
function GM:IsUnderDisplacementExtensive( pos )
    local underBasic, underNested = self:IsUnderDisplacement( pos )
    if underBasic or underNested then return true end

    local traceStruct = {
        mask = MASK_SOLID_BRUSHONLY,
        start = pos,
    }
    for index = 1, 100 do
        -- check next to the pos to see if there's any empty space next to it
        underDisplacementOffset.x = math.Rand( -1, 1 ) * ( index^1.5 )
        underDisplacementOffset.y = math.Rand( -1, 1 ) * ( index^1.5 )
        local checkingPos = pos + underDisplacementOffset
        if not util.IsInWorld( checkingPos ) then continue end

        traceStruct.endpos = checkingPos

        local seePosResult = util.TraceLine( traceStruct )
        -- this way goes into a wall
        if seePosResult.Hit then continue end

        local checkingIsUnder, checkingIsNested = self:IsUnderDisplacement( checkingPos )
        if checkingIsUnder or checkingIsNested then return true end

    end
    return false

end

function GM:getFurthestConnectedNav( start, dist, ignoreBlocker )
    local res = GAMEMODE:getNearestPosOnNav( start, 20000 )
    local startArea = res.area

    if not startArea:IsValid() then return end

    local scoreData = {}
    scoreData.startPos = start
    scoreData.allowUnderwater = startArea:IsUnderwater()

    local scoreFunction = function( scoreData, area1, area2 )

        if area2:IsBlocked() and not ignoreBlocker then return 0 end

        local area2Center = area2:GetCenter()
        local distanceTravelled = area2Center:DistToSqr( scoreData.startPos )
        local score = distanceTravelled ^ math.Rand( 0.5, 1.5 ) --ree not random enough

        if area2:IsUnderwater() and not scoreData.allowUnderwater then
            score = 0
        end

        if not area2:IsConnected( area1 ) then
            score = 0
        end

        --debugoverlay.Text( area1:GetCenter(), math.Round( math.sqrt( score ) ), 40, false )

        return score

    end
    return GAMEMODE:findValidNavResult( scoreData, start, dist, scoreFunction )

end

local vec40Z = Vector( 0,0,40 )

function GM:GetNearbyWalkableArea( playerReference, start, count )
    local spawnTraceOffset = vec40Z
    local res = GAMEMODE:getNearestPosOnNav( start, 20000 )
    local startArea = res.area

    if not ( startArea and startArea.IsValid and startArea:IsValid() ) then return end
    local canBeUnderwater = startArea:IsUnderwater()
    local occupiedSpawnAreas = occupiedSpawnAreas or {}

    local scoreData = {}
    scoreData.startPos = res.pos
    scoreData.allowUnderwater = startArea:IsUnderwater()
    scoreData.traceOffset = spawnTraceOffset

    local scoreFunction = function( scoreData, area1, area2 )

        if occupiedSpawnAreas[area2:GetID()] then return 0 end
        if area2:IsUnderwater() and not canBeUnderwater then return 0 end

        local area2Center = area2:GetCenter()
        local distanceTravelled = area2Center:DistToSqr( scoreData.startPos )
        local score = distanceTravelled * math.Rand( 0.5, 1.5 )
        local traceOffset = scoreData.traceOffset

        if area2:IsUnderwater() and not scoreData.allowUnderwater then
            score = 1
        end
        if area2:GetSizeX() < 50 then
            score = 1
        end
        if area2:GetSizeY() < 50 then
            score = 1
        end

        if score > 0 then

            local startPos = area1:GetCenter() + traceOffset
            if area1 == startArea then
                startPos = playerReference:GetShootPos()
            end

            local traceData = {
                start = startPos,
                endpos = area2:GetCenter() + traceOffset,
                mask = CONTENTS_PLAYERCLIP
            }

            local trace = util.TraceLine( traceData )

            if trace.Hit or trace.StartSolid then return 0 end

        end

        --debugoverlay.Text( area2:GetCenter(), math.Round( math.sqrt( score ) ), 5, false  )

        return score

    end

    local radAdd = count * 100

    local outPos, outArea = GAMEMODE:findValidNavResult( scoreData, start, math.random( 300, 800 ) + radAdd, scoreFunction )

    if not outPos then return end

    local traceData = {
        start = playerReference:GetShootPos(),
        endpos = outPos + spawnTraceOffset,
        mask = CONTENTS_PLAYERCLIP
    }

    local trace = util.TraceLine( traceData )
    if trace.Hit then return end

    return outPos, outArea

end

function GM:getRemaining( num, curtime )
    return math.abs( num - curtime )
end

function GM:countAlive( stuff )
    local count = 0
    for _, curr in pairs( stuff ) do
        if curr:Health() > 0 then
            count = count + 1

        end
    end
    return count

end


function GM:returnAliveInTable( stuff )
    local aliveStuff = {}
    for _, curr in ipairs( stuff ) do
        if curr:Health() > 0 then
            table.insert( aliveStuff, curr )

        end
    end
    return aliveStuff

end

function GM:returnDeadInTable( stuff )
    local deadStuff = {}
    for _, curr in ipairs( stuff ) do
        if curr:Health() <= 0 then
            table.insert( deadStuff, curr )

        end
    end
    return deadStuff

end

function GM:returnWinnableInTable( stuff )
    local winnableStuff = {}
    for _, curr in pairs( stuff ) do
        if curr:Health() > 0 and not curr.glee_isUndead then
            table.insert( winnableStuff, curr )

        end
    end
    return winnableStuff
end

function GM:anotherAlivePlayer( block )
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() > 0 and ply ~= block then
            return ply

        end
    end
end

function GM:anAlivePlayer()
    local plys = self:getAlivePlayers()
    local randomPly = table.Random( plys )
    return randomPly

end

function GM:getDeadPlayers()
    local players = player.GetAll()
    local deadPlayers = GAMEMODE:returnDeadInTable( players )

    return deadPlayers

end

function GM:getAlivePlayers()
    local players = player.GetAll()
    local alivePlayers = GAMEMODE:returnAliveInTable( players )

    return alivePlayers

end

function GM:nearestAlivePlayer( pos )
    local nearestPlyDistSqr = math.huge
    local nearestPly = nil

    for _, alivePly in ipairs( GAMEMODE:getAlivePlayers() ) do
        local distToPlySqr = alivePly:GetPos():DistToSqr( pos )
        if distToPlySqr < nearestPlyDistSqr then
            nearestPlyDistSqr = distToPlySqr
            nearestPly = alivePly

        end
    end

    return nearestPly, nearestPlyDistSqr
end


function GM:CountWinnablePlayers()
    local aliveCount = 0
    for _, curr in pairs( player.GetAll() ) do
        if curr:Health() > 0 and not curr.glee_isUndead then
            aliveCount = aliveCount + 1

        end
    end
    return aliveCount
end


function GM:allPlayerShootPositions()
    local positions = {}
    for _, ply in ipairs( player.GetAll() ) do
        if ply:Health() <= 0 then continue end
        table.insert( positions, ply:GetShootPos() )
    end
    return positions

end

function GM:getNearestHunter( pos, hunters )
    hunters = hunters or table.Copy( GAMEMODE.termHunt_hunters )
    table.sort( hunters, function( a, b ) -- sort HUNTERS by distance to pos
        if not IsValid( a ) then return false end
        if not IsValid( b ) then return true end
        local ADist = a:GetShootPos():DistToSqr( pos )
        local BDist = b:GetShootPos():DistToSqr( pos )
        return ADist < BDist
    end )
    return hunters[1]
end

function GM:aRandomHunter( hunters )
    hunters = hunters or table.Copy( GAMEMODE.termHunt_hunters )

    table.Shuffle( hunters )

    for _, hunter in ipairs( hunters ) do
        if IsValid( hunter ) and hunter:Health() > 0 then
            return hunter

        end
    end
end

function GM:anyAreCloserThan( positions, checkPosition, closerThanDistance, zTolerance )
    for _, position in ipairs( positions ) do
        local tooClose = position:DistToSqr( checkPosition ) < closerThanDistance^2
        local zToleranceException = math.abs( position.z - checkPosition.z ) > zTolerance
        if tooClose and not zToleranceException then
            return true
        end
    end
end

function GM:speakAsHuntersGlee( msg )
    PrintMessage( HUD_PRINTTALK, "HUNTER'S GLEE: " .. msg )

end

function GM:Bleed( player, extent )
    local boneCount = math.Clamp( player:GetBoneCount(), 0, extent )
    local operationCount = boneCount * 0.5

    for _ = 0, operationCount do
        local randBoneIndex = math.random( 1, boneCount )
        local bonePos = player:GetBonePosition( randBoneIndex )
        if not bonePos then continue end
        local edata = EffectData()

        edata:SetOrigin( bonePos )
        edata:SetNormal( VectorRand() )
        edata:SetEntity( player )
        util.Effect( "BloodImpact", edata )

    end

end

function GM:connectionDistance( currArea, otherArea )
    local currCenter = currArea:GetCenter()

    local nearestInitial = otherArea:GetClosestPointOnArea( currCenter )
    local nearestFinal   = currArea:GetClosestPointOnArea( nearestInitial )
    nearestFinal.z = nearestInitial.z
    local distTo   = nearestInitial:DistToSqr( nearestFinal )
    return distTo, nearestFinal, nearestInitial

end

--CHATGPT funcs for making sure people dont fucking end up in "map teleport rooms"

function GM:GetConnectedNavAreaGroups( navAreas )
    local groups = {}

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

            -- mark the navarea as visited
            visited[navArea] = true

            -- find all connected navareas and add them to the group
            local queue = {}
            table.insert( queue, navArea )
            while #queue > 0 do
                local currentNavArea = table.remove( queue, 1 )
                for _, connectedNavArea in ipairs( currentNavArea:GetAdjacentAreas() ) do
                    if visited[connectedNavArea] then continue end
                    local connectedBothWays = connectedNavArea:IsConnected( currentNavArea ) and currentNavArea:IsConnected( connectedNavArea )
                    if not connectedBothWays then continue end
                    local eitherIsUnderwater = currentNavArea:IsUnderwater() or connectedNavArea:IsUnderwater()
                    if math.abs( currentNavArea:ComputeAdjacentConnectionHeightChange( connectedNavArea ) ) > 50 and not eitherIsUnderwater then continue end
                    -- add the connected navarea to the group
                    table.insert( group, connectedNavArea )

                    -- mark the connected navarea as visited
                    visited[connectedNavArea] = true

                    -- add the connected navarea to the queue to be processed
                    table.insert( queue, connectedNavArea )
                end
            end

            -- add the group to the list of groups
            table.insert( groups, group )
        end
    end

    return groups

end

-- loop thru all navarea groups to find the closest navarea to the current group, in every other group.
  -- specifically...
  -- for every navarea in every group, check the distance to navareas in every other group with navarea:GetClosestPointOnArea( otherAreasCenter )
  -- if the distance between the areas is smaller than the last distance, we have the new best distance to return
  -- at the end, the function should return a table of "navarea pairs" with this structure: linkageData = { linkageDistance = nil, linkageArea1 = nil, linkageArea2 = nil }

function GM:FindPotentialLinkagesBetweenNavAreaGroups( groups, maxLinksPerGroup )
    local doneGroupPairs = {}
    local groupLinkages = {}
    maxLinksPerGroup = maxLinksPerGroup or 5

    local firstGroups = groups

    local biggestGroup = GAMEMODE:GetLargestGroupOfNavareas( groups )
    if #biggestGroup > 50000 then -- too fat, just do the biggest one
        firstGroups = { biggestGroup }

    end

    for group1Id, group1 in ipairs( firstGroups ) do
        for group2Id, group2 in ipairs( groups ) do
            local biggestCompareGroup = group1Id
            local smallestCompareGroup = group2Id
            if #group2 > #group1 then
                biggestCompareGroup = group2Id
                smallestCompareGroup = group1Id
            end

            local key = biggestCompareGroup .. " " .. smallestCompareGroup
            local alreadyDone = doneGroupPairs[key]

            local quotaSquared = 2500^2

            if group1Id ~= group2Id and not alreadyDone then -- skip if checking the same group
                local currGroupLinkages = {} -- create an array to store linkages for each group pair
                for _, area1 in ipairs( group1 ) do
                    for _, area2 in ipairs( group2 ) do
                        -- dont even bother, too far
                        if area1:GetCenter():DistToSqr( area2:GetCenter() ) > quotaSquared then continue end
                        local dist, checkPos1, checkPos2 = GAMEMODE:connectionDistance( area1, area2 )

                        local linkage = { linkageDistance = dist, linkageArea1 = area1, linkageArea2 = area2, area1Closest = checkPos1, area2Closest = checkPos2 }
                        table.insert( currGroupLinkages, linkage )

                    end
                end
                -- sort linkages by distance in ascending order
                table.sort( currGroupLinkages, function( a, b ) return a.linkageDistance < b.linkageDistance end )

                local doneCount = 0

                -- only keep the maxLinksPerGroup closest linkages
                while #currGroupLinkages > maxLinksPerGroup and doneCount < 5000 do
                    doneCount = doneCount + 1
                    table.remove( currGroupLinkages )
                end

                table.Add( groupLinkages, currGroupLinkages )

                doneGroupPairs[key] = true

            end
        end
    end

    return groupLinkages

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
function GM:GetGroupThatNavareaExistsIn( navArea, navAreaGroups )
    -- iterate over each navarea group
    if istable( navAreaGroups ) then
        for _, group in ipairs( navAreaGroups ) do
            if coroutine_running() then
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
        for _, hunter in ipairs( GAMEMODE.termHunt_hunters ) do
            if IsValid( hunter ) then
                hunterRef = hunter

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

function GM:GetNavmeshGroupsWithPlayers()
    local bigGroups = GAMEMODE.biggestNavmeshGroups
    local alivePlayers = GAMEMODE:getAlivePlayers()

    if #alivePlayers <= 0 then return end

    local groupsWithPlayers = {}
    local doneGroups = {}

    for _, alivePly in ipairs( alivePlayers ) do
        if coroutine_running() then
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