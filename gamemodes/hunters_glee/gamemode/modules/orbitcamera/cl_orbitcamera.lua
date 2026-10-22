-- The third person camera that orbits something, spectating it or taunting as it.
-- Where it sits, and how far out, scrolled in and out, are shared by both

local closestDistance = 15
local defaultDistance = 100
local maxDistance = 1500
local zoomRate = 10 -- per scroll notch, five times that while sprinting

-- Whether ent is subject, or rides it, or its vehicle, however far down the parenting goes
local function isPartOf( ent, subject, vehicle )
    while IsValid( ent ) do
        if ent == subject or ent == vehicle then return true end
        ent = ent:GetParent()

    end

    return false

end

-- How far out the camera orbits, settled on the first time it's asked for, from how big subject is.
-- Forgotten when what's orbited changes, see ResetOrbitDistance
function GM:GetOrbitDistance( subject )
    local ply = LocalPlayer()
    local orbitDist = ply.glee_OrbitDistance
    if orbitDist then return orbitDist end

    if math.abs( defaultDistance - closestDistance ) <= 50 then
        orbitDist = defaultDistance

    else
        orbitDist = math.Clamp( subject:BoundingRadius() + defaultDistance / 2, closestDistance, maxDistance )

    end

    ply.glee_OrbitDistance = orbitDist

    return orbitDist

end

function GM:ResetOrbitDistance()
    LocalPlayer().glee_OrbitDistance = nil

end

-- Scrolled in, negative, or out. Nothing while there's no orbit going, it settles its own distance first
function GM:ZoomOrbit( direction )
    local ply = LocalPlayer()
    local oldDist = ply.glee_OrbitDistance
    if not oldDist then return end

    local rate = zoomRate
    if ply:KeyDown( IN_SPEED ) then
        rate = rate * 5

    end

    ply.glee_OrbitDistance = math.Clamp( oldDist + direction * rate, closestDistance, maxDistance )

end

-- Where the camera sits, looking along ang at pivot, from subject's orbit distance. Pulled in short of
-- anything in the way, but never anything that's part of subject, eg what it carries, its vehicle
function GM:GetOrbitOrigin( subject, pivot, ang )
    local vehicle = NULL
    if subject.InVehicle and subject:InVehicle() then
        vehicle = subject:GetVehicle()
        if IsValid( vehicle:GetParent() ) then
            vehicle = vehicle:GetParent()

        end
    end

    local dir = -ang:Forward()
    local desiredPos = pivot + dir * self:GetOrbitDistance( subject )

    local tr = util.TraceLine( {
        start = pivot + dir * closestDistance,
        endpos = desiredPos,
        filter = function( ent )
            return not isPartOf( ent, subject, vehicle )

        end,
    } )

    return tr.HitPos

end
