-- top-left HUD: round timer, score, skulls, hints

local GAMEMODE = GAMEMODE or GM
local CurTime  = CurTime

local neverShowInfo = CreateClientConVar( "cl_huntersglee_nevershowtoplefthud", 0, true, false, "Never show round info, score, and skull count?", 0, 1 )
local alwaysShowInfo = CreateClientConVar( "cl_huntersglee_alwaysshowtoplefthud", 0, true, false, "Always show round info, score, and skull count?", 0, 1 )

local paddingFromEdge   = terminator_Extras.defaultHudPaddingFromEdge
local paddingFromBottom = terminator_Extras.defaultHudPaddingFromBottom
local laneSpacing      = terminator_Extras.glee_HL2Hud.laneSpacing
-- fonts are now defined in cl_gleehud.lua

local hour = 60 * 60

local hl2Hud = terminator_Extras.glee_HL2Hud

local defaultHudColor  = hl2Hud.colorHappyYellow
local infoChangedColor = Color( 255, 50, 50 )


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




-- Hint system

-- deliberately not a lesson, this one nags again every session
hook.Add( "InitPostEntity", "glee_clreadhints", function()
    LocalPlayer().glee_HasDoneSpectateFlashlight = nil

end )

local deadCategories = {
    "DEADSACRIFICES",
    "DEADGIFTS",
}

hook.Add( "glee_cl_confirmedpurchase", "storeIfPlayerBoughtUndeadItem", function( ply, id )
    local itemData = GAMEMODE:GetShopItemData( id )
    if not itemData then return end

    GAMEMODE:LearnLesson( "BoughtAnItem" )

    local isDeadItem = false
    for _, category in ipairs( deadCategories ) do
        if not itemData.tags[category] then continue end
        isDeadItem = true

    end
    if not isDeadItem then return end
    if ply:Health() > 0 then return end

    GAMEMODE:LearnLesson( "BoughtAGhostItem" )

    if id == "resurrection" then
        GAMEMODE:LearnLesson( "BoughtDivineIntervention" )

    end
end )


net.Receive( "glee_followedsomething", function()
    if not IsValid( LocalPlayer() ) then return end -- ???????
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 120, 0.8 )
    GAMEMODE:LearnLesson( "SpectatedSomeone" )

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
    GAMEMODE:LearnLesson( "SwitchedSpectateModes" )

end )

net.Receive( "glee_stoppedspectating", function()
    if not IsValid( LocalPlayer() ) then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 90, 0.8 )
    GAMEMODE:LearnLesson( "StoppedSpectating" )

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

    local dead      = me:Health() <= 0

    local GAMMODE = GAMEMODE

    if not dead then
        local inBetween = GAMEMODE:RoundState() == GAMEMODE.ROUND_INACTIVE
        local hasBoughtSomething = GAMMODE:HasLearnedLesson( "BoughtAnItem" )
        local myScore = me:GetScore()

        local timeToBuy = not hasBoughtSomething and myScore >= 25 and inBetween
        local meagreWealth = not hasBoughtSomething and myScore >= 75

        -- hey you should open the shop!!!!
        if timeToBuy or meagreWealth then
            local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
            if not valid then GAMMODE:LearnLesson( "BoughtAnItem" ) return end

            if not me.glee_OpenedHuntersGleeShop and me:GetNWInt( "termHuntPlyBPM" ) <= 80 then
                return true, "You have score to spend, things to buy!\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

            elseif not hasBoughtSomething and me:GetNWInt( "termHuntPlyBPM" ) <= 75 then
                return true, "You can't stop thinking about the shop...\nYou should buy something to make this hunt bearable...\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

            end
        end

    -- hey you should mess with the alive people and revive yourself!!!
    elseif dead then
        local myScore = me:GetScore()

        local result, hooksHint = hook.Run( "huntersglee_cl_displayhint_predeadhints", me )

        local hasEscaped = me:HasEscaped()

        if result then
            return result, hooksHint

        elseif not me.glee_OpenedHuntersGleeShop then
            local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
            if not valid then me.glee_OpenedHuntersGleeShop = true return end

            return true, "Death is not the end.\nPress \" " .. string.upper( phrase ) .. " \" to open the shop."

        elseif not GAMMODE:HasLearnedLesson( "BoughtAGhostItem" ) then
            return true, "Purchase 'Sacrifices' to make score while dead!"

        elseif not GAMMODE:HasLearnedLesson( "SpectatedSomeone" ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+attack" )
            if not valid then GAMMODE:LearnLesson( "SpectatedSomeone" ) return end

            return true, "Press " .. phrase .. " to follow stuff!"

        elseif not GAMMODE:HasLearnedLesson( "SwitchedSpectateModes" ) and IsValid( me:GetObserverTarget() ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+jump" )
            if not valid then GAMMODE:LearnLesson( "SwitchedSpectateModes" ) return end

            return true, "Press " .. phrase .. " to switch spectate modes!"

        elseif not GAMMODE:HasLearnedLesson( "StoppedSpectating" ) and IsValid( me:GetObserverTarget() ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+attack2" )
            if not valid then GAMMODE:LearnLesson( "StoppedSpectating" ) return end

            return true, "Press " .. phrase .. " to stop following stuff!"

        elseif not me.glee_HasDoneSpectateFlashlight and ( me.flashlightAdditive or 0 ) >= 100 and render.GetLightColor( me:GetPos() ):LengthSqr() < 0.008 then
            local valid, phrase = GAMEMODE:TranslatedBind( "+impulse 100" )
            if not valid then me.glee_HasDoneSpectateFlashlight = true return end

            return true, "Press " .. phrase .. " to toggle the spectate flashlight!"

        elseif not hasEscaped and not GAMMODE:HasLearnedLesson( "BoughtDivineIntervention" ) then
            if myScore >= GAMEMODE:shopItemCost( "resurrection", me ) then
                return true, "Buy Divine Intervention in the shop to resurrect yourself..."

            else
                return true, "Keep placing 'Sacrifices'\nAll of them can earn you Score,\nif you're clever with them..."

            end

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

    return hint, true, doFlash, 0 -- dont override color

end


-- ---------------------------------------------------------------------------
-- Entry table and creation
-- ---------------------------------------------------------------------------

-- Order here is top to bottom on screen. An entry needs either a think, or a panelClass
-- whose panel has ManageHudState; the manager calls think on anything without one.
local hudEntries = {
    {
        key             = "roundInfo",
        font            = "glee_mediumLargeHL2Font",
        flashDuration   = 0.4,
        fadeSpeed       = 0.15,
        fadeStartDelay  = 6,
        think           = thinkRoundInfo,
    },
    {
        key            = "score",
        panelClass     = "glee_hl2hudscorecount",
        flashDuration  = 0.15,
        fadeSpeed      = 0.4,
        fadeStartDelay = 4,
        setup = function( box )
            box:SetLabel( "Score: " )
            box:SetCountFunc( function( ply ) return ply:GetScore() end )
            box:SetSuffix0( " ( Heartbeats Per Minute )" )
            box:SetSmallCountThreshold( 10 )
            box:SetLargePositiveChangeSound( "hunters_glee/209578_zott820_cash-register-purchase.wav" )
            box:SetLargeNegativeChangeSound( "buttons/lever7.wav" )

        end,
    },
    {
        key            = "skulls",
        panelClass     = "glee_hl2hudscorecount",
        flashDuration  = 0.15,
        fadeSpeed      = 0.3,
        fadeStartDelay = 6,
        setup = function( box )
            box:SetLabel( "Skulls: " )
            box:SetCountFunc( function( ply ) return ply:GetSkulls() end )
            box:SetChangeVisibleDuration( 4 )

        end,
    },
    {
        key             = "hint",
        flashDuration   = 0.15,
        think           = thinkHint,
    },
}

local function createTopLeftBoxes()
    for _, entry in ipairs( hudEntries ) do
        local storageKey = "gleeHud_TL_" .. entry.key
        if IsValid( terminator_Extras[storageKey] ) then terminator_Extras[storageKey]:Remove() end

        local box = vgui.Create( entry.panelClass or "glee_hl2hudbox", GetAutoHidingHUDPanel() )
        terminator_Extras[storageKey] = box

        box:SetFlashDuration( entry.flashDuration )
        if entry.font then
            box:SetIconFont( entry.font )

        end
        if entry.fadeSpeed then
            box:SetFadeSpeed( entry.fadeSpeed )

        end
        if entry.fadeStartDelay then
            box:SetFadeStartDelay( entry.fadeStartDelay )

        end
        if entry.setup then
            entry.setup( box )

        end
    end
end

hook.Add( "OnGamemodeLoaded", "glee_topleft_create", createTopLeftBoxes )
if GAMEMODE then createTopLeftBoxes() end


-- ---------------------------------------------------------------------------
-- Manager
-- ---------------------------------------------------------------------------

local pleasePaintFor = {}

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

        local xOffset      = 0
        local forceThisKey = alwaysShow

        local plsPaint = pleasePaintFor[entry.key]
        if plsPaint and plsPaint > cur then
            forceThisKey = true

        end

        if box.ManageHudState then
            xOffset = box:ManageHudState( ply, cur, forceThisKey, neverShow ) or 0

        else
            local doFadeDelays = true
            local text, stayPresent, doFlash, textColor -- localize these so...
            text, stayPresent, doFlash, xOffset, textColor = entry.think( ply, cur ) -- xOffset can leak out of this scope

            if textColor then box:SetIconColor( textColor ) end

            box:SetText( text or "" )
            box:AutoSize()

            if forceThisKey and text ~= "" then
                stayPresent = true

            elseif neverShow then
                stayPresent = false
                doFlash      = false
                doFadeDelays = false

            end

            if stayPresent then
                if doFlash then box:SetState( box.STATE_FLASH ) end
                box:SetState( box.STATE_NORMAL )

            else
                box:SetDoFadeDelays( doFadeDelays )
                box:SetState( box.STATE_FADING )

            end
        end

        box:SetPos( x + xOffset, laneY )

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


-- so other code can request specific elements to stay visible

hook.Add( "glee_cl_pleasepainttopleft_for", "glee_topleftinfo_forcepaint", function( key, add )
    pleasePaintFor[key] = CurTime() + add

end )
