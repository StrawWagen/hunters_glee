--[[------------------------------------
    The notice feed, where huntersGlee_Notify's messages land, see lua/autorun/sh_glee_notify.lua.
    gmod's notification library is pointed here too, so addons' notices match.

    A stack of glee_noticeboxes in the bottom right, newest at the bottom.
    Icons are glee_hud/cl_icons.lua's, baked here, in the layout, before the boxes paint.
    Each fades out once its time is up, and is removed once it's gone. A client notice's think can change that, see noticeMeta.
    Each keeps its alive and dead fields, and switches over when the player dies or spawns.
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
local ICON_SIZE = 48 -- 1080p pixels, scaled by the style
local ICON_MAX_SCREEN = 0.05 -- of the screen's height, past this an icon stops growing with the gui scale

local printNotices = CreateClientConVar( "cl_huntersglee_printnotices", "1", true, false, "Print notices in console?", 0, 1 )
local uncappedIcons = CreateClientConVar( "cl_huntersglee_noticeicons_uncapped", "0", true, false, "Let notice icons grow past their cap, with the gui scale?", 0, 1 )
local iconScale = CreateClientConVar( "glee_notify_iconscale", "1", true, false, "Scales every notice's icon.", 0.1, 2 )

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

-- What makes two messages the same one. From the text before its {num} is filled, so a running total finds itself
local function identityOf( text, description, fields )
    return table.concat( { text or "", description or "", fields.icon or "", fields.iconWeapon or "" }, "\0" )

end

local function findSame( identity )
    for _, notice in ipairs( notices ) do
        if notice.identity == identity then return notice end

    end
end

-- What a notice's think is handed, to change it while it's up
local noticeMeta = {}
noticeMeta.__index = noticeMeta

function noticeMeta:GetTimeLeft()
    return math.max( self.expiresAt - CurTime(), 0 )

end

function noticeMeta:SetTimeLeft( seconds )
    self.expiresAt = CurTime() + seconds

end

-- fades out, like huntersGlee_CancelNotify
function noticeMeta:Cancel()
    self.expiresAt = 0

end

local function newNotice()
    local box = vgui.Create( "glee_noticebox", GetAutoHidingHUDPanel() )
    box:SetFont( FONT )
    box:SetMaxTextWidth( maxTextWidth )
    box:SetTextAlign( TEXT_ALIGN_RIGHT )
    box:SetFlashDuration( FLASH_DURATION )
    box:SetFadeSpeed( FADE_SPEED )
    box:SetDoFadeDelays( false )

    local notice = setmetatable( { box = box }, noticeMeta )
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

local function stateNow()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return "dead" end

    return huntersGlee_NotifyStateOf( ply )

end

-- the same fields in both states, for notices from outside huntersGlee_Notify
local function inBothStates( fields )
    return { alive = fields, dead = fields }

end

-- text and description with {+bind}s filled in, {num} left for the total
local function filledText( fields )
    local text = fields.text and GAMEMODE:FillBinds( fields.text )
    local description = fields.description and GAMEMODE:FillBinds( fields.description )

    return text, description

end

local function withTotal( text, total )
    if not text or not total then return text end

    return ( string.gsub( text, "{num}", tostring( total ) ) )

end

-- true if glee_blockNotices blocks it. text is nil for an icon alone
local function blocked( text, description, fields )
    return hook.Run( "glee_blockNotices", text, description, fields.kind ) == true

end

local function iconOf( fields )
    if fields.iconWeapon then return terminator_Extras.glee_WeaponIcon( fields.iconWeapon ) end
    if fields.icon then return terminator_Extras.glee_MaterialIcon( fields.icon ) end

end

-- in the box's style, so after the style's set. Every frame, the style can change
local function unscaledIconHeight( box, iconSize )
    if iconSize then return ScrH() * iconSize end

    local style = box:Style()
    local height = style:Scaled( ICON_SIZE )
    if uncappedIcons:GetBool() then return height end

    return math.min( height, style:Settings().iconMaxSize, ScrH() * ICON_MAX_SCREEN )

end

-- the player's scale goes on last, past the cap
local function iconHeight( box, iconSize )
    return unscaledIconHeight( box, iconSize ) * iconScale:GetFloat()

end

-- what a state looks like, its time and flashes are set on arrival alone
local function showFields( notice, fields, text, description )
    notice.replaceKey = fields.replaceKey
    terminator_Extras.glee_SetPanelStyle( notice.box, fields.style ) -- nil goes back to the hud's own
    setText( notice, text, description )
    setKind( notice, fields.kind )

    notice.icon = iconOf( fields )
    notice.iconSize = fields.iconSize
    notice.iconBadge = fields.iconBadge

end

-- After a death or spawn, false if the notice has nothing for the new state
local function switchState( notice, state )
    local fields = notice.states[state]
    if not fields then return false end

    local text, description = filledText( fields )
    text = withTotal( text, notice.total )
    if blocked( text, description, fields ) then return false end

    notice.state = state
    showFields( notice, fields, text, description )

    local box = notice.box
    if notice.expiresAt > CurTime() then
        box:SetState( box.STATE_FLASH )

    end

    return true

end

--[[---------------------------------------------------------
    GM:AddNotice
    Puts a message in the feed, or flashes the one already showing it.
    Nothing for the player's state, nothing shown.
    huntersGlee_Notify calls this, call that instead.
    @param states: { alive = fields, dead = fields }, either nil for nothing in that state.
        fields are huntersGlee_Notify's, plain values. kind and time are always filled in, text or an icon is there.
        A flashInterval of 0 is the default too, it's what the net sends for none.
        {+bind}s and {num} are filled in here.
    @return: None
--]]---------------------------------------------------------
function GM:AddNotice( states )
    local state = stateNow()
    local fields = states[state]
    if not fields then return end

    local text, description = filledText( fields )
    local identity = identityOf( text, description, fields )
    local existing = findByKey( fields.replaceKey ) or findSame( identity )

    local total = fields.addNum
    if total and existing and existing.total then
        total = existing.total + total

    end

    text = withTotal( text, total )
    if blocked( text, description, fields ) then return end

    local notice = existing or newNotice()
    notice.states = states
    notice.state = state
    notice.identity = identity
    notice.total = total

    -- a countdown updates the one box every second, logging each would flood the console
    if not existing and printNotices:GetBool() then
        local line = text or fields.iconWeapon or fields.icon
        if description then
            line = line .. " - " .. description

        end
        permaPrint( "Notice; " .. string.gsub( line, "\n", " " ) )

    end
    notice.expiresAt = CurTime() + fields.time

    showFields( notice, fields, text, description )

    local box = notice.box
    box:SetState( box.STATE_FLASH )

    -- the same message again without flashes doesn't cut the first one's short
    local extraFlashes = fields.extraFlashes or 0
    if extraFlashes > 0 then
        local flashInterval = fields.flashInterval
        if not flashInterval or flashInterval <= 0 then
            flashInterval = DEFAULT_FLASH_INTERVAL

        end
        notice.flashesLeft = extraFlashes
        notice.flashInterval = flashInterval
        notice.nextFlashAt = CurTime() + flashInterval

    end

    local sound = huntersGlee_NotifyKinds[fields.kind].sound
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

    notice:Cancel()

end


-- written in the same order by sh_glee_notify.lua
local function readState()
    if not net.ReadBool() then return end

    local fields = {}
    fields.text = net.ReadString()
    fields.description = net.ReadString()
    fields.kind = net.ReadString()
    fields.time = net.ReadFloat()
    fields.replaceKey = net.ReadString()
    fields.style = net.ReadString()
    fields.extraFlashes = net.ReadUInt( 8 )
    fields.flashInterval = net.ReadFloat()
    fields.icon = net.ReadString()
    fields.iconWeapon = net.ReadString()
    fields.iconSize = net.ReadFloat()
    fields.iconBadge = net.ReadString()

    if net.ReadBool() then
        fields.addNum = net.ReadDouble()

    end

    if fields.text == "" then fields.text = nil end
    if fields.description == "" then fields.description = nil end
    if fields.replaceKey == "" then fields.replaceKey = nil end
    if fields.style == "" then fields.style = nil end
    if fields.icon == "" then fields.icon = nil end
    if fields.iconWeapon == "" then fields.iconWeapon = nil end
    if fields.iconSize <= 0 then fields.iconSize = nil end
    if fields.iconBadge == "" then fields.iconBadge = nil end

    return fields

end

net.Receive( "glee_notify", function()
    local alive = readState()
    local dead = readState()

    GAMEMODE:AddNotice( { alive = alive, dead = dead } )

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

-- Every notice's, every frame, so an erroring think is dropped or it'd spam the console.
-- Not once it's fading, it's on its way out
local function runThink( notice, cur )
    local fields = notice.states[notice.state]
    local think = fields.think
    if not think or notice.expiresAt <= cur then return end

    if not xpcall( think, ErrorNoHaltWithStack, notice ) then
        fields.think = nil

    end
end

-- before GM:HUDPaint, so the claim is in before anything dodging it looks
hook.Add( "HUDPaint", "glee_noticefeed_layout", function()
    updateGap()

    local state = stateNow()
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

        if notice.state ~= state and not switchState( notice, state ) then
            box:Remove()
            table.remove( notices, index )
            continue

        end

        runThink( notice, cur )
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

        -- out here, a panel's Paint would bake it offset by the panel's position
        local icon = notice.icon
        if icon then icon:Bake() end

        -- every frame, a style change swaps the fonts and icon size out from under it
        box:SetIcon( icon, icon and iconHeight( box, notice.iconSize ), notice.iconBadge )
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

    GAMEMODE:AddNotice( inBothStates( {
        text = text,
        kind = kindOfNotifyType[notifyType] or "info",
        time = time or 5,
    } ) )

end

-- No bar, the percentage goes on the end. Stays up until Kill.
-- Progress is updated over and over, so an update changes the text without flashing
function notification.AddProgress( id, text, frac )
    if frac then
        text = text .. " " .. math.Round( frac * 100 ) .. "%"

    end

    local notice = findByKey( id )
    if notice then
        notice.states[notice.state].text = text -- one table in both states, see inBothStates
        setText( notice, text )
        return

    end

    GAMEMODE:AddNotice( inBothStates( {
        text = text,
        kind = "info",
        time = math.huge,
        replaceKey = id,
    } ) )

end

function notification.Kill( id )
    GAMEMODE:CancelNotice( id )

end
