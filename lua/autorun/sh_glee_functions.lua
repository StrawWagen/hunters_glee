
-- Small helpers both realms use, outside the gamemode so weapons and entities work without it.
-- Server only ones are in server/sv_glee_functions.lua

terminator_Extras = terminator_Extras or {}

if SERVER then
    AddCSLuaFile()

end

local bit_band = bit.band
local util_PointContents = util.PointContents

--[[---------------------------------------------------------
    terminator_Extras.glee_IsInWall
    Inside a wall, or out in the void past the map's edge, both read as solid brush.
    World brushes only, props and brush entities don't count.
    Works clientside, unlike util.IsInWorld, and costs far less than a trace.
    @param pos: The point to check.
    @return: true if it's in solid brush.
--]]---------------------------------------------------------
function terminator_Extras.glee_IsInWall( pos )
    return bit_band( util_PointContents( pos ), MASK_SOLID_BRUSHONLY ) > 0

end
