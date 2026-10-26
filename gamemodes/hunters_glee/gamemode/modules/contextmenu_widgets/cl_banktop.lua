
-- The bank leaderboard. Every account is a tile of its owner's playermodel, richest first,
-- on a carousel you drag or scroll to fling around

local TITLE              = "HIGHEST BANK BALANCES"
local HEADER_FONT        = "mediumLarge"
local DETAIL_FONT        = "small"
local TILE_FONT          = "small"
local MESSAGE_FONT       = "medium"
local SEARCH_WIDTH_1080P = 200
local SEARCH_PLACEHOLDER = "Search..."
local REFRESH_INTERVAL   = 0.25

local TILE_1080P       = 120
local TILES_ACROSS     = 7 -- before it has to scroll, sizes the window
local TILE_GAP_RATIO   = 0.2 -- of a tile, as are the next two
local ICON_INSET_RATIO = 0.08
local MEDAL_RATIO      = 22 / 120
local FIRST_MEDAL_MUL  = 1.25
local MEDAL_ROTATION   = -18
local HOVER_SCALE      = 1.18
local HOVER_LERP_SPEED = 10
local YOU_BOUNCE_1080P = 2

-- the sizes SpawnIcon's own resize menu offers, so the rendered icons are shared with it
local ICON_RESOLUTIONS = { 64, 128, 256, 512 }

local WHEEL_IMPULSE_TILES = 10
local FRICTION            = 8000 -- px/s shed every second
local SPRING_STRENGTH     = 28 -- pulls it back when flung past an end
local OVERSHOOT_1080P     = 50 -- furthest past an end it can be flung

local SLIDE_SOUND            = "physics/concrete/concrete_scrape_smooth_loop1.wav"
local SLIDE_FULL_SPEED_TILES = 30 -- tiles a second, where the scrape is loudest
local SLIDE_VOLUME           = 0.5
local SLIDE_PITCH_BASE       = 85
local SLIDE_PITCH_SPAN       = 25

local skullMat = Material( "vgui/hud/deadshopicon.png", "smooth noclamp" )
local medalMats = {
    Material( "icon16/award_star_gold_1.png", "smooth" ),
    Material( "icon16/award_star_silver_1.png", "smooth" ),
    Material( "icon16/award_star_bronze_3.png", "smooth" ),
}

-- nil when the leaderboard can be shown
local function blockReason()
    local me = LocalPlayer()
    local roundActive = GAMEMODE.RoundState and GAMEMODE:RoundState() == GAMEMODE.ROUND_ACTIVE
    if roundActive and me:Alive() then
        return "Focus on the hunt, you could be killed at any time.\nOnly the dead have time for banking."

    end
end

local function formatFunds( n )
    local s = tostring( math.floor( n + 0.5 ) )
    local k
    repeat
        s, k = s:gsub( "^(-?%d+)(%d%d%d)", "%1,%2" )
    until k == 0
    return s

end

local function lossText( funds )
    local minFunds = GAMEMODE:GetBankMinFunds()
    if minFunds > 0 and funds < minFunds then return "This account is about to close!" end

    local days = math.Round( GAMEMODE:GetBankChargePeriod() / 86400, 1 )
    local dayWord = days > 1 and " days" or " day"
    local loss = funds * GAMEMODE:GetBankChargePerPeriod() / 100

    return "Losing " .. formatFunds( loss ) .. " score every " .. days .. dayWord .. "!"

end

local function tileMetrics( panel )
    local tileSize = panel:Style():Scaled( TILE_1080P )
    return tileSize, math.floor( tileSize * TILE_GAP_RATIO )

end


-- Tiles ---------------------------------------------------------------------

local function isHovered( tile )
    return tile.carousel.hovered == tile

end

-- SpawnIcon picks its icon's resolution when it's given the model, and only stretches it after
local function renderIcon( tile )
    local tileSize = tileMetrics( tile )
    local biggest = tileSize * HOVER_SCALE * ( 1 - ICON_INSET_RATIO * 2 )

    local resolution = ICON_RESOLUTIONS[#ICON_RESOLUTIONS]
    for _, candidate in ipairs( ICON_RESOLUTIONS ) do
        if candidate >= biggest then
            resolution = candidate
            break

        end
    end

    tile.icon:SetSize( resolution, resolution )
    tile.icon:SetModel( tile.entry.modelPath )
    tile:InvalidateLayout()

end

local function makeTile( carousel, entry )
    local tile = vgui.Create( "glee_panel", carousel )
    tile.carousel   = carousel
    tile.entry      = entry
    tile.hoverScale = 1

    -- one the viewer doesn't have, like an unsubscribed workshop model, would draw as an ERROR
    if entry.modelPath and util.IsValidModel( entry.modelPath ) then
        tile.icon = vgui.Create( "SpawnIcon", tile )
        tile.icon:SetMouseInputEnabled( false ) -- the carousel takes every press, for dragging
        renderIcon( tile )

    end

    function tile:OnHudStyleChanged()
        if not self.icon then return end
        renderIcon( self )

    end

    function tile:PerformLayout( w, h )
        if not self.icon then return end

        local inset = math.floor( w * ICON_INSET_RATIO )
        self.icon:SetPos( inset, inset )
        self.icon:SetSize( w - inset * 2, h - inset * 2 )

    end

    function tile:GetVisualState()
        if isHovered( self ) then return "hovered" end
        if self.entry.isMine then return "chosen" end
        return "idle"

    end

    function tile:GetContentColor()
        if isHovered( self ) then return "hovered" end
        if self.entry.isMine then return "chosen" end
        return "text"

    end

    function tile:PaintContent( w, h, contentColor )
        if self.icon then return end

        local inset = math.floor( w * ICON_INSET_RATIO )
        surface.SetDrawColor( contentColor )
        surface.SetMaterial( skullMat )
        surface.DrawTexturedRect( inset, inset, w - inset * 2, h - inset * 2 )

    end

    -- over the SpawnIcon, which paints after PaintContent
    function tile:PaintOver( w, h )
        local style = self:Style()
        local pad   = style:Metric( "blockPadding" )
        local rank  = self.entry.rank

        local rankText = "#" .. rank
        local rankW, rankH = style:Measure( rankText, TILE_FONT )
        style:Draw( rankText, TILE_FONT, w - pad - rankW, h - pad - rankH, self:GetContentColor(), false )

        local medal = medalMats[rank]
        if medal then
            local size = math.floor( w * MEDAL_RATIO )
            if rank == 1 then
                size = math.floor( size * FIRST_MEDAL_MUL )

            end
            surface.SetDrawColor( 255, 255, 255, 255 )
            surface.SetMaterial( medal )
            surface.DrawTexturedRectRotated( size * 0.6, h - size * 0.6, size, size, MEDAL_ROTATION )

        end

        if self.entry.isMine then
            local bounce = math.sin( RealTime() * 5 + self.carousel.slideSpeed / 25 ) * style:Scaled( YOU_BOUNCE_1080P )
            style:Draw( "You!", TILE_FONT, w * 0.5, pad + bounce, "chosen" )

        end
    end

    return tile

end


-- Carousel ------------------------------------------------------------------

local function stopSlideSound( carousel )
    if not carousel.slidePlaying then return end

    carousel.slideSound:Stop()
    carousel.slidePlaying = false

end

-- loudness is 0 to 1
local function updateSlideSound( carousel, loudness )
    if loudness <= 0 then
        stopSlideSound( carousel )
        return

    end

    if not carousel.slideSound then
        carousel.slideSound = CreateSound( LocalPlayer(), SLIDE_SOUND )

    end

    local volume = loudness * SLIDE_VOLUME
    local pitch  = math.floor( SLIDE_PITCH_BASE + SLIDE_PITCH_SPAN * loudness )
    if carousel.slidePlaying then
        carousel.slideSound:ChangeVolume( volume, 0 )
        carousel.slideSound:ChangePitch( pitch, 0 )

    else
        carousel.slideSound:PlayEx( volume, pitch )
        carousel.slidePlaying = true

    end
end

-- scrollX runs from -halfSpan to halfSpan, 0 is centred
local function coast( carousel, dt, halfSpan, overshoot )
    local velX = carousel.velX
    if velX ~= 0 then
        carousel.scrollX = carousel.scrollX + velX * dt

        local sign = velX > 0 and 1 or -1
        local slowed = velX - sign * FRICTION * dt
        if ( slowed > 0 and 1 or -1 ) ~= sign then
            slowed = 0

        end
        carousel.velX = slowed

    end

    if math.abs( carousel.scrollX ) <= halfSpan then return end

    local target = math.Clamp( carousel.scrollX, -halfSpan, halfSpan )
    carousel.scrollX = math.Clamp( carousel.scrollX, -halfSpan - overshoot, halfSpan + overshoot )
    carousel.velX = carousel.velX + ( target - carousel.scrollX ) * SPRING_STRENGTH * dt
    carousel.velX = carousel.velX * ( 1 - math.min( 0.9, 3 * dt ) )

end

-- Places the shown tiles, growing the one under the cursor. Returns that one
local function layoutTiles( carousel, dt, tileSize, gap, contentW )
    local w, h = carousel:GetSize()
    local mouseX, mouseY = carousel:CursorPos()
    local rowY  = ( h - tileSize ) * 0.5
    local baseX = ( w - contentW ) * 0.5 + carousel.scrollX
    local lerp  = math.min( dt * HOVER_LERP_SPEED, 1 )

    local hovered
    for index, tile in ipairs( carousel.shown ) do
        local slotX = baseX + ( index - 1 ) * ( tileSize + gap )

        -- against the slot, not the grown tile, so the edge of a hover doesn't flicker
        if mouseX >= slotX and mouseX <= slotX + tileSize and mouseY >= rowY and mouseY <= rowY + tileSize then
            hovered = tile

        end

        tile.hoverScale = Lerp( lerp, tile.hoverScale, tile == hovered and HOVER_SCALE or 1 )

        local size   = math.Round( tileSize * tile.hoverScale )
        local offset = ( tileSize - size ) * 0.5
        tile:SetSize( size, size )
        tile:SetPos( slotX + offset, rowY + offset )

    end

    return hovered

end

local function makeCarousel( parent )
    local carousel = vgui.Create( "glee_panel", parent )
    carousel:SetPaintBackground( false )
    carousel:SetMouseInputEnabled( true )

    carousel.tiles        = {} -- every account's, richest first
    carousel.shown        = {} -- the ones the search lets through, richest first
    carousel.loaded       = false
    carousel.filter       = ""
    carousel.hovered      = nil
    carousel.scrollX      = 0
    carousel.velX         = 0
    carousel.snapToStart  = true
    carousel.isDragging   = false
    carousel.dragLastX    = 0
    carousel.dragLastT    = 0
    carousel.lastScrollX  = 0
    carousel.slideSpeed   = 0 -- px a second
    carousel.slideSound   = nil
    carousel.slidePlaying = false

    -- stub, called with the tile now under the cursor, or nil
    function carousel:OnHoveredChanged( _tile )
    end

    function carousel:SetAccounts( accounts )
        for _, tile in ipairs( self.tiles ) do
            tile:Remove()

        end

        local mySteamID = LocalPlayer():SteamID()
        local entries = {}
        for steamID, account in pairs( accounts ) do
            table.insert( entries, {
                ownersName = account.ownersName,
                funds      = account.funds,
                modelPath  = account.modelPath,
                isMine     = steamID == mySteamID,
            } )
        end
        table.sort( entries, function( a, b ) return a.funds > b.funds end )

        self.tiles = {}
        for rank, entry in ipairs( entries ) do
            entry.rank = rank
            table.insert( self.tiles, makeTile( self, entry ) )

        end

        self.loaded = true
        self:ApplyFilter()

    end

    function carousel:SetFilter( text )
        self.filter = string.lower( string.Trim( text ) )
        self:ApplyFilter()

    end

    function carousel:ApplyFilter()
        self.shown = {}
        for _, tile in ipairs( self.tiles ) do
            local shown = self.filter == "" or string.find( string.lower( tile.entry.ownersName ), self.filter, 1, true ) ~= nil
            tile:SetVisible( shown )
            if shown then
                table.insert( self.shown, tile )

            end
        end

        self.snapToStart = true

    end

    -- a hidden panel doesn't Think, so the scrape would loop forever
    function carousel:StopSliding()
        self.velX = 0
        self.isDragging = false
        self:MouseCapture( false )
        stopSlideSound( self )

    end

    carousel.OnRemove = carousel.StopSliding

    function carousel:OnMousePressed( mouseCode )
        if mouseCode ~= MOUSE_LEFT then return end

        self:MouseCapture( true )
        self.isDragging = true
        self.velX = 0
        self.dragLastX = gui.MouseX()
        self.dragLastT = SysTime()
        self:Style():PlaySound( "switch", 60, nil, 0.18, 60 )

    end

    function carousel:OnMouseReleased( mouseCode )
        if mouseCode ~= MOUSE_LEFT then return end

        self:MouseCapture( false )
        self.isDragging = false
        self:Style():PlaySound( "switch", 80, nil, 0.14, 60 )

    end

    function carousel:OnCursorMoved()
        if not self.isDragging then return end

        local now = SysTime()
        local cursorX = gui.MouseX()
        local deltaX = cursorX - self.dragLastX

        self.scrollX = self.scrollX + deltaX
        self.velX = deltaX / math.max( now - self.dragLastT, 0.0001 )
        self.dragLastX = cursorX
        self.dragLastT = now

    end

    function carousel:OnMouseWheeled( delta )
        if self.isDragging then return true end

        local tileSize = tileMetrics( self )
        self.velX = self.velX + delta * tileSize * WHEEL_IMPULSE_TILES
        return true

    end

    function carousel:Think()
        local dt = RealFrameTime()
        local tileSize, gap = tileMetrics( self )
        local contentW = math.max( #self.shown * ( tileSize + gap ) - gap, 0 )
        local halfSpan = math.max( ( contentW - self:GetWide() ) * 0.5, 0 )

        if self.snapToStart and self:GetWide() > 0 then
            self.snapToStart = false
            self.scrollX = halfSpan -- the richest end
            self.velX = 0

        end

        if not self.isDragging then
            coast( self, dt, halfSpan, self:Style():Scaled( OVERSHOOT_1080P ) )

        end

        self.slideSpeed = math.abs( self.scrollX - self.lastScrollX ) / math.max( dt, 0.0001 )
        self.lastScrollX = self.scrollX
        updateSlideSound( self, math.Clamp( self.slideSpeed / ( tileSize * SLIDE_FULL_SPEED_TILES ), 0, 1 ) )

        local hovered = layoutTiles( self, dt, tileSize, gap, contentW )
        if hovered == self.hovered then return end

        self.hovered = hovered
        self:Style():PlaySound( "switch", hovered and 90 or 80, nil, 0.12, 60 )
        self:OnHoveredChanged( hovered )

    end

    function carousel:GetContentWidth()
        local tileSize, gap = tileMetrics( self )
        return TILES_ACROSS * ( tileSize + gap ) - gap

    end

    -- room for a grown tile
    function carousel:GetContentHeight()
        return math.ceil( tileMetrics( self ) * HOVER_SCALE )

    end

    return carousel

end


-- Window --------------------------------------------------------------------

local function openBankTop()
    local me = LocalPlayer()
    if not IsValid( me ) then return end

    local frame = vgui.Create( "glee_frame" )
    local style = frame:Style()
    local gap = style:Metric( "laneSpacing" )

    local title = vgui.Create( "glee_heading", frame )
    title:SetFont( HEADER_FONT )
    title:SetText( TITLE )
    title:Dock( TOP )
    title:DockMargin( 0, 0, 0, gap )
    title:SetMouseInputEnabled( true ) -- glee_panels start deaf to the mouse, which would hide the search from it

    local search = vgui.Create( "glee_textentry", title )
    search:SetPlaceholder( SEARCH_PLACEHOLDER )
    search:SetWide( style:Scaled( SEARCH_WIDTH_1080P ) )
    search:Dock( RIGHT )
    search:SetTooltip( "Search for an account by its owner's name." )

    function search:OnHudStyleChanged()
        vgui.GetControlTable( "glee_textentry" ).OnHudStyleChanged( self )
        self:SetWide( self:Style():Scaled( SEARCH_WIDTH_1080P ) )

    end

    -- so a narrow carousel can't squeeze the search over the heading
    function title:GetContentWidth()
        return vgui.GetControlTable( "glee_heading" ).GetContentWidth( self ) + gap + search:GetWide()

    end

    local detail = vgui.Create( "glee_panel", frame )
    detail:SetPaintBackground( false )
    detail:SetFont( DETAIL_FONT )
    detail:SetTextAlign( TEXT_ALIGN_LEFT )
    detail:SetContentColor( "text" )
    detail:Dock( TOP )
    detail:DockMargin( 0, 0, 0, gap )

    -- two lines whether or not anything's hovered, so the carousel doesn't jump
    function detail:GetContentHeight()
        return draw.GetFontHeight( self:GetResolvedFont() ) * 2 + self:GetTextPadding() * 2

    end

    function detail:OnHudStyleChanged()
        self:SetTall( self:GetContentHeight() )

    end
    detail:OnHudStyleChanged()

    local carousel = makeCarousel( frame )
    carousel:Dock( FILL )

    function carousel:OnHoveredChanged( tile )
        if not tile then
            detail:SetText( "" )
            return

        end

        local entry = tile.entry
        detail:SetText( entry.ownersName .. " - " .. formatFunds( entry.funds ) .. " SCORE\n" .. lossText( entry.funds ) )

    end

    function search:OnChange( text )
        carousel:SetFilter( text )

    end

    -- stands in for the carousel and its detail line
    local message = vgui.Create( "glee_panel", frame )
    message:SetPaintBackground( false )
    message:SetFont( MESSAGE_FONT )
    message:SetContentColor( "text" )
    message:Dock( FILL )
    message:SetVisible( false )

    local function currentMessage()
        local reason = blockReason()
        if reason then return reason end
        if not carousel.loaded then return "Fetching accounts..." end
        if #carousel.shown > 0 then return end
        if carousel.filter ~= "" then return "Nobody by that name banks here." end

        return "Nobody banks here."

    end

    local shownMessage
    local function refresh()
        local text = currentMessage()
        if text == shownMessage then return end
        shownMessage = text

        local hasMessage = text ~= nil
        if hasMessage then
            message:SetText( text )
            carousel:StopSliding()

        end

        message:SetVisible( hasMessage )
        carousel:SetVisible( not hasMessage )
        detail:SetVisible( not hasMessage )
        frame:InvalidateLayout()

    end

    local nextRefresh = 0

    -- on the title, a glee_frame given its own Think stops shaking
    function title:Think()
        if nextRefresh > RealTime() then return end
        nextRefresh = RealTime() + REFRESH_INTERVAL

        refresh()

    end

    -- sized with the carousel in, before a message can stand in for it
    frame:SizeToContents()
    frame:Center()
    refresh()

    local function requestAccounts()
        local asked = GAMEMODE:RequestAllBankAccounts( function( accounts )
            if not IsValid( carousel ) then return end
            carousel:SetAccounts( accounts )

        end )
        if asked then return end

        -- RequestAllBankAccounts asks at most once a second
        timer.Simple( 1.05, function()
            if not IsValid( carousel ) then return end
            requestAccounts()

        end )
    end
    requestAccounts()

    terminator_Extras.easyClosePanel( frame )

    me:EmitSound( "physics/wood/wood_crate_impact_soft3.wav", 50, 200, 0.45 )

    return frame

end

concommand.Add( "glee_banktop_open", function()
    local newFrame = openBankTop()
    if not IsValid( newFrame ) then return end

    if IsValid( GAMEMODE.glee_BankTop_Holder ) then
        GAMEMODE.glee_BankTop_Holder:Remove()

    end

    GAMEMODE.glee_BankTop_Holder = newFrame

    function newFrame:OnRemove()
        if GAMEMODE.glee_BankTop_Holder ~= self then return end
        GAMEMODE.glee_BankTop_Holder = nil

    end
end )

-- an open window keeps running the functions it was built from, so an autorefresh rebuilds it
if IsValid( GAMEMODE and GAMEMODE.glee_BankTop_Holder ) then
    RunConsoleCommand( "glee_banktop_open" )

end

-- the spawnmenu icon's own window, which init throws away for the real one
local width, height = glee_sizeScaled( 1100, 290 )
GM:DoGatedDesktopIcon( "HuntersGlee_BankTop", {
    title = "Bank Leaderboard",
    icon = "icon16/coins.png",
    width = width,
    height = height,
    onewindow = true,
    init = function( _, window )
        if IsValid( window ) then window:Remove() end
        RunConsoleCommand( "glee_banktop_open" )

    end
}, function( me )
    return me:BankHasAccount()

end )
