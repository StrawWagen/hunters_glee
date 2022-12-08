-- patches gaps in navmesh, using players as a guide
-- patches will never be ideal, but they will be better than nothing

function GM:navPatchingThink( ply )

    if ply:GetMoveType() == MOVETYPE_NOCLIP or ply:GetObserverMode() ~= OBS_MODE_NONE then ply.oldPatchingArea = nil return end

    local plyPos = ply:GetPos()

    local result = self:getNearestPosOnNav( plyPos, 40 )
    local currArea = result.area
    if not currArea or not currArea:IsValid() then return end

    local oldArea = ply.oldPatchingArea
    ply.oldPatchingArea = currArea

    if not oldArea or not oldArea:IsValid() then return end
    if currArea == oldArea then return end 
    self:smartConnectionThink( currArea, oldArea )
    self:smartConnectionThink( oldArea, currArea ) -- lol backwards
end

local function connectionDistance( currArea, otherArea )
    local currCenter = currArea:GetCenter() 
    
    local nearestInitial = otherArea:GetClosestPointOnArea( currCenter )
    local nearestFinal   = currArea:GetClosestPointOnArea( nearestInitial )
    nearestFinal.z = nearestInitial.z
    local distTo   = nearestInitial:DistToSqr( nearestFinal )
    return distTo

end

function GM:smartConnectionThink( currArea, oldArea )
    if oldArea:IsConnected( currArea ) then return end

    local distTo = connectionDistance( currArea, oldArea )
    local Dist75 = distTo > 74^2 and distTo < 76^2

    if distTo > 55^2 and not Dist75 then return end

    
    local currCenter = currArea:GetCenter() 

    local navDirTakenByConnection = oldArea:ComputeDirection( currCenter )
    local areasInNavDir = oldArea:GetAdjacentAreasAtSide( navDirTakenByConnection )

    if table.Count( areasInNavDir ) > 0 then return end
    

    oldArea:ConnectTo( currArea )
    --print( distTo, oldArea:GetID() )
end
