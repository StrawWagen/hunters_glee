--[[
    glee_consentform — extends glee_panel

    A title, a scrolling wall of terms, then a line to sign and a decline row. Nobody has
    to read the terms to sign, nobody will.

    Signing calls OnAgree at once, then slams a stamp onto the signature, rattling the
    form's glee_frame. OnStamped follows once the stamp has sat a moment. The form takes
    no more clicks after signing.

    SetCheck's function is asked whether signing would go through, a few times a second
    and again the moment it's signed. While it says no, the line can't be signed and its
    reason sits above it.

    Paints nothing, its frame does. Its height counts every line of the terms, so give the
    frame's SizeToContents a max height.

        local form = vgui.Create( "glee_consentform", frame )
        form:SetTitle( "TERMS AND CONDITIONS" )
        form:SetSigner( LocalPlayer():Nick() )
        form:SetCheck( function() return true end ) -- or false, "why not"
        form:SetSections( { { heading = "1. DEFINITIONS", body = "..." } } )
        form:Dock( FILL )
        function form:OnAgree() end
        function form:OnStamped() end
        function form:OnDecline() end
        frame:SizeToContents( maxHeight )
]]

local WIDTH_1080P = 720 -- the settings menu's

local TITLE_FONT   = "mediumLarge" -- font roles, the style picks them
local HEADING_FONT = "medium"
local BODY_FONT    = "small"

local STAMP_INK    = Material( "vgui/hud/deadshopicon_transparent.png", "smooth mips" )
local STAMP_ALONG  = 0.7 -- where across the signature it lands, 0 at the X, 1 at the line's end
local STAMP_LINGER = 1.2 -- seconds the stamp sits after landing, before OnStamped

local SHAKE_STRENGTH_1080P = 10
local SHAKE_DURATION       = 0.35

local CASH_REGISTER = "hunters_glee/209578_zott820_cash-register-purchase.wav"

local CHECK_INTERVAL = 0.25 -- seconds between asking the check
local REFUSAL_FONT   = "small"
local REFUSAL_COLOR  = "alert"


local PANEL = {}

PANEL.Init = function( self )
    self:SetPaintBackground( false )
    self:SetMouseInputEnabled( true ) -- glee_panel's default, off, cuts off every child too

    self._bodies    = {}
    self._headings  = {}
    self._wrapWidth = nil

    self._check       = nil
    self._nextCheckAt = 0
    self._refusal     = nil -- the check's last reason, nil while it says yes

    self._title = vgui.Create( "glee_heading", self )
    self._title:SetFont( TITLE_FONT )
    self._title:Dock( TOP )

    -- BOTTOM docks stack upward in creation order, so decline is made first to sit lowest
    self._decline = vgui.Create( "glee_button", self )
    self._decline:SetLabel( "I DO NOT AGREE" )
    self._decline:Dock( BOTTOM )
    self._decline.DoClick = function() self:OnDecline() end

    self._signature = vgui.Create( "glee_signature", self )
    self._signature:SetTooltip( "By signing this you confirm that you can, in fact read.\nAnd have read, specifically, this document." )
    self._signature:Dock( BOTTOM )
    self._signature.OnSigned = function() self:Sign() end

    self._refusalLine = vgui.Create( "glee_panel", self )
    self._refusalLine:SetPaintBackground( false )
    self._refusalLine:SetFont( REFUSAL_FONT )
    self._refusalLine:SetTextAlign( TEXT_ALIGN_LEFT )
    self._refusalLine:SetContentColor( REFUSAL_COLOR )
    self._refusalLine:Dock( BOTTOM )
    self._refusalLine:SetVisible( false )

    self._scroll = vgui.Create( "glee_scrollpanel", self )
    self._scroll:Dock( FILL )

    self:ApplySpacing()

end

-- stubs
PANEL.OnAgree = function( _self )
end

PANEL.OnStamped = function( _self )
end

PANEL.OnDecline = function( _self )
end

PANEL.SetTitle = function( self, title )
    self._title:SetText( title )

end

PANEL.SetSigner = function( self, name )
    self._signature:SetSigner( name )

end

-- check returns true, or false and a reason. nil never refuses
PANEL.SetCheck = function( self, check )
    self._check = check
    self:RunCheck()

end

-- Asks the check now, and locks or unlocks the signature on its answer. True if it allows signing
PANEL.RunCheck = function( self )
    self._nextCheckAt = RealTime() + CHECK_INTERVAL

    local allowed, reason = true, nil
    if self._check then
        allowed, reason = self._check()

    end

    self:SetRefusal( not allowed and ( reason or "" ) or nil )
    return allowed == true

end

-- reason is shown above the signature, which can't be signed while there is one
PANEL.SetRefusal = function( self, reason )
    if reason == self._refusal then return end

    self._refusal = reason
    self._signature:SetDisabled( reason ~= nil )

    self._refusalLine:SetVisible( reason ~= nil )
    self._refusalLine:SetText( reason or "" )

    self._wrapWidth = nil -- the line has to wrap, and the form re-dock, around the new text
    self:InvalidateLayout()

end

-- The signature calls this once it's written out
PANEL.Sign = function( self )
    if IsValid( self._stamp ) then return end

    -- the reason changed since the last check, like the hunt ending mid-signature
    if not self:RunCheck() then
        self._signature:Unsign()
        return

    end

    self:SetMouseInputEnabled( false )
    self:OnAgree()

    local signature = self._signature
    local stampX = signature:GetX() + signature:GetContentWidth() * STAMP_ALONG
    local stampY = signature:GetY() + signature:GetTall() * 0.5

    local stamp = vgui.Create( "glee_stamp", self )
    stamp:SetInk( STAMP_INK )
    stamp.OnImpact = function() self:StampLanded() end
    stamp:Slam( stampX, stampY )
    self._stamp = stamp

    terminator_Extras.glee_Style( "god", self:Style().scaleName ):PlaySound( "arrival", 90, nil, 0.4 )

end

PANEL.StampLanded = function( self )
    self._stampLandedAt = RealTime()

    terminator_Extras.glee_Style( "god", self:Style().scaleName ):PlaySound( "landing", 60, nil, 1 )
    LocalPlayer():EmitSound( CASH_REGISTER, 75, 60, 0.6 )

    -- only a glee_frame can shake, a form docked into anything else just doesn't
    local frame = self:GetParent()
    if IsValid( frame ) and frame.Shake then
        frame:Shake( self:Style():Scaled( SHAKE_STRENGTH_1080P ), SHAKE_DURATION )

    end
end

-- sections: { { heading = "1. DEFINITIONS", body = "..." }, ... }. Bodies wrap, and keep
-- their own newlines. Replaces any terms already set
PANEL.SetSections = function( self, sections )
    self._scroll:Clear()
    self._bodies    = {}
    self._headings  = {}
    self._wrapWidth = nil

    for _, section in ipairs( sections ) do
        local heading = vgui.Create( "glee_heading", self._scroll )
        heading:SetFont( HEADING_FONT )
        heading:SetText( section.heading )
        heading:Dock( TOP )
        table.insert( self._headings, heading )

        local body = vgui.Create( "glee_panel", self._scroll )
        body:SetFont( BODY_FONT )
        body:SetTextAlign( TEXT_ALIGN_LEFT )
        body:SetContentColor( "text" )
        body:SetText( section.body )
        body:Dock( TOP )
        table.insert( self._bodies, body )

    end

    self:ApplySpacing()
    self:InvalidateLayout()

end

-- The gaps come from the style, so a style change redoes them
PANEL.ApplySpacing = function( self )
    local style = self:Style()
    local pad = style:Metric( "blockPadding" )
    local gap = style:Metric( "laneSpacing" )

    self:DockPadding( pad, pad, pad, pad )
    self._title:DockMargin( 0, 0, 0, gap )
    self._refusalLine:DockMargin( 0, gap, 0, 0 )
    self._signature:DockMargin( 0, gap * 2, 0, 0 )
    self._decline:DockMargin( 0, gap, 0, 0 )

    -- the right margin keeps the terms off the scroll bar
    for index, heading in ipairs( self._headings ) do
        local topGap = index > 1 and gap * 3 or 0
        heading:DockMargin( 0, topGap, pad, gap )

    end

    for _, body in ipairs( self._bodies ) do
        body:DockMargin( 0, 0, pad, 0 )

    end
end

-- Wraps the terms, the signature and the refusal to this width and returns the height of
-- everything, all the terms included. Runs from PerformLayout, before the dock pass, so it
-- mustn't read positions or size anything but those
PANEL.LayoutForWidth = function( self, w )
    local style = self:Style()
    local pad = style:Metric( "blockPadding" )
    local gap = style:Metric( "laneSpacing" )

    -- less our padding, the bar and its gap, and the body's pad * 2 either side of its text
    local wrapWidth = w - pad * 2 - self._scroll:GetVBar():GetWide() - pad - pad * 4

    -- every body rewraps on a new width, and a layout pass happens far more often than that
    if wrapWidth ~= self._wrapWidth then
        self._wrapWidth = wrapWidth

        for _, body in ipairs( self._bodies ) do
            body:SetMaxTextWidth( wrapWidth )
            body:AutoSize()

        end

        self._signature:SetMaxWidth( w - pad * 2 ) -- less our padding

        -- less our padding, and the line's pad * 2 either side of its text
        self._refusalLine:SetMaxTextWidth( w - pad * 2 - pad * 4 )
        self._refusalLine:AutoSize()
    end

    local termsHeight = self._scroll:GetContentHeight()
    local rowsHeight = gap * 2 + self._signature:GetTall() + gap + self._decline:GetTall()
    if self._refusal then
        rowsHeight = rowsHeight + gap + self._refusalLine:GetTall()

    end

    return pad + self._title:GetTall() + gap + termsHeight + rowsHeight + pad

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

-- a new font is a new wrap, see LayoutForWidth
PANEL.OnHudStyleChanged = function( self )
    self._wrapWidth = nil
    self:ApplySpacing()
    self:InvalidateLayout()

end

PANEL.Think = function( self )
    if not self._stamp then
        if RealTime() >= self._nextCheckAt then self:RunCheck() end
        return

    end

    if not self._stampLandedAt or self._stampFinished then return end
    if RealTime() < self._stampLandedAt + STAMP_LINGER then return end

    self._stampFinished = true
    self:OnStamped()

end

vgui.Register( "glee_consentform", PANEL, "glee_panel" )
