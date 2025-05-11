AddCSLuaFile()

ENT.Type = "point"
ENT.Base = "base_point"

ENT.Category    = "Other"
ENT.PrintName   = "Fog emitter"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Heavy fog that sticks to the floor"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

ENT.fogAreasManaging = {}
ENT.fogAreasLevels = {}
ENT.fogAreasManagingLookup = {}
ENT.maxFogAreaDepths = {}
ENT.fogSkips = {}

ENT.OriginNavArea = nil

ENT.EvaporationRate = 1
ENT.SpreadingMultiplier = 0.5 -- sloshy or gooey
ENT.FogVolume = 300 * 1000 * 1000

local function canSpreadSimple( area1, area2 )
    if math.abs( area1:ComputeGroundHeightChange( area2 ) ) > 65 then return end
    return true

end

local function getNearestNavFloor( pos, radius )
    radius = radius or 2000
    if not pos then return NULL end
    local Dat = {
        start = pos,
        endpos = pos + Vector( 0,0,-500 ),
        mask = MASK_SOLID
    }
    local Trace = util.TraceLine( Dat )
    if not Trace.HitWorld then return NULL end
    local navArea = navmesh.GetNearestNavArea( Trace.HitPos, false, radius, false, true, -2 )
    if not navArea then return NULL end
    if not navArea:IsValid() then return NULL end
    return navArea
end

local function GetSurfaceArea( area )
    return area:GetSizeX() * area:GetSizeY()

end

function ENT:Initialize()
    local navArea = getNearestNavFloor( self:GetPos() )
    if not navArea or not navArea.IsValid then return end

    local adjAreas = navArea:GetAdjacentAreas()
    local biggestSurfaceArea = GetSurfaceArea( navArea )

    local bestPotArea = nil

    for _, potArea in ipairs( adjAreas ) do
        local surfaceArea = GetSurfaceArea( potArea )
        if surfaceArea > biggestSurfaceArea and canSpreadSimple( navArea, potArea ) then
            bestPotArea = potArea
            biggestSurfaceArea = surfaceArea

        end
    end

    navArea = bestPotArea or navArea

    print( navArea, "a", bestPotArea )

    self.OriginNavArea = navArea
    self:AddAreaToFog( navArea )

end

local insert_Local = table.insert

function ENT:GetAreasMaxFogDepth( area, id )
    id = id or area:GetID()
    local cachedDepth = self.maxFogAreaDepths[id]
    if cachedDepth then return cachedDepth end

    local center = area:GetCenter()

    local dat = {
        start = center + Vector( 0,0,10 ),
        endpos = center + Vector( 0,0,1000 ),
        mask = MASK_SOLID_BRUSHONLY
    }

    local trace = util.TraceLine( dat )
    local depth = center:Distance( trace.HitPos )
    if trace.HitSky then
        depth = 1000
    end
    self.maxFogAreaDepths[id] = depth
    return depth

end


function ENT:SkipAdd( skipStart, skipEnd )
    local oldSkips = self.fogSkips[skipStart:GetID()] or {}
    local noDo = nil
    for _, skip in ipairs( oldSkips ) do
        if skip == skipEnd then noDo = true break end
    end
    if not noDo then
        insert_Local( oldSkips, skipEnd )
        self.fogSkips[skipStart:GetID()] = oldSkips

    end
end

local fourDirections = {
    Vector( 1, 0, 0 ),
    Vector( 0, 1, 0 ),
    Vector( -1, 0, 0 ),
    Vector( 0, -1, 0 ),

}

function ENT:SkipsCheck( navArea )
    local mySurfaceArea = GetSurfaceArea( navArea )
    local neighbors = navArea:GetAdjacentAreas()

    local skipStart = nil
    local skipEnd = nil
    for _, potentialNeighbor in ipairs( neighbors ) do
        local neighborArea = GetSurfaceArea( potentialNeighbor )
        if not skipStart then
            if neighborArea * 0.5 > mySurfaceArea then
                skipStart = potentialNeighbor

            end
        elseif not skipEnd then
            if neighborArea * 0.5 > mySurfaceArea then
                skipEnd = potentialNeighbor
                break

            end
        end
    end
    if skipStart and skipEnd then
        self:SkipAdd( skipStart, skipEnd )
        self:SkipAdd( skipEnd, skipStart )

    end

    local traceStart = navArea:GetCenter()
    local added = {}

    for _ = 1, 3 do
        traceStart = traceStart + Vector( 0, 0, 25 )
        for _, direction in ipairs( fourDirections ) do
            local trDat = {
                start = traceStart,
                endpos = traceStart + direction * 200,
                mask = MASK_SHOT
            }

            local traceResult = util.TraceLine( trDat )
            local nearestNavFloor = getNearestNavFloor( traceResult.HitPos, 5 ) -- high precision get areas that are off cliffs

            if nearestNavFloor and nearestNavFloor.IsValid and nearestNavFloor:IsValid() and not added[ nearestNavFloor:GetID() ] and nearestNavFloor ~= navArea then
                added[ nearestNavFloor:GetID() ] = true
                self:SkipAdd( navArea, nearestNavFloor )
            end
        end
    end

end

function ENT:GetSkips( area, id )
    id = id or area:GetID()
    return self.fogSkips[id] or {}

end


function ENT:AddAreaToFog( navArea )

    self:SkipsCheck( navArea )

    local id = navArea:GetID()
    if self.fogAreasManagingLookup[id] == true then return end
    self.fogAreasManagingLookup[id] = true
    insert_Local( self.fogAreasManaging, navArea )
    self:SetAreaLocalFogLevel( id, 0 )

    return true

end

function ENT:RemoveAreaFromFog( areaToRemove, id )
    id = id or areaToRemove:GetID()
    self.fogAreasManagingLookup[id] = nil
    self.fogAreasLevels[id] = nil
    for currIndex, currArea in ipairs( self.fogAreasManaging ) do
        if currArea == areaToRemove then
            table.remove( self.fogAreasManaging, currIndex )
            break
        end
    end
end

function ENT:SetAreaLocalFogLevel( areaId, localLevel )
    self.fogAreasLevels[ areaId ] = localLevel

end

function ENT:GetAreaLocalFogLevel( areaId )
    return self.fogAreasLevels[ areaId ] or 0

end

function ENT:AreaLocalLevelToWorld( area, localLevel )
    local globalLevel = nil
    if area then
        globalLevel = localLevel + area:GetCenter().z

    end
    return globalLevel

end

function ENT:GetFogLevels( area )
    if not area or not area.IsValid then return end
    local localLevel = self:GetAreaLocalFogLevel( area:GetID() )
    return self:AreaLocalLevelToWorld( area, localLevel ), localLevel

end

function ENT:Area2HasHigherFog( area1, area2 )
    if not area1 or not area2 then return end
    if not area1.IsValid or not area2.IsValid then return end
    local area1ID = area1:GetID()
    local area2ID = area2:GetID()

    local area1LocalLevel = self:GetAreaLocalFogLevel( area1ID )
    local area2LocalLevel = self:GetAreaLocalFogLevel( area2ID )

    if self:AreaLocalLevelToWorld( area2, area2LocalLevel ) > self:AreaLocalLevelToWorld( area1, area1LocalLevel ) then return true end
    return false

end

function ENT:EqualizeGlobalFogLevel( area1, area2, spreadingMultipler )
    -- get the local and global fog levels
    local area1GlobalFogLevel, area1LocalFogLevel = self:GetFogLevels( area1 )
    local area2GlobalFogLevel, area2LocalFogLevel = self:GetFogLevels( area2 )

    -- get the difference between the global fog levels
    local fogLevelDifference = area1GlobalFogLevel - area2GlobalFogLevel
    fogLevelDifference = fogLevelDifference * spreadingMultipler

    --print( area1LocalFogLevel, area2LocalFogLevel, fogLevelDifference )

    --debugoverlay.Text( area2:GetCenter(), fogLevelDifference, 1 )

    -- if the difference is less than or equal to a certain threshold, we don't need to do anything
    if math.abs( fogLevelDifference ) <= 0.01 then
        return
    end

    local area1ID = area1:GetID()
    local area2ID = area2:GetID()

    -- Get the Surface area of each area
    local area1SurfaceArea = GetSurfaceArea( area1 )
    local area2SurfaceArea = GetSurfaceArea( area2 )
    local totalSurfaceArea = area1SurfaceArea + area2SurfaceArea
    local area1Percent = area1SurfaceArea / totalSurfaceArea
    local area2Percent = area2SurfaceArea / totalSurfaceArea

    --Calculate the amount of fog that each area should recieve
    local area1New = area1LocalFogLevel - fogLevelDifference * area2Percent
    local area2New = area2LocalFogLevel + fogLevelDifference * area1Percent

    -- Correct for negative values
    local area1Bite = area1New - math.max( area1New, 0 )
    local area2Bite = area2New - math.max( area2New, 0 )
    area1New = area1New + area2Bite
    area2New = area2New + area1Bite
    area1New = math.max( area1New, 0 )
    area2New = math.max( area2New, 0 )

    area1New = math.min( area1New, self:GetAreasMaxFogDepth( area1, area1ID ) )
    area2New = math.min( area2New, self:GetAreasMaxFogDepth( area2, area2ID ) )

    -- Update the fog levels
    self:SetAreaLocalFogLevel( area1ID, area1New )
    self:SetAreaLocalFogLevel( area2ID, area2New )

end



-- fog base think
-- every second, go thru all areas we're managing
    -- check 50% of areas to see if their fog can spread to neighbors
    -- use generic function self:EqualizeFogLevels( area, neighbor )
    -- this function just takes areas, and equalizes their global fog level

local add_Local = table.Add
local abs_Local = math.abs
local coroutine_status = coroutine.status
local coroutine_yield = coroutine.yield
local coroutine_resume = coroutine.resume

local function doFogEntThink( self, evaporationRate, spreadingMultipler )
    local addedSurfaceArea = 0
    local maxAdded = 250000

    for _, currArea in ipairs( self.fogAreasManaging ) do
        coroutine_yield()
        local currAreaId = currArea:GetID()
        local currLocalFogLevel = self:GetAreaLocalFogLevel( currAreaId )
        local doSpread = nil
        local doEqualize = true
        local doNeighborThink = true
        local doExitTheSystem = nil

        local globalLevel = self:GetFogLevels( currArea )
        local pos = currArea:GetCenter()
        pos.z = globalLevel
        --debugoverlay.Cross( pos, 5, 1, Color( 255,255,255 ), true )

        currLocalFogLevel = currLocalFogLevel + -evaporationRate

        if currLocalFogLevel > 1 then
            self:SetAreaLocalFogLevel( currAreaId, currLocalFogLevel )
            doSpread = true

        elseif currLocalFogLevel <= 1 then
            doNeighborThink = nil
            doExitTheSystem = true

        end

        if doNeighborThink then
            local adjacents = currArea:GetAdjacentAreas()
            local skips = self:GetSkips( currArea )
            add_Local( adjacents, skips )

            for _, currNeighbor in ipairs( adjacents ) do
                if doSpread and addedSurfaceArea < maxAdded and self:AddAreaToFog( currNeighbor ) then
                    --print( "blah", currNeighbor, addedSurfaceArea )
                    addedSurfaceArea = addedSurfaceArea + GetSurfaceArea( currNeighbor )

                end
                if doEqualize then
                    self:EqualizeGlobalFogLevel( currArea, currNeighbor, spreadingMultipler )

                end

            end
        end
        if doExitTheSystem then
            self:RemoveAreaFromFog( currArea, currAreaId )

        end
    end
    coroutine_yield( "done" )
end

ENT.FogCoroutine = coroutine.create( function() end )

function ENT:Think()
    if not SERVER then return end
    self:NextThink( CurTime() )

    local nextBigThink = self.nextBigThink or 0

    if self.FogVolume > 0 and nextBigThink < CurTime() and coroutine_status( self.FogCoroutine ) == "dead" then

        self.nextBigThink = CurTime() + 1
        local originArea = self.OriginNavArea

        local fogEmitAreas = { originArea }
        table.Add( fogEmitAreas, self.OriginNavArea:GetAdjacentAreas() )

        local defaultSurfaceArea = 56250

        local startingAmount = 600
        local levelsToEmit = startingAmount

        for _, fogEmitArea in ipairs( fogEmitAreas ) do
            if levelsToEmit <= 0 then break end
            if not canSpreadSimple( originArea, fogEmitArea ) then continue end

            local emittingNavArea = GetSurfaceArea( fogEmitArea )
            local totalSurfaceArea = defaultSurfaceArea + emittingNavArea
            local scalarEmit = defaultSurfaceArea / totalSurfaceArea
            local scalarBite = emittingNavArea / totalSurfaceArea

            local levelToSetTo = levelsToEmit * scalarEmit
            local levelToSetToClamped = math.Clamp( levelToSetTo, 0, self:GetAreasMaxFogDepth( fogEmitArea ) )

            local remainingLevels = levelToSetToClamped * scalarBite

            self:SetAreaLocalFogLevel( fogEmitArea:GetID(), levelToSetToClamped )

            levelsToEmit = 0 + remainingLevels

            print( levelsToEmit, levelToSetTo, remainingLevels )

        end

        self.FogCoroutine = coroutine.create( doFogEntThink )

    end

    local oldTime = SysTime()

    local spreadingMultipler = self.SpreadingMultiplier
    local evaporationRate    = self.EvaporationRate

    while abs_Local( oldTime - SysTime() ) < 0.004 and self.FogCoroutine and coroutine_status( self.FogCoroutine ) ~= "dead" do
        coroutine_resume( self.FogCoroutine, self, evaporationRate, spreadingMultipler )
    end

    return true
end

function ENT:OnRemove()
end


function ENT:UpdateTransmitState()

    return TRANSMIT_NEVER

end