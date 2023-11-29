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
