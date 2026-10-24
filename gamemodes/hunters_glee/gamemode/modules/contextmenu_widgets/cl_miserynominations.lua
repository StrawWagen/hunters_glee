
-- The Misery Nominations window. Hold a misery's row to nominate it, hold your own to withdraw it.
-- Every check and charge is the server's, through huntersglee_misery_nominate and _withdraw, this only shows them

local REFRESH_INTERVAL = 0.25
local MAX_HEIGHT_1080P = 775 -- the settings menu's
local HEADER_FONT = "mediumLarge"

-- glee_signature's
local HOLD_TIME  = 1.6
local DRAIN_TIME = 0.4
local TICKS      = 12 -- scratches across one hold

local FILL_ALPHA = 60

-- half a bank document's fanfare, see glee_consentform
local SHAKE_STRENGTH_1080P = 5
local SHAKE_DURATION       = 0.35
local LANDING_VOLUME       = 0.5

local WOBBLE_1080P       = 1 -- how far your nomination's text wanders, always
local BURST_1080P        = 6 -- and how far it's thrown when you first nominate it
local BURST_DURATION     = 0.5

local SEARCH_WIDTH_1080P = 200
local SEARCH_PLACEHOLDER = "Search..."

local UNKNOWN_LABEL = "???"
local WIDEST_MULT   = "00.00x"
local WIDEST_VALUE  = "000000"

-- an escape multiplier never really reads 0, it floors above it. 0 is one that hasn't synced yet
local function knownMultiplier( setName )
    local mul = GAMEMODE:GetSpawnsetsEscapeMultiplier( setName )
    if mul <= 0 then return end
    return mul

end

local function multiplierText( setName )
    local mul = knownMultiplier( setName )
    if not mul then return "?x" end
    return math.Round( mul, 2 ) .. "x"

end

local function rowLabel( setName )
    if not GAMEMODE:HasSeenMisery( setName ) then return UNKNOWN_LABEL end
    return GAMEMODE:GetPrettyNameOfSpawnSet( setName )

end

local UNKNOWN_HEADER = "A MISERY UNKNOWN TO YOU..."
local FULLY_CORRUPT_MUL  = 3 -- at this multiplier and up, not a letter of the description survives
local LEAST_CORRUPTION   = 0.3 -- even the easiest keep this much of it hidden

-- [setName] = { mul = the multiplier it was corrupted at, text = string }
local corruptedCache = {}

-- An unseen misery's description, its letters swapped for ? marks, more of them the harder it is.
-- The same letters go every time, so it doesn't flicker as the window refreshes
local function corruptedDescription( setName, description )
    local mul = knownMultiplier( setName ) or FULLY_CORRUPT_MUL
    local cached = corruptedCache[setName]
    if cached and cached.mul == mul then return cached.text end

    local corruption = math.Clamp( mul / FULLY_CORRUPT_MUL, LEAST_CORRUPTION, 1 )

    local chars = {}
    local index = 0
    for char in string.gmatch( description, utf8.charpattern ) do
        index = index + 1
        local roll = tonumber( util.CRC( setName .. index ) ) / 4294967295
        if roll < corruption and not string.find( char, "%s" ) then
            char = "?"

        end
        chars[index] = char

    end

    local text = table.concat( chars )
    corruptedCache[setName] = { mul = mul, text = text }

    return text

end

local function nominatorOf( setName )
    for steamID64, nomination in pairs( GAMEMODE:GetMiseryNominations() ) do
        if nomination.setName == setName then return steamID64, nomination end

    end
end

-- your nomination, if it's of setName, and whether it's suspended
local function myNominationOf( setName )
    local me = LocalPlayer():SteamID64()
    local nomination = GAMEMODE:GetMiseryNominations()[me]
    local suspended = false
    if not nomination then
        nomination = GAMEMODE:GetSuspendedMiseryNominations()[me]
        suspended = true

    end

    if not nomination or nomination.setName ~= setName then return end
    return nomination, suspended

end

local function rowValue( setName )
    local mine = myNominationOf( setName )
    if mine then return tostring( mine.cost ) end
    if nominatorOf( setName ) then return "TAKEN" end
    if not knownMultiplier( setName ) then return "?" end

    return tostring( GAMEMODE:GetMiseryNominationCost( LocalPlayer(), setName ) )

end

local function rowTooltip( setName, reason )
    local lines = {}

    local registered = GAMEMODE:GetRegisteredSpawnSet( setName )
    if not GAMEMODE:HasSeenMisery( setName ) then
        table.insert( lines, UNKNOWN_HEADER )
        if registered and registered.description then
            table.insert( lines, corruptedDescription( setName, registered.description ) )

        end
    elseif registered and registered.description then
        table.insert( lines, registered.description )

    end

    local mine, suspended = myNominationOf( setName )
    local nominator = nominatorOf( setName )
    if mine then
        local status = suspended and "Your nomination, suspended until there's room for it on the ballot." or "Your nomination."
        table.insert( lines, status .. " Hold to withdraw it, forfeiting the " .. mine.cost .. " score it cost." )

    elseif nominator then
        local ply = player.GetBySteamID64( nominator )
        table.insert( lines, "Nominated by " .. ( IsValid( ply ) and ply:Nick() or "someone" ) .. "." )

    elseif reason then
        table.insert( lines, reason )

    end

    if #lines <= 0 then return false end
    return table.concat( lines, "\n\n" )

end

local function slotsText()
    -- alone, nobody else's nominations are worth counting
    if player.GetCount() <= 1 then return "" end
    return table.Count( GAMEMODE:GetMiseryNominations() ) .. "/" .. GAMEMODE:GetMiseryVoteMaxOptions()

end

local function knownCost( setName )
    if not knownMultiplier( setName ) then return end
    return GAMEMODE:GetMiseryNominationCost( LocalPlayer(), setName )

end

-- cheapest first, unsynced ones last. Ties go by name, so the order is the same every open
local function cheapestFirst( a, b )
    local aCost = knownCost( a.setName )
    local bCost = knownCost( b.setName )
    if ( aCost == nil ) ~= ( bCost == nil ) then return aCost ~= nil end
    if aCost and aCost ~= bCost then return aCost < bCost end

    return rowLabel( a.setName ) .. a.setName < rowLabel( b.setName ) .. b.setName

end

local function textWidth( font, text )
    surface.SetFont( font )
    return ( surface.GetTextSize( text ) )

end


-- Rows ----------------------------------------------------------------------

local function isMine( row )
    return myNominationOf( row.setName ) ~= nil

end

local function stopHolding( row )
    row._holding = false
    row:MouseCapture( false )

end

local function scratch( row )
    local tick = math.floor( row._fill * TICKS )
    if tick <= row._lastTick then return end

    row._lastTick = tick
    row:Style():PlaySound( "switch", 70 + ( tick / TICKS ) * 60, nil, 0.3 )

end

local function commit( row )
    stopHolding( row )
    row:Style():PlaySound( "press", 80, nil, 1 )

    if isMine( row ) then
        RunConsoleCommand( "huntersglee_misery_withdraw" )
        return

    end

    RunConsoleCommand( "huntersglee_misery_nominate", row.setName )

    -- dying mid-window swaps the style, so it's fetched now
    local frame = row.frame
    local style = frame:Style()
    terminator_Extras.glee_Style( "god", style.scaleName ):PlaySound( "landing", 60, nil, LANDING_VOLUME )
    frame:Shake( style:Scaled( SHAKE_STRENGTH_1080P ), SHAKE_DURATION )
    row._burstAt = RealTime()

end

local function wobbleReach( row )
    local style = row:Style()
    local reach = 0
    if isMine( row ) then
        reach = style:Scaled( WOBBLE_1080P )

    end

    local burstProgress = ( RealTime() - row._burstAt ) / BURST_DURATION
    if burstProgress < 1 then
        reach = reach + style:Scaled( BURST_1080P ) * ( 1 - burstProgress ) ^ 2

    end

    return reach

end

local function paintFill( row, w, h )
    if row._fill <= 0 then return end

    local style = row:Style()
    local color = ColorAlpha( style:Color( isMine( row ) and "alert" or "happy" ), FILL_ALPHA )
    local screenX, screenY = row:LocalToScreen( 0, 0 )

    render.SetScissorRect( screenX, screenY, screenX + w * row._fill, screenY + h, true )
    draw.RoundedBox( style:Metric( "boxCornerRadius" ), 0, 0, w, h, color )
    render.SetScissorRect( 0, 0, 0, 0, false )

end

local function makeRow( frame, parent, setName )
    local row = vgui.Create( "glee_row", parent )
    row.frame    = frame
    row.setName  = setName
    row._fill     = 0 -- how far the hold has got, 0 to 1
    row._holding  = false
    row._lastTick = 0
    row._burstAt  = -math.huge

    -- only measured, never drawn, so the frame already fits the name once it's seen
    row:SetLabel( GAMEMODE:GetPrettyNameOfSpawnSet( setName ) )
    row:SetReservedValue( WIDEST_VALUE )

    local function multColumnWidth()
        return textWidth( row:GetResolvedFont(), WIDEST_MULT )

    end

    function row:GetContentWidth()
        local gap = self:Style():Metric( "laneSpacing" )
        return vgui.GetControlTable( "glee_row" ).GetContentWidth( self ) + gap + multColumnWidth()

    end

    function row:GetVisualState()
        if isMine( self ) then return "chosen" end
        return vgui.GetControlTable( "glee_row" ).GetVisualState( self )

    end

    function row:GetContentColor()
        if isMine( self ) then return "chosen" end
        return vgui.GetControlTable( "glee_row" ).GetContentColor( self )

    end

    -- a press starts a hold rather than being a click, so this replaces the row's own
    function row:OnMousePressed( mouseCode )
        if mouseCode ~= MOUSE_LEFT then return end
        if self:GetDisabled() then return end

        self._holding = true
        self:MouseCapture( true )

    end

    function row:OnMouseReleased( mouseCode )
        if mouseCode ~= MOUSE_LEFT then return end
        stopHolding( self )

    end

    function row:AdditionalThink()
        -- a release off the row never reaches OnMouseReleased. Disabling mid-hold lets go too
        if self._holding and ( self:GetDisabled() or not input.IsMouseDown( MOUSE_LEFT ) ) then
            stopHolding( self )

        end

        if self._holding then
            self._fill = self._fill + FrameTime() / HOLD_TIME
            scratch( self )
            if self._fill >= 1 then
                self._fill = 1
                commit( self )

            end
        else
            self._fill = math.max( self._fill - FrameTime() / DRAIN_TIME, 0 )
            self._lastTick = math.floor( self._fill * TICKS )

        end
    end

    function row:PaintContent( w, h, contentColor )
        paintFill( self, w, h )

        local reach = wobbleReach( self )
        if reach > 0 then
            local matrix = Matrix()
            matrix:Translate( Vector( math.Rand( -reach, reach ), math.Rand( -reach, reach ), 0 ) )
            cam.PushModelMatrix( matrix, true )

        end

        local font     = self:GetResolvedFont()
        local innerPad = self:GetTextPadding() * 2
        local gap      = self:Style():Metric( "laneSpacing" )
        local midY     = h * 0.5
        local value    = rowValue( self.setName )
        local valueW   = math.max( textWidth( font, value ), textWidth( font, WIDEST_VALUE ) )

        draw.SimpleText( rowLabel( self.setName ), font, innerPad, midY, contentColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
        draw.SimpleText( multiplierText( self.setName ), font, w - innerPad - valueW - gap, midY, contentColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
        draw.SimpleText( value, font, w - innerPad, midY, contentColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )

        if reach > 0 then cam.PopModelMatrix() end

    end

    return row

end


-- Window --------------------------------------------------------------------

local function openMiseryNominations()
    local me = LocalPlayer()
    if not IsValid( me ) then return end

    local frame = vgui.Create( "glee_frame" )
    local style = frame:Style()
    local pad = style:Metric( "blockPadding" )
    local gap = style:Metric( "laneSpacing" )

    local title = vgui.Create( "glee_heading", frame )
    title:SetFont( HEADER_FONT )
    title:SetText( "NOMINATE A MISERY..." )
    title:Dock( TOP )
    title:DockMargin( 0, 0, pad, gap ) -- lines the slot count up with the rows' values
    title:SetTooltip( "Nominate a misery,\nit will appear in the next Misery vote. (rtm)" )

    local slots = vgui.Create( "glee_panel", title )
    slots:SetPaintBackground( false )
    slots:SetFont( HEADER_FONT )
    slots:SetTextAlign( TEXT_ALIGN_RIGHT )
    slots:SetContentColor( "text" )
    slots:SetText( "0/0" )
    slots:AutoSize()
    slots:Dock( RIGHT )
    slots:SetMouseInputEnabled( true ) -- glee_panels start deaf to the mouse, which hides tooltips
    slots:SetTooltip( "Nominations made, out of the places on the next Misery vote's ballot." )

    -- refresh is defined below, and the search can't be typed in before then
    local filter = ""
    local refresh

    local search = vgui.Create( "glee_textentry", title )
    search:SetPlaceholder( SEARCH_PLACEHOLDER )
    search:SetWide( style:Scaled( SEARCH_WIDTH_1080P ) )
    search:Dock( RIGHT )
    search:DockMargin( 0, 0, gap, 0 )
    search:SetTooltip( "Search for a specific Misery's name.\nUnknown Miseries are not searchable..." )

    function search:OnChange( text )
        filter = string.lower( string.Trim( text ) )
        refresh()

    end

    function search:OnHudStyleChanged()
        vgui.GetControlTable( "glee_textentry" ).OnHudStyleChanged( self )
        self:SetWide( self:Style():Scaled( SEARCH_WIDTH_1080P ) )

    end

    -- so a narrow list can't squeeze the search over the heading
    function title:GetContentWidth()
        return vgui.GetControlTable( "glee_heading" ).GetContentWidth( self ) + gap + search:GetWide() + gap + slots:GetWide()

    end

    local scroll = vgui.Create( "glee_scrollpanel", frame )
    scroll:Dock( FILL )

    local rows = {}
    for setName, _ in pairs( GAMEMODE:GetSpawnSets() ) do
        -- unless it's what your suspended nomination is waiting on, which needs a row to be withdrawn from
        if setName == GAMEMODE:GetSpawnSetName() and not myNominationOf( setName ) then continue end

        local row = makeRow( frame, scroll, setName )
        row:Dock( TOP )
        row:DockMargin( 0, 0, pad, gap ) -- the right margin keeps it off the scroll bar
        table.insert( rows, row )

    end

    -- sorted once every multiplier is in, so rows don't jump around while they arrive
    local sorted = false

    local function sortRows()
        table.sort( rows, cheapestFirst )
        for index, row in ipairs( rows ) do
            row:SetZPos( index )

        end
    end

    -- by the label shown, so an unseen misery's name can't be found by searching for it
    local function matchesFilter( row )
        if filter == "" then return true end
        return string.find( string.lower( rowLabel( row.setName ) ), filter, 1, true ) ~= nil

    end

    function refresh()
        -- the server drops requests closer than half a second apart, like one right after the
        -- scoreboard's, so this keeps asking. Cached multipliers aren't asked for again
        local toRequest = {}
        local allKnown = true
        for _, row in ipairs( rows ) do
            table.insert( toRequest, { isSpawnset = true, key = row.setName } )
            allKnown = allKnown and knownMultiplier( row.setName ) ~= nil

        end
        GAMEMODE:RequestEscapeMultipliers( toRequest )

        if allKnown and not sorted then
            sorted = true
            sortRows()

        end

        local slotText = slotsText()
        if slots.shownText ~= slotText then
            slots.shownText = slotText
            slots:SetText( slotText )

            -- blank, it would still hold its width, leaving a gap right of the search
            local hasSlots = slotText ~= ""
            slots:SetVisible( hasSlots )
            search:DockMargin( 0, 0, hasSlots and gap or 0, 0 )
            title:InvalidateLayout()

        end

        -- labels change as miseries are seen, so this runs every refresh, not only on typing
        local shownChanged = false
        for _, row in ipairs( rows ) do
            local shown = matchesFilter( row )
            if row:IsVisible() ~= shown then
                row:SetVisible( shown )
                shownChanged = true

            end
        end

        if shownChanged then
            scroll:GetCanvas():InvalidateLayout()
            scroll:InvalidateLayout()

        end

        for _, row in ipairs( rows ) do
            local allowed, reason
            if isMine( row ) then
                allowed, reason = GAMEMODE:CanWithdrawMiseryNomination( me )

            else
                allowed, reason = GAMEMODE:CanNominateMisery( me, row.setName )

            end
            row:SetDisabled( not allowed )

            local tooltip = rowTooltip( row.setName, reason )
            if tooltip ~= row.shownTooltip then
                row.shownTooltip = tooltip
                row:SetTooltip( tooltip )

            end
        end
    end

    local nextRefresh = 0

    -- on the title, a glee_frame given its own Think stops shaking
    function title:Think()
        if nextRefresh > RealTime() then return end
        nextRefresh = RealTime() + REFRESH_INTERVAL

        refresh()

    end

    -- labels and every column's width are fixed from here, so the frame is sized once
    sortRows()
    refresh()
    frame:SizeToContents( math.min( style:Scaled( MAX_HEIGHT_1080P ), ScrH() * 0.9 ) )
    frame:Center()

    terminator_Extras.easyClosePanel( frame )

    me:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 160, 0.45 )

    return frame

end

concommand.Add( "glee_miserynominations_open", function()
    local newFrame = openMiseryNominations()
    if not IsValid( newFrame ) then return end

    if IsValid( GAMEMODE.glee_MiseryNominations_Holder ) then
        GAMEMODE.glee_MiseryNominations_Holder:Remove()

    end

    GAMEMODE.glee_MiseryNominations_Holder = newFrame

    function newFrame:OnRemove()
        if GAMEMODE.glee_MiseryNominations_Holder ~= self then return end
        GAMEMODE.glee_MiseryNominations_Holder = nil

    end
end )

-- an open window keeps running the functions it was built from, so an autorefresh rebuilds it
if IsValid( GAMEMODE and GAMEMODE.glee_MiseryNominations_Holder ) then
    RunConsoleCommand( "glee_miserynominations_open" )

end

-- the spawnmenu icon's own window, which init throws away for the real one
local width, height = glee_sizeScaled( 520, 500 )
GM:DoGatedDesktopIcon( "HuntersGlee_MiseryNominations", {
    title = "Misery Nominations",
    icon = "icon16/flag_red.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        if IsValid( window ) then window:Remove() end
        RunConsoleCommand( "glee_miserynominations_open" )

    end
}, {
    -- sv_banking syncs bank items as NW2 bools, see cl_banking
    nw2Vars = { "Glee_BankItem_" .. GM.MiseryNominationBankItem },
    canShow = function( me )
        return me:HasBankItem( GAMEMODE.MiseryNominationBankItem )

    end,
} )
