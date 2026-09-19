--[[------------------------------------
    Hud elements saying what part of the screen they are using, so other elements can sit
    around them without knowing, or importing, whatever drew them.

    Say what you are using every frame you draw it. Nobody has to say when they stop:
    a claim only lasts the frame it was made in.
--]]-------------------------------------

local used = {}

-- name is yours to pick, and replaces your last claim
function GM:ImUsingHudSpace( name, x, y, w, h )
    local space = used[name]
    if not space then
        space = {}
        used[name] = space

    end

    space.x, space.y, space.w, space.h = x, y, w, h
    space.frame = FrameNumber()

end

-- The bottom of the lowest thing x, y, w, h runs into, or nil when it is clear.
-- Draw below what you get back
function GM:HudSpaceInMyWay( x, y, w, h )
    local thisFrame = FrameNumber()
    local lowest = nil

    for _, space in pairs( used ) do
        if space.frame ~= thisFrame then continue end
        if x + w <= space.x or x >= space.x + space.w then continue end
        if y + h <= space.y or y >= space.y + space.h then continue end

        local bottom = space.y + space.h
        if lowest and bottom <= lowest then continue end

        lowest = bottom

    end

    return lowest

end
