-- where a flyer goes when it's got nothing better to do
-- left alone it drifts off to the map's edge, so it spends some of its time heading for where players hang out
local gleeFlightNavigator = terminator_Extras.gleeFlightNavigator

-- a spot players have been, picked at random weighted by how much
-- it's not trying to get there, just to stay near people
local hotTime = 20
-- then it drifts one way, the navigator's traces bend it round walls
local lazyTime = 40
-- how far ahead the drifting carrot sits
local lazyDist = 2000

-- nil when there's no heat to go on, outside of glee, or before anyone's moved
local function pickHotPos()
    if not GAMEMODE.IsReallyHuntersGlee then return end
    local heatmap = GAMEMODE.navmeshActivityHeatmap
    if not heatmap then return end

    local totalHeat = 0
    for area, heat in pairs( heatmap ) do
        if not IsValid( area ) then continue end
        totalHeat = totalHeat + heat

    end
    if totalHeat <= 0 then return end

    local picked = math.Rand( 0, totalHeat )
    for area, heat in pairs( heatmap ) do
        if not IsValid( area ) then continue end
        picked = picked - heat
        if picked <= 0 then return area:GetCenter() end

    end
end

-- heading is locked for the whole phase
-- read off the velocity every think, a slow turner chases its own turn round in circles
local function pickLazyHeading( ent, navData )
    local vel = navData.measuredVel
    local heading = Vector( vel.x, vel.y, 0 )
    if heading:IsZero() then
        heading = ent:GetForward()
        heading.z = 0

    end
    heading:Normalize()
    return heading

end

local function aboveTheFloor( pos, wanderHeight )
    local floorTr = terminator_Extras.getFloorTr( pos )
    if not floorTr.Hit or floorTr.StartSolid then return pos end
    return Vector( pos.x, pos.y, floorTr.HitPos.z + wanderHeight )

end

local function startHotPhase( navData )
    local hotPos = pickHotPos()
    if not hotPos then return false end

    navData.wanderPhase = "hot"
    navData.wanderPhaseEnd = CurTime() + hotTime
    navData.wanderHotPos = hotPos
    return true

end

local function startLazyPhase( ent, navData )
    navData.wanderPhase = "lazy"
    navData.wanderPhaseEnd = CurTime() + lazyTime
    navData.wanderHeading = pickLazyHeading( ent, navData )

end

-- the off-the-map-edge case, a lazy drift that's run out of map goes hot early
-- with no heat to go on, it turns round instead
local function lazyRanOutOfMap( ent, navData )
    if startHotPhase( navData ) then return end

    local myPos = ent:GetPos()
    local headingYaw = navData.wanderHeading:Angle().y
    -- looks wider each try, all the way round if it has to
    for try = 1, 8 do
        local spread = 30 * try
        local heading = Angle( 0, headingYaw + math.Rand( -spread, spread ), 0 ):Forward()
        if util.IsInWorld( myPos + heading * lazyDist ) then
            navData.wanderHeading = heading
            return

        end
    end
end

local function phasePos( ent, navData )
    if navData.wanderPhase == "hot" then return navData.wanderHotPos end
    return ent:GetPos() + navData.wanderHeading * lazyDist

end

-- call each think while wandering, then Steer to what it returns
-- uses cfg.wanderHeight, how high above the floor to wander
function gleeFlightNavigator.WanderPos( ent )
    local navData = ent.glee_FlightNav
    local cfg = navData.cfg

    -- hot and lazy take turns, lazy fills in when there's no heat
    local phaseOver = CurTime() >= ( navData.wanderPhaseEnd or 0 )
    if phaseOver and ( navData.wanderPhase == "hot" or not startHotPhase( navData ) ) then
        startLazyPhase( ent, navData )

    end

    if navData.wanderPhase == "lazy" and not util.IsInWorld( phasePos( ent, navData ) ) then
        lazyRanOutOfMap( ent, navData )

    end

    local wanderPos = aboveTheFloor( phasePos( ent, navData ), cfg.wanderHeight )

    local debugConVar = cfg.debugConVar
    if debugConVar and debugConVar:GetBool() then
        debugoverlay.Text( wanderPos, "wander " .. navData.wanderPhase, 1 )

    end
    return wanderPos

end

-- call when Steer gives up on a wander pos, it picks a fresh phase
function gleeFlightNavigator.RestartWander( ent )
    ent.glee_FlightNav.wanderPhaseEnd = 0

end
