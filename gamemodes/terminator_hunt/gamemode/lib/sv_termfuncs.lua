function GM:doorIsUsable( door )
    local center = door:WorldSpaceCenter()
    local forward = door:GetForward()
    local starOffset = forward * 50
    local endOffset  = forward * 2

    local traceDatF = {
        mask = MASK_SOLID_BRUSHONLY,
        start = center + starOffset,
        endpos = center + endOffset
    }

    local traceDatB = {
        mask = MASK_SOLID_BRUSHONLY,
        start = center + -starOffset,
        endpos = center + -endOffset
    }

    local traceBack = util.TraceLine( traceDatB )
    local traceFront = util.TraceLine( traceDatF )

    local canSmash = not traceBack.Hit and not traceFront.Hit
    return canSmash

end

-- guess what this does
function GM:posCanSee( startPos, endPos )
    if not startPos then return end
    if not endPos then return end
    
    local mask = {
        start = startPos,
        endpos = endPos,
        mask = MASK_SOLID + CONTENTS_HITBOX,
    }
    local trace = util.TraceLine( mask )
    return not trace.Hit, trace

end

-- another mystery
function GM:dirToPos( startPos, endPos )
    if not startPos then return end
    if not endPos then return end

    return ( endPos - startPos ):GetNormalized()

end 

-- other cool function
function GM:getNearestNav( pos, distance )
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + Vector( 0,0,-500 ),
        mask = 131083
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

function GM:getNearestNavFloor( pos )
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + Vector( 0,0,-500 ),
        mask = 131083
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, 2000, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea

end

-- cool function that lets us find nearest point on nav
function GM:getNearestPosOnNav( pos, distance )
    local distIn = distance or 2000
    local result = { pos = nil, area = NULL }
    if not pos then return result end
    local navFound = GAMEMODE:getNearestNav( pos, distance )
    if not navFound then return result end
    if not navFound:IsValid() then return result end
    result = { pos = navFound:GetClosestPointOnArea( pos ), area = navFound }
    return result

end

-- iterative function that finds connected area with the best score
-- areas with highest return from scorefunc are selected
-- areas that return 0 score from scorefunc are ignored
-- returns the best scoring area if it's further than dist or no other options exist
function GM:findValidNavResult( data, start, radius, scoreFunc )
    local pos = start
    local res = GAMEMODE:getNearestPosOnNav( pos )
    local cur = res.area
    if not IsValid( cur ) then return end
    local curId = cur:GetID()

    local opened = { [curId] = true }
    local closed = {}
    local openedSequential = {}
    local closedSequential = {}
    local distances = { [curId] = cur:GetCenter():Distance( pos ) }
    local scores = { [curId] = 1 }
    local opCount = 0

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

        local area = navmesh.GetNavAreaByID( areaId )
        local myDist = distances[areaId]
        local noMoreOptions = #openedSequential == 1 and #closedSequential >= 2

        if noMoreOptions or opCount >= 300 then
            local _,bestClosedAreaId = table.Random( closed )
            local bestClosedScore = 0

            for _, currClosedId in ipairs( closedSequential ) do
                local currClosedScore = scores[currClosedId]

                if isnumber( currClosedScore ) and currClosedScore > bestClosedScore then
                    bestClosedScore = currClosedScore
                    bestClosedAreaId = currClosedId

                end
            end
            local bestClosedArea = navmesh.GetNavAreaByID( bestClosedAreaId )
            return bestClosedArea:GetCenter(), bestClosedArea

        elseif myDist > radius then
            return area:GetCenter(), area

        end

        for _, adjArea in ipairs( area:GetAdjacentAreas() ) do
            local adjID = adjArea:GetID()

            if not closed[adjID] then
                local adjDist = area:GetCenter():Distance( adjArea:GetCenter() )
                local distance = myDist + adjDist

                distances[adjID] = distance
                scores[adjID] = scoreFunc( data, area, adjArea )
                opened[adjID] = scores[adjID] > 0
                table.insert( openedSequential, adjID )

            end
        end
    end
end

function GM:getFurthestConnectedNav( start, dist, ignoreBlocker )
    local res = GAMEMODE:getNearestPosOnNav( start )
    local startArea = res.area

    if not startArea:IsValid() then return end

    local scoreData = {}
    scoreData.startPos = start
    scoreData.allowUnderwater = startArea:IsUnderwater()

    local scoreFunction = function( scoreData, area1, area2 )

        if area2:HasAttributes( NAV_MESH_NAV_BLOCKER ) and not ignoreBlocker then return 0 end

        local area2Center = area2:GetCenter()
        local distanceTravelled = area2Center:DistToSqr( scoreData.startPos )
        local score = distanceTravelled --ree not random enough

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

function GM:getRemaining( num, curtime )
    return math.abs( num - curtime )
end

function GM:countAlive( stuff ) 
    count = 0
    for _, curr in pairs( stuff ) do
        if curr:Alive() then
            count = count + 1

        end
    end
    return count 

end

function GM:allPlayerShootPositions()
    positions = {} 
    for _, ply in ipairs(player.GetAll()) do
        table.insert( positions, ply:GetShootPos() )
    end
    return positions

end

function GM:getNearestHunter( pos )
    local hunters = table.Copy( GAMEMODE.termHunt_hunters )
    table.sort( hunters, function( a, b ) -- sort HUNTERS by distance to curr area 
        if not IsValid( a ) then return false end
        if not IsValid( b ) then return true end 
        local ADist = a:GetShootPos():DistToSqr( pos )
        local BDist = b:GetShootPos():DistToSqr( pos )
        return ADist < BDist 
    end )
    return hunters[1]
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