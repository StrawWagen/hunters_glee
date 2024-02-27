
function GM:SpawnABearTrap( pos, ang )
    local bearTrap = ents.Create( "termhunt_bear_trap" )
    if not IsValid( bearTrap ) then return end
    bearTrap:SetPos( pos )
    bearTrap:SetAngles( ang )
    bearTrap:Spawn()

    return bearTrap

end

local nextBearTrapSpawnCheck = 0
local offsetFromGround = Vector( 0, 0, 25 )
-- beartrapsPlacedAlready INTENTIONALLY persists thru rounds
local beartrapsPlacedAlready = {}
local mapBearTrapCount = math.random( 1, 6 )
if math.random( 0, 100 ) < 25 then
    mapBearTrapCount = 0

end

local vec_down = Vector( 0, 0, -1 )

hook.Add( "Think", "glee_addbeartrapjobs", function()
    if nextBearTrapSpawnCheck > CurTime() then return end
    if GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE then nextBearTrapSpawnCheck = CurTime() + 15 return end

    local bearTraps = ents.FindByClass( "termhunt_bear_trap" )
    if #bearTraps >= mapBearTrapCount then nextBearTrapSpawnCheck = CurTime() + 60 return end

    local livePly = GAMEMODE:anAlivePlayer()
    if not IsValid( livePly ) then return end

    local bearTrapJob = {}
    bearTrapJob.jobsName = "beartrap"
    bearTrapJob.posFindingOrigin = livePly:GetPos()
    bearTrapJob.spawnRadius = 4000

    bearTrapJob.originIsDefinitive = false
    bearTrapJob.sortForNearest = false
    bearTrapJob.beartrapsPlacedAlready = beartrapsPlacedAlready
    bearTrapJob.areaFilteringFunction = function( currJob, area )
        if area:IsBlocked() then return end
        if area:IsUnderwater() then return end
        -- dont place bearTraps in spots twice per session!
        if currJob.beartrapsPlacedAlready[ area:GetID() ] then return end
        return true

    end
    bearTrapJob.hideFromPlayers = true
    bearTrapJob.posDerivingFunc = function( _, area )
        local points = { area:GetCenter() + offsetFromGround }
        return points

    end
    bearTrapJob.maxPositionsForScoring = 400
    bearTrapJob.posScoringBudget = 1000
    bearTrapJob.posScoringFunction = function( _, toCheckPos, budget )
        -- get nook score, the more nooked the point is, the bigger the score.
        local nookScore = terminator_Extras.GetNookScore( toCheckPos )

        local nearest, distSqr = GAMEMODE:nearestAlivePlayer( toCheckPos )
        if nearest and distSqr < 750^2 then
            nookScore = nookScore / 2

        end

        -- dont go in perfect spots!
        if nookScore > 5 then
            nookScore = 0

        end

        budget = budget + - 1
        return nookScore

    end
    bearTrapJob.onPosFoundFunction = function( _, bestPosition )
        local entsAtPos = ents.FindInSphere( bestPosition, 100 )

        -- don't spawn a beartrap under props...
        local blocked
        for _, ent in ipairs( entsAtPos ) do
            if IsValid( ent ) and IsValid( ent:GetPhysicsObject() ) and ent:NearestPoint( bestPosition ):Distance( bestPosition ) < 35 then
                blocked = true
                break

            end
        end

        if blocked then
            hook.Run( "glee_procbeartrap_blockbeartrapareas", bestPosition )
            return false

        end

        local result = util.QuickTrace( bestPosition, vec_down * 100 )
        local trapsPos = result.HitPos + result.HitNormal
        local trapsAng = result.HitNormal:Angle()
        trapsAng:RotateAroundAxis( trapsAng:Right(), -90 )

        local bearTrap = GAMEMODE:SpawnABearTrap( trapsPos, trapsAng )
        if not IsValid( bearTrap ) then return false end

        --debugoverlay.Cross( trapsPos, 100, 60, color_white, true )
        hook.Run( "glee_procbeartrap_blockbeartrapareas", bearTrap:GetPos() )

        -- remove beartraps really far away from players
        local timerName = "glee_proceduralbeartraps_removestale_" .. bearTrap:GetCreationID()
        timer.Create( timerName, 120, 0, function()
            if not IsValid( bearTrap ) then timer.Remove( timerName ) return end
            local bearTrapsPos = bearTrap:GetPos()
            local nearest, distSqr = GAMEMODE:nearestAlivePlayer( bearTrapsPos )
            if not IsValid( nearest ) then SafeRemoveEntity( bearTrap ) timer.Remove( timerName ) return end
            if distSqr > 5000^2 then SafeRemoveEntity( bearTrap ) timer.Remove( timerName ) return end

        end )

        return true

    end

    GAMEMODE:addProceduralSpawnJob( bearTrapJob )
    --print( "ADDED" )
    --PrintTable( bearTrapJob )

    nextBearTrapSpawnCheck = CurTime() + 60

    if mapBearTrapCount > 4 and #navmesh.GetAllNavAreas() < 4000 then
        mapBearTrapCount = math.random( 1, 4 )

    end
end )

local function postPlaced( bestPosition )
    local placedArea = GAMEMODE:getNearestNav( bestPosition, 500 )
    if placedArea and placedArea.IsValid and placedArea:IsValid() then
        beartrapsPlacedAlready[ placedArea:GetID() ] = true
        for _, area in ipairs( placedArea:GetAdjacentAreas() ) do
            beartrapsPlacedAlready[ area:GetID() ] = true

        end
    end
end

hook.Add( "glee_procbeartrap_blockbeartrapareas", "tracklastbeartrap", function( blockPos )
    postPlaced( blockPos )

end )