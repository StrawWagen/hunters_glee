--[[
    glee_guiltchecker — extends glee_panel

    The persistent guilt readout, laid out like the HL2 suit cluster: the skull
    sits to the LEFT of a column holding the day count and the evil meter. The
    tier's description sits under the whole cluster.

    Every element inside is a glee_hudbox ( glee_meter is one too ). This panel
    paints nothing itself; whatever frame holds it draws the background behind it.
    The "you are evil" throb is those boxes' own URGENT state.

    It picks its own width, and its height follows from that width, so a glee_frame's
    SizeToContents fits it. Inside, sizes only ever flow inwards, which is the direction
    VGUI already works in: the description fills whatever the cluster leaves behind.

    Dock tree:
        self                  Dock FILL, DockPadding( pad )
        +- cluster            Dock TOP   ( height set in PerformLayout )
        |  +- skull           Dock LEFT
        |  +- column          Dock FILL
        |     +- days         Dock TOP
        |     +- meter        Dock TOP
        +- desc               Dock FILL  ( takes the rest )

    It reads LocalPlayer()'s guilt itself, so callers configure nothing:
        local checker = vgui.Create( "glee_guiltchecker", frame )
        checker:Dock( FILL )
        frame:SizeToContents()
]]

local skullMat = Material( "vgui/hud/deadshopicon.png", "smooth noclamp" )

local WIDTH_1080P      = 460
local METER_CHUNKS     = 20
local METER_BAR_HEIGHT = 12

-- the skull box is squared off to the height of the column beside it, so we have
-- to know its padding ratio to work back from a box height to an icon size
local SKULL_PADDING_RATIO = 0.4

local THROB_SLOWEST = 0.5  -- seconds between blinks the moment they turn evil
local THROB_FASTEST = 0.15 -- ...and once they hit the worst tier


-- The boxes take their own normal and urgent colours from their style. The accent
-- ( skull, day count, description, meter fill ) comes from the guilt tier itself, so
-- recolour tiers in PermaGuiltInfo, sh_guilt.lua.
-- Darker than the box it sits in, so unlit chunks read as recessed
local METER_UNLIT_COLOR = "bgDark"


-- 0 the moment they turn evil, 1 at the worst tier
local function evilFraction( days )
    local levels = GAMEMODE.PermaGuiltLevels

    local firstEvilDay = levels.ALMOST_GUILTY
    local worstDay     = levels.EXTREMELY_GUILTY

    local daysIntoEvil = days - firstEvilDay
    local evilSpan     = worstDay - firstEvilDay

    return math.Clamp( daysIntoEvil / evilSpan, 0, 1 )

end


local PANEL = {}

PANEL.Init = function( self )
    self:SetPaintBackground( false )

    self._lastLevel = nil
    self._lastDays  = nil

    self._cluster = vgui.Create( "glee_panel", self )
    self._cluster:SetPaintBackground( false )
    self._cluster:Dock( TOP )

    self._skull = vgui.Create( "glee_hudbox", self._cluster )
    self._skull:SetPaddingRatio( SKULL_PADDING_RATIO )
    self._skull:SetMaterial( skullMat )
    self._skull:Dock( LEFT )

    self._column = vgui.Create( "glee_panel", self._cluster )
    self._column:SetPaintBackground( false )
    self._column:Dock( FILL )

    self._days = vgui.Create( "glee_hudbox", self._column )
    self._days:SetFont( "mediumLarge" )
    self._days:Dock( TOP )

    self._meter = vgui.Create( "glee_meter", self._column )
    self._meter:SetChunks( METER_CHUNKS )
    self._meter:SetEmptyColor( METER_UNLIT_COLOR )
    self._meter:Dock( TOP )

    self._desc = vgui.Create( "glee_hudbox", self )
    self._desc:SetFont( "small" )
    self._desc:Dock( FILL )

    self._boxes     = { self._skull, self._days, self._meter, self._desc }
    self._throbbers = { self._skull, self._days, self._meter }

    for _, box in ipairs( self._boxes ) do
        box:SetDoFadeDelays( false )

    end

    self:ApplySpacing()
    self:Refresh()

end

-- The gaps come from the style, so a style change redoes them
PANEL.ApplySpacing = function( self )
    local style = self:Style()
    local gap = style:Metric( "laneSpacing" )
    local pad = style:Metric( "blockPadding" )

    self:DockPadding( pad, pad, pad, pad )
    self._skull:DockMargin( 0, 0, gap, 0 )
    self._meter:DockMargin( 0, gap, 0, 0 )
    self._desc:DockMargin( 0, gap, 0, 0 )

end

PANEL.ApplyTier = function( self, tierData )
    self._skull:SetContentColor( tierData.color )
    self._days:SetContentColor( tierData.color )
    self._desc:SetContentColor( tierData.color )
    self._meter:SetFillColor( tierData.color )

    self._desc:SetText( tierData.desc )

    -- a new tier is a new description, which is a new height. whoever owns the
    -- frame has to hear about that, or the new one gets clipped
    if not self.OnLayoutChanged then return end

    self:OnLayoutChanged()

end

PANEL.ApplyDays = function( self, days )
    local dayWord = ( days == 1 ) and " DAY" or " DAYS"
    self._days:SetText( days .. dayWord .. " OF GUILT" )

    local worstDay = GAMEMODE.PermaGuiltLevels.EXTREMELY_GUILTY
    self._meter:SetFill( days / worstDay )

    -- PerformLayout measures the day box, so the text it measures has to be this one
    self:InvalidateLayout()

end

-- Applies whatever the player's guilt has changed to, and returns it.
-- Init calls this too: the first layout pass runs before the first Think, and it
-- measures the day box, so the text has to already be in there by then.
PANEL.Refresh = function( self )
    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    local level, tierData = GAMEMODE:GetPlysGuiltLevel( ply )
    local days = math.Round( GAMEMODE:GetPersistentGuilt( ply ), 2 )

    if level ~= self._lastLevel then
        self._lastLevel = level
        self:ApplyTier( tierData )

    end

    if days ~= self._lastDays then
        self._lastDays = days
        self:ApplyDays( days )

    end

    return level, days

end

PANEL.Think = function( self )
    local level, days = self:Refresh()
    if not level then return end

    -- the description stays steady; it's the guilt itself that throbs
    self._desc:SetState( self._desc.STATE_NORMAL )

    local evil = level >= GAMEMODE.PermaGuiltLevels.ALMOST_GUILTY

    -- only read in URGENT, so it costs nothing to set while they're still innocent
    local throbInterval = Lerp( evilFraction( days ), THROB_SLOWEST, THROB_FASTEST )

    for _, box in ipairs( self._throbbers ) do
        box:SetUrgentInterval( throbInterval )
        box:SetState( evil and box.STATE_URGENT or box.STATE_NORMAL )

    end
end

-- Lays the children out for a panel this wide, and returns the height they came to.
--
-- The frame asks this, through GetContentHeight, BEFORE setting its own height, so the
-- frame is always as tall as the layout actually is. Nothing here may read a position,
-- size self, or touch the frame: it runs from PerformLayout too, which is before the
-- dock pass.
--
-- Sizes come from the fonts and the hud padding, both of which move with the
-- player's ui scale, so no caller may assume a height. Assuming one is what
-- makes the panel come out short and clip the description.
PANEL.LayoutForWidth = function( self, w )
    local style = self:Style()
    local gap = style:Metric( "laneSpacing" )
    local pad = style:Metric( "blockPadding" )

    -- days and meter both know their own height, so the column's is just the sum
    self._days:AutoSize()
    self._meter:SetBarHeight( style:Scaled( METER_BAR_HEIGHT ) )

    local columnH = self._days:GetTall() + gap + self._meter:GetTall()
    self._cluster:SetTall( columnH )

    -- Dock can't express "square the skull off to the column beside it": Dock LEFT
    -- needs a width up front, and that width is the column's height
    self._skull:SetIconSize( columnH / ( 1 + SKULL_PADDING_RATIO ) )

    -- the description is Dock FILL, so the dock pass gives it its height. it is
    -- measured here anyway, because the frame's height is the sum that includes it.
    -- the wrap width is ours, less our DockPadding, less the padding its own box
    -- puts around its text
    self._desc:SetMaxTextWidth( w - pad * 2 - pad * 4 )
    self._desc:AutoSize()

    return pad + columnH + gap + self._desc:GetTall() + pad

end

PANEL.PerformLayout = function( self, w, _h )
    self:LayoutForWidth( w )

end

PANEL.GetContentWidth = function( self )
    return self:Style():Scaled( WIDTH_1080P )

end

-- at whatever width it's been docked to
PANEL.GetContentHeight = function( self )
    return self:LayoutForWidth( self:GetWide() )

end

-- the frame re-fits itself after this, once every box inside has its new font
PANEL.OnHudStyleChanged = function( self )
    self:ApplySpacing()
    self:InvalidateLayout()

end

vgui.Register( "glee_guiltchecker", PANEL, "glee_panel" )
