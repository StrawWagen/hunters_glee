
AddCSLuaFile()

local uiScaleVert = ScrH() / 1080
local uiScaleHoris = ScrW() / 1920

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

-- dead on match for
terminator_Extras.defaultHudPaddingFromEdge = glee_sizeScaled( nil, 26 )
terminator_Extras.defaultHudTextPaddingFromEdge = glee_sizeScaled( nil, 54 ) -- dead on match for the "health" text
