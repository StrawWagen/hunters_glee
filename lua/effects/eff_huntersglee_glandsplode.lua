-- A big bomb gland explosion, the particle burst and red and yellow blood plastered everywhere.
-- Sent reliably so it's never dropped, see termhunt_bombbig and termhunt_bombgland
-- terminator_Extras.DoReliableEffect( "eff_huntersglee_glandsplode", pos, { magnitude = scale } )
-- scale 1 is one big bomb

local splatterCount = 25
local splatterMax = 80 -- big decals eat into r_decals fast
local splatterReach = 700

local splatterMats = {}
for i = 1, 6 do
    splatterMats[#splatterMats + 1] = Material( "decals/blood" .. i )
    splatterMats[#splatterMats + 1] = Material( "decals/yblood" .. i )

end

local decalTr = { mask = MASK_SOLID_BRUSHONLY }

local function randomDirection()
    local dir = VectorRand() -- not unit length, VectorRand samples a cube
    dir:Normalize()
    return dir

end

local function splatter( pos, scale )
    local mat = splatterMats[math.random( 1, #splatterMats )]
    if mat:IsError() then return end

    decalTr.start = pos
    decalTr.endpos = pos + randomDirection() * math.Rand( 0.25, 1 ) * splatterReach * scale
    local tr = util.TraceLine( decalTr )
    if not tr.Hit then return end

    local size = math.Rand( 3, 6 ) * scale
    util.DecalEx( mat, tr.Entity, tr.HitPos, tr.HitNormal, color_white, size, size * math.Rand( 0.7, 1.3 ) )

end

function EFFECT:Init( data )
    local pos = data:GetOrigin()
    local scale = data:GetMagnitude()

    ParticleEffect( "glee_gland_explosion_big", pos, angle_zero )

    for _ = 1, math.min( math.ceil( splatterCount * scale ), splatterMax ) do
        splatter( pos, scale )

    end
end

function EFFECT:Think()
    return false

end

function EFFECT:Render()
end
