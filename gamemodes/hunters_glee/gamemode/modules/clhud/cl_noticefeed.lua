--[[------------------------------------
    The notice feed, where huntersGlee_Notify's messages land, see lua/autorun/sh_glee_notify.lua.
    gmod's notification library is pointed here too, so addons' notices match.

    A stack of glee_noticeboxes in the bottom right, newest at the bottom.
    Each fades out once its time is up, and is removed once it's gone.
    The stack sits above the ammo counter, and sinks into its place once there hasn't been one for a while.

    Return true from glee_hideNotices to hide the feed, like glee_blockGenericAnnouncements hides
    the announcing text. Notices keep counting down while hidden.
--]]-------------------------------------

local GAMEMODE = GAMEMODE or GM

local paddingFromEdge = terminator_Extras.defaultHudPaddingFromEdge
local gapAboveAmmo = paddingFromEdge + glee_sizeScaled( 96, nil ) -- level with the bottom of the heartbeat icon, keep in step with cl_bpm.lua
local gapWithoutAmmo = terminator_Extras.defaultHudPaddingFromBottom * 2 -- as far off the bottom as the top left lane is off the top, keep in step with cl_topleftinfo.lua
local maxTextWidth = glee_sizeScaled( nil, 600 )

local FONT = "notice"
local FLASH_DURATION = 0.3
local DEFAULT_FLASH_INTERVAL = 0.5 -- for extraFlashes. under FLASH_DURATION, they run together into one long flash
local FADE_SPEED = 255 -- alpha lost per second, out of 255
local ALMOST_FADED = 25 -- below this alpha the gap a fading box leaves starts closing, as in cl_topleftinfo
local GAP_RISE_TIME = 0.15 -- seconds to get up out of the ammo counter's way
local GAP_DROP_DELAY = 5 -- seconds with no ammo counter before the stack comes down, so swapping weapons doesn't bounce it
local GAP_DROP_TIME = 3 -- seconds to come down. much slower and the text visibly ticks down a pixel at a time

local printNotices = CreateClientConVar( "cl_huntersglee_printnotices", "1", true, false, "Print notices in console?", 0, 1 )

-- an autorefresh would orphan the old boxes
for _, notice in ipairs( terminator_Extras.gleeHud_Notices or {} ) do
    if IsValid( notice.box ) then notice.box:Remove() end

end
terminator_Extras.gleeHud_Notices = {}

local notices = terminator_Extras.gleeHud_Notices -- oldest first

local function findByKey( replaceKey )
    if not replaceKey then return end

    for _, notice in ipairs( notices ) do
        if notice.replaceKey == replaceKey then return notice end

    end
end

local function findSame( text, description )
    for _, notice in ipairs( notices ) do
        if notice.text == text and notice.description == description then return notice end

    end
end

local function newNotice()
    local box = vgui.Create( "glee_noticebox", GetAutoHidingHUDPanel() )
    box:SetFont( FONT )
    box:SetMaxTextWidth( maxTextWidth )
    box:SetTextAlign( TEXT_ALIGN_RIGHT )
    box:SetFlashDuration( FLASH_DURATION )
    box:SetFadeSpeed( FADE_SPEED )
    box:SetDoFadeDelays( false )

    local notice = { box = box }
    notices[#notices + 1] = notice

    return notice

end

local function setText( notice, text, description )
    notice.text = text
    notice.description = description
    notice.box:SetText( text )
    notice.box:SetDescription( description )

end

local function setKind( notice, kind )
    local role = huntersGlee_NotifyKinds[kind].role
    notice.box:SetContentColor( role )
    notice.box:SetFlashContentColor( role ) -- the flash's own role is red, every kind would flash like an alert

end

--[[---------------------------------------------------------
    GM:AddNotice
    Puts a message in the feed, or flashes the one already showing it.
    huntersGlee_Notify calls this, call that instead.
    @param data: huntersGlee_Notify's, every field filled in but description, replaceKey, style,
        extraFlashes, flashInterval and onlyWhile. A flashInterval of 0 is the default too, it's what the net sends for none.
        {+bind}s are filled in here.
    @return: None
--]]---------------------------------------------------------
function GM:AddNotice( data )
    local text = self:FillBinds( data.text )
    local description = data.description and self:FillBinds( data.description )
    if hook.Run( "glee_blockNotices", text, description, data.kind ) then return end

    local existing = findByKey( data.replaceKey ) or findSame( text, description )
    local notice = existing or newNotice()
    notice.replaceKey = data.replaceKey
    notice.onlyWhile = data.onlyWhile
    notice.onlyWhileHeld = false

    -- a countdown updates the one box every second, logging each would flood the console
    if not existing and printNotices:GetBool() then
        local line = description and text .. " - " .. description or text
        permaPrint( "Notice; " .. string.gsub( line, "\n", " " ) )

    end
    notice.expiresAt = CurTime() + data.time

    local box = notice.box
    terminator_Extras.glee_SetPanelStyle( box, data.style ) -- nil goes back to the hud's own

    setText( notice, text, description )
    setKind( notice, data.kind )

    box:SetState( box.STATE_FLASH )

    -- the same message again without flashes doesn't cut the first one's short
    local extraFlashes = data.extraFlashes or 0
    if extraFlashes > 0 then
        local flashInterval = data.flashInterval
        if not flashInterval or flashInterval <= 0 then
            flashInterval = DEFAULT_FLASH_INTERVAL

        end
        notice.flashesLeft = extraFlashes
        notice.flashInterval = flashInterval
        notice.nextFlashAt = CurTime() + flashInterval

    end

    local sound = huntersGlee_NotifyKinds[data.kind].sound
    if sound and not hook.Run( "glee_hideNotices" ) then
        box:Style():PlaySound( sound, 100, CHAN_STATIC, 0.5 )

    end
end

--[[---------------------------------------------------------
    GM:CancelNotice
    Takes down the message holding this replaceKey, if there is one.
    huntersGlee_CancelNotify calls this, call that instead.
    @param replaceKey: The key it was sent with.
    @param data: optional, huntersGlee_CancelNotify's options.
        noFade, gone this frame instead of fading out.
    @return: None
--]]---------------------------------------------------------
function GM:CancelNotice( replaceKey, data )
    local notice = findByKey( replaceKey )
    if not notice then return end

    if data and data.noFade then
        notice.box:Remove()
        table.RemoveByValue( notices, notice )
        return

    end

    notice.expiresAt = 0

end


net.Receive( "glee_notify", function()
    local data = {}
    data.text = net.ReadString()
    data.description = net.ReadString()
    data.kind = net.ReadString()
    data.time = net.ReadFloat()
    data.replaceKey = net.ReadString()
    data.style = net.ReadString()
    data.extraFlashes = net.ReadUInt( 8 )
    data.flashInterval = net.ReadFloat()
    data.onlyWhile = net.ReadString()

    if data.description == "" then data.description = nil end
    if data.replaceKey == "" then data.replaceKey = nil end
    if data.style == "" then data.style = nil end
    if data.onlyWhile == "" then data.onlyWhile = nil end

    GAMEMODE:AddNotice( data )

end )

net.Receive( "glee_notify_cancel", function()
    local replaceKey = net.ReadString()
    local data = {}
    data.noFade = net.ReadBool()

    GAMEMODE:CancelNotice( replaceKey, data )

end )


-- The engine won't say if it's drawing the ammo counter, so this asks what it asks.
-- When unsure say true, the stack staying up is fine but dropping onto a counter isn't
local function ammoCounterShowing( ply )
    if ply:Health() <= 0 then return false end
    if hook.Run( "HUDShouldDraw", "CHudAmmo" ) == false then return false end

    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) then return false end
    if wep.DrawAmmo == false then return false end

    -- first, plenty of weapons with no ammo type draw a count through this
    local display = wep.CustomAmmoDisplay and wep:CustomAmmoDisplay()
    if display then return display.Draw ~= false end

    return wep:GetPrimaryAmmoType() >= 0 or wep:GetSecondaryAmmoType() >= 0

end

local gapRiseSpeed = ( gapAboveAmmo - gapWithoutAmmo ) / GAP_RISE_TIME
local gapDropSpeed = ( gapAboveAmmo - gapWithoutAmmo ) / GAP_DROP_TIME
local ammoLastSeen = 0
local currentGap = gapAboveAmmo

-- Runs while the feed is empty too, a notice arriving mid weapon swap has to start at the right height
local function updateGap()
    local ply = LocalPlayer()
    local now = RealTime()

    if IsValid( ply ) and ammoCounterShowing( ply ) then
        ammoLastSeen = now

    end

    local stayUp = now - ammoLastSeen < GAP_DROP_DELAY
    local targetGap = stayUp and gapAboveAmmo or gapWithoutAmmo

    if #notices <= 0 then
        currentGap = targetGap
        return

    end

    local speed = stayUp and gapRiseSpeed or gapDropSpeed
    currentGap = math.Approach( currentGap, targetGap, speed * RealFrameTime() )

end

-- The message can land before the health update does, so onlyWhile has to have held once first
local function outlivedOnlyWhile( notice, isAlive )
    if not notice.onlyWhile then return false end

    if isAlive == ( notice.onlyWhile == "alive" ) then
        notice.onlyWhileHeld = true
        return false

    end

    return notice.onlyWhileHeld

end

-- before GM:HUDPaint, so the claim is in before anything dodging it looks
hook.Add( "HUDPaint", "glee_noticefeed_layout", function()
    updateGap()

    local ply = LocalPlayer()
    local isAlive = IsValid( ply ) and ply:Alive() and ply:Health() > 0 -- KillSilent leaves health above 0
    local cur = CurTime()
    local right = ScrW() - paddingFromEdge * 1.5
    local stackBottom = ScrH() - currentGap
    local y = stackBottom
    local widest = 0
    local hidden = hook.Run( "glee_hideNotices" )

    -- newest first, from the bottom up
    for index = #notices, 1, -1 do
        local notice = notices[index]
        local box = notice.box

        if not IsValid( box ) then
            table.remove( notices, index )
            continue

        end

        if outlivedOnlyWhile( notice, isAlive ) then
            box:Remove()
            table.remove( notices, index )
            continue

        end

        local expired = notice.expiresAt <= cur

        -- a hidden box doesn't think, so it would never fade to HIDDEN
        if expired and ( hidden or box:GetState() == box.STATE_HIDDEN ) then
            box:Remove()
            table.remove( notices, index )
            continue

        end

        box:SetVisible( not hidden )
        if hidden then continue end

        if expired then
            box:SetState( box.STATE_FADING )

        else
            box:SetState( box.STATE_NORMAL )

            local flashesLeft = notice.flashesLeft
            if flashesLeft and flashesLeft > 0 and notice.nextFlashAt <= cur then
                notice.flashesLeft = flashesLeft - 1
                notice.nextFlashAt = cur + notice.flashInterval
                box:SetState( box.STATE_FLASH )

            end
        end

        -- every frame, a style change swaps the fonts out from under it
        box:AutoSize()

        local w, h = box:GetSize()
        box:SetPos( right - w, y - h )

        local myHeight = h + box:Style():Metric( "laneSpacing" )
        local stateAlpha = box:GetStateAlpha()
        if expired and stateAlpha < ALMOST_FADED then
            myHeight = myHeight * stateAlpha / ALMOST_FADED

        end

        y = y - myHeight
        widest = math.max( widest, w )

    end

    if widest <= 0 then return end

    GAMEMODE:ImUsingHudSpace( "noticeFeed", right - widest, y, widest, stackBottom - y )

end )


-- gmod's notification library, for sandbox's notices and every addon's

local kindOfNotifyType = {
    [NOTIFY_GENERIC] = "info",
    [NOTIFY_ERROR]   = "bad",
    [NOTIFY_UNDO]    = "info",
    [NOTIFY_HINT]    = "info",
    [NOTIFY_CLEANUP] = "info",
}

function notification.AddLegacy( text, notifyType, time )
    if not text or text == "" then return end -- nothing to show, it'd be an empty box

    GAMEMODE:AddNotice( {
        text = text,
        kind = kindOfNotifyType[notifyType] or "info",
        time = time or 5,
    } )

end

-- No bar, the percentage goes on the end. Stays up until Kill.
-- Progress is updated over and over, so an update changes the text without flashing
function notification.AddProgress( id, text, frac )
    if frac then
        text = text .. " " .. math.Round( frac * 100 ) .. "%"

    end

    local notice = findByKey( id )
    if notice then
        setText( notice, text )
        return

    end

    GAMEMODE:AddNotice( {
        text = text,
        kind = "info",
        time = math.huge,
        replaceKey = id,
    } )

end

function notification.Kill( id )
    GAMEMODE:CancelNotice( id )

end
