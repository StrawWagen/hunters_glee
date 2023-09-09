util.doorIsUsable = function( door )
    local center = door:WorldSpaceCenter()
    local forward = door:GetForward()
    local starOffset = forward * 50
    local endOffset  = forward * 2

    local traceDatF = {
        mask = MASK_SOLID_BRUSHONLY,
        start = center + starOffset,
        endpos = center + endOffset
    }

    local traceDatB = {
        mask = MASK_SOLID_BRUSHONLY,
        start = center + -starOffset,
        endpos = center + -endOffset
    }

    local traceBack = util.TraceLine( traceDatB )
    local traceFront = util.TraceLine( traceDatF )

    local canSmash = not traceBack.Hit and not traceFront.Hit
    return canSmash

end