include( "shared.lua" )
include( "cl_targetid.lua" )
include( "shoppinggui.lua" )

-- TIME
local fontData = {
    font = "Arial",
    extended = false,
    size = 30,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = true,
}
local timeFont = surface.CreateFont( "termhuntTimeFont", fontData )


-- BEAT COUNT
local fontData = {
    font = "Arial",
    extended = false,
    size = 30,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
local beatsFont = surface.CreateFont( "termhuntBeatsFont", fontData )


-- the RATE YOUR HJEAT BEATS OH GOD HE'S HERE
local fontData = {
    font = "Arial",
    extended = false,
    size = 80,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
local timeFont = surface.CreateFont( "termhuntBPMFont", fontData )

-- triumphant font
local fontData = {
    font = "Arial",
    extended = false,
    size = 50,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
}
local timeFont = surface.CreateFont( "termhuntTriumphantFont", fontData )

local nextPaint = 0
local nextBeat = 0

local oldHitTexture = ""

local doingGUI = false

local screenMiddleW = ScrW() / 2
local screenMiddleH = ScrH() / 2

local GAMEMODE = GM

local function playerSpectateColor( ply, visible )
    local teamColor = GAMEMODE:GetTeamColor( player ) 
    local color = nil
    local a = nil
    if ply:Health() <= 0 then
        if visible then
            color = Color( 87,117,117)
            a = 255
        end
    elseif ply:Health() > 0 then
        if visible then
            color = teamColor
            a = 160 
        end
    end
    color.a = a
    return color
end

local function paintPlayer( player )
    if doingGUI then return end
    
	local text = "ERROR"
	local font = "TargetID"
	
	if ( player:IsPlayer() ) then
		text = player:Nick()
	else
		return
		--text = trace.Entity:GetClass()
	end
	
    local OnScreenDat = player:GetPos():ToScreen()
    if not OnScreenDat.visible then return end

	surface.SetFont( font )
	local w, h = surface.GetTextSize( text )
	
	local PosX = OnScreenDat.x
    local PosY = OnScreenDat.y
	
	if ( PosX == 0 && PosY == 0 ) then
	
		PosX = ScrW() / 2
		PosY = ScrH() / 2
	
	end
	
	local x = PosX
	local y = PosY
	
	x = x - w / 2
	y = y + -30

    local textColor = playerSpectateColor( player, OnScreenDat.visible )
	
	-- The fonts internal drop shadow looks lousy with AA on
	draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
	draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
	draw.SimpleText( text, font, x, y, textColor )
	
	y = y + h + 5
	
	local text = player:Frags()
	local font = "TargetIDSmall"
	
	surface.SetFont( font )
	local w, h = surface.GetTextSize( text )
	local x = PosX - w / 2
	
	draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
	draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
	draw.SimpleText( text, font, x, y, textColor )
end

local function paintOtherPlayers( localPlayer )
    for _, ply in ipairs( player.GetAll() ) do
        if ply != localPlayer then
            paintPlayer( ply )
        end
    end
end

local function beatThink( ply, cur )
    if nextBeat > cur then return end
    local BPM = ply:GetNWInt( "termHuntPlyBPM" )
    local beatTime = math.Clamp( 60 / BPM, 0, 2 ) 
    local pitch = BPM
    local volume = ( BPM / 240 ) + -0.1
    nextBeat = cur + beatTime
    if ply:Alive() then
        ply:EmitSound( "418788_name_heartbeat_single.wav", 100, pitch, volume )
    end
end


local function paintRoundInfo( ply, cur )
    if doingGUI then return end

    local timeVal = GetGlobalInt( "TERMHUNTER_PLAYERTIMEVALUE", 0 )
    local infoVal = GetGlobalString( "TERMHUNTER_PLAYERVALUENAME", "---" )
    local infoColor = Color( 255, 255, 255 )
    local resetTime = ply.resetColorTime or 0
    if resetTime > cur then 
        infoColor = ply.infoColorOverride
    end
    if not ply.oldInfo then
        ply.oldInfo = "---"
    end

    local combinedString = infoVal .. string.ToMinutesSeconds( timeVal )

    if ply.oldInfo ~= infoVal then
        ply.oldInfo = infoVal
        ply.infoColorOverride = Color( 255, 50, 50 )
        ply.resetColorTime = cur + 0.1
        ply:EmitSound( "buttons/lightswitch2.wav" )
    end

    surface.SetFont( "termhuntTimeFont" )
    surface.SetTextColor( infoColor )
    surface.SetTextPos( 128, 128 ) 
    surface.DrawText( combinedString )

end


local BPMCriteria = 65 -- needs to match serverside var

local function paintMyTotalBeats( ply, cur )
    if doingGUI then return end

    local myTotalBeats = ply:Frags()
    local textCombo = "Score: " .. myTotalBeats
    if myTotalBeats <= 0 then
        textCombo = "Score: " .. myTotalBeats .. " ( Beats Above " .. BPMCriteria .. " )"
    end
    local textColor = Color( 190, 0, 0 )
    local resetTime = ply.resetBeatsColorTime or 0
    if resetTime > cur then 
        textColor = ply.beatsColorOverride
    end

    if ply.oldBeats ~= myTotalBeats then
        ply.oldBeats = myTotalBeats
        ply.beatsColorOverride = Color( 255, 50, 50 )
        ply.resetBeatsColorTime = cur + 0.15
    end

    surface.SetFont( "termhuntBeatsFont" )
    surface.SetTextColor( textColor )
    surface.SetTextPos( 128, 128 + 60 ) 
    surface.DrawText( textCombo )

end

local fadeRangeStart, fadeRangeEnd = BPMCriteria, BPMCriteria + 40
local fadeRangeSize = math.abs( fadeRangeStart - fadeRangeEnd )
local bpmTextAlpha = 30

local function paintPlyBPM( ply )
    if doingGUI then return end

    local blockingScore = ply:GetNWBool( "termHuntBlockScoring" ) 
    local BPM = ply:GetNWInt( "termHuntPlyBPM" )
    local currBpmTextAlpha = bpmTextAlpha

    if BPM > fadeRangeStart and not blockingScore then
        local difference = math.Clamp( math.abs( BPM - fadeRangeEnd ), fadeRangeStart, fadeRangeEnd )
        local constrainedDiff = difference + fadeRangeStart
        local normalizedConstDiff = fadeRangeSize / constrainedDiff   
        currBpmTextAlpha = 40 + bpmTextAlpha + ( normalizedConstDiff * 240 )
        currBpmTextAlpha = math.Clamp( currBpmTextAlpha, 0, 255 )
    end
    
    local BPMString = BPM

    surface.SetFont( "termhuntBPMFont" )
    local size = surface.GetTextSize( BPMString )
    surface.SetTextColor( Color( 255, 50, 50, currBpmTextAlpha ) )
    surface.SetTextPos( screenMiddleW + -( size * 0.5 ), screenMiddleH + 20 ) 
    surface.DrawText( BPMString )

end

local function paintTotalScore()
    if doingGUI then return end
    
    local Text = "Hunt's tally"

    surface.SetFont( "termhuntTriumphantFont" )
    local size = surface.GetTextSize( Text )
    surface.SetTextColor( Color( 255,255,255 ) )
    surface.SetTextPos( screenMiddleW + -( size * 0.5 ), screenMiddleH + -90 ) 
    surface.DrawText( Text )

    local Text =  GetGlobalInt( "termHuntTotalScore", 0 )

    local size = surface.GetTextSize( Text )
    surface.SetFont( "termhuntTriumphantFont" )
    surface.SetTextColor( Color( 190, 0, 0 ) )
    surface.SetTextPos( screenMiddleW + -( size * 0.5 ), screenMiddleH + -40 ) 
    surface.DrawText( Text )
end

local function paintFinestPrey()

    if doingGUI then return end

    local winner = GetGlobalEntity( "termHuntWinner", NULL )
    local winnerScore = GetGlobalInt( "termHuntWinnerScore", 0 )

    local Text = "Finest Prey"

    surface.SetFont( "termhuntTriumphantFont" )
    local size = surface.GetTextSize( Text )
    surface.SetTextColor( Color( 255,255,255 ) )
    surface.SetTextPos( screenMiddleW + -( size * 0.5 ), screenMiddleH + 64 ) 
    surface.DrawText( Text )

    local winner = winner
    if not IsValid( winner ) then return end 
    local Text2 = winner:Name()

    surface.SetFont( "termhuntTriumphantFont" )
    local size = surface.GetTextSize( Text2 )
    surface.SetTextColor( Color( 255,255,255 ) )
    surface.SetTextPos( screenMiddleW + -( size * 0.5 ), screenMiddleH + 64 + 50 ) 
    surface.DrawText( Text2 )

    local Text3 = winnerScore

    surface.SetFont( "termhuntTriumphantFont" )
    local size = surface.GetTextSize( Text3 )
    surface.SetTextColor( Color( 190, 0, 0 ) )
    surface.SetTextPos( screenMiddleW + -( size * 0.5 ), screenMiddleH + 64 + 100 ) 
    surface.DrawText( Text3 )
end

function HUDPaint()
    local ply = LocalPlayer()
    local cur = UnPredictedCurTime()
    local displayWinners = GetGlobalBool( "termHuntDisplayWinners", false )
    if displayWinners then
        paintOtherPlayers( ply )
        local hit = nil
        local pit = 90
        if ply.displayedWinners ~= displayWinners then -- define curtime for dramatic text
            ply:EmitSound( "53937_meutecee_trumpethit07.wav", 120, 100 )
            ply.winnerDisplayedStart     = cur
            ply.displayTotalScoreTime     = cur + 4
            ply.displayFinestPrey         = cur + 4 + 4
            ply.totalHitSound = 0
            ply.finestHitSound = 0
        end
        if ply.displayTotalScoreTime < cur then
            if ply.totalHitSound ~= ply.winnerDisplayedStart then
                hit = true
                pit = 100
                ply.totalHitSound = ply.winnerDisplayedStart
            end
            paintTotalScore()
        end
        if ply.displayFinestPrey < cur then
            if ply.finestHitSound ~= ply.winnerDisplayedStart then
                hit = true
                pit = 80
                ply.finestHitSound = ply.winnerDisplayedStart
            end
            paintFinestPrey()
        end
        if hit then
            ply:EmitSound( "doors/heavy_metal_stop1.wav", 100, pit )
        end
    else
        local spectating = ply:Health() <= 0
        if spectating == true then
            paintOtherPlayers( ply )
        else
            beatThink( ply, cur )
        end
        if nextPaint > cur then return end
        local nextPaint = cur + 0.1
        if spectating == true then
            paintRoundInfo( ply, cur )
            paintMyTotalBeats( ply, cur )
        else
            paintRoundInfo( ply, cur )
            paintMyTotalBeats( ply, cur )
            paintPlyBPM( ply )
        end
    end
    ply.displayedWinners = displayWinners
end
hook.Add("HUDPaint", "termhunt_playerdisplay", HUDPaint)


potentialResurrectionData = {}
nextResurrectRecieve = 0

net.Receive( "storeResurrectPos", function()
    local nextRecieve = nextResurrectRecieve
    if nextRecieve > CurTime() then return end
    nextResurrectRecieve = CurTime() + 0.01
    local ply = net.ReadEntity()
    local data = { ply = ply, pos = ply:GetPos() }
    for ind, data in ipairs( potentialResurrectionData ) do
        if data.ply ~= ply then continue end
        table.remove( potentialResurrectionData, ind )
    end
    table.insert( potentialResurrectionData, data )
end )


-- yoinked from darkrp so we do it right
local FKeyBinds = {
    ["gm_showspare1"] = "ShowShop"
}

function GM:PlayerBindPress( ply, bind, pressed )
    local bnd = string.match( string.lower( bind ), "gm_[a-z]+[12]?" )

    if bnd and FKeyBinds[bnd] then
        hook.Call( FKeyBinds[bnd], GAMEMODE )

    end
end

function GM:ShowShop()
    doingGUI = not doingGUI

    if doingGUI then
        termHuntOpenTheShop()

    else
        termHuntCloseTheShop()

    end
end
