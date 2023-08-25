include( "shared.lua" )
include( "cl_targetid.lua" )
include( "cl_scoreboard.lua" )
include( "cl_spectateflashlight.lua" )
include( "shoppinggui.lua" )

local doHud = CreateClientConVar( "huntersglee_cl_showhud", 1, true, false, "Show the hud? Beats, score, round state...", 0, 1 )

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
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntTimeFont", fontData )


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
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntScoreFont", fontData )

-- SHOP hINT
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
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntShopHintFont", fontData )

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
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntBPMFont", fontData )

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
    shadow = true,
    additive = false,
    outline = false,
}
surface.CreateFont( "termhuntTriumphantFont", fontData )

local nextBeat = 0

local screenMiddleW = ScrW() / 2
local screenMiddleH = ScrH() / 2

local GAMEMODE = GM

local function playerSpectateColor( ply, visible )
    local teamColor = GAMEMODE:GetTeamColor( ply )
    local color = nil
    local a = nil
    if ply:Health() <= 0 then
        if visible then
            color = Color( 87,117,117 )
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

function huntersGlee_PaintPlayer( player, posOverride )
    if not GAMEMODE:CanShowDefaultHud() then return end

    local text = "ERROR"
    local font = "TargetID"

    if not IsValid( player ) then return end

    if ( player:IsPlayer() ) then
        text = player:Nick()
    else
        return
        --text = trace.Entity:GetClass()
    end

    local pos = posOverride or player:GetPos()

    local OnScreenDat = pos:ToScreen()
    if not OnScreenDat.visible then return end

    surface.SetFont( font )
    local _, h = surface.GetTextSize( text )

    local PosX = OnScreenDat.x
    local PosY = OnScreenDat.y

    if PosX == 0 and PosY == 0 then

        PosX = ScrW() / 2
        PosY = ScrH() / 2

    end

    local x = PosX
    local y = PosY

    y = y + -30

    local textColor = playerSpectateColor( player, OnScreenDat.visible )
    surface.drawShadowedTextBetter( text, font, textColor, x, y )

    y = y + h + 5

    if player:Health() <= 0 then
        text = player:GetScore() .. " Score"

    else
        text = player:Health() .. "%"

    end
    font = "TargetIDSmall"
    surface.drawShadowedTextBetter( text, font, textColor, x, y )

end

local function paintOtherPlayers( localPlayer )
    for _, ply in ipairs( player.GetAll() ) do
        if ply ~= localPlayer then
            huntersGlee_PaintPlayer( ply )

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

    if timeVal == math.huge then
        timeVal = 0
    end

    local combinedString = infoVal .. string.ToMinutesSeconds( timeVal )

    if ply.oldInfo ~= infoVal then
        ply.oldInfo = infoVal
        ply.infoColorOverride = Color( 255, 50, 50 )
        ply.resetColorTime = cur + 0.1
        ply:EmitSound( "buttons/lightswitch2.wav" )
    end

    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end

    surface.drawShadowedTextBetter( combinedString, "termhuntTimeFont", infoColor, 128, 128, false )

end

-- oops i dropped my spaghetti
local definitelyBoughtAnUndeadItem = CreateClientConVar( "cl_huntersgleehint_hasboughtundead", 0, true, false, "Player has seen the purchase undead stuff hint?", 0, 1 )
local hasBoughtDivineIntervention = CreateClientConVar( "cl_huntersgleehint_hasboughtintervention", 0, true, false, "Player has seen 'its time for divine intervention'?", 0, 1 )
local hasSpectatedSomeone = CreateClientConVar( "cl_huntersgleehint_hasspectatedsomeone", 0, true, false, "Player has seen 'its time for divine intervention'?", 0, 1 )
local hasSwitchedSpectateModes = CreateClientConVar( "cl_huntersgleehint_hasswitchedspectatemodes", 0, true, false, "Player has seen from the eyes of something?", 0, 1 )
local hasStoppedSpectating = CreateClientConVar( "cl_huntersgleehint_hasstoppedspectating", 0, true, false, "Player has stopped following something?", 0, 1 )

LocalPlayer().glee_DefinitelyBoughtAnUndeadItem = definitelyBoughtAnUndeadItem:GetBool()
LocalPlayer().glee_HasBoughtDivineIntervention = hasBoughtDivineIntervention:GetBool()
LocalPlayer().glee_HasSpectatedSomeone = hasSpectatedSomeone:GetBool()
LocalPlayer().glee_HasSwitchedSpectateModes = hasSwitchedSpectateModes:GetBool()
LocalPlayer().glee_HasStoppedSpectatingSomething = hasStoppedSpectating:GetBool()
LocalPlayer().glee_HasDoneSpectateFlashlight = nil

hook.Add( "glee_cl_confirmedpurchase", "storeIfPlayerBoughtUndeadItem", function( ply, id )
    local itemData = GAMEMODE:GetShopItemData( id )
    if itemData.category ~= "Undead" then return end
    if ply:Health() > 0 then return end

    ply.glee_DefinitelyBoughtAnUndeadItem = true
    RunConsoleCommand( "cl_huntersgleehint_hasboughtundead", "1" )

    if id == "resurrection" then
        RunConsoleCommand( "cl_huntersgleehint_hasboughtintervention", "1" )
        ply.glee_HasBoughtDivineIntervention = true

    end
end )

net.Receive( "glee_followedsomething", function()
    LocalPlayer().glee_HasSpectatedSomeone = true
    RunConsoleCommand( "cl_huntersgleehint_hasspectatedsomeone", "1" )

end )
net.Receive( "glee_switchedspectatemodes", function()
    LocalPlayer().glee_HasSwitchedSpectateModes = true
    RunConsoleCommand( "cl_huntersgleehint_hasswitchedspectatemodes", "1" )

end )
net.Receive( "glee_stoppedspectating", function()
    LocalPlayer().glee_HasStoppedSpectatingSomething = true
    RunConsoleCommand( "cl_huntersgleehint_hasstoppedspectating", "1" )

end )

local function shouldPaintHint()
    local inBetween = GAMEMODE:RoundState() == GAMEMODE.ROUND_INACTIVE
    local me = LocalPlayer()
    local dead = me:Health() <= 0

    if not ( inBetween or dead ) then return end

    if inBetween then
        if me.openedHuntersGleeShop then return end
        if me:GetScore() < 50 then return end
        return true, "You have score to spend, things to buy!"

    elseif dead then

        local myScore = me:GetScore()

        if not me.openedHuntersGleeShop then
            return true, "Death is not the end."

        elseif not me.glee_DefinitelyBoughtAnUndeadItem then
            return true, "Purchase an 'Undead' item. If you earn enough, you can come back.", true

        elseif not me.glee_HasBoughtDivineIntervention and myScore >= GAMEMODE:shopItemCost( "resurrection", me ) then
            return true, "It's time for Divine Intervention.", true

        elseif not me.glee_HasSpectatedSomeone then
            local clientsLeftClick = input.LookupBinding( "+attack" )
            clientsLeftClick = input.GetKeyCode( clientsLeftClick )

            local keyName = input.GetKeyName( clientsLeftClick )
            local phrase = language.GetPhrase( keyName )
            return true, "Press " .. phrase .. " to follow stuff!", true

        elseif not me.glee_HasSwitchedSpectateModes and IsValid( me:GetObserverTarget() ) then
            local clientsSpaceBar = input.LookupBinding( "+jump" )
            clientsSpaceBar = input.GetKeyCode( clientsSpaceBar )

            local keyName = input.GetKeyName( clientsSpaceBar )
            local phrase = language.GetPhrase( keyName )
            return true, "Press " .. phrase .. " to switch spectate modes!", true

        elseif not me.glee_HasStoppedSpectatingSomething and IsValid( me:GetObserverTarget() ) then
            local clientsSpaceBar = input.LookupBinding( "+attack2" )
            clientsSpaceBar = input.GetKeyCode( clientsSpaceBar )

            local keyName = input.GetKeyName( clientsSpaceBar )
            local phrase = language.GetPhrase( keyName )
            return true, "Press " .. phrase .. " to stop following stuff!", true

        elseif not me.glee_HasDoneSpectateFlashlight and render.GetLightColor( me:GetPos() ):LengthSqr() < 0.005 then

            local flashlightBind = input.LookupBinding( "impulse 100", false )
            flashlightBind = input.GetKeyCode( flashlightBind )

            local keyName = input.GetKeyName( flashlightBind )
            local phrase = language.GetPhrase( keyName )
            return true, "Press " .. phrase .. " to toggle the spectate flashlight!", true

        end
    end
end

local openTheDamnShopSound = Sound( "buttons/lightswitch2.wav" )
local openTheDamnShopState = nil

local function paintHintForTheShop( _, cur )
    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end
    local _, preamble, blockPostAmble = shouldPaintHint()

    local clientsMenuKey = input.LookupBinding( "+menu" )
    clientsMenuKey = input.GetKeyCode( clientsMenuKey )

    local keyName = input.GetKeyName( clientsMenuKey )
    local phrase = language.GetPhrase( keyName )

    local postamble = ""
    if not blockPostAmble then
        postamble = " Press \" " .. string.upper( phrase ) .. " \" to open the shop."

    end

    local text = preamble .. postamble
    local textColor = Color( 255, 255, 255 )

    if ( cur % 8 ) > 7.75 then
        textColor = Color( 100, 100, 100 )
        if not openTheDamnShopState then
            openTheDamnShopState = true
            LocalPlayer():EmitSound( openTheDamnShopSound, 60, 80, 0.8 )

        end
    else
        openTheDamnShopState = nil

    end

    surface.drawShadowedTextBetter( text, "termhuntShopHintFont", textColor, 128, 128 + 120, false )

end

local darkRed = Color( 200, 0, 0 )
local brighterRed = Color( 255, 50, 50 )
local superScoreColor = Color( 255, 255, 0 )
local BPMCriteria = 60

local function paintMyTotalScore( ply, cur )
    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end

    local myTotalScore = ply:GetScore()
    local textCombo = "Score: " .. myTotalScore
    if myTotalScore == 0 then
        textCombo = "Score: " .. myTotalScore .. " ( Heartbeats Per Minute )"
    end

    local textColor = darkRed
    local resetTime = ply.resetScoreColorTime or 0
    local oldScore = ply.oldDisplayScore or 0
    local scoreDisplayShakeTime = ply.scoreDisplayShakeTime or 0

    if resetTime > cur then
        textColor = ply.scoreColorOverride
        if ply.scoreDisplayAddAtEnd then
            textCombo = textCombo .. ply.scoreDisplayAddAtEnd
        end
    end

    local scoreToCompare = ply.oldScoreToCompare or 0

    if oldScore ~= myTotalScore then

        local overrideColor = brighterRed
        local overrideColorTime = 0.1
        local scoreDisplayAddAtEnd = nil
        local textShakeTime = 0

        -- difference to show
        local difference = myTotalScore - scoreToCompare
        -- real difference, between score now and last time we checked
        local realDifference = myTotalScore - oldScore

        if difference >= 500 then
            overrideColor = superScoreColor

        elseif difference >= 100 then
            overrideColor = color_white

        end

        if realDifference >= 500 then
            overrideColorTime = 8
            textShakeTime = 8
            ply:EmitSound( "209578_zott820_cash-register-purchase.wav", 70, 70 )

        elseif realDifference >= 100 then
            overrideColorTime = 4
            textShakeTime = 3

        elseif realDifference >= 10 then
            overrideColorTime = 3
            textShakeTime = 1

        elseif realDifference <= -10 then
            overrideColorTime = 4
            textShakeTime = 3

        end

        ply.scoreColorOverride = overrideColor
        ply.resetScoreColorTime = math.max( cur + overrideColorTime, math.Clamp( resetTime + overrideColorTime, 0, cur + 10 ) )
        ply.scoreDisplayShakeTime = math.max( cur + textShakeTime, scoreDisplayShakeTime + textShakeTime )
        ply.oldDisplayScore = myTotalScore

        if difference > 0 then
            scoreDisplayAddAtEnd = " +" .. difference

        else
            scoreDisplayAddAtEnd = " " .. difference

        end
        ply.scoreDisplayAddAtEnd = scoreDisplayAddAtEnd

    end

    -- no longer displaying the change, just reset it
    if resetTime < cur then
        ply.oldScoreToCompare = myTotalScore

    end

    local offset = 60
    if scoreDisplayShakeTime > cur then
        local scale = scoreDisplayShakeTime - cur
        scale = scale * 2
        offset = offset + math.Rand( -scale, scale )

    end

    surface.SetFont( "termhuntScoreFont" )
    surface.SetTextColor( textColor )
    surface.SetTextPos( 128, 128 + offset )
    surface.DrawText( textCombo )

end

local fadeRangeStart, fadeRangeEnd = BPMCriteria, BPMCriteria + 40
local fadeRangeSize = math.abs( fadeRangeStart - fadeRangeEnd )
local bpmTextAlpha = 30

local function paintPlyBPM( ply )
    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end

    local blockingScore = ply:GetNWBool( "termHuntBlockScoring" ) or ply:GetNWBool( "termHuntBlockScoring2" )
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

    surface.drawShadowedTextBetter( BPMString, "termhuntBPMFont", Color( 255, 50, 50, currBpmTextAlpha ), screenMiddleW, screenMiddleH + 20 )

end

local function paintTotalScore()
    if not GAMEMODE:CanShowDefaultHud() then return end

    local Text = "Hunt's tally"
    surface.drawShadowedTextBetter( Text, "termhuntTriumphantFont", color_white, screenMiddleW, screenMiddleH + -90 )

    Text = GetGlobalInt( "termHuntTotalScore", 0 )
    Text = math.Round( Text )
    surface.drawShadowedTextBetter( Text, "termhuntTriumphantFont", Color( 255, 0, 0 ), screenMiddleW, screenMiddleH + -40 )

end

local function paintFinestPrey()

    if not GAMEMODE:CanShowDefaultHud() then return end

    local winner = GetGlobalEntity( "termHuntWinner", NULL )
    local winnerScore = GetGlobalInt( "termHuntWinnerScore", 0 )

    local Text = "Finest Prey"
    surface.drawShadowedTextBetter( Text, "termhuntTriumphantFont", color_white, screenMiddleW, screenMiddleH + 64 )

    local winner = winner
    if not IsValid( winner ) then return end

    local Text2 = winner:Name()
    surface.drawShadowedTextBetter( Text2, "termhuntTriumphantFont", color_white, screenMiddleW, screenMiddleH + 64 + 50 )

    local Text3 = winnerScore
    surface.drawShadowedTextBetter( Text3, "termhuntTriumphantFont", Color( 255, 0, 0 ), screenMiddleW, screenMiddleH + 64 + 100 )

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
        if spectating == true then
            paintRoundInfo( ply, cur )
            paintMyTotalScore( ply, cur )

        else
            paintRoundInfo( ply, cur )
            paintMyTotalScore( ply, cur )
            paintPlyBPM( ply )

        end
        if shouldPaintHint() then
            paintHintForTheShop( ply, cur )

        end
    end
    ply.displayedWinners = displayWinners

end
hook.Add( "HUDPaint", "termhunt_playerdisplay", HUDPaint )

-- yoinked from darkrp so we do it right
local FKeyBinds = {
    ["+menu"] = "ShowShop",
}

function GM:PlayerBindPress( _, bind, _ )
    if FKeyBinds[bind] then
        hook.Call( FKeyBinds[bind], GAMEMODE )

    end
end

function GM:CanShowDefaultHud()
    local ply = LocalPlayer()

    if not ply.MAINSCROLLPANEL then return true end
    if not IsValid( ply.MAINSCROLLPANEL ) then return true end
    if ply.MAINSCROLLPANEL:IsMouseInputEnabled() then return nil end

    return true

end

LocalPlayer().openedHuntersGleeShop = nil

function GM:ShowShop()
    if self:CanShowDefaultHud() then
        LocalPlayer().openedHuntersGleeShop = true
        termHuntOpenTheShop()

    end
end


-- dumping random net crap here

potentialResurrectionData = {}
local nextResurrectRecieve = 0

net.Receive( "storeResurrectPos", function()
    if nextResurrectRecieve > CurTime() then return end
    nextResurrectRecieve = CurTime() + 0.01
    local ply = net.ReadEntity()
    local pos = net.ReadVector()
    local data = { ply = ply, pos = pos }
    for ind, overlapData in ipairs( potentialResurrectionData ) do -- remove old resurrect pos
        if overlapData.ply ~= ply then continue end
        table.remove( potentialResurrectionData, ind )
    end
    table.insert( potentialResurrectionData, data )
end )

local function IsSpectatingTerminator()
    local spectateTarget = LocalPlayer():GetObserverTarget()
    if not spectateTarget:IsNextBot() then return end

    return true, spectateTarget

end

hook.Add( "CalcView", "glee_override_spectating_angles", function( ply, _, _, fov )
    local is, spectateTarget = IsSpectatingTerminator()

    if not is then return end

    local mode = ply:GetObserverMode()
    if mode ~= OBS_MODE_IN_EYE then return end

    local ang = spectateTarget:GetAngles()
    local forward = ang:Forward()

    if not spectateTarget.GetShootPos then return end

    local view = {
        origin = spectateTarget:GetShootPos() + forward * 15,
        angles = ang,
        fov = fov,
        drawviewer = false

    }
    return view

end )