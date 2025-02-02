include( "shared.lua" )
include( "cl_shopstandards.lua" ) -- has to load almost first
include( "cl_shoppinggui.lua" )
include( "modules/cl_souls.lua" )
include( "modules/cl_targetid.lua" )
include( "modules/cl_scoreboard.lua" )
include( "modules/cl_obfuscation.lua" )
include( "modules/cl_killfeedoverride.lua" )
include( "modules/cl_spectateflashlight.lua" )
include( "modules/spawnset/cl_spawnsetvote.lua" )
include( "modules/signalstrength/cl_signalstrength.lua" )
include( "modules/thirdpersonflashlight/cl_flashlight.lua" )
include( "modules/firsttimeplayers/cl_firsttimeplayers.lua" )

include( "modules/battery/cl_battery.lua" )
include( "modules/bpm/cl_bpm.lua" )

local GAMEMODE = GM

-- from https://github.com/Facepunch/garrysmod/blob/e189f14c088298ca800136fcfcfaf5d8535b6648/garrysmod/lua/includes/modules/killicon.lua#L202
local killIconColor = Color( 255, 80, 0, 255 )
killicon.Add( "glee_skullpickup", "vgui/hud/glee_skullpickup", killIconColor )

local doHud = CreateClientConVar( "huntersglee_cl_showhud", 1, true, false, "Show the hud? Beats, score, round state...", 0, 1 )
local paddingFromEdge = terminator_Extras.defaultHudTextPaddingFromEdge
local scoreDisplayPadding = glee_sizeScaled( nil, 60 )
local scoreMaxShakeSize = glee_sizeScaled( nil, 2 )
local skullDisplayPadding = glee_sizeScaled( nil, 96 )
local hintPadding = glee_sizeScaled( nil, 156 )

local CurTime = CurTime

-- TIME
local fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 30 ),
    weight = 500,
    blursize = 0,
    scanlines = 1,
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
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 30 ),
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
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 30 ),
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

fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 40 ),
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
surface.CreateFont( "huntersglee_finestpreyhint", fontData )

-- the RATE YOUR HJEAT BEATS OH GOD HE'S HERE
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 80 ),
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
fontData = {
    font = "Arial",
    extended = false,
    size = glee_sizeScaled( nil, 50 ),
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

local nextDontDrawCheck = 0
local dontDraw

function GAMEMODE:DontDrawDefaultHud()
    local cur = CurTime()
    if nextDontDrawCheck < cur then
        dontDraw = nil
        nextDontDrawCheck = cur + 1
        if hook.Run( "HUDShouldDraw", "CHudHealth" ) == false then dontDraw = true return true end
        if hook.Run( "HUDShouldDraw", "CHudBattery" ) == false then dontDraw = true return true end

    end
    if dontDraw then return true end

end

GAMEMODE.currRoundState = GAMEMODE.currRoundState or GAMEMODE.ROUND_SETUP

function GAMEMODE:RoundState()
    return GAMEMODE.currRoundState

end

net.Receive( "glee_roundstate", function()
    GAMEMODE.currRoundState = net.ReadInt( 8 )

end )

function GAMEMODE:TranslatedBind( bind )
    local lookedUp = input.LookupBinding( bind )
    if not lookedUp then return end

    local keyCode = input.GetKeyCode( lookedUp )
    -- unbound
    if not keyCode then return end

    local keyName = input.GetKeyName( keyCode )
    local phrase = language.GetPhrase( keyName )

    return true, phrase

end

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
    local volume = ( BPM / 200 ) + -0.1
    nextBeat = cur + beatTime

    if ply:Health() > 0 then
        ply:EmitSound( "418788_name_heartbeat_single.wav", 100, pitch, volume )

    end

    return true, beatTime

end


local function paintRoundInfo( ply, cur )
    local typeVal = GetGlobalString( "GLEE_SpawnSetPrettyName", "Hunter's Glee" )
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

    if typeVal ~= "Hunter's Glee" then
        combinedString = typeVal .. " : " .. combinedString

    end

    if ply.oldInfo ~= infoVal then
        ply.oldInfo = infoVal
        ply.infoColorOverride = Color( 255, 50, 50 )
        ply.resetColorTime = cur + 0.1
        ply:EmitSound( "buttons/lightswitch2.wav" )
    end

    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end

    surface.drawShadowedTextBetter( combinedString, "termhuntTimeFont", infoColor, paddingFromEdge, paddingFromEdge, false )

end


local invisibleColor = Color( 0, 0, 0, 0 )
local darkRed = Color( 200, 0, 0 )
local brighterRed = Color( 255, 50, 50 )
local superScoreColor = Color( 255, 255, 0 )

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
        ply.scoreDisplayShakeTime = math.max( cur + textShakeTime, scoreDisplayShakeTime + textShakeTime / 2 )
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

    local offset = scoreDisplayPadding
    if scoreDisplayShakeTime > cur then
        local scale = scoreDisplayShakeTime - cur
        scale = scale * scoreMaxShakeSize
        offset = offset + math.Rand( -scale, scale )

    end

    surface.SetFont( "termhuntScoreFont" )
    surface.SetTextColor( textColor )
    surface.SetTextPos( paddingFromEdge, paddingFromEdge + offset )
    surface.DrawText( textCombo )

end

local function paintMyTotalSkulls( ply, cur )
    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end

    local myTotalSkulls = ply:GetSkulls()
    local textCombo = "Skulls: " .. myTotalSkulls

    local textColor = invisibleColor
    local resetTime = ply.resetSkullsColorTime or 0
    local oldSkulls = ply.oldDisplaySkulls or 0
    local skullsDisplayShakeTime = ply.skullsDisplayShakeTime or 0

    if resetTime > cur then
        textColor = ply.skullsColorOverride
        if ply.skullsDisplayAddAtEnd then
            textCombo = textCombo .. ply.skullsDisplayAddAtEnd
        end
    end

    local skullsToCompare = ply.oldSkullsToCompare or 0

    if myTotalSkulls >= 1 then
        textColor = darkRed

    end

    if oldSkulls ~= myTotalSkulls then

        local overrideColor = brighterRed
        local overrideColorTime = 4
        local skullsDisplayAddAtEnd = nil
        local textShakeTime = 1

        -- difference to show
        local difference = myTotalSkulls - skullsToCompare

        ply.skullsColorOverride = overrideColor
        ply.resetSkullsColorTime = math.max( cur + overrideColorTime, math.Clamp( resetTime + overrideColorTime, 0, cur + 10 ) )
        ply.skullsDisplayShakeTime = math.max( cur + textShakeTime, skullsDisplayShakeTime + textShakeTime )
        ply.oldDisplaySkulls = myTotalSkulls

        if difference > 0 then
            skullsDisplayAddAtEnd = " +" .. difference

        else
            skullsDisplayAddAtEnd = " " .. difference

        end
        ply.skullsDisplayAddAtEnd = skullsDisplayAddAtEnd

    end

    -- no longer displaying the change, just reset it
    if resetTime < cur then
        ply.oldSkullsToCompare = myTotalSkulls

    end

    local offset = skullDisplayPadding
    if skullsDisplayShakeTime > cur then
        local scale = skullsDisplayShakeTime - cur
        scale = scale * scoreMaxShakeSize
        offset = offset + math.Rand( -scale, scale )

    end

    surface.SetFont( "termhuntScoreFont" )
    surface.SetTextColor( textColor )
    surface.SetTextPos( paddingFromEdge, paddingFromEdge + offset )
    surface.DrawText( textCombo )

end


local additionalString = ""
local defaultFont = "termhuntShopHintFont"
local theFont = defaultFont
local lastWinner = nil
local lastWinnersSkulls = 0
local finestPreyColor = Color( 255, 255, 255, 0 )
local winnerFadeAwayTime = 0

local function paintFinestPreyEncouragement( ply, cur )
    if #player.GetAll() <= 1 then return end
    local newWinner = GetGlobalEntity( "termHuntWinner", NULL )
    if not IsValid( newWinner ) then return end
    local tieBroken = GetGlobalBool( "termHuntWinnerTied", false )
    local newWinnersSkulls = newWinner:GetSkulls()
    if newWinnersSkulls <= 0 then return end

    if newWinner ~= lastWinner then
        if IsValid( lastWinner ) then
            winnerFadeAwayTime = math.max( cur, winnerFadeAwayTime ) + 5
            if newWinnersSkulls > 0 then
                -- lost finest prey
                if lastWinner == ply and newWinner ~= ply then
                    ply:EmitSound( "buttons/combine_button2.wav", 0, 100, 0.75 )
                    additionalString = "\nThey're the finest prey!"
                    theFont = "huntersglee_finestpreyhint"

                -- gained it!
                elseif lastWinner ~= ply and newWinner == ply then
                    ply:EmitSound( "buttons/blip1.wav", 0, 100, 0.5, CHAN_STATIC )
                    additionalString = "\nYou're the finest prey!"
                    theFont = "huntersglee_finestpreyhint"

                end
            end
            if tieBroken then
                additionalString = "\nTie broken with score."

            end
        elseif newWinner and newWinnersSkulls == 1 then
            winnerFadeAwayTime = math.max( cur, winnerFadeAwayTime ) + 5
            ply:EmitSound( "buttons/blip1.wav", 0, 100, 0.5, CHAN_STATIC )
            firstSkulling = newWinner
            additionalString = "\nFirst skull!"
            theFont = "huntersglee_finestpreyhint"

        elseif newWinnersSkulls > 1 and additionalString == "\nFirst skull!" then
            additionalString = ""

        end
    elseif newWinnersSkulls ~= lastWinnersSkulls and newWinnersSkulls > lastWinnersSkulls then
        winnerFadeAwayTime = math.max( cur, winnerFadeAwayTime ) + 2

    end

    if newWinner and newWinner == ply then
        theFont = "huntersglee_finestpreyhint"

    end

    lastWinnersSkulls = newWinnersSkulls
    lastWinner = newWinner

    if winnerFadeAwayTime > CurTime() then
        finestPreyColor.a = 255

    else
        finestPreyColor.a = math.Clamp( finestPreyColor.a + -0.7, 0, 255 )

    end

    if finestPreyColor.a <= 0 or newWinnersSkulls <= 0 then
        additionalString = ""
        theFont = defaultFont
        return

    end

    local sIfMultiple = ""
    if newWinnersSkulls > 1 then
        sIfMultiple = "s"

    end

    local theText

    if newWinner == ply then
        theText = " You have " .. newWinnersSkulls .. " skull" ..  sIfMultiple .. "!" .. additionalString

    else
        theText = newWinner:Nick() .. " has " .. newWinnersSkulls .. " skull" ..  sIfMultiple .. "!" .. additionalString

    end

    surface.drawShadowedTextBetter( theText, theFont, finestPreyColor, screenMiddleW, paddingFromEdge, true )

end


-- oops i dropped my spaghetti
local definitelyBoughtAnUndeadItem = CreateClientConVar( "cl_huntersgleehint_hasboughtundead", 0, true, false, "Player has seen the purchase undead stuff hint?", 0, 1 )
local hasBoughtDivineIntervention = CreateClientConVar( "cl_huntersgleehint_hasboughtintervention", 0, true, false, "Player has seen 'its time for divine intervention'?", 0, 1 )
local hasSpectatedSomeone = CreateClientConVar( "cl_huntersgleehint_hasspectatedsomeone", 0, true, false, "Player has seen 'its time for divine intervention'?", 0, 1 )
local hasSwitchedSpectateModes = CreateClientConVar( "cl_huntersgleehint_hasswitchedspectatemodes", 0, true, false, "Player has seen from the eyes of something?", 0, 1 )
local hasStoppedSpectating = CreateClientConVar( "cl_huntersgleehint_hasstoppedspectating", 0, true, false, "Player has stopped following something?", 0, 1 )


hook.Add( "InitPostEntity", "glee_clreadhints", function()
    LocalPlayer().glee_DefinitelyBoughtAnUndeadItem = definitelyBoughtAnUndeadItem:GetBool()
    LocalPlayer().glee_HasBoughtDivineIntervention = hasBoughtDivineIntervention:GetBool()
    LocalPlayer().glee_HasSpectatedSomeone = hasSpectatedSomeone:GetBool()
    LocalPlayer().glee_HasSwitchedSpectateModes = hasSwitchedSpectateModes:GetBool()
    LocalPlayer().glee_HasStoppedSpectatingSomething = hasStoppedSpectating:GetBool()
    LocalPlayer().glee_HasDoneSpectateFlashlight = nil

end )

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
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 0, 120, 0.8 )
    LocalPlayer().glee_HasSpectatedSomeone = true
    RunConsoleCommand( "cl_huntersgleehint_hasspectatedsomeone", "1" )

end )
net.Receive( "glee_followednexthing", function()
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 0, 200, 0.5 )

end )
net.Receive( "glee_switchedspectatemodes", function()
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 0, 180, 0.5 )
    LocalPlayer().glee_HasSwitchedSpectateModes = true
    RunConsoleCommand( "cl_huntersgleehint_hasswitchedspectatemodes", "1" )

end )
net.Receive( "glee_stoppedspectating", function()
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 0, 90, 0.8 )
    LocalPlayer().glee_HasStoppedSpectatingSomething = true
    RunConsoleCommand( "cl_huntersgleehint_hasstoppedspectating", "1" )

end )

local function genericHints()
    local me = LocalPlayer()

    local wep = me:GetActiveWeapon()
    if not IsValid( wep ) then
        wep = me.ghostEnt

    end

    local isWepHintPreStack, wepHintPreStack
    if wep and wep.HintPreStack then
        isWepHintPreStack, wepHintPreStack = wep:HintPreStack()

    end
    if isWepHintPreStack then
        return true, wepHintPreStack
    end

    local inBetween = GAMEMODE:RoundState() == GAMEMODE.ROUND_INACTIVE
    local dead = me:Health() <= 0

    if inBetween then
        if not me.openedHuntersGleeShop and me:GetScore() >= 50 then
            local clientsMenuKey = input.LookupBinding( "+menu" )
            if not clientsMenuKey then me.openedHuntersGleeShop = true return end

            clientsMenuKey = input.GetKeyCode( clientsMenuKey )
            if not clientsMenuKey then me.openedHuntersGleeShop = true return end

            local keyName = input.GetKeyName( clientsMenuKey )
            local phrase = language.GetPhrase( keyName )

            return true, "You have score to spend, things to buy!\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

        end
    elseif dead then
        local myScore = me:GetScore()

        local result, hooksHint = hook.Run( "huntersglee_cl_displayhint_predeadhints", me )

        if result then
            return result, hooksHint

        elseif not me.openedHuntersGleeShop then
            local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
            if not valid then me.openedHuntersGleeShop = true return end

            return true, "Death is not the end.\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

        elseif not me.glee_DefinitelyBoughtAnUndeadItem then
            return true, "Purchase 'gifts' to make score while dead. You can even revive yourself."

        elseif not me.glee_HasSpectatedSomeone then
            local valid, phrase = GAMEMODE:TranslatedBind( "+attack" )
            if not valid then me.glee_HasSpectatedSomeone = true return end

            return true, "Press " .. phrase .. " to follow stuff!"

        elseif not me.glee_HasSwitchedSpectateModes and IsValid( me:GetObserverTarget() ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+jump" )
            if not valid then me.glee_HasSwitchedSpectateModes = true return end

            return true, "Press " .. phrase .. " to switch spectate modes!"

        elseif not me.glee_HasStoppedSpectatingSomething and IsValid( me:GetObserverTarget() ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+attack2" )
            if not valid then me.glee_HasStoppedSpectatingSomething = true return end

            return true, "Press " .. phrase .. " to stop following stuff!"

        elseif not me.glee_HasDoneSpectateFlashlight and render.GetLightColor( me:GetPos() ):LengthSqr() < 0.005 then
            local valid, phrase = GAMEMODE:TranslatedBind( "+impulse 100" )
            if not valid then me.glee_HasDoneSpectateFlashlight = true return end

            return true, "Press " .. phrase .. " to toggle the spectate flashlight!"

        elseif not me.glee_HasBoughtDivineIntervention and myScore >= GAMEMODE:shopItemCost( "resurrection", me ) then
            return true, "Buy Divine Intervention in the shop to resurrect yourself."

        end

        result, hooksHint = hook.Run( "huntersglee_cl_displayhint_postdeadhints", me )
        if result then
            return result, hooksHint

        end
    end
    local isWepHintPostStack, wepHintPostStack
    if wep and wep.HintPostStack then
        isWepHintPostStack, wepHintPostStack = wep:HintPostStack()

    end
    if isWepHintPostStack then
        return true, wepHintPostStack

    end
end

local openTheDamnShopSound = Sound( "buttons/lightswitch2.wav" )
local openTheDamnShopState = nil

local function paintTheDamnHint( _, theHint, cur )
    if not GAMEMODE:CanShowDefaultHud() then return end
    if not doHud:GetBool() then return end

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

    surface.drawShadowedTextBetter( theHint, "termhuntShopHintFont", textColor, paddingFromEdge, paddingFromEdge + hintPadding, false )

end

local totalScoreNameOffset = glee_sizeScaled( nil, -90 )
local totalScoreOffset = glee_sizeScaled( nil, -40 )

local function paintTotalScore()
    if not GAMEMODE:CanShowDefaultHud() then return end

    local Text = "Hunt's tally"
    surface.drawShadowedTextBetter( Text, "termhuntTriumphantFont", color_white, screenMiddleW, screenMiddleH + totalScoreNameOffset )

    Text = GetGlobalInt( "termHuntTotalScore", 0 )
    Text = math.Round( Text )
    surface.drawShadowedTextBetter( Text, "termhuntTriumphantFont", Color( 255, 0, 0 ), screenMiddleW, screenMiddleH + totalScoreOffset )

end

local preyTextOffset1 = glee_sizeScaled( nil, 64 )
local preyTextOffset2 = glee_sizeScaled( nil, 50 )
local preyTextOffset3 = glee_sizeScaled( nil, 50 )

local function paintFinestPrey()

    if not GAMEMODE:CanShowDefaultHud() then return end

    local winner = GetGlobalEntity( "termHuntWinner", NULL )
    local winnerSkulls = GetGlobalInt( "termHuntWinnerSkulls", 0 )

    local preyText1Y = screenMiddleH + preyTextOffset1
    local preyText2Y = preyText1Y + preyTextOffset2
    local preyText3Y = preyText2Y + preyTextOffset3

    local Text = "Finest Prey"
    surface.drawShadowedTextBetter( Text, "termhuntTriumphantFont", color_white, screenMiddleW, preyText1Y )

    local winner = winner
    if not IsValid( winner ) then
        local Text2 = "Nobody"
        surface.drawShadowedTextBetter( Text2, "termhuntTriumphantFont", color_white, screenMiddleW, preyText2Y )

        local Text3 = "No skulls were collected"
        surface.drawShadowedTextBetter( Text3, "termhuntTriumphantFont", Color( 255, 0, 0 ), screenMiddleW, preyText3Y )
        return

    end

    local Text2 = winner:Name()
    surface.drawShadowedTextBetter( Text2, "termhuntTriumphantFont", color_white, screenMiddleW, preyText2Y )

    local sIfMultiple = ""
    if winnerSkulls > 1 then
        sIfMultiple = "s"

    end

    local Text3 = winnerSkulls .. " Skull" .. sIfMultiple
    surface.drawShadowedTextBetter( Text3, "termhuntTriumphantFont", Color( 255, 0, 0 ), screenMiddleW, preyText3Y )

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
        paintRoundInfo( ply, cur )
        paintMyTotalScore( ply, cur )
        paintMyTotalSkulls( ply, cur )
        --paintFinestPreyEncouragement( ply, cur )

        local needsHints, hint = genericHints()
        if needsHints then
            paintTheDamnHint( ply, hint, cur )

        end

        local spectating = ply:Health() <= 0

        if spectating == true then
            paintOtherPlayers( ply )

        else
            hook.Run( "glee_cl_aliveplyhud", ply, cur )

        end

    end
    ply.displayedWinners = displayWinners

end
hook.Add( "HUDPaint", "termhunt_playerdisplay", HUDPaint )

local function ClThink()
    local ply = LocalPlayer()
    local cur = UnPredictedCurTime()
    local spectating = ply:Health() <= 0

    if spectating then return end

    -- sounds
    local didBeat, interval = beatThink( ply, cur )
    if didBeat then
        hook.Run( "glee_cl_heartbeat", ply, interval )

    end
end

hook.Add( "Think", "termhunt_clthink", ClThink )

hook.Add( "PreDrawViewModel", "glee_dontdrawviewmodelsWHENDEAD", function( _vm, ply )
    if ply:Health() > 0 then return end -- they are alive
    if ( ply:GetObserverMode() == OBS_MODE_IN_EYE ) and IsValid( ply:GetObserverTarget() ) then return end -- spectating another player

    return true -- dont draw vm

end )

-- flash the window on round state change!
-- only flash when round ends, and goes into active
local oldState = nil
local toFlash = {
    [GAMEMODE.ROUND_ACTIVE]     = true,
    [GAMEMODE.ROUND_LIMBO]      = true,
}

hook.Add( "Think", "termhunt_alertroundchange", function()
    local currState = GAMEMODE:RoundState()
    if oldState == currState then return end
    oldState = currState

    if not toFlash[currState] then return end
    if system.HasFocus() then return end
    system.FlashWindow()

end )

function GAMEMODE:CanShowDefaultHud()
    local ply = LocalPlayer()

    if not ply.MAINSSHOPPANEL then return true end
    if not IsValid( ply.MAINSSHOPPANEL ) then return true end
    if ply.MAINSSHOPPANEL:IsMouseInputEnabled() then return nil end

    return true

end

local function IsSpectatingTerminator()
    local spectateTarget = LocalPlayer():GetObserverTarget()
    if not spectateTarget:IsNextBot() then return nil, spectateTarget end

    return true, spectateTarget

end

hook.Add( "CalcView", "glee_override_spectating_angles", function( ply, _, ang, fov )

    local isTerm, spectateTarget = IsSpectatingTerminator()
    local mode = ply:GetObserverMode()

    if mode == OBS_MODE_CHASE then

        if not spectateTarget.GetShootPos then return end

        local pivot = spectateTarget:GetShootPos()
        local dir = -ang:Forward()
        local fallbackDrawPos = pivot + dir * 15
        local desiredDrawPos = pivot + dir * 100

        local checkTr = {
            start = fallbackDrawPos,
            endpos = desiredDrawPos,
            filter = spectateTarget

        }

        local spectateTr = util.TraceLine( checkTr )

        local view = {
            origin = spectateTr.HitPos,
            angles = ang,
            fov = fov,
            drawviewer = false,

        }
        return view
    end

    if not isTerm then return end

    if mode == OBS_MODE_IN_EYE then
        local termAng
        if spectateTarget.GetEyeAngles then
            termAng = spectateTarget:GetEyeAngles()

        else
            termAng = spectateTarget:GetAngles()

        end

        local forward = termAng:Forward()

        if not spectateTarget.GetShootPos then return end

        local view = {
            origin = spectateTarget:GetShootPos() + forward * 15,
            angles = termAng,
            fov = fov,
            znear = 8,
            drawviewer = false

        }
        return view

    end
end )

--binds
-- yoinked from darkrp so we do it right
local FKeyBinds = {
    ["+menu"] = "ShowShop",
    ["noclip"] = "DropCurrentWeapon",

}

function GM:PlayerBindPress( _, bind, _, code )
    if FKeyBinds[bind] then
        hook.Call( FKeyBinds[bind], GAMEMODE, code )

    end
end

function GM:DropCurrentWeapon( keyCode )
    if not keyCode then return end
    local name = "glee_dropweaponhold"
    timer.Create( name, 0.05, 0, function()
        if not input.IsButtonDown( keyCode ) then timer.Remove( name ) return end
        net.Start( "glee_dropcurrentweapon" )
        net.SendToServer()

    end )
end