-- Resolution scaling. Everything in glee_hud declares sizes in 1080p pixels and runs
-- them through glee_sizeScaled, so one number looks the same on every monitor

local math_Round = math.Round

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

    Use nil for the axis you don't need.
    Results are whole pixels; for a size whose fraction matters, see glee_sizeScaledExact.
--]]-------------------------------------
function glee_sizeScaled( sizeX, sizeY )
    if sizeX and sizeY then
        return math_Round( sizeX * uiScaleHoris ), math_Round( sizeY * uiScaleVert )

    elseif sizeX then
        return math_Round( sizeX * uiScaleHoris )

    elseif sizeY then
        return math_Round( sizeY * uiScaleVert )

    end
end

-- glee_sizeScaled without the rounding, for a 1080p size that is deliberately fractional.
-- A 2.5px shadow offset rounded to 3 is a different look at 1080p, where nothing scales
function glee_sizeScaledExact( sizeX, sizeY )
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
terminator_Extras.defaultHudPaddingFromEdge = glee_sizeScaled( nil, 24.5 ) -- how far to start the faded background
terminator_Extras.defaultHudPaddingFromBottom = glee_sizeScaled( nil, 26 ) -- how far to start the faded background
terminator_Extras.defaultHudTextPaddingFromEdge = glee_sizeScaled( nil, 54 ) -- dead on match for the "health" text
