-- top-left HUD: round timer, score, skulls, hints

local GAMEMODE = GAMEMODE or GM
local CurTime  = CurTime

local neverShowInfo = CreateClientConVar( "huntersglee_cl_nevershowtoplefthud", 0, true, false, "Never show round info, score, and skull count?", 0, 1 )
local alwaysShowInfo = CreateClientConVar( "huntersglee_cl_alwaysshowtoplefthud", 0, true, false, "Always show round info, score, and skull count?", 0, 1 )

local paddingFromEdge   = terminator_Extras.defaultHudPaddingFromEdge
local paddingFromBottom = terminator_Extras.defaultHudPaddingFromBottom
local scoreMaxShakeSize = glee_sizeScaled( nil, 2 )
local laneSpacing       = terminator_Extras.hl2hud.laneSpacing
local blockPadding      = terminator_Extras.hl2hud.blockPadding
-- fonts are now defined in cl_gleehud.lua

local hour = 60 * 60

local hl2Hud = terminator_Extras.hl2hud

local defaultHudColor   = hl2Hud.colorHappyYellow
local unhappyHudColor   = hl2Hud.colorUnHappyYellow
local infoChangedColor  = Color( 255, 50, 50 )
local superScoreColor   = Color( 255, 255, 0 )


-- ---------------------------------------------------------------------------
-- Round info
-- think returns: text, stayPresent, doFlash, xOffset, textColor
-- ---------------------------------------------------------------------------

local oldInfo         = "---"
local infoColorExpiry = 0

local function thinkRoundInfo( ply, cur )
    local typeVal = GetGlobalString( "GLEE_SpawnSetPrettyName", "Hunter's Glee" )
    local timeVal = GetGlobalInt( "TERMHUNT_PLAYERTIMEVALUE", 0 )
    local infoVal = GetGlobalString( "TERMHUNT_PLAYERVALUENAME", "---" )

    if timeVal == math.huge then timeVal = 0 end

    local combinedString = infoVal

    if timeVal > hour then
        local hours    = math.floor( timeVal / hour )
        combinedString = combinedString .. hours .. ":"

    end

    combinedString = combinedString .. string.ToMinutesSeconds( timeVal )

    if typeVal ~= "Hunter's Glee" then
        combinedString = typeVal .. " : " .. combinedString

    end

    local doFlash = false
    if oldInfo ~= infoVal then
        oldInfo         = infoVal
        doFlash         = true -- this also wakes it up
        infoColorExpiry = cur + 0.4
        ply:EmitSound( "buttons/lightswitch2.wav" )

    end

    local textColor   = infoColorExpiry > cur and infoChangedColor or defaultHudColor
    local stayPresent = GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE

    return combinedString, stayPresent, doFlash, 0, textColor

end


-- ---------------------------------------------------------------------------
-- Score
-- think returns: text, stayPresent, doFlash, xOffset, textColor
-- ---------------------------------------------------------------------------

local scoreColorOverride    = nil
local scoreColorExpiry      = 0
local scoreVisibleUntil     = 0
local scoreDisplayShakeTime = 0
local scoreDisplayAddAtEnd  = nil
local oldDisplayScore       = 0
local oldScoreToCompare     = 0

local function thinkScore( ply, cur )
    local myTotalScore = ply:GetScore()
    local textCombo    = "Score: " .. myTotalScore

    if myTotalScore == 0 then
        textCombo = "Score: " .. myTotalScore .. " ( Heartbeats Per Minute )"

    end

    local textColor = unhappyHudColor
    local doFlash   = false

    if scoreColorExpiry > cur then
        textColor = scoreColorOverride

        if scoreDisplayAddAtEnd then
            textCombo = textCombo .. scoreDisplayAddAtEnd

        end
    end

    if oldDisplayScore ~= myTotalScore then
        doFlash = true

        local overrideColor     = defaultHudColor
        local overrideColorTime = 0.1
        local textShakeTime     = 0

        -- difference to show
        local difference    = myTotalScore - oldScoreToCompare
        -- real difference, between score now and last time we checked
        local realDifference = myTotalScore - oldDisplayScore
        local absDifference  = math.abs( realDifference )

        if difference >= 500 then
            overrideColor = superScoreColor

        end

        if absDifference >= 500 then
            overrideColorTime = 8
            textShakeTime     = 8
            ply:EmitSound( "hunters_glee/209578_zott820_cash-register-purchase.wav", 70, 70 )

        elseif absDifference >= 100 then
            overrideColorTime = 4
            textShakeTime     = 3

        elseif absDifference >= 10 then
            overrideColorTime = 3
            textShakeTime     = 1

        end

        scoreColorOverride    = overrideColor
        scoreColorExpiry      = math.max( cur + overrideColorTime, math.Clamp( scoreColorExpiry + overrideColorTime, 0, cur + 10 ) )
        scoreDisplayShakeTime = math.max( cur + textShakeTime, scoreDisplayShakeTime + textShakeTime / 2 )
        oldDisplayScore       = myTotalScore

        if absDifference >= 25 then
            scoreVisibleUntil = math.max( cur + overrideColorTime, scoreVisibleUntil )

        end

        if difference > 0 then
            scoreDisplayAddAtEnd = " +" .. difference

        else
            scoreDisplayAddAtEnd = " " .. difference

        end
    end

    if scoreColorExpiry < cur then
        oldScoreToCompare = myTotalScore

    end

    local xOffset = 0
    if scoreDisplayShakeTime > cur then
        local shakeScale = ( scoreDisplayShakeTime - cur ) * scoreMaxShakeSize
        xOffset          = math.Rand( -shakeScale, shakeScale )

    end

    local stayPresent = scoreVisibleUntil > cur

    stayPresent = stayPresent or myTotalScore <= 10

    doFlash = doFlash and stayPresent -- flash also wakes it up

    return textCombo, stayPresent, doFlash, xOffset, textColor

end


-- ---------------------------------------------------------------------------
-- Skulls
-- think returns: text, stayPresent, doFlash, xOffset, textColor
-- ---------------------------------------------------------------------------

local skullsColorOverride   = nil
local skullsColorExpiry     = 0
local skullsDisplayAddAtEnd = nil
local oldDisplaySkulls      = 0
local oldSkullsToCompare    = 0

local function thinkSkulls( ply, cur )
    local myTotalSkulls = ply:GetSkulls()
    local textCombo     = "Skulls: " .. myTotalSkulls

    local textColor = unhappyHudColor
    local doFlash   = false

    if skullsColorExpiry > cur then
        textColor = skullsColorOverride

        if skullsDisplayAddAtEnd then
            textCombo = textCombo .. skullsDisplayAddAtEnd

        end
    end

    if oldDisplaySkulls ~= myTotalSkulls then
        doFlash = true

        local overrideColorTime = 4
        local difference        = myTotalSkulls - oldSkullsToCompare

        skullsColorOverride   = defaultHudColor
        skullsColorExpiry     = math.max( cur + overrideColorTime, math.Clamp( skullsColorExpiry + overrideColorTime, 0, cur + 10 ) )
        oldDisplaySkulls      = myTotalSkulls

        if difference > 0 then
            skullsDisplayAddAtEnd = " +" .. difference

        else
            skullsDisplayAddAtEnd = " " .. difference

        end
    end

    if skullsColorExpiry < cur then
        oldSkullsToCompare = myTotalSkulls

    end

    local stayPresent = skullsColorExpiry > cur

    return textCombo, stayPresent, doFlash, 0, textColor

end


-- Hint system

-- oops i dropped my spaghetti
local definitelyBoughtAnUndeadItem = CreateClientConVar( "cl_huntersgleehint_hasboughtundead", 0, true, false, "Player has seen the purchase undead stuff hint?", 0, 1 )
local hasBoughtDivineIntervention  = CreateClientConVar( "cl_huntersgleehint_hasboughtintervention", 0, true, false, "Player has seen 'its time for divine intervention'?", 0, 1 )
local hasSpectatedSomeone          = CreateClientConVar( "cl_huntersgleehint_hasspectatedsomeone", 0, true, false, "Player has seen 'its time for divine intervention'?", 0, 1 )
local hasSwitchedSpectateModes     = CreateClientConVar( "cl_huntersgleehint_hasswitchedspectatemodes", 0, true, false, "Player has seen from the eyes of something?", 0, 1 )
local hasStoppedSpectating         = CreateClientConVar( "cl_huntersgleehint_hasstoppedspectating", 0, true, false, "Player has stopped following something?", 0, 1 )


hook.Add( "InitPostEntity", "glee_clreadhints", function()
    LocalPlayer().glee_DefinitelyBoughtAnUndeadItem  = definitelyBoughtAnUndeadItem:GetBool()
    LocalPlayer().glee_HasBoughtDivineIntervention   = hasBoughtDivineIntervention:GetBool()
    LocalPlayer().glee_HasSpectatedSomeone           = hasSpectatedSomeone:GetBool()
    LocalPlayer().glee_HasSwitchedSpectateModes      = hasSwitchedSpectateModes:GetBool()
    LocalPlayer().glee_HasStoppedSpectatingSomething = hasStoppedSpectating:GetBool()
    LocalPlayer().glee_HasDoneSpectateFlashlight     = nil

end )

local deadCategories = {
    "DEADSACRIFICES",
    "DEADGIFTS",
}

hook.Add( "glee_cl_confirmedpurchase", "storeIfPlayerBoughtUndeadItem", function( ply, id )
    local itemData = GAMEMODE:GetShopItemData( id )
    if not itemData then return end

    local isDeadItem = false
    for _, category in ipairs( deadCategories ) do
        if not itemData.tags[category] then continue end
        isDeadItem = true

    end
    if not isDeadItem then return end
    if ply:Health() > 0 then return end

    ply.glee_DefinitelyBoughtAnUndeadItem = true
    RunConsoleCommand( "cl_huntersgleehint_hasboughtundead", "1" )

    if id == "resurrection" then
        RunConsoleCommand( "cl_huntersgleehint_hasboughtintervention", "1" )
        ply.glee_HasBoughtDivineIntervention = true

    end
end )


net.Receive( "glee_followedsomething", function()
    if not IsValid( LocalPlayer() ) then return end -- ???????
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 120, 0.8 )
    LocalPlayer().glee_HasSpectatedSomeone = true
    RunConsoleCommand( "cl_huntersgleehint_hasspectatedsomeone", "1" )

    LocalPlayer().glee_SpectateOrbitDistance = nil

end )

net.Receive( "glee_followednexthing", function()
    if not IsValid( LocalPlayer() ) then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 200, 0.5 )

    LocalPlayer().glee_SpectateOrbitDistance = nil

end )

net.Receive( "glee_switchedspectatemodes", function()
    if not IsValid( LocalPlayer() ) then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 180, 0.5 )
    LocalPlayer().glee_HasSwitchedSpectateModes = true
    RunConsoleCommand( "cl_huntersgleehint_hasswitchedspectatemodes", "1" )

end )

net.Receive( "glee_stoppedspectating", function()
    if not IsValid( LocalPlayer() ) then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 90, 0.8 )
    LocalPlayer().glee_HasStoppedSpectatingSomething = true
    RunConsoleCommand( "cl_huntersgleehint_hasstoppedspectating", "1" )

    LocalPlayer().glee_SpectateOrbitDistance = nil

end )

net.Receive( "glee_starteddriving", function()
    if not IsValid( LocalPlayer() ) then return end
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_LIMBO then return end -- hack fix to stop these sounds from overriding roundEndSound
    LocalPlayer():EmitSound( "weapons/crossbow/bolt_fly4.wav", 100, 150, 1 )
    LocalPlayer():EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 200, 1 )
    LocalPlayer():EmitSound( "ui/buttonclick.wav", 100, 80, 1 )
    LocalPlayer().glee_NextControlSomethingHint = CurTime() + 60

    LocalPlayer().glee_SpectateOrbitDistance = nil

end )

net.Receive( "glee_stoppeddriving", function()
    if not IsValid( LocalPlayer() ) then return end
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_LIMBO then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 100, 0.8 )
    LocalPlayer():EmitSound( "weapons/crossbow/bolt_fly4.wav", 100, 50, 0.25 )
    LocalPlayer():EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 150, 0.25 )

end )


local function genericHints()
    local me = LocalPlayer()

    local wep = me:GetActiveWeapon()
    if not IsValid( wep ) and IsValid( me.ghostEnt ) then
        wep = me.ghostEnt

    end

    local wepOwnedByMe = IsValid( wep ) and wep:GetOwner() == me

    local isWepHintPreStack, wepHintPreStack
    if wep and wep.HintPreStack and wepOwnedByMe then
        isWepHintPreStack, wepHintPreStack = wep:HintPreStack()

    end
    if isWepHintPreStack then
        return true, wepHintPreStack

    end

    local inBetween = GAMEMODE:RoundState() == GAMEMODE.ROUND_INACTIVE
    local dead      = me:Health() <= 0

    if inBetween then
        -- hey you should open the shop!!!!
        if not me.openedHuntersGleeShop and me:GetScore() >= 50 then
            local clientsMenuKey = input.LookupBinding( "+menu" )
            if not clientsMenuKey then me.openedHuntersGleeShop = true return end

            clientsMenuKey = input.GetKeyCode( clientsMenuKey )
            if not clientsMenuKey then me.openedHuntersGleeShop = true return end

            local keyName = input.GetKeyName( clientsMenuKey )
            local phrase  = language.GetPhrase( keyName )

            return true, "You have score to spend, things to buy!\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

        end

    -- hey you should mess with the alive people and revive yourself!!!
    elseif dead then
        local myScore = me:GetScore()

        local result, hooksHint = hook.Run( "huntersglee_cl_displayhint_predeadhints", me )

        local hasEscaped = me:HasEscaped()

        if result then
            return result, hooksHint

        elseif not me.openedHuntersGleeShop then
            local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
            if not valid then me.openedHuntersGleeShop = true return end

            return true, "Death is not the end.\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

        elseif not me.glee_DefinitelyBoughtAnUndeadItem then
            return true, "Purchase 'sacrifices' to make score while dead!"

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

        elseif not me.glee_HasDoneSpectateFlashlight and ( me.flashlightAdditive or 0 ) >= 100 and render.GetLightColor( me:GetPos() ):LengthSqr() < 0.008 then
            local valid, phrase = GAMEMODE:TranslatedBind( "+impulse 100" )
            if not valid then me.glee_HasDoneSpectateFlashlight = true return end

            return true, "Press " .. phrase .. " to toggle the spectate flashlight!"

        elseif not hasEscaped and not me.glee_HasBoughtDivineIntervention and myScore >= GAMEMODE:shopItemCost( "resurrection", me ) then
            return true, "Buy Divine Intervention in the shop to resurrect yourself..."

        elseif hasEscaped and ( me.glee_NextControlSomethingHint or 0 ) < CurTime() and GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE and player.GetCount() > 1 then
            if not me.glee_WasATerminatorOnTheMap then
                local wasBased
                for _, ent in ents.Iterator() do
                    if not ent.isTerminatorHunterBased then continue end
                    wasBased = true
                    break

                end
                if not wasBased then
                    me.glee_NextControlSomethingHint = CurTime() + 15
                    return

                else
                    me.glee_WasATerminatorOnTheMap = true

                end
            end

            if IsValid( me:GetDrivingEntity() ) then
                me.glee_NextControlSomethingHint = CurTime() + 60
                return

            end

            local valid, phrase = GAMEMODE:TranslatedBind( "+zoom" )
            if not valid then
                valid, phrase = GAMEMODE:TranslatedBind( "toggle_zoom" )
                if not valid then
                    return true, "If you had +zoom bound to anything, you could POSESS hunters right now..."

                end
            end

            local obsTarg = me:GetObserverTarget()
            if IsValid( obsTarg ) and obsTarg.isTerminatorHunterBased then
                return true, "Press " .. phrase .. " to POSESS the hunter you're spectating..."

            elseif not IsValid( obsTarg ) or not obsTarg.isTerminatorHunterBased then
                return true, "Spectate a hunter!\nYou'll be able to posess them..."

            end
        end

        -- dont spam flicker the flashlight hint
        if not me.glee_HasDoneSpectateFlashlight and render.GetLightColor( me:GetPos() ):LengthSqr() < 0.005 then
            me.flashlightAdditive = ( me.flashlightAdditive or 0 ) + 1

        else
            me.flashlightAdditive = 0

        end

        result, hooksHint = hook.Run( "huntersglee_cl_displayhint_postdeadhints", me )
        if result then
            return result, hooksHint

        end
    end

    local isWepHintPostStack, wepHintPostStack
    if wep and wep.HintPostStack and wepOwnedByMe then
        isWepHintPostStack, wepHintPostStack = wep:HintPostStack()

    end
    if isWepHintPostStack then
        return true, wepHintPostStack

    end

    local result, hooksHint = hook.Run( "huntersglee_cl_displayhint_poststack", me )
    if result then
        return result, hooksHint

    end
end


-- ---------------------------------------------------------------------------
-- Hint think
-- think returns: text, stayPresent, doFlash, xOffset
-- ---------------------------------------------------------------------------

local nextHintCheck    = 0
local needsHints
local hint
local nextHintFlash    = 0

local tackleTheDamnHintSound = Sound( "common/wpn_select.wav" )

local function thinkHint( _ply, cur )
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_LIMBO then
        return "", false, false, 0

    end
    if nextHintCheck < cur then
        needsHints, hint = genericHints()
        nextHintCheck    = cur + math.Rand( 0.1, 0.09 )

    end

    if not needsHints then
        return "", false, false, 0

    end

    local doFlash = false
    if nextHintFlash < cur then
        doFlash       = true
        nextHintFlash = cur + 8
        LocalPlayer():EmitSound( tackleTheDamnHintSound, 60, 120, 0.4 )

    end

    return hint, true, doFlash, 0

end


-- ---------------------------------------------------------------------------
-- Entry table and creation
-- ---------------------------------------------------------------------------

local hudEntries = {
    {
        key             = "roundInfo",
        font            = "termhuntTimeFont",
        textPadding     = blockPadding,
        flashDuration   = 0.4,
        fadeSpeed       = 0.15,
        fadeStartDelay  = 6,
        normalColor     = hl2Hud.colorBackground:Copy(),
        flashColor      = hl2Hud.colorBackgroundUrgent:Copy(),
        iconColor       = hl2Hud.colorHappyYellow:Copy(),
        think           = thinkRoundInfo,
    },
    {
        key             = "score",
        font            = "termhuntScoreFont",
        textPadding     = blockPadding,
        flashDuration   = 0.15,
        fadeSpeed       = 0.4,
        fadeStartDelay  = 4,
        normalColor     = hl2Hud.colorBackground:Copy(),
        flashColor      = hl2Hud.colorBackgroundUrgent:Copy(),
        iconColor       = hl2Hud.colorHappyYellow:Copy(),
        think           = thinkScore,
    },
    {
        key             = "skulls",
        font            = "termhuntScoreFont",
        textPadding     = blockPadding,
        flashDuration   = 0.15,
        fadeSpeed       = 0.3,
        fadeStartDelay  = 6,
        normalColor     = hl2Hud.colorBackground:Copy(),
        flashColor      = hl2Hud.colorBackgroundUrgent:Copy(),
        iconColor       = hl2Hud.colorHappyYellow:Copy(),
        think           = thinkSkulls,
    },
    {
        key             = "hint",
        font            = "termhuntHintFont",
        textPadding     = blockPadding,
        flashDuration   = 0.15,
        normalColor     = hl2Hud.colorBackground:Copy(),
        flashColor      = hl2Hud.colorBackgroundUrgent:Copy(),
        iconColor       = hl2Hud.colorHappyYellow:Copy(),
        flashIconColor  = hl2Hud.colorRedUrgent:Copy(),
        think           = thinkHint,
    },
}

local function createTopLeftBoxes()
    for _, entry in ipairs( hudEntries ) do
        local storageKey = "gleeHud_TL_" .. entry.key
        if IsValid( terminator_Extras[storageKey] ) then terminator_Extras[storageKey]:Remove() end

        local box = vgui.Create( "glee_hl2hudbox", GetAutoHidingHUDPanel() )
        terminator_Extras[storageKey] = box

        box:SetIconFont( entry.font )
        box:SetTextPadding( entry.textPadding )
        box:SetFlashDuration( entry.flashDuration )
        box:SetNormalBoxColor( entry.normalColor )
        box:SetFlashBoxColor( entry.flashColor )
        box:SetIconColor( entry.iconColor )
        if entry.flashIconColor then
            box:SetFlashIconColor( entry.flashIconColor )

        end
        if entry.fadeSpeed then
            box:SetFadeSpeed( entry.fadeSpeed )

        end
        if entry.fadeStartDelay then
            box:SetFadeStartDelay( entry.fadeStartDelay )

        end
    end
end

hook.Add( "OnGamemodeLoaded", "glee_topleft_create", createTopLeftBoxes )
if GAMEMODE then createTopLeftBoxes() end


-- ---------------------------------------------------------------------------
-- Manager
-- ---------------------------------------------------------------------------

hook.Add( "glee_cl_topleftinfo", "glee_topleftinfo_draw", function( ply, cur )
    if not GAMEMODE:CanShowDefaultHud() then
        for _, entry in ipairs( hudEntries ) do
            local box = terminator_Extras["gleeHud_TL_" .. entry.key]
            if IsValid( box ) then box:SetState( box.STATE_HIDDEN ) end

        end
        return

    end

    local almostFadeStart = 25
    local x = paddingFromEdge + paddingFromEdge / 2
    local laneY = paddingFromBottom * 2

    local neverShow = neverShowInfo:GetBool()
    local isTabHeld = input.IsKeyDown( KEY_TAB )
    local alwaysShow = isTabHeld or alwaysShowInfo:GetBool()

    for _, entry in ipairs( hudEntries ) do
        local box = terminator_Extras["gleeHud_TL_" .. entry.key]
        if not IsValid( box ) then continue end

        local doFadeDelays = true
        local text, stayPresent, doFlash, xOffset, textColor = entry.think( ply, cur )

        if textColor then box:SetIconColor( textColor ) end

        box:SetText( text or "" )
        box:AutoSize()

        if alwaysShow and text ~= "" then
            stayPresent = true

        elseif neverShow then
            stayPresent = false
            doFlash = false
            doFadeDelays = false

        end

        if stayPresent then
            if doFlash then box:SetState( box.STATE_FLASH ) end

            box:SetState( box.STATE_NORMAL )

        else
            box:SetDoFadeDelays( doFadeDelays )
            box:SetState( box.STATE_FADING )

        end

        box:SetPos( x + ( xOffset or 0 ), laneY )

        local stateAlpha = box:GetStateAlpha()

        if stateAlpha > 0 then
            local myY = box:GetTall() + laneSpacing
            local pendingState = box:GetPendingState()
            local goingAway = pendingState == box.STATE_FADING or pendingState == box.STATE_HIDDEN
            if goingAway and stateAlpha < almostFadeStart then
                local toAlmostFaded = stateAlpha / almostFadeStart
                myY = myY * toAlmostFaded

            end

            laneY = laneY + myY

        end
    end
end )
