
local terminator_Extras = terminator_Extras or {}

-- another mystery
terminator_Extras.dirToPos = terminator_Extras.dirToPos or function( startPos, endPos )
    if not startPos then return vec_zero end
    if not endPos then return vec_zero end

    return ( endPos - startPos ):GetNormalized()

end

terminator_Extras.PosCanSeeComplex = terminator_Extras.PosCanSeeComplex or function( startPos, endPos, filter, mask )
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