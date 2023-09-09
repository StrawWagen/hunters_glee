
AddCSLuaFile()

terminator_Extras = terminator_Extras or {}

-- guess what this does
terminator_Extras.posCanSee = function( startPos, endPos, mask )
    if not startPos then return end
    if not endPos then return end

    mask = mask or bit.bor( MASK_SOLID, CONTENTS_HITBOX )

    local trData = {
        start = startPos,
        endpos = endPos,
        mask = mask,
    }
    local trace = util.TraceLine( trData )
    return not trace.Hit, trace

end

-- another mystery
terminator_Extras.dirToPos = terminator_Extras.dirToPos or function( startPos, endPos )
    if not startPos then return vec_zero end
    if not endPos then return vec_zero end

    return ( endPos - startPos ):GetNormalized()

end

terminator_Extras.PosCanSeeComplex = function( startPos, endPos, filter, mask )
    if not startPos then return end
    if not endPos then return end

    local filterTbl = {}
    local collisiongroup = nil

    if IsValid( filter ) then
        filterTbl = table.Copy( filter:GetChildren() )
        table.insert( filterTbl, filter )

        collisiongroup = filter:GetCollisionGroup()

    end

    if not mask then
        mask = bit.bor( CONTENTS_SOLID, CONTENTS_HITBOX )

    end

    local traceData = {
        filter = filterTbl,
        start = startPos,
        endpos = endPos,
        mask = mask,
        collisiongroup = collisiongroup,
    }
    local trace = util.TraceLine( traceData )
    return not trace.Hit, trace

end

local nookDirections = {
    Vector( 1, 0, 0 ),
    Vector( -1, 0, 0 ),
    Vector( 0, 1, 0 ),
    Vector( 0, -1, 0 ),
    Vector( 0, 0, 1 ),
    Vector( 0, 0, -1 ),
}

terminator_Extras.GetNookScore = function( pos, distance, overrideDirections )
    local directions = overrideDirections or nookDirections
    local facesBlocked = 0
    distance = distance or 800

    for _, direction in ipairs( directions ) do
        local traceData = {
            start = pos,
            endpos = pos + direction * distance,
            mask = MASK_SOLID_BRUSHONLY,

        }

        local trace = util.TraceLine( traceData )
        if not trace.Hit then continue end

        facesBlocked = facesBlocked + math.abs( trace.Fraction - 1 )

    end

    return facesBlocked

end