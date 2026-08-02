--[[
    glee_guiltchecker — extends glee_hl2layoutpanel

    The persistent guilt readout, laid out like the HL2 suit cluster: the skull
    sits to the LEFT of a column holding the day count and the evil meter. The
    tier's description sits under the whole cluster.

    Every element inside is a glee_hl2hudbox ( glee_hl2meter is one too ). This panel
    paints nothing itself; whatever frame holds it draws the background behind it.
    The "you are evil" throb is those boxes' own URGENT state.

    Nothing here sizes itself. The frame is a fixed size, this fills it, and the
    description fills whatever the cluster leaves behind. Sizes only ever flow
    inwards, which is the direction VGUI already works in.

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
]]

local skullMat = Material( "vgui/hud/deadshopicon.png", "smooth noclamp" )

local METER_CHUNKS     = 20
local METER_BAR_HEIGHT = 12

-- the skull box is squared off to the height of the column beside it, so we have
-- to know its padding ratio to work back from a box height to an icon size
local SKULL_PADDING_RATIO = 0.4

local THROB_SLOWEST = 0.5  -- seconds between blinks the moment they turn evil
local THROB_FASTEST = 0.15 -- ...and once they hit the worst tier


-- The boxes take their own normal and urgent colours from the palette. The accent
-- ( skull, day count, description, meter fill ) comes from the guilt tier itself, so
-- recolour tiers in PermaGuiltInfo, sh_guilt.lua.
-- Only the meter needs a colour of its own, and it can't be read at file load because
-- the HL2 palette doesn't exist yet.
local function meterUnlitColor()
    -- darker than the box it sits in, so unlit chunks read as recessed
    return terminator_Extras.glee_HL2Hud.colorBackgroundDark

end


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
    self.BaseClass.Init( self )

    local hud = terminator_Extras.glee_HL2Hud
    local gap = hud.laneSpacing
    local pad = hud.blockPadding

    self:DockPadding( pad, pad, pad, pad )

    self._lastLevel = nil
    self._lastDays  = nil

    self._cluster = vgui.Create( "glee_hl2layoutpanel", self )
    self._cluster:Dock( TOP )

    self._skull = vgui.Create( "glee_hl2hudbox", self._cluster )
    self._skull:SetPaddingRatio( SKULL_PADDING_RATIO )
    self._skull:SetMaterial( skullMat )
    self._skull:Dock( LEFT )
    self._skull:DockMargin( 0, 0, gap, 0 )

    self._column = vgui.Create( "glee_hl2layoutpanel", self._cluster )
    self._column:Dock( FILL )

    self._days = vgui.Create( "glee_hl2hudbox", self._column )
    self._days:SetIconFont( "glee_mediumLargeHL2Font" )
    self._days:Dock( TOP )

    self._meter = vgui.Create( "glee_hl2meter", self._column )
    self._meter:SetChunks( METER_CHUNKS )
    self._meter:SetEmptyColor( meterUnlitColor() )
    self._meter:Dock( TOP )
    self._meter:DockMargin( 0, gap, 0, 0 )

    self._desc = vgui.Create( "glee_hl2hudbox", self )
    self._desc:SetIconFont( "glee_smallHL2Font" )
    self._desc:Dock( FILL )
    self._desc:DockMargin( 0, gap, 0, 0 )

    self._boxes     = { self._skull, self._days, self._meter, self._desc }
    self._throbbers = { self._skull, self._days, self._meter }

    for _, box in ipairs( self._boxes ) do
        box:SetDoFadeDelays( false )

    end

    self:Refresh()

end

PANEL.ApplyTier = function( self, tierData )
    self._skull:SetIconColor( tierData.color )
    self._days:SetIconColor( tierData.color )
    self._desc:SetIconColor( tierData.color )
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
-- Callers who own the frame ask this BEFORE sizing it, so the frame is always as
-- tall as the layout actually is. Nothing here may read a position, size self, or
-- touch the frame: it runs from PerformLayout too, which is before the dock pass.
--
-- Sizes come from the fonts and the hud padding, both of which move with the
-- player's ui scale, so no caller may assume a height. Assuming one is what
-- makes the panel come out short and clip the description.
PANEL.LayoutForWidth = function( self, w )
    local hud = terminator_Extras.glee_HL2Hud
    local gap = hud.laneSpacing
    local pad = hud.blockPadding

    -- days and meter both know their own height, so the column's is just the sum
    self._days:AutoSize()
    self._meter:SetBarHeight( glee_sizeScaled( nil, METER_BAR_HEIGHT ) )

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

vgui.Register( "glee_guiltchecker", PANEL, "glee_hl2layoutpanel" )
