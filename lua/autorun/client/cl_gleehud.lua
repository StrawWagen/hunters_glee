
AddCSLuaFile()

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

    Use nil for the axis you don’t need.
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

terminator_Extras = terminator_Extras or {}

-- USED FOR ADDING TO DEFAULT HUD, eg, beating heart element. NOT GUIS
terminator_Extras.defaultHudPaddingFromEdge = glee_sizeScaled( nil, 24.5 ) -- how far to start the faded background
terminator_Extras.defaultHudPaddingFromBottom = glee_sizeScaled( nil, 26 ) -- how far to start the faded background
terminator_Extras.defaultHudTextPaddingFromEdge = glee_sizeScaled( nil, 54 ) -- dead on match for the "health" text


terminator_Extras.glee_DeadPlyColor = Color( 87, 117, 117 )
terminator_Extras.glee_EscapedPlyColor = Color( 0, 190, 255 )

terminator_Extras.hl2hud = {
    iconMaxSize     = 128,
    boxCornerRadius = 10,
    blockPadding    = glee_sizeScaled( nil, 8 ),  -- y-padding between box edge and text
    laneSpacing     = glee_sizeScaled( nil, 6 ),  -- gap between stacked hud boxes
    fontName        = "Trebuchet MS",

    colorHappyYellow      = Color( 255, 230, 0, 220 ),
    colorUnHappyYellow    = Color( 225, 200, 0, 220 ),
    colorRedUrgent        = Color( 255, 50, 50, 200 ),
    colorBackground       = Color( 0, 0, 0, 76 ),
    colorBackgroundUrgent = Color( 100, 100, 50, 76 ),
}

surface.CreateFont( "termhuntTimeFont", {
    font      = "Trebuchet MS",
    size      = glee_sizeScaled( nil, 34 ),
    weight    = 2000,
    blursize  = 0,
    scanlines = 1,
    antialias = true,
} )

surface.CreateFont( "termhuntScoreFont", {
    font      = "Trebuchet MS",
    size      = glee_sizeScaled( nil, 28 ),
    weight    = 1000,
    blursize  = 0,
    scanlines = 0,
    antialias = true,
} )

surface.CreateFont( "termhuntHintFont", {
    font      = "Trebuchet MS",
    size      = glee_sizeScaled( nil, 28 ),
    weight    = 1000,
    blursize  = 0,
    scanlines = 0,
    antialias = true,
} )

function terminator_Extras.glee_PlayerNameColor( ply, visible )
    local color = nil
    local a = nil
    if ply:Health() <= 0 then
        if ply.HasEscaped and ply:HasEscaped() then
            color = terminator_Extras.glee_EscapedPlyColor
            a = 255

        elseif visible then
            color = terminator_Extras.glee_DeadPlyColor
            a = 255

        end
    elseif ply:Health() > 0 then
        if visible then
            color = GAMEMODE:GetTeamColor( ply )
            a = 160

        end
    end

    if not color then return terminator_Extras.glee_DeadPlyColor end
    color.a = a

    return color
end