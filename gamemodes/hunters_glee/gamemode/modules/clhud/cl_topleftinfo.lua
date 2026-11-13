-- top-left HUD: round timer, score, skulls, hints

local GAMEMODE = GAMEMODE or GM
local CurTime  = CurTime

local neverShowInfo = CreateClientConVar( "cl_huntersglee_nevershowtoplefthud", 0, true, false, "Never show round info, score, and skull count?", 0, 1 )
local alwaysShowInfo = CreateClientConVar( "cl_huntersglee_alwaysshowtoplefthud", 1, true, false, "Always show round info, score, and skull count?", 0, 1 )

local paddingFromEdge   = terminator_Extras.defaultHudPaddingFromEdge
local paddingFromBottom = terminator_Extras.defaultHudPaddingFromBottom
local laneSpacing      = terminator_Extras.glee_Style( "hl2" ):Metric( "laneSpacing" )

local hour = 60 * 60

-- ---------------------------------------------------------------------------
-- Boxes driven by a think
-- A think is the box's ManageHudState, see glee_countbox's, and ends in showText
-- ---------------------------------------------------------------------------

-- "" means it's going away, the last text fades out with it instead of an empty box
local function showText( box, text, stayPresent, doFlash, alwaysShow, neverShow )
    if text ~= "" then
        box:SetText( text )
        box:AutoSize()

    end

    local doFadeDelays = true
    if alwaysShow and text ~= "" then
        stayPresent = true

    elseif neverShow then
        stayPresent  = false
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


-- ---------------------------------------------------------------------------
-- Round info
-- ---------------------------------------------------------------------------

local oldInfo         = "---"
local infoColorExpiry = 0

local function thinkRoundInfo( box, ply, cur, alwaysShow, neverShow )
    local spawnSetName = GAMEMODE:GetSpawnSetName()
    local typeVal = GAMEMODE:GetPrettyNameOfSpawnSet( spawnSetName )
    if typeVal == "" then
        typeVal = "Hunter's Glee"

    end
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

    box:SetContentColor( infoColorExpiry > cur and "alert" or "happy" )

    local stayPresent = GAMEMODE:RoundState() ~= GAMEMODE.ROUND_ACTIVE
    showText( box, combinedString, stayPresent, doFlash, alwaysShow, neverShow )

    return 0

end




-- Hint system
-- Every hint source returns: true, text, hintData
-- The first source with a hint wins. hintData is optional, a table of
--     urgent = true -- bigger and shaking, keep it for the few hints that must never be missed
--     return true, "Press \" Q \" to open the shop.", { urgent = true }

local nextPossessHint = 0 -- the escaped player's possess hint, pushed back while it can't apply
local wasAHunterOnTheMap = false
local aliveDarkChecks = 0
local deadDarkChecks = 0

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
    if ply:Health() <= 0 then
        GAMEMODE:LearnLesson( "BoughtAGhostItem" )

        if id == "resurrection" then
            GAMEMODE:LearnLesson( "BoughtDivineIntervention" )

        end
    else
        if id == "signalflare" then
            GAMEMODE:LearnLesson( "BoughtSignalFlare" )

        end
    end
end )

hook.Add( "glee_shop_finishopening", "glee_shop_detecttypeofopen", function( ply )
    GAMEMODE:LearnLesson( "OpenedShop" )
    if ply:Health() <= 0 then
        GAMEMODE:LearnLesson( "OpenedDeadShop" )

    else
        GAMEMODE:LearnLesson( "OpenedAliveShop" )

    end
end )


net.Receive( "glee_followedsomething", function()
    if not IsValid( LocalPlayer() ) then return end -- ???????
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 120, 0.8 )
    GAMEMODE:LearnLesson( "SpectatedSomeone" )

    GAMEMODE:ResetOrbitDistance()

end )

net.Receive( "glee_followednexthing", function()
    if not IsValid( LocalPlayer() ) then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 200, 0.5 )

    GAMEMODE:ResetOrbitDistance()

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

    GAMEMODE:ResetOrbitDistance()

end )

net.Receive( "glee_starteddriving", function()
    if not IsValid( LocalPlayer() ) then return end
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_LIMBO then return end -- hack fix to stop these sounds from overriding roundEndSound
    LocalPlayer():EmitSound( "weapons/crossbow/bolt_fly4.wav", 100, 150, 1 )
    LocalPlayer():EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 200, 1 )
    LocalPlayer():EmitSound( "ui/buttonclick.wav", 100, 80, 1 )
    nextPossessHint = CurTime() + 60

    GAMEMODE:ResetOrbitDistance()

end )

net.Receive( "glee_stoppeddriving", function()
    if not IsValid( LocalPlayer() ) then return end
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_LIMBO then return end
    LocalPlayer():EmitSound( "ui/buttonrollover.wav", 100, 100, 0.8 )
    LocalPlayer():EmitSound( "weapons/crossbow/bolt_fly4.wav", 100, 50, 0.25 )
    LocalPlayer():EmitSound( "ambient/levels/labs/electric_explosion5.wav", 100, 150, 0.25 )

end )


local urgentHint = { urgent = true }

local aliveDarkLightSqr = 0.005
local aliveDarkChecksNeeded = 50 -- hint checks run 10 times a second


-- Crouch jump hint
-- After a jump, look for a ledge in front of them that only a crouch jump reaches.
-- Once found, the hint sticks to that ledge until they get up there, or walk away.

local crouchJumpSearchTime   = 3 -- seconds after pressing jump
local crouchJumpBailDelay    = 0.15
local crouchJumpHullScale    = 0.75
local crouchJumpMinLedge     = 36 -- lowest ledge worth the hint, found by testing in game
local crouchJumpForgetDistSqr = 150^2
local crouchJumpLearnDistSqr = 64^2

local crouchJumpSearchUntil = 0
local nextCrouchJumpCheck = 0
local crouchJumpLedge -- the ledge the hint is stuck to

hook.Add( "KeyPress", "glee_crouchjumphint", function( ply, key )
    if key ~= IN_JUMP then return end
    if ply ~= LocalPlayer() then return end
    if not IsFirstTimePredicted() then return end

    crouchJumpSearchUntil = CurTime() + crouchJumpSearchTime

end )

local function findCrouchJumpLedge( me )
    local feet = me:GetPos()
    local up = vector_up

    -- how high a crouch jump gets their feet
    local apex = me:GetJumpPower() ^ 2 / ( 2 * GetConVar( "sv_gravity" ):GetFloat() )
    local _, standMaxs = me:GetHull()
    local _, duckMaxs = me:GetHullDuck()
    local minReach = crouchJumpMinLedge
    local maxReach = apex + ( standMaxs.z - duckMaxs.z )

    local halfWidth = standMaxs.x * crouchJumpHullScale
    local hullMins = Vector( -halfWidth, -halfWidth, -1 )
    local hullMaxs = Vector( halfWidth, halfWidth, 1 )

    local forward = me:GetAimVector()
    forward.z = 0
    forward:Normalize()

    local lookAhead = standMaxs.x + halfWidth + 8 -- just past their own hull
    local ledgeCheckPos = feet + forward * lookAhead
    local downStart = ledgeCheckPos + up * ( maxReach + 1 )

    -- clear path from their eyes to above the ledge
    local clearTr = util.TraceLine( {
        start = me:GetShootPos(),
        endpos = downStart,
        mask = MASK_PLAYERSOLID,
        filter = me,
    } )
    if clearTr.Hit then return end

    -- a wall, not a ramp they could walk up
    local wallTr = util.TraceLine( {
        start = feet + up * ( me:GetStepSize() + 1 ),
        endpos = ledgeCheckPos + up * ( me:GetStepSize() + 1 ),
        mask = MASK_PLAYERSOLID,
        filter = me,
    } )
    if not wallTr.Hit or math.abs( wallTr.HitNormal.z ) > 0.3 then return end

    local downTr = util.TraceHull( {
        start = downStart,
        endpos = ledgeCheckPos + up * minReach,
        mins = hullMins,
        maxs = hullMaxs,
        mask = MASK_PLAYERSOLID,
        filter = me,
    } )
    if downTr.StartSolid or not downTr.Hit then return end
    if downTr.HitNormal.z < 0.7 then return end -- too steep to stand on

    -- room for them to crouch up there
    local headroomTr = util.TraceHull( {
        start = downTr.HitPos + up,
        endpos = downTr.HitPos + up * duckMaxs.z,
        mins = hullMins,
        maxs = hullMaxs,
        mask = MASK_PLAYERSOLID,
        filter = me,
    } )
    if headroomTr.Hit then return end

    return downTr.HitPos

end

local function crouchJumpHint( me, cur )
    if GAMEMODE:HasLearnedLesson( "CrouchJumped" ) then return end

    if crouchJumpLedge then
        local feet = me:GetPos()
        local distSqr = feet:DistToSqr( crouchJumpLedge )
        if distSqr > crouchJumpForgetDistSqr then
            crouchJumpLedge = nil

        elseif me:OnGround() and feet.z >= crouchJumpLedge.z - 2 and distSqr < crouchJumpLearnDistSqr then
            crouchJumpLedge = nil
            GAMEMODE:LearnLesson( "CrouchJumped" )

        else
            return true, "Hold CROUCH while midair.\nTo jump over high ledges.", urgentHint

        end
        return

    end

    if crouchJumpSearchUntil < cur then return end -- only if they are failing a jump
    if nextCrouchJumpCheck > cur then return end
    if me:GetMoveType() ~= MOVETYPE_WALK or me:WaterLevel() >= 2 then return end

    local found = findCrouchJumpLedge( me )
    if not found then
        nextCrouchJumpCheck = cur + crouchJumpBailDelay
        return

    end
    crouchJumpLedge = found

    return true, "Hold CROUCH while midair.\nTo jump over high ledges.", urgentHint

end

local function genericHints()
    local me = LocalPlayer()

    -- ghost ents can have HintPreStack
    local wep = me:GetActiveWeapon()
    if not IsValid( wep ) and IsValid( me.ghostEnt ) then
        wep = me.ghostEnt

    end

    local wepOwnedByMe = IsValid( wep ) and wep:GetOwner() == me

    local isWepHintPreStack, wepHintPreStack, wepHintPreStackData
    if wep and wep.HintPreStack and wepOwnedByMe then
        isWepHintPreStack, wepHintPreStack, wepHintPreStackData = wep:HintPreStack()

    end
    if isWepHintPreStack then
        return true, wepHintPreStack, wepHintPreStackData

    end

    local dead      = me:Health() <= 0

    local GAMMODE = GAMEMODE

    if not dead then
        if not GAMMODE:HasLearnedLesson( "UsedAliveFlashlight" ) and render.GetLightColor( me:GetShootPos() ):LengthSqr() < aliveDarkLightSqr then
            aliveDarkChecks = aliveDarkChecks + 1

        else
            aliveDarkChecks = 0

        end

        if aliveDarkChecks >= aliveDarkChecksNeeded and not GAMMODE:UnboundHintSkipped( "impulse 100" ) then
            local flashlightValid, flashlightPhrase = GAMEMODE:TranslatedBind( "impulse 100" )
            if not flashlightValid then return GAMMODE:UnboundHint( "impulse 100", "You're missing out on your flashlight..." ) end

            return true, "Press " .. string.upper( flashlightPhrase ) .. " to toggle your flashlight.\nIt uses Battery charge."

        end

        local isCrouchJumpHint, crouchJumpText, crouchJumpData = crouchJumpHint( me, CurTime() )
        if isCrouchJumpHint then
            return true, crouchJumpText, crouchJumpData

        end

        local result, hooksHint, hooksHintData = hook.Run( "huntersglee_cl_displayhint_prealivehints", me )
        if result then
            return result, hooksHint, hooksHintData

        end

        local inBetween = GAMEMODE:RoundState() == GAMEMODE.ROUND_INACTIVE
        local hasBoughtSomething = GAMMODE:HasLearnedLesson( "BoughtAnItem" )

        local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
        if not valid and not hasBoughtSomething then return GAMMODE:UnboundHint( "+menu", "You're missing out on the shop...", true ) end

        local myScore = me:GetScore()

        local timeToBuy = not hasBoughtSomething and myScore >= 25 and inBetween
        local meagreWealth = not hasBoughtSomething and myScore >= 75
        local blockShop = GAMMODE:ShopOpenBlocked()

        -- Preparing's ticking away, and shop markups kick in once the hunt starts
        if not GAMMODE:HasLearnedLesson( "OpenedAliveShop" ) and not blockShop and timeToBuy and me:GetNWInt( "termHuntPlyBPM" ) <= 80 then
            return true, "Spend before the HUNT.\nPress " .. string.upper( phrase ) .. " to open the SHOP.\nWhile discounts last...", urgentHint

        end

        -- hey you should open the shop!!!!
        if not blockShop and ( timeToBuy or meagreWealth ) then
            if not GAMMODE:HasLearnedLesson( "OpenedAliveShop" ) and me:GetNWInt( "termHuntPlyBPM" ) <= 80 then
                return true, "UNSPENT SCORE: " .. myScore .. "\nScore exists to be spent.\nPress\" " .. string.upper( phrase ) .. " \" uplink to the shop.", urgentHint

            elseif not hasBoughtSomething and me:GetNWInt( "termHuntPlyBPM" ) <= 75 then
                return true, "YOU HAVE UNREALIZED SCORE\nPurchase something, a loadout, DEFEND YOURSELF.\nPress \" " .. string.upper( phrase ) .. " \" to open the shop.", urgentHint

            end
        end

        if not blockShop and not GAMMODE:HasLearnedLesson( "BoughtSignalFlare" ) and GAMMODE:canShowInShop( me, "signalflare" ) then
            local skulls = me:GetSkulls()
            if skulls >= GAMMODE:shopItemSkullCost( "signalflare", me ) then
                return true, "EXTRACTION POSSIBLE\nBuy an Escape Flaregun from the shop.\nSPEND YOUR SKULLS", urgentHint

            end
        end

        result, hooksHint, hooksHintData = hook.Run( "huntersglee_cl_displayhint_postalivehints", me )
        if result then
            return result, hooksHint, hooksHintData

        end

    -- hey you should mess with the alive people and revive yourself!!!
    elseif dead then
        local myScore = me:GetScore()
        local hasEscaped = me:HasEscaped()

        local result, hooksHint, hooksHintData = hook.Run( "huntersglee_cl_displayhint_predeadhints", me )
        if result then
            return result, hooksHint, hooksHintData

        elseif not GAMMODE:HasLearnedLesson( "SpectatedSomeone" ) and not GAMMODE:UnboundHintSkipped( "+attack" ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+attack" )
            if not valid then return GAMMODE:UnboundHint( "+attack", "You can't follow anything while spectating..." ) end

            return true, "Press " .. phrase .. " to follow stuff!"

        elseif not GAMMODE:HasLearnedLesson( "SwitchedSpectateModes" ) and not GAMMODE:UnboundHintSkipped( "+jump" ) and IsValid( me:GetObserverTarget() ) then
            local valid, phrase = GAMEMODE:TranslatedBind( "+jump" )
            if not valid then return GAMMODE:UnboundHint( "+jump", "You can't switch spectate modes..." ) end

            return true, "Press " .. phrase .. " to switch spectate modes!"

        elseif not GAMMODE:HasLearnedLesson( "StoppedSpectating" ) and IsValid( me:GetObserverTarget() ) then
            return true, "Press any movement key to stop following stuff!"

        elseif not GAMMODE:HasLearnedLesson( "OpenedDeadShop" ) and not GAMMODE:ShopOpenBlocked() then
            local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
            if not valid then return GAMMODE:UnboundHint( "+menu", "You're missing out on the ghost shop...\nDeath is not the end.", true ) end

            if me.glee_SpawnedInDeadTutorialPlease then
                return true, "Press \" " .. string.upper( phrase ) .. " \" to open the shop.\nDIVINE INTERVENTION AWAITS.", urgentHint

            else
                return true, "Death is not the end.\nPress \" " .. string.upper( phrase ) .. " \" to open the shop.", urgentHint

            end
        elseif not GAMMODE:HasLearnedLesson( "BoughtAGhostItem" ) and not GAMMODE:ShopOpenBlocked() then
            if me.glee_SpawnedInDeadTutorialPlease then
                local valid, phrase = GAMEMODE:TranslatedBind( "+menu" )
                if not valid then
                    valid, phrase = GAMEMODE:TranslatedBind( "gm_showhelp" )
                    if not valid then return GAMMODE:UnboundHint( "+menu", "You're missing out on the ghost shop...\nIt's time to HAUNT for PROFIT.", true ) end

                end
                local hint = table.concat( {
                    "It's time to HAUNT for PROFIT.\n",
                    "Press \" " .. string.upper( phrase ) .. " \" to return to the GHOST SHOP.\n",
                    "Sacrifices can make you money, if placed correctly...\n",
                    "Gifts always cost you.",
                } )
                return true, hint

            else
                return true, "Purchase 'Sacrifices' to make score while dead!"

            end
        elseif not me.glee_HasDoneSpectateFlashlight and not GAMMODE:UnboundHintSkipped( "impulse 100" ) and deadDarkChecks >= 100 and render.GetLightColor( me:GetPos() ):LengthSqr() < 0.008 then
            local valid, phrase = GAMEMODE:TranslatedBind( "impulse 100" )
            if not valid then return GAMMODE:UnboundHint( "impulse 100", "You're missing out on the spectate flashlight..." ) end

            return true, "Press " .. phrase .. " to toggle the spectate flashlight!"

        elseif not hasEscaped and not GAMMODE:HasLearnedLesson( "BoughtDivineIntervention" ) and GAMMODE:canShowInShop( me, "resurrection" ) and not GAMMODE:ShopOpenBlocked() then
            if myScore >= GAMMODE:shopItemCost( "resurrection", me ) then
                return true, "You now have enough to buy DIVINE INTERVENTION in the shop.\nYour temporary form awaits..."

            elseif myScore > -1 then
                return true, "Keep placing 'Sacrifices'\nAll of them can earn you Score,\nif you're clever with them...", urgentHint

            else
                return true, "You are in DEBT.\nKeep placing sacrifices.\nThey can get you out of this hole.\nIf you're clever with them...", urgentHint

            end
        elseif hasEscaped and nextPossessHint < CurTime() and GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE and player.GetCount() > 1 then
            if not wasAHunterOnTheMap then
                local wasBased
                for _, ent in ents.Iterator() do
                    if not ent.isTerminatorHunterBased then continue end
                    wasBased = true
                    break

                end
                if not wasBased then
                    nextPossessHint = CurTime() + 15
                    return -- one return every 15s is fine here

                else
                    wasAHunterOnTheMap = true

                end
            end

            if IsValid( me:GetDrivingEntity() ) then
                nextPossessHint = CurTime() + 60
                return -- one return every 60s is fine

            end

            local valid, phrase = GAMEMODE:TranslatedBind( "+zoom" )
            if not valid then
                valid, phrase = GAMEMODE:TranslatedBind( "toggle_zoom" )
                if not valid then
                    return GAMMODE:UnboundHint( "+zoom", "You could be POSESSING hunters right now...", true )

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
            deadDarkChecks = deadDarkChecks + 1

        else
            deadDarkChecks = 0

        end

        result, hooksHint, hooksHintData = hook.Run( "huntersglee_cl_displayhint_postdeadhints", me )
        if result then
            return result, hooksHint, hooksHintData

        end
    end

    local isWepHintPostStack, wepHintPostStack, wepHintPostStackData
    if wep and wep.HintPostStack and wepOwnedByMe then
        isWepHintPostStack, wepHintPostStack, wepHintPostStackData = wep:HintPostStack()

    end
    if isWepHintPostStack then
        return true, wepHintPostStack, wepHintPostStackData

    end

    local result, hooksHint, hooksHintData = hook.Run( "huntersglee_cl_displayhint_poststack", me )
    if result then
        return result, hooksHint, hooksHintData

    end
end


-- ---------------------------------------------------------------------------
-- Hint think
-- ---------------------------------------------------------------------------

local nextHintCheck    = 0
local needsHints
local hint
local hintData
local wasUrgent
local nextHintFlash    = 0
local urgentShakeUntil = 0

local urgentShakeDuration = 1
local urgentShakeMaxSize  = glee_sizeScaled( nil, 2 ) -- the same as the score's

local tackleTheDamnHintSound = Sound( "common/wpn_select.wav" )

local function thinkHint( box, _ply, cur, alwaysShow, neverShow )
    if GAMEMODE:RoundState() == GAMEMODE.ROUND_LIMBO then
        showText( box, "", false, false, alwaysShow, neverShow )
        return 0

    end
    if nextHintCheck < cur then
        needsHints, hint, hintData = genericHints()
        nextHintCheck    = cur + math.Rand( 0.09, 0.1 )

    end

    if not needsHints then
        wasUrgent = false
        showText( box, "", false, false, alwaysShow, neverShow )
        return 0

    end

    local urgent = hintData and hintData.urgent

    -- an urgent hint doesn't wait out the last hint's flash cooldown
    if urgent and not wasUrgent then
        nextHintFlash = 0

    end
    wasUrgent = urgent

    local doFlash = false
    if nextHintFlash < cur then
        doFlash       = true
        nextHintFlash = cur + 8
        if urgent then
            urgentShakeUntil = cur + urgentShakeDuration

        end
        if system.HasFocus() then
            LocalPlayer():EmitSound( tackleTheDamnHintSound, 60, 120, 0.4 )

        end
    end

    local xOffset = 0
    if urgent and urgentShakeUntil > cur then
        local shakeScale = ( urgentShakeUntil - cur ) / urgentShakeDuration * urgentShakeMaxSize
        xOffset = math.Rand( -shakeScale, shakeScale )

    end

    box:SetFont( urgent and "hintUrgent" or "medium" )
    showText( box, hint, true, doFlash, alwaysShow, neverShow )

    return xOffset

end


-- ---------------------------------------------------------------------------
-- Entry table and creation
-- ---------------------------------------------------------------------------

-- Order here is top to bottom on screen. An entry needs either a think, or a panelClass
-- whose panel has its own ManageHudState
local hudEntries = {
    {
        key             = "roundInfo",
        font            = "mediumLarge",
        flashDuration   = 0.4,
        fadeSpeed       = 9, -- alpha lost per second, out of 255
        fadeStartDelay  = 6,
        think           = thinkRoundInfo,
    },
    {
        key            = "score",
        panelClass     = "glee_countbox",
        flashDuration  = 0.15,
        fadeSpeed      = 24,
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
        panelClass     = "glee_countbox",
        flashDuration  = 0.15,
        fadeSpeed      = 18,
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
        fadeSpeed       = 1500, -- a hint that stopped being true shouldn't linger
        think           = thinkHint,
    },
}

local function createTopLeftBoxes()
    for _, entry in ipairs( hudEntries ) do
        local storageKey = "gleeHud_TL_" .. entry.key
        if IsValid( terminator_Extras[storageKey] ) then terminator_Extras[storageKey]:Remove() end

        local box = vgui.Create( entry.panelClass or "glee_hudbox", GetAutoHidingHUDPanel() )
        terminator_Extras[storageKey] = box

        box:SetFlashDuration( entry.flashDuration )
        if entry.font then
            box:SetFont( entry.font )

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
        if entry.think then
            box.ManageHudState = entry.think

        end
    end
end

hook.Add( "OnGamemodeLoaded", "glee_topleft_create", createTopLeftBoxes )
if GAMEMODE then createTopLeftBoxes() end


-- ---------------------------------------------------------------------------
-- Manager
-- ---------------------------------------------------------------------------

local pleasePaintFor = {}

local function hideBoxes()
    for _, entry in ipairs( hudEntries ) do
        local box = terminator_Extras["gleeHud_TL_" .. entry.key]
        if IsValid( box ) then box:SetState( box.STATE_HIDDEN ) end

    end
end

-- the boxes paint whether or not this hook runs, and it stops running on the win screen
hook.Add( "glee_paintWinScreen", "glee_topleftinfo_hide", hideBoxes )

hook.Add( "glee_cl_topleftinfo", "glee_topleftinfo_draw", function( ply, cur )
    if not GAMEMODE:CanShowDefaultHud() then
        hideBoxes()
        return

    end

    local almostFadeStart = 25
    local x = paddingFromEdge + paddingFromEdge / 2
    local laneY = paddingFromBottom * 2 -- 2x paddingFromBottom away from the top of the screen

    -- the lane grows downward as boxes are laid out, so its extent is only known at the end
    local laneTop = laneY
    local laneWidest = 0

    local neverShow = neverShowInfo:GetBool()
    local isTabHeld = input.IsKeyDown( KEY_TAB )
    local alwaysShow = isTabHeld or alwaysShowInfo:GetBool()

    for _, entry in ipairs( hudEntries ) do
        local box = terminator_Extras["gleeHud_TL_" .. entry.key]
        if not IsValid( box ) then continue end

        local forceThisKey = alwaysShow

        local plsPaint = pleasePaintFor[entry.key]
        if plsPaint and plsPaint > cur then
            forceThisKey = true

        end

        local xOffset = box:ManageHudState( ply, cur, forceThisKey, neverShow ) or 0

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
            laneWidest = math.max( laneWidest, xOffset + box:GetWide() )

        end
    end

    -- roundInfo carries the Misery's name, so this reaches the middle of the screen on a
    -- long one. See GM:ImUsingHudSpace
    if laneWidest > 0 then
        GAMEMODE:ImUsingHudSpace( "topLeft", x, laneTop, laneWidest, laneY - laneTop )

    end
end )


-- so other code can request specific elements to stay visible

hook.Add( "glee_cl_pleasepainttopleft_for", "glee_topleftinfo_forcepaint", function( key, add )
    pleasePaintFor[key] = CurTime() + add

end )
