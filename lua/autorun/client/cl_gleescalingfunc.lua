
AddCSLuaFile()

local uiScaleVert = ScrH() / 1080
local uiScaleHoris = ScrW() / 1920

--[[------------------------------------
    glee_sizeScaled
    Desc: scales sizes based on screen resolution
    Pass 1080p pixel values; they are scaled to the current resolution.

    Examples:
    - glee_sizeScaled( 400 )           -> 400 * uiScaleHoris (same visual width as 400px at 1080p)
    - glee_sizeScaled( nil, 26 )       -> 26  * uiScaleVert  (same visual height as 26px at 1080p)
    - glee_sizeScaled( 64, 32 )        -> returns both scaled width and height

    Use nil for the axis you don’t need.
--]]-------------------------------------
function glee_sizeScaled( sizeX, sizeY )
    if sizeX and sizeY then
        return sizeX * uiScaleHoris, sizeY * uiScaleVert

    elseif sizeX then
        return sizeX * uiScaleHoris

    elseif sizeY then
        return sizeY * uiScaleVert

    end
end

terminator_Extras = terminator_Extras or {}

-- USED FOR ADDING TO DEFAULT HUD, eg, beating heart element. NOT GUIS
terminator_Extras.defaultHudPaddingFromEdge = glee_sizeScaled( nil, 26 ) -- how far to start the faded background
terminator_Extras.defaultHudTextPaddingFromEdge = glee_sizeScaled( nil, 54 ) -- dead on match for the "health" text
