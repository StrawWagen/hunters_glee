
local coroutine_yield = coroutine.yield

function GM:DoGreedyPatch()

    local doors = ents.FindByClass( "prop_door_rotating" )
    local doorPatches = 0

    for _, door in ipairs( doors ) do
        coroutine_yield()
        local patched = GAMEMODE:patchDoor( door )

        if patched then
            doorPatches = doorPatches + 1

        end
    end

    GAMEMODE:speakAsHuntersGlee( "Made " .. doorPatches .. " New navareas under doors." )

    --glasss
    local glasss = ents.FindByClass( "func_breakable_surf" )
    local breakables = ents.FindByClass( "func_breakable" )

    breakables = table.Add( breakables, glasss )

    local breakablePatches = 0

    for _, breakable in ipairs( breakables ) do
        coroutine_yield()

        local breakableNormal = GAMEMODE:seeIfBreakableAndGetNormal( breakable )
        if not breakableNormal then continue end

        local tooSmall, zHeight = GAMEMODE:breakableIsTooSmall( breakable, breakableNormal )
        if tooSmall then continue end

        local patched = GAMEMODE:patchBreakable( breakable, breakableNormal, zHeight )

        if patched then
            --debugoverlay.Cross( breakable:WorldSpaceCenter(), 20, 10, color_white, true )
            breakablePatches = breakablePatches + 1

        end
    end

    GAMEMODE:speakAsHuntersGlee( "Made " .. breakablePatches .. " New navareas in breakable windows/brushes." )

    local navmeshGroups, groupCorners = GAMEMODE:GetConnectedNavAreaGroups( navmesh.GetAllNavAreas() )

    GAMEMODE:speakAsHuntersGlee( "Understanding navmesh..." )

    local potentialLinkages = GAMEMODE:FindPotentialLinkagesBetweenNavAreaGroups( navmeshGroups, groupCorners, nil )

    GAMEMODE:speakAsHuntersGlee( "Patching..." )

    GAMEMODE:TakePotentialLinkagesAndLinkTheValidOnes( potentialLinkages )

    GAMEMODE:speakAsHuntersGlee( "Greedy navpatcher is... DONE!" )

    GAMEMODE.HuntersGleeDoneTheGreedyPatch = true

    coroutine_yield( "done" )

end

hook.Add( "glee_sv_validgmthink", "glee_managenavpatching", function( players )
    local playersToPatch = {}
    local addedPlayerCreationIds = {}
    -- we should always patch people being chased if we can!
    for _, ply in ipairs( players ) do
        local lowCount = #playersToPatch < 4
        if lowCount and ply.huntersGleeHunterThatIsTargetingPly then
            table.insert( playersToPatch, ply )
            addedPlayerCreationIds[ ply:GetCreationID() ] = true

        elseif not lowCount then
            break

        end
    end

    -- if there is still room in the table, add people not being chased
    if #playersToPatch < 4 then
        for _, ply in ipairs( players ) do
            local lowCount = #playersToPatch < 4
            if lowCount and not addedPlayerCreationIds[ ply:GetCreationID() ] then
                table.insert( playersToPatch, ply )

            elseif not lowCount then
                break

            end
        end
    end

    for _, ply in ipairs( playersToPatch ) do
        GAMEMODE:navPatchingThink( ply )

    end
end )

-- patches gaps in navmesh, using players as a guide
-- patches will never be ideal, but they will be better than nothing

local tooFarDistSqr = 40^2
local offGroundOffset = Vector( 0, 0, 20 )

function GM:navPatchingThink( ply )

    local badMovement = ply:GetMoveType() == MOVETYPE_NOCLIP or ply:Health() <= 0 or ply:GetObserverMode() ~= OBS_MODE_NONE or ply:InVehicle()

    if badMovement then ply.oldPatchingArea = nil return end

    local plyPos = ply:GetPos()

    local currArea, distToArea = ply:GetNavAreaData()
    if not currArea or not currArea:IsValid() then return end
    -- cant be sure of areas further away than this!
    if distToArea > tooFarDistSqr then return end
    -- cant see it!
    if not currArea:IsVisible( plyPos ) then return end

    local oldArea = ply.oldPatchingArea
    ply.oldPatchingArea = currArea

    if not oldArea or not oldArea:IsValid() then return end
    if currArea == oldArea then return end

    local currClosestPos = currArea:GetClosestPointOnArea( plyPos )
    local oldClosestPos = oldArea:GetClosestPointOnArea( plyPos )
    local zOverride = math.max( plyPos.z, oldClosestPos.z + 10, currClosestPos.z + 10 ) + 10 -- just check walls

    local plyPos2 = Vector( plyPos.x, plyPos.y, zOverride ) -- yuck
    currClosestPos.z = zOverride

    --debugoverlay.Line( plyPos2, currClosestPos, 5, Color(255,255,255), true )
    --print( plyPos2.z, currClosestPos.z, plyPos.z )

    if not terminator_Extras.PosCanSee( plyPos2, currClosestPos, MASK_SOLID_BRUSHONLY ) then return end

    local oldAreasCenter = oldArea:GetCenter()
    local currAreasCenter = currArea:GetCenter()

    -- dont create connections thru floors, specifcally a problem around elevators!
    if math.abs( currAreasCenter.z - oldAreasCenter.z ) > 50 then
        local check1Start = currAreasCenter + offGroundOffset
        local check1End = Vector( currAreasCenter.x, currAreasCenter.y, oldAreasCenter.z + 20 )
        local check1CanSee = terminator_Extras.PosCanSee( check1Start, check1End, MASK_SOLID_BRUSHONLY )

        local check2Start = oldAreasCenter + offGroundOffset
        local check2End = Vector( oldAreasCenter.x, oldAreasCenter.y, currAreasCenter.z + 20 )
        local check2CanSee = terminator_Extras.PosCanSee( check2Start, check2End, MASK_SOLID_BRUSHONLY )

        if not check1CanSee and not check2CanSee then return end

    end

    self:smartConnectionThink( oldArea, currArea )
    self:smartConnectionThink( currArea, oldArea )

end

-- see if the z of start area, to the check areas, is less then criteria
local function arePlanar( startArea, toCheckAreas, criteria )
    for _, currArea in ipairs( toCheckAreas ) do
        if startArea:IsConnected( currArea ) then
            local height = math.abs( startArea:ComputeAdjacentConnectionHeightChange( currArea ) )
            if height < criteria then return true end

        end

        local startAreaClosest = startArea:GetClosestPointOnArea( currArea:GetCenter() )
        local currAreaClosest = currArea:GetClosestPointOnArea( startAreaClosest )

        height = currAreaClosest.z - startAreaClosest.z
        height = math.abs( height )

        if height < criteria then return true end

    end
    return false
end

local function goodDist( distTo )
    local distQuota = 75
    local minCheck = -1
    local maxCheck = 1

    while distQuota < 400 do
        local min = distQuota + minCheck
        local max = distQuota + maxCheck
        min = min^2
        max = max^2

        if distTo > min and distTo < max then return true end
        distQuota = distQuota + 25

    end

    return nil

end

local function connectionDistance( currArea, otherArea )
    local currCenter = currArea:GetCenter()

    local nearestInitial = otherArea:GetClosestPointOnArea( currCenter )
    local nearestFinal   = currArea:GetClosestPointOnArea( nearestInitial )
    nearestFinal.z = nearestInitial.z
    local distToSqr   = nearestInitial:DistToSqr( nearestFinal )
    return distToSqr, nearestFinal, nearestInitial

end

-- do checks to see if connection from old area to curr area is a good idea, then connect it if so
function GM:smartConnectionThink( oldArea, currArea, ignorePlanar )
    if oldArea:IsConnected( currArea ) then return end

    -- get dist sqr and old area's closest point to curr area
    local distToSqr, _, currAreasClosest = connectionDistance( oldArea, currArea )

    if distToSqr > 55^2 and not goodDist( distToSqr ) then return end

    local pos1 = oldArea:GetClosestPointOnArea( currAreasClosest )
    local pos2 = currArea:GetClosestPointOnArea( pos1 )
    local criteria = math.abs( pos1.z - pos2.z ) + 25
    --debugoverlay.Cross( pos1, 50, 10, color_white, true )
    --debugoverlay.Cross( pos2, 100, 10, Color( 255,0,0 ), true )

    local navDirTakenByConnection = oldArea:ComputeDirection( pos2 )
    local areasInNavDir = oldArea:GetAdjacentAreasAtSide( navDirTakenByConnection )

    if not ignorePlanar then
        local areasAtSameZ = #areasInNavDir > 0 and arePlanar( currArea, areasInNavDir, criteria ) == true
        if areasAtSameZ then return end

    end

    oldArea:ConnectTo( currArea )

    return true

end

local vec_zero = Vector( 0, 0, 0 )
local IsValid = IsValid

-- loop thru all navarea groups to find the closest navarea to the current group, in every other group.
  -- specifically...
  -- for every navarea in every group, check the distance to navareas in every other group with navarea:GetClosestPointOnArea( otherAreasCenter )
  -- if the distance between the areas is smaller than the last distance, we have the new best distance to return
  -- at the end, the function should return a table of "navarea pairs" with this structure: linkageData = { linkageDistance = nil, linkageArea1 = nil, linkageArea2 = nil }

local distanceToJustIgnore = 750
local distanceToJustIgnoreSqr = distanceToJustIgnore^2
local groupDistToJustIgnore = ( distanceToJustIgnore * 2 )
local boxSize = Vector( distanceToJustIgnore, distanceToJustIgnore, distanceToJustIgnore )

function GM:FindPotentialLinkagesBetweenNavAreaGroups( groups, groupCorners, maxLinksPerGroup )

    -- yay! caching!
    local centers = {}
    local function areasCenter( area )
        local currCenter = centers[area]
        if currCenter then return currCenter end
        if not IsValid( area ) then return vec_zero end
        currCenter = area:GetCenter()

        centers[area] = currCenter
        return currCenter

    end

    local groupCenters = {}
    local function groupsCenter( groupsId, group )
        local groupsAveragePos = groupCenters[ groupsId ]
        if groupsAveragePos then return groupsAveragePos end

        for _, area in ipairs( group ) do
            if groupsAveragePos then
                groupsAveragePos = groupsAveragePos + areasCenter( area )

            else
                groupsAveragePos = areasCenter( area )

            end
        end

        if not groupsAveragePos then return vec_zero end
        groupsAveragePos = groupsAveragePos / #group

        groupCenters[ groupsId ] = groupsAveragePos
        return groupsAveragePos

    end

    local groupLinkages = {}
    local distToQuitAtSqr = 30^2

    local function addValidLinkages( group1, group2 )
        local currGroupLinkages = {} -- the potential links to sift through, picks the best ones after
        -- yahoo! caching!
        local tooFarAreas = {}

        for _, area1 in ipairs( group1 ) do
            if not area1:IsValid() then continue end
            coroutine_yield()
            local perfectConnectionCount = 0

            for _, area2 in ipairs( group2 ) do
                if not area2:IsValid() then continue end
                coroutine_yield()

                local area2sId = area2:GetID()

                -- was cached as too far
                if tooFarAreas[ area2sId ] then continue end

                local distBetweenSqr = areasCenter( area1 ):DistToSqr( areasCenter( area2 ) )

                -- dont even bother, too far
                if distBetweenSqr > distanceToJustIgnoreSqr then
                    tooFarAreas[ area2sId ] = true
                    local adjAreas = area2:GetAdjacentAreas()
                    for _, adjArea in ipairs( adjAreas ) do
                        tooFarAreas[ adjArea:GetID() ] = true

                    end
                    continue

                end
                local distToSqr, checkPos1, checkPos2 = connectionDistance( area1, area2 )

                local linkage = { linkageDistance = distToSqr, linkageArea1 = area1, linkageArea2 = area2, area1Closest = checkPos1, area2Closest = checkPos2 }
                table.insert( currGroupLinkages, linkage )

                if distToSqr < distToQuitAtSqr then
                    perfectConnectionCount = perfectConnectionCount + 1

                end
                if perfectConnectionCount > 10 then
                    break

                end
            end
        end

        -- sort linkages by distance in ascending order, best ones first, worst ones last
        table.sort( currGroupLinkages, function( a, b ) return a.linkageDistance < b.linkageDistance end )

        local doneCount = 0

        -- only keep the maxLinksPerGroup closest linkages
        while #currGroupLinkages > maxLinksPerGroup and doneCount < 5000 do
            doneCount = doneCount + 1
            -- remove the worst linkage
            local removed = table.remove( currGroupLinkages )
            -- all the distances left are ideal, not pass
            if removed.linkageDistance < distToQuitAtSqr then break end

        end

        --for _, link in ipairs( currGroupLinkages ) do
            --debugoverlay.Line( link.area1Closest, link.area2Closest, 20, color_white, true )

        --end

        table.Add( groupLinkages, currGroupLinkages )

    end

    local doneGroupPairs = {}
    local miniGroupSize = 15

    maxLinksPerGroup = maxLinksPerGroup or 5

    for group1Id, group1 in ipairs( groups ) do
        local group1Size = #group1
        -- small group! just check proximity, dont waste time checking every pair
        if group1Size < miniGroupSize then
            coroutine_yield()
            local group1Ids = {}
            for _, area in ipairs( group1 ) do
                if not IsValid( area ) then continue end
                group1Ids[ area:GetID() ] = true

            end

            local groups1Center = groupsCenter( group1Id, group1 )
            local foundInTheBox = navmesh.FindInBox( groups1Center + boxSize, groups1Center - boxSize )
            local fauxGroup2 = {}
            for _, found in ipairs( foundInTheBox ) do
                if not group1Ids[ found:GetID() ] then
                    table.insert( fauxGroup2, found )

                end
            end

            if #fauxGroup2 <= 0 then continue end

            addValidLinkages( group1, fauxGroup2 )
            --print( tostring( group1Id ) .. " " .. tostring( group1Size ), "mini" )
            continue

        end

        for group2Id, group2 in ipairs( groups ) do
            coroutine_yield()
            -- cant connect a group to itself
            if group1Id == group2Id then continue end

            local group2Size = #group2

            -- this was already handled, or will be handled!
            if group2Size < miniGroupSize then continue end

            local biggestCompareGroup = group1Id
            local smallestCompareGroup = group2Id
            if group2Size > group1Size then
                biggestCompareGroup = group2Id
                smallestCompareGroup = group1Id
            end

            local key = biggestCompareGroup .. " " .. smallestCompareGroup
            local alreadyDone = doneGroupPairs[key]

             -- already checked this group pair!
            if alreadyDone then continue end

            -- ignore groups if they're nowhere near eachother
            local areCloseEnough
            local group1sCenter = groupsCenter( group1Id, group1 )
            local group2sCenter = groupsCenter( group2Id, group2 )

            local group1sCorners = groupCorners[group1Id]
            local group2sCorners = groupCorners[group2Id]
            -- check if any two corners are close enough for us to patch these
            for ind1 = 0, 3 do
                local cornerOf1 = group1sCorners[ind1]
                local corner1DistToCenter = cornerOf1:Distance( group1sCenter )
                for ind2 = 0, 3 do
                    local cornerOf2 = group2sCorners[ind2]
                    local corner2DistToCenter = cornerOf2:Distance( group2sCenter )
                    local distSqr = cornerOf1:DistToSqr( cornerOf2 )
                    local distNeeded = groupDistToJustIgnore + ( corner1DistToCenter * 0.5 ) + ( corner2DistToCenter * 0.5 )
                    if distSqr < distNeeded^2 then
                        areCloseEnough = true
                        break
                    end
                end
                if areCloseEnough then
                    break
                end
            end

            if not areCloseEnough then continue end

            --print( tostring( group1Id ) .. " " .. tostring( group1Size ), tostring( group2Id ) .. " " .. tostring( group2Size ) )
            addValidLinkages( group1, group2 )

            doneGroupPairs[key] = true

        end
    end

    return groupLinkages

end


local offsets = {
    Vector( 0,0,10 ),
    Vector( 0,0,25 ),
    Vector( 0,0,35 ),
    Vector( 0,0,45 ),
    Vector( 0,0,55 )

}

local powTwo200 = 200^2

local function connectionDataVisOffsetCheck( currentData )
    -- find the actual nearest 2 spots on the area
    local area1Closest = Vector( 0, 0, 0 )
    local area2Closest = Vector( 0, 0, 0 )
    area1Closest:Set( currentData.area1Closest )
    area2Closest:Set( currentData.area2Closest )

    --debugoverlay.Line( area1Closest, area2Closest, 120, Color( 255,255,255 ), true )

    if not currentData.linkageArea1 then return end
    if not currentData.linkageArea2 then return end

    area1Closest.z = currentData.linkageArea1:GetClosestPointOnArea( currentData.area2Closest ).z
    area2Closest.z = currentData.linkageArea2:GetClosestPointOnArea( currentData.area1Closest ).z

    local visibleCount = 0
    for _, offset in ipairs( offsets ) do
        if not terminator_Extras.PosCanSee( area1Closest + offset, area2Closest + offset, MASK_SOLID ) then continue end
        --debugoverlay.Line( area1Closest + offset, area2Closest + offset, 120, Color( 255,255,255 ), true )
        visibleCount = visibleCount + 1

    end
    return visibleCount

end

function GM:TakePotentialLinkagesAndLinkTheValidOnes( groupLinkages )

    local linkedCount = 0

    for _, currentData in ipairs( groupLinkages ) do
        if not currentData then continue end
        if currentData.linkageDistance > powTwo200 then continue end -- discard linkages that are definitely too far
        if math.abs( currentData.linkageArea1:GetCenter().z - currentData.linkageArea1:GetCenter().z ) > 400 then continue end

        if connectionDataVisOffsetCheck( currentData ) <= 3 then continue end
        --debugoverlay.Line( currentData.area1Closest, currentData.area2Closest, 120, Color( 255,255,255 ), true )

        if GAMEMODE:smartConnectionThink( currentData.linkageArea1, currentData.linkageArea2 ) then
            linkedCount = linkedCount + 1

        end
        if GAMEMODE:smartConnectionThink( currentData.linkageArea2, currentData.linkageArea1 ) then
            linkedCount = linkedCount + 1

        end
    end

    GAMEMODE:speakAsHuntersGlee( "Success! Made " .. linkedCount .. " New links between orphan areas" )

end

function GM:PlaceANavAreaUnderDoor( door )
    local center = door:WorldSpaceCenter()
    local forward = door:GetForward()
    local right = door:GetRight()

    local corner1 = center + ( forward * 8 ) + ( right * 15 )
    local corner2 = center + ( -forward * 8 ) + ( -right * 15 )

    corner1 = GAMEMODE:getFloor( corner1 )
    corner2 = GAMEMODE:getFloor( corner2 )

    local newArea = navmesh.CreateNavArea( corner1, corner2 )

    --debugoverlay.Cross( corner1, 10, 40, Color( 255,0,0 ), true )
    --debugoverlay.Cross( corner2, 10, 40, Color( 255,0,0 ), true )

    return true, newArea

end

function GM:patchDoor( door )
    local dividesNavmesh, behindNav, inFrontNav, navsWeCovered = GAMEMODE:doesDoorNeedANewNavArea( door )
    if dividesNavmesh then
        local patched, createdArea = GAMEMODE:PlaceANavAreaUnderDoor( door )
        if not patched then return end

        local overlaps, areaThatOverlaps = GAMEMODE:anyAreasOverlapStrict( createdArea, navsWeCovered )

        -- ok we made the area, now doubleee check to see if it overlaps any areas.
        if overlaps then
            createdArea:Remove()
            createdArea = areaThatOverlaps

        end

        if not createdArea or not createdArea.IsValid or not createdArea:IsValid() then return end

        self:smartConnectionThink( createdArea, behindNav, true )
        self:smartConnectionThink( behindNav, createdArea, true )

        self:smartConnectionThink( createdArea, inFrontNav, true )
        self:smartConnectionThink( inFrontNav, createdArea, true )

        return patched

    end
end

local down = Vector( 0,0,-1 )

function GM:PlaceANavAreaUnderBreakable( breakable, breakableForward, isCrouch )
    local center = breakable:WorldSpaceCenter()
    center = GAMEMODE:getFloor( center )

    local forward = breakableForward
    local right = breakableForward:Cross( down )

    local corner1 = center + ( forward * 10 ) + ( right * 15 )
    local corner2 = center + ( -forward * 10 ) + ( -right * 15 )

    local newArea = navmesh.CreateNavArea( corner1, corner2 )

    if isCrouch then
        newArea:SetAttributes( NAV_MESH_CROUCH )

    end

    --debugoverlay.Cross( corner1, 10, 40, Color( 255,0,0 ), true )
    --debugoverlay.Cross( corner2, 10, 40, Color( 255,0,0 ), true )

    return true, newArea

end

function GM:patchBreakable( breakable, breakableNormal, zHeight )

    local breakableExtent = 10 -- find a path between areas thats simpler than this
    local isCrouch = zHeight < 68

    local _, behindNav, inFrontNav, navsWeCovered = GAMEMODE:doesEntDivideNavmesh( breakable, breakableNormal, breakableExtent )

    if not navsWeCovered then return end

    local breakableRight = breakableNormal:Angle():Right()
    local dividesNavmesh = GAMEMODE:noAreasThatCrossThis( breakable:WorldSpaceCenter(), breakableRight, breakable, navsWeCovered )

    if dividesNavmesh ~= true then return end

    local patched, createdArea = GAMEMODE:PlaceANavAreaUnderBreakable( breakable, breakableNormal, isCrouch )
    if not patched then return end

    -- ok we made the area, now double check to see if it overlaps any areas.
    local overlaps, areaThatOverlaps = GAMEMODE:anyAreasOverlapStrict( createdArea, navsWeCovered )

    -- overlaps!
    if overlaps then
        createdArea:Remove()
        createdArea = areaThatOverlaps

        -- didnt actually patch anything
        patched = false

    end

    if not createdArea or not createdArea.IsValid or not createdArea:IsValid() then return end

    self:smartConnectionThink( createdArea, behindNav, true )
    self:smartConnectionThink( behindNav, createdArea, true )

    self:smartConnectionThink( createdArea, inFrontNav, true )
    self:smartConnectionThink( inFrontNav, createdArea, true )

    return patched

end



-- take a prop_door_rotating,
-- get two positions, one behind the door, and one in front
-- we then use both of those to get the navareas on either side of the door
-- we then explore the navmesh starting at one of the areas on the side of the door
-- if we reach the opposite side of the door within 10 navareas then the door doesn't need a navarea, return false
-- return true

local searchDist = 4

function GM:doesEntDivideNavmesh( ent, entNormal, maxConnectionExtent )
    -- check if there's a navarea directly under the ent's world space center
    local center = ent:WorldSpaceCenter()

    -- get positions behind and in front of the ent
    local behindEntPos = center + entNormal * -40
    local inFrontEntPos = center + entNormal * 40

    -- get the navareas on either side of the ent
    local behindNav = GAMEMODE:getNearestNavFloor( behindEntPos, searchDist * 2, 500 )
    local inFrontNav = GAMEMODE:getNearestNavFloor( inFrontEntPos, searchDist * 2, 500 )
    --debugoverlay.Cross( behindEntPos, 4, 40, Color( 255,255,255 ), true )
    --debugoverlay.Cross( inFrontEntPos, 4, 40, Color( 255,255,255 ), true )

    local behindIsGood = behindNav and behindNav.IsValid and behindNav:IsValid()
    local frontIsGood = inFrontNav and inFrontNav.IsValid and inFrontNav:IsValid()

    local validAndAreasAreNotSame = behindIsGood and frontIsGood and behindNav ~= inFrontNav

    if validAndAreasAreNotSame then

        local frontNavCenter = inFrontNav:GetCenter()

        -- explore the navmesh starting at one of the areas on the side of the ent
        local open = {}
        local closed = {}
        local navsWeCovered = { inFrontNav, behindNav }
        table.insert( open, behindNav )

        local ops = 0

        while #open > 0 do
            ops = ops + 1
            -- they are not connected via a short path, return end
            if ops >= maxConnectionExtent then return true, behindNav, inFrontNav, navsWeCovered end

            table.sort( open, function( areaA, areaB )
                local areaADist = areaA:GetCenter():DistToSqr( frontNavCenter )
                local areaBDist = areaB:GetCenter():DistToSqr( frontNavCenter )
                return areaADist < areaBDist

            end )

            local currentNav = table.remove( open, 1 )
            --debugoverlay.Cross( currentNav:GetCenter(), 5, 40, Color( 255, 255, 255 ), true )

            if currentNav == inFrontNav then
                --debugoverlay.Cross( currentNav:GetCenter(), 10, 40, Color( 0, 0, 255 ), true )
                return false, behindNav, inFrontNav, navsWeCovered

            end

            table.insert( closed, currentNav )

            local areasToCheck = table.Add( currentNav:GetAdjacentAreas(), currentNav:GetIncomingConnections() )

            for _, adjacentNav in ipairs( areasToCheck ) do
                if not table.HasValue( closed, adjacentNav ) and not table.HasValue( open, adjacentNav ) then
                    table.insert( open, adjacentNav )
                    table.insert( navsWeCovered, adjacentNav )

                end
            end
        end
        return true, behindNav, inFrontNav, navsWeCovered

    else
        return

    end
end

function GM:noAreasThatCrossThis( pos, right, reference, navsToCheck )

    -- navareas are often not exactly aligned to the center of the thing
    local doorPos1 = pos + right * 10
    local doorPos2 = pos + right * -10
    local doorMin, doorMax = reference:WorldSpaceAABB()

    for _, checkNav in ipairs( navsToCheck ) do

        local targZ = checkNav:GetCenter().z
        -- give some wiggle room
        local maxZ = doorMax.z + 20
        local minZ = doorMin.z + -20

        -- this navarea is directly under the thing
        local contains = checkNav:Contains( doorPos1 ) or checkNav:Contains( doorPos2 ) or checkNav:Contains( pos )
        -- is the navarea on another floor?
        local reasonableZ = targZ > minZ and targZ < maxZ

        if contains and reasonableZ then
            --debugoverlay.Cross( doorPos1, 100, 60, Color( 255,255,255 ), true )
            return false

        end
    end
    return true

end

function GM:anyAreasOverlapStrict( crossArea, navsToCheck )
    local reference = crossArea:GetCenter()

    for _, checkNav in ipairs( navsToCheck ) do

        local targ = checkNav:GetCenter()
        local targZ = targ.z
        -- give some wiggle room
        local maxZ = reference.z + 10
        local minZ = reference.z + -10

        -- is it directly inside the other thing?
        local contains = checkNav:IsOverlappingArea( crossArea )
        -- is on the same Z as it?
        local reasonableZ = targZ > minZ and targZ < maxZ

        if contains and reasonableZ then
            --debugoverlay.Cross( targ, 100, 60, Color( 255,0,0 ), true )
            return true, checkNav

        end
    end
    return nil

end

function GM:doesDoorNeedANewNavArea( door )
    if not util.doorIsUsable( door ) then return end
    -- assume door divides navmesh

    local doorExtent = 50
    -- do our best to find areas that already go under the door
    local _, behindNav, inFrontNav, navsWeCovered = GAMEMODE:doesEntDivideNavmesh( door, door:GetForward(), doorExtent )

    if not navsWeCovered then return end

    local doorRight = door:GetRight()
    local doorPos = door:WorldSpaceCenter()

    local dividesNavmesh = GAMEMODE:noAreasThatCrossThis( doorPos, doorRight, door, navsWeCovered )

    if dividesNavmesh ~= true then return end

    return dividesNavmesh, behindNav, inFrontNav, navsWeCovered

end

local ang_zero = Angle()

function GM:breakableIsTooSmall( breakable, breakableForward )
    local breakableAng = breakableForward:Angle()
    local mins, maxs = breakable:WorldSpaceAABB()

    mins = WorldToLocal( mins, ang_zero, breakable:WorldSpaceCenter(), breakableAng )
    maxs = WorldToLocal( maxs, ang_zero, breakable:WorldSpaceCenter(), breakableAng )

    local yAdded = math.abs( mins.y ) + math.abs( maxs.y )
    local zAdded = math.abs( mins.z ) + math.abs( maxs.z )

    local tooThin = yAdded < 32
    local tooShort = zAdded < 45
    local isBad = tooThin or tooShort
    return isBad, zAdded

end

local offsetsToCheck = {
    Vector( 100, 0, 0 ),
    Vector( -100, 0, 0 ),
    Vector( 0, 100, 0 ),
    Vector( 0, -100, 0 ),
    Vector( 0, 0, 100 ),
    Vector( 0, 0, -100 ),
}

function GM:seeIfBreakableAndGetNormal( breakable )
    local pos = breakable:WorldSpaceCenter()
    for _, offset in ipairs( offsetsToCheck ) do
        local trStruct = {
            start = pos + offset,
            endpos = pos,
        }
        --debugoverlay.Line( trStruct.start, trStruct.endpos, 60 )

        local traceResult = util.TraceLine( trStruct )

        if not traceResult.Hit then continue end
        if traceResult.StartSolid then continue end
        if traceResult.Entity ~= breakable then continue end

        return traceResult.HitNormal

    end
end
