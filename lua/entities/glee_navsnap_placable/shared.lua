AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "screamer_crate"
DEFINE_BASECLASS( ENT.Base )

--[[------------------------------------
    Base for placables that snap to the center of a navarea, instead of riding the eye trace.

        ENT.Base = "glee_navsnap_placable"
        ENT.SnapMinAreaSize = 100 -- smallest side
        ENT.SnapMaxSlope = 0.15

        function ENT:SnapAreaFilter( area )
            if area:IsUnderwater() then return false, "Not underwater." end
            return true
        end

    Only areas near where the placer's looking are checked, never the whole navmesh.
    Override Place, like any other placable.
--]]-------------------------------------

ENT.PrintName   = "Navarea Snapping Placable"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Base for placables that snap to navareas"
ENT.Spawnable   = false
ENT.Category    = "Hunter's Glee"

ENT.PosOffset = Vector( 0, 0, 0 ) -- sits right on the area's center

ENT.SnapSearchRadius = 400 -- around the eye trace's hit
ENT.SnapMinAreaSize = 50 -- smallest side
ENT.SnapMaxAreaSize = math.huge -- largest side
ENT.SnapMaxSlope = math.huge -- rise over run, of the area's steepest half
ENT.SnapInterval = 0.1

ENT.noPurchaseReason_NoSnap = "There's nowhere fitting, near here."

function ENT:SetupDataTablesExtra()
    self:NetworkVar( "Bool", "Snapped" )

end

if CLIENT then
    function ENT:DoHudStuff()
        local scoreGained = math.Round( self:GetGivenScore() )
        if scoreGained >= 0 then return end

        self:DrawPlacingLine( "Cost: " .. math.abs( scoreGained ) )

    end
end

if not SERVER then return end

local math_abs = math.abs
local math_sqrt = math.sqrt

-- rise over run of the triangle's plane
local function triangleSlope( a, b, c )
    local normal = ( b - a ):Cross( c - a )
    local up = math_abs( normal.z )
    if up <= 0 then return math.huge end

    return math_sqrt( normal.x^2 + normal.y^2 ) / up

end

-- navareas aren't always planar, so each half gets its own normal, and the steeper one counts
-- corners go NW, NE, SE, SW
local function areaSlope( area )
    local nw = area:GetCorner( 0 )
    local ne = area:GetCorner( 1 )
    local se = area:GetCorner( 2 )
    local sw = area:GetCorner( 3 )

    return math.max( triangleSlope( nw, ne, se ), triangleSlope( nw, se, sw ) )

end

-- navareas never change while we're placing, so these are only ever worked out once
function ENT:AreaShapeFits( area )
    local cache = self.areaShapeFitsCache
    if not cache then
        cache = {}
        self.areaShapeFitsCache = cache

    end

    local fits = cache[area]
    if fits ~= nil then return fits end

    local sizeX = area:GetSizeX()
    local sizeY = area:GetSizeY()

    fits = math.min( sizeX, sizeY ) >= self.SnapMinAreaSize
        and math.max( sizeX, sizeY ) <= self.SnapMaxAreaSize
        and areaSlope( area ) <= self.SnapMaxSlope

    cache[area] = fits
    return fits

end

--[[---------------------------------------------------------
    ENT:SnapAreaFilter
    @desc For child classes, can this area be snapped to? Runs after the size and slope checks.
    @param area: The candidate navarea.
    @return: Boolean, and a reason when false
--]]---------------------------------------------------------
function ENT:SnapAreaFilter( _area )
    return true

end

-- the nearest fitting area center to the eye trace's hit, or nil and the last filter's reason
function ENT:FindSnapArea()
    local trace = self.player:GetEyeTrace()
    if not trace.Hit then return end

    local hitPos = trace.HitPos
    local areas = navmesh.Find( hitPos, self.SnapSearchRadius, 200, 200 )

    local bestArea
    local bestDistSqr = math.huge
    local filterReason

    for _, area in ipairs( areas ) do
        if not self:AreaShapeFits( area ) then continue end

        local distSqr = area:GetCenter():DistToSqr( hitPos )
        if distSqr >= bestDistSqr then continue end

        local allowed, reason = self:SnapAreaFilter( area )
        if not allowed then
            filterReason = reason
            continue

        end

        bestArea = area
        bestDistSqr = distSqr

    end

    return bestArea, filterReason, hitPos

end

function ENT:ManageMyPos()
    if ( self.nextSnap or 0 ) > CurTime() then return end
    self.nextSnap = CurTime() + self.SnapInterval

    local area, reason, hitPos = self:FindSnapArea()
    self.snapArea = area
    self.snapFailReason = reason
    self:SetSnapped( area ~= nil )

    -- nothing fits, so it follows their aim, red, to show where they're looking
    local pos = area and area:GetCenter() or hitPos
    if not pos then return end

    self:SetPos( pos )

end

function ENT:CalculateCanPlace()
    if not self.snapArea then return false, self.snapFailReason or self.noPurchaseReason_NoSnap end

    return BaseClass.CalculateCanPlace( self )

end

function ENT:UpdateGivenScore()
    self:SetGivenScore( 0 )

end
