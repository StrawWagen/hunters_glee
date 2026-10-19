--[[
    glee_wheel — extends glee_panel

    A radial menu. Up to 8 items a page on a ring of wedges, picked by direction from the
    centre, clockwise from the top. Each wedge shows its item's icon, or its label when it
    has no icon, the icon failed to load, or it's hovered. The hole in the middle is left clear.

        local wheel = vgui.Create( "glee_wheel" )
        wheel:SetSize( 600, 600 )
        wheel:SetItems( {
            { label = "Wave" },
            { label = "Supplies", icon = Material( "..." ) },
        } )
        function wheel:OnItemSelected( item, index ) end

        -- optional, polled every STATUS_POLL_INTERVAL for the items on the page
        function wheel:GetItemStatus( item, index )
            return canPick, cooldownEnd, cooldownLength
        end

    Two ways to aim it:
        Clicked: MakePopup it, the cursor aims and a click on the ring picks. A click anywhere
            else closes it, the hole here, off the panel through easyClosePanel.
        Held: HoldAim it while a key is down, the mouse aims without turning the view.
            Release it when the key comes up, that picks whatever's aimed at, then closes.

    Past 8 items it pages, the mouse wheel flips them. Keys 1 to 8 pick on the current page.
    Close fades it out, then removes it.
]]

local PER_PAGE = 8
local START_ANGLE = -90 -- the top

-- radii, of half the width. OUTER + CHOSEN_PUSH must stay under 1, or the chosen wedge clips
local INNER_RATIO       = 0.46
local OUTER_RATIO       = 0.84
local HOVER_PUSH_RATIO  = 0.05
local CHOSEN_PUSH_RATIO = 0.09
-- of the inner radius, nothing's picked inside it while HoldAim'd. It must stay under 1, held aim is
-- clamped to the inner radius. Clicked, the dead zone is the hole inside the page bar, see holeRadius
local DEAD_ZONE_RATIO   = 0.5

local ICON_FILL = 0.75 -- of the wedge's thickness, or its width if that's narrower

local CHOSEN_FLASH_TIME  = 0.2
local HOVER_RATE         = 30 -- per second, of exponential easing. 30 is most of the way in 0.1s
local PAGE_SCROLL_RATE   = 60

local IDLE_DIM             = 0.6 -- every other wedge's label, while one's hovered
local COOLDOWN_SWEEP_ALPHA = 40
local LIFTED_PX            = 0.5 -- pushed further than this, a wedge takes its piece of the ring with it

local STATUS_POLL_INTERVAL = 0.1 -- the shop caches canPurchase this long too

local LABEL_FONT = "medium" -- a font role

local PANEL = {}

PANEL.Init = function( self )
    self:SetPaintBackground( false )
    self:SetMouseInputEnabled( true ) -- glee_panel's default, off, would swallow every click
    self:SetKeyboardInputEnabled( true )

    self._items   = {}
    self._page    = 1
    self._hovered = nil -- slot on the page, nil in the dead zone
    self._pressed = false

    self._statuses       = {} -- by item index, only the current page's are fresh
    self._nextStatusPoll = 0

    -- by slot on the page, what Paint eases and lays out
    self._slots = {}
    for slot = 1, PER_PAGE do
        self._slots[slot] = { hover = 0, color = Color( 0, 0, 0, 0 ), contentColor = Color( 0, 0, 0, 0 ) }

    end

    self._focus = 0 -- eases to 1 while anything's hovered
    -- pages flipped, never wrapped, so the grip keeps turning the way it's scrolled past the last page
    self._pageSteps  = 0
    self._pageScroll = 0 -- eases to _pageSteps

    self._enteredAt  = RealTime()
    self._exitingAt  = nil
    self._chosenSlot = nil
    self._chosenAt   = nil

    self._held = false
    self._aimX, self._aimY = 0, 0

    self._drawColor = Color( 0, 0, 0, 0 )

end

-- stub
PANEL.OnItemSelected = function( _self, _item, _index )
end

-- stub. canPick false greys the item out and refuses the pick.
-- cooldownEnd is a CurTime, cooldownLength its full length; the wedge sweeps only when given both
PANEL.GetItemStatus = function( _self, _item, _index )
    return true

end

-- items: { { label = "Wave", icon = Material or nil, ... }, ... }. Anything else on an item is the caller's
PANEL.SetItems = function( self, items )
    self._items = items
    self._page = 1
    self._pageSteps = 0
    self._pageScroll = 0
    self._hovered = nil
    self._chosenSlot = nil
    self._statuses = {}
    self._nextStatusPoll = 0

end


-- Layout ----------------------------------------------------------------------

local function pageCount( self )
    return math.max( math.ceil( #self._items / PER_PAGE ), 1 )

end

local function pageRange( self )
    local first = ( self._page - 1 ) * PER_PAGE + 1
    return first, math.min( first + PER_PAGE - 1, #self._items )

end

local function slotsOnPage( self )
    local first, last = pageRange( self )
    return math.max( last - first + 1, 1 )

end

local function radii( self )
    local halfW = self:GetWide() * 0.5
    return halfW * INNER_RATIO, halfW * OUTER_RATIO, halfW

end

-- The page bar's frame and track, out from the middle, inside a ring whose inner edge is ringInner.
-- Its own frame sits a lane's spacing in, padded like the main ring's wedges
local function pageRingRadii( style, ringInner )
    local pad = style:Metric( "blockPadding" )
    local frameOuter = ringInner - style:Metric( "laneSpacing" )
    local trackOuter = frameOuter - pad
    local trackInner = trackOuter - pad * 2 -- as wide as the scrollpanel's bar
    local frameInner = trackInner - pad

    return frameInner, trackInner, trackOuter, frameOuter

end

-- Where a click stops picking and closes: inside the page bar when there is one, so aiming at
-- it still picks, or else inside the ring
local function holeRadius( self )
    local inner = radii( self )
    if pageCount( self ) <= 1 then return inner end

    return ( pageRingRadii( self:Style(), inner ) )

end

local function slotAngles( self, slot )
    local degreesPerSlot = 360 / slotsOnPage( self )
    local startDeg = START_ANGLE + ( slot - 1 ) * degreesPerSlot - degreesPerSlot * 0.5
    return startDeg, startDeg + degreesPerSlot

end

local function setPage( self, page )
    page = ( ( page - 1 ) % pageCount( self ) ) + 1
    if page == self._page then return end

    self._page = page
    self._hovered = nil
    self._chosenSlot = nil
    self._nextStatusPoll = 0
    for _, data in ipairs( self._slots ) do
        data.hover = 0

    end

    self:Style():PlaySound( "switch", 100, nil, 0.3, 60 )

end


-- Status ----------------------------------------------------------------------

local function pollStatuses( self )
    if self._nextStatusPoll > CurTime() then return end
    self._nextStatusPoll = CurTime() + STATUS_POLL_INTERVAL

    local first, last = pageRange( self )
    for index = first, last do
        local status = self._statuses[index] or {}
        self._statuses[index] = status

        status.canPick, status.cooldownEnd, status.cooldownLength = self:GetItemStatus( self._items[index], index )

    end
end

-- nil before the item's first poll
local function slotStatus( self, slot )
    local first = pageRange( self )
    return self._statuses[first + slot - 1]

end

local function canPickSlot( self, slot )
    local status = slotStatus( self, slot )
    return status and status.canPick or false

end

-- 1 just started, 0 done or no sweep
local function cooldownRemaining( status )
    if not status or not status.cooldownEnd or not status.cooldownLength then return 0 end
    if status.cooldownLength <= 0 then return 0 end

    return math.Clamp( ( status.cooldownEnd - CurTime() ) / status.cooldownLength, 0, 1 )

end


-- Picking ---------------------------------------------------------------------

local function aimOffset( self )
    if self._held then return self._aimX, self._aimY end

    local w, h = self:GetSize()
    local cursorX, cursorY = self:CursorPos()
    return cursorX - w * 0.5, cursorY - h * 0.5

end

-- by direction alone, so a flick picks without aiming at the wedge
local function slotUnderAim( self )
    if #self._items == 0 then return end

    local deltaX, deltaY = aimOffset( self )
    local distanceSqr = deltaX * deltaX + deltaY * deltaY

    if self._held then
        local deadZone = radii( self ) * DEAD_ZONE_RATIO
        if distanceSqr < deadZone * deadZone then return end

    else
        -- clicked, only the ring picks, so nothing lights up where a click would close it.
        -- Out to a hovered wedge's push, or it would flicker off the edge it just pushed out
        local deadZone = holeRadius( self )
        local _, outer, halfW = radii( self )
        local reach = outer + halfW * HOVER_PUSH_RATIO
        if distanceSqr < deadZone * deadZone or distanceSqr > reach * reach then return end

    end

    local degreesPerSlot = 360 / slotsOnPage( self )
    local angle = math.deg( math.atan2( deltaY, deltaX ) )

    return math.floor( ( ( angle - START_ANGLE + degreesPerSlot * 0.5 ) % 360 ) / degreesPerSlot ) + 1

end

-- OnItemSelected may Close or Remove the wheel, nothing may touch self after it
local function selectSlot( self, slot )
    local first = pageRange( self )
    local index = first + slot - 1
    local item = self._items[index]
    if not item then return end

    if not canPickSlot( self, slot ) then
        self:Style():PlaySound( "switch", 60, nil, 0.3, 60 )
        return

    end

    self._chosenSlot = slot
    self._chosenAt = RealTime()
    self:Style():PlaySound( "press" )
    self:OnItemSelected( item, index )

end

PANEL.OnMousePressed = function( self, mouseCode )
    if mouseCode ~= MOUSE_LEFT then return end

    self._pressed = true

end

PANEL.OnMouseReleased = function( self, mouseCode )
    if mouseCode ~= MOUSE_LEFT then return end

    self._pressed = false

    local slot = slotUnderAim( self )
    if not slot then
        self:Close()
        return

    end

    selectSlot( self, slot )

end

PANEL.OnMouseWheeled = function( self, delta )
    if pageCount( self ) <= 1 then return end

    self._pageSteps = self._pageSteps - delta
    setPage( self, self._pageSteps + 1 )
    return true

end

PANEL.OnKeyCodePressed = function( self, keyCode )
    local slot = keyCode - KEY_0
    if slot < 1 or slot > slotsOnPage( self ) then return end

    selectSlot( self, slot )

end

-- the mouse aims from the centre, and the view holds still, until Release or Close
PANEL.HoldAim = function( self )
    self._held = true
    self._aimX, self._aimY = 0, 0

    hook.Add( "InputMouseApply", self, function( wheel, _cmd, x, y )
        local aimX, aimY = wheel._aimX + x, wheel._aimY + y

        -- clamped short, so turning back the other way doesn't take a long drag
        local limit = radii( wheel )
        local length = math.sqrt( aimX * aimX + aimY * aimY )
        if length > limit then
            aimX, aimY = aimX / length * limit, aimY / length * limit

        end

        wheel._aimX, wheel._aimY = aimX, aimY
        return true

    end )
end

-- does nothing unless HoldAim'd, a clicked wheel isn't closed by some key coming up
PANEL.Release = function( self )
    if not self._held or self._exitingAt then return end

    local slot = slotUnderAim( self )
    if slot then selectSlot( self, slot ) end

    if IsValid( self ) then self:Close() end

end

-- Plays the style's exit, then removes it. easyClosePanel calls this every frame escape is down
PANEL.Close = function( self )
    if self._exitingAt then return end

    self._exitingAt = RealTime()
    self:SetMouseInputEnabled( false )
    self:SetKeyboardInputEnabled( false )
    hook.Remove( "InputMouseApply", self )

    self:NewAnimation( self:Style():ExitDuration( slotsOnPage( self ) ), 0, -1, function( _, wheel )
        wheel:Remove()

    end )
end


-- Animation -------------------------------------------------------------------

-- the chosen wedge's pop, the wheel's own. Coming in and leaving are the style's
local function easeOut( t )
    local inverse = 1 - t
    return 1 - inverse * inverse * inverse

end

local function approach( current, target, rate, dt )
    return current + ( target - current ) * ( 1 - math.exp( -rate * dt ) )

end

PANEL.Think = function( self )
    if self._exitingAt then return end

    pollStatuses( self )

    local hovered = slotUnderAim( self )
    if hovered ~= self._hovered then
        local pitch = 80
        if hovered then
            pitch = canPickSlot( self, hovered ) and 90 or 70

        end
        self:Style():PlaySound( "switch", pitch, nil, 0.14, 60 )

        self._hovered = hovered

    end

    local dt = RealFrameTime()
    for slot = 1, slotsOnPage( self ) do
        local data = self._slots[slot]
        data.hover = approach( data.hover, slot == hovered and 1 or 0, HOVER_RATE, dt )

    end

    self._focus = approach( self._focus, hovered and 1 or 0, HOVER_RATE, dt )
    self._pageScroll = approach( self._pageScroll, self._pageSteps, PAGE_SCROLL_RATE, dt )

end

-- The style's exit for one part: fade, scale and progress. Nothing's moved while it isn't leaving
local function exitMotion( self, style, order )
    if not self._exitingAt then return 1, 1, 0 end

    local fade, scale, _, progress = style:Exit( self._exitingAt, order )
    return fade, scale, progress

end

-- each slot's radii, push and fade this frame, onto self._slots. Wedges come in and leave in
-- order, clockwise from the top, as the style staggers its parts
local function layoutSlots( self, style, inner, outer, halfW )
    for slot = 1, slotsOnPage( self ) do
        local data = self._slots[slot]
        local order = slot - 1

        local fade, scale = style:Entrance( self._enteredAt, order )
        local exitFade, exitScale, exitProgress = exitMotion( self, style, order )

        -- the pick stays whole and pops out while the rest leave, and fades only at the last
        local isChosen = self._exitingAt and slot == self._chosenSlot
        if isChosen then
            fade = fade * ( 1 - exitProgress * exitProgress * exitProgress )

        else
            fade, scale = fade * exitFade, scale * exitScale

        end

        local push = 0
        if canPickSlot( self, slot ) then push = halfW * HOVER_PUSH_RATIO * data.hover end
        if isChosen then push = push + halfW * ( CHOSEN_PUSH_RATIO - HOVER_PUSH_RATIO ) * easeOut( exitProgress ) end

        local startDeg, endDeg = slotAngles( self, slot )
        local mid = math.rad( ( startDeg + endDeg ) * 0.5 )
        local dirX, dirY = math.cos( mid ), math.sin( mid )

        data.startDeg, data.endDeg = startDeg, endDeg
        data.inner, data.outer = inner * scale, outer * scale
        data.push = push
        data.offsetX, data.offsetY = dirX * push, dirY * push

        local contentRadius = push + ( data.inner + data.outer ) * 0.5
        data.contentX, data.contentY = dirX * contentRadius, dirY * contentRadius

        data.fade = fade
        data.dim = Lerp( self._focus * ( 1 - data.hover ), 1, IDLE_DIM )

    end
end


-- Paint -----------------------------------------------------------------------

local function mixColor( out, from, to, t )
    out.r = Lerp( t, from.r, to.r )
    out.g = Lerp( t, from.g, to.g )
    out.b = Lerp( t, from.b, to.b )
    out.a = Lerp( t, from.a, to.a )

end

-- shared scratch, use it before asking for another
local function fadedColor( self, color, alphaMul )
    local out = self._drawColor
    out.r, out.g, out.b, out.a = color.r, color.g, color.b, color.a * alphaMul
    return out

end

-- Backdrops, the ring and the wedges, are the style's, see handle:ArcBackground. This is for the
-- plain fills over them, the page grip and the cooldown sweep. fromFrac and toFrac, 0 to 1, keep
-- part of it clockwise. Drawn with RNDX like the backdrops, surface would blend it darker
local function drawWedge( centerX, centerY, inner, outer, startDeg, endDeg, gap, color, fromFrac, toFrac )
    local shape = terminator_Extras.glee_HudHelpers.ArcShape( centerX, centerY, inner, outer, startDeg, endDeg, gap, fromFrac, toFrac )
    if shape then shape:Color( color ):Draw() end

end

local function isLifted( data )
    return data.push > LIFTED_PX

end

-- the ring is the wheel's frame, each wedge sits in it padded like a settings row in its menu.
-- Drawn without the lifted wedges' pieces, in unbroken runs between them, so no seams show at slot edges
local function paintRing( self, style, centerX, centerY, inner, outer, fade )
    local count = slotsOnPage( self )

    local firstLifted
    for slot = 1, count do
        if isLifted( self._slots[slot] ) then
            firstLifted = slot
            break

        end
    end

    if not firstLifted then
        style:ArcBackground( centerX, centerY, inner, outer, 0, 360, 0, "bgDark", fade, "idle", self )
        return

    end

    -- once round, starting just after a lifted slot, so the walk ends on one and every run gets closed
    local degreesPerSlot = 360 / count
    local runStartDeg, runLength = 0, 0
    for step = 1, count do
        local slot = ( firstLifted + step - 1 ) % count + 1
        if isLifted( self._slots[slot] ) then
            if runLength > 0 then
                local runEndDeg = runStartDeg + runLength * degreesPerSlot
                style:ArcBackground( centerX, centerY, inner, outer, runStartDeg, runEndDeg, 0, "bgDark", fade, "idle", self )
                runLength = 0

            end
        else
            if runLength == 0 then runStartDeg = slotAngles( self, slot ) end
            runLength = runLength + 1

        end
    end
end

local function paintWedge( self, style, slot, centerX, centerY, pad, gap, chosenFlash )
    local data = self._slots[slot]
    local canPick = canPickSlot( self, slot )
    local wedgeX, wedgeY = centerX + data.offsetX, centerY + data.offsetY

    -- pushed out, it takes its piece of the ring along, blur and all
    if isLifted( data ) then
        style:ArcBackground( wedgeX, wedgeY, data.inner, data.outer, data.startDeg, data.endDeg, 0, "bgDark", data.fade, "idle", self )

    end

    -- a disabled wedge still lights up under the aim, some styles' disabled is the same as idle
    local litState = ( self._pressed and canPick and slot == self._hovered ) and "pressed" or "hovered"
    local color = data.color
    mixColor( color, style:BackdropColor( "bg", canPick and "idle" or "disabled" ), style:BackdropColor( "bg", litState ), data.hover )
    if slot == self._chosenSlot and chosenFlash > 0 then
        mixColor( color, color, style:BackdropColor( "bg", "chosen" ), chosenFlash )

    end

    local wedgeInner, wedgeOuter = data.inner + pad, data.outer - pad
    style:ArcBackground( wedgeX, wedgeY, wedgeInner, wedgeOuter, data.startDeg, data.endDeg, gap, color, data.fade, nil, self )

    -- what's left of the cooldown, shrinking clockwise
    local remaining = cooldownRemaining( slotStatus( self, slot ) )
    if remaining > 0 then
        local sweepColor = fadedColor( self, style:Color( "text" ), data.fade )
        sweepColor.a = COOLDOWN_SWEEP_ALPHA * data.fade
        drawWedge( wedgeX, wedgeY, wedgeInner, wedgeOuter, data.startDeg, data.endDeg, gap, sweepColor, 1 - remaining, 1 )

    end
end

local function paintWedges( self, style, centerX, centerY, now )
    local pad, gap = style:Metric( "blockPadding" ), style:Metric( "laneSpacing" )
    local chosenFlash = self._chosenAt and math.Clamp( 1 - ( now - self._chosenAt ) / CHOSEN_FLASH_TIME, 0, 1 ) or 0

    -- lifted ones last, so their piece of the ring goes over their neighbours, not under
    for slot = 1, slotsOnPage( self ) do
        local data = self._slots[slot]
        if data.fade > 0 and not isLifted( data ) then paintWedge( self, style, slot, centerX, centerY, pad, gap, chosenFlash ) end

    end

    for slot = 1, slotsOnPage( self ) do
        local data = self._slots[slot]
        if data.fade > 0 and isLifted( data ) then paintWedge( self, style, slot, centerX, centerY, pad, gap, chosenFlash ) end

    end
end

-- the colours a settings row's text takes: happy, or text when disabled. Hover only touches the backdrop
local function paintContents( self, style, centerX, centerY )
    local font = style:Font( LABEL_FONT )
    local pad, gap = style:Metric( "blockPadding" ), style:Metric( "laneSpacing" )
    local spanRad = math.rad( 360 / slotsOnPage( self ) )
    local first = pageRange( self )

    for slot = 1, slotsOnPage( self ) do
        local data = self._slots[slot]
        local item = self._items[first + slot - 1]
        if item and data.fade > 0 then
            local role = style:Color( canPickSlot( self, slot ) and "happy" or "text" )
            local color = data.contentColor
            color.r, color.g, color.b, color.a = role.r, role.g, role.b, role.a * data.fade * data.dim

            local x, y = centerX + data.contentX, centerY + data.contentY
            -- Material() hands back the error checkerboard for a missing file, never nil
            if item.icon and not item.icon:IsError() and data.hover < 0.5 then
                local thickness = data.outer - data.inner - pad * 2
                local width = ( data.inner + data.outer ) * 0.5 * spanRad - gap
                local iconSize = math.min( thickness, width ) * ICON_FILL

                surface.SetDrawColor( color )
                surface.SetMaterial( item.icon )
                surface.DrawTexturedRect( x - iconSize * 0.5, y - iconSize * 0.5, iconSize, iconSize )

            else
                draw.SimpleText( item.label or "", font, x, y, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

            end
        end
    end
end

-- glee_scrollpanel's bar bent into a second ring inside the first, so the mouse wheel reads as
-- the way to page. The grip is one page's share of it, page 1 at the top, turning clockwise
local function paintPages( self, style, centerX, centerY, ringInner, fade )
    local pages = pageCount( self )
    if pages <= 1 then return end

    local frameInner, inner, outer, frameOuter = pageRingRadii( style, ringInner )

    style:ArcBackground( centerX, centerY, frameInner, frameOuter, 0, 360, 0, "bgDark", fade, "idle", self )
    style:ArcBackground( centerX, centerY, inner, outer, 0, 360, 0, "bg", fade, "idle", self )

    local gripSpan = 360 / pages
    local gripStart = START_ANGLE - gripSpan * 0.5 + gripSpan * self._pageScroll
    drawWedge( centerX, centerY, inner, outer, gripStart, gripStart + gripSpan, 0, fadedColor( self, style:Color( "happy" ), fade ), 0, 1 )

end

PANEL.Paint = function( self, w, h )
    local style = self:Style()
    local now = RealTime()
    local centerX, centerY = w * 0.5, h * 0.5
    local inner, outer, halfW = radii( self )

    -- the ring and page bar, as one part, the first
    local fade, scale = style:Entrance( self._enteredAt )
    local exitFade, exitScale = exitMotion( self, style, 0 )
    fade, scale = fade * exitFade, scale * exitScale

    layoutSlots( self, style, inner, outer, halfW )

    paintRing( self, style, centerX, centerY, inner * scale, outer * scale, fade )
    paintWedges( self, style, centerX, centerY, now )
    paintContents( self, style, centerX, centerY )
    paintPages( self, style, centerX, centerY, inner * scale, fade )

end

vgui.Register( "glee_wheel", PANEL, "glee_panel" )
