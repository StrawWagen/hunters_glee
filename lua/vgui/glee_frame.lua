--[[
    glee_frame — extends DFrame

    A DFrame with derma's window furniture turned off and its style's backdrop in its
    place, so a menu built out of glee panels sits on a matching background.

    DFrame's Init leaves DockPadding( 5, 29, 5, 5 ) behind for a title bar this doesn't
    have. This replaces it with blockPadding, again on every style change.

    easyClosePanel is left to the caller: it wraps whatever Think the frame has when it
    runs, so call it after assigning your own, never before.

    Build its contents docked inside it, then let it size itself around them. After a
    style change it sizes itself again, once its contents have caught up.

        local frame = vgui.Create( "glee_frame" )
        local row = vgui.Create( "glee_row", frame )
        row:Dock( TOP )
        frame:SizeToContents()
        frame:Center()
        terminator_Extras.easyClosePanel( frame )
]]

local PANEL = {}

-- vgui runs every Init in the chain, base first. Calling DFrame's again from here builds
-- a second set of title bar furniture, and only the set the accessors point at is hidden.
PANEL.Init = function( self )
    self:SetTitle( "" )
    self:ShowCloseButton( false )
    self:SetDraggable( false )
    self:MakePopup()

    self._backdrop    = "bgDark"
    self._padContents = true

    self:ApplyPadding()

end

-- see glee_hud/cl_stylecontext.lua
PANEL.Style = function( self )
    return terminator_Extras.glee_PanelStyle( self )

end

-- False for contents that bring their own padding
PANEL.SetPadContents = function( self, padContents )
    self._padContents = padContents
    self:ApplyPadding()

end

PANEL.ApplyPadding = function( self )
    local pad = 0
    if self._padContents then
        pad = self:Style():Metric( "blockPadding" )

    end

    self:DockPadding( pad, pad, pad, pad )

end

PANEL.OnHudStyleChanged = PANEL.ApplyPadding

--[[---------------------------------------------------------
    frame:SizeToContents
    As wide as its widest docked child wants, then as tall as they stack at that width.
    Keeps its centre where it was, so call Center after the first one.
    @param maxHeight: Stops growing here, for contents in a scroll panel. Optional.
    @return: None
--]]---------------------------------------------------------
PANEL.SizeToContents = function( self, maxHeight )
    self:StopShaking() -- it keeps its centre, which mustn't be a shaken one
    self._sizesToContents  = true
    self._maxContentHeight = maxHeight

    local centerX, centerY = self:GetX() + self:GetWide() * 0.5, self:GetY() + self:GetTall() * 0.5
    local left, top, right, bottom = self:GetDockPadding()

    local contentW = terminator_Extras.glee_DockedContentSize( self )
    self:SetWide( contentW + left + right )

    -- docks the children to that width now, since what they wrap to depends on it
    self:InvalidateLayout( true )

    local _, contentH = terminator_Extras.glee_DockedContentSize( self )
    local height = contentH + top + bottom
    if maxHeight then
        height = math.min( height, maxHeight )

    end

    self:SetTall( height )
    self:SetPos( centerX - self:GetWide() * 0.5, centerY - height * 0.5 )

end


-- Shaking -------------------------------------------------------------------

--[[---------------------------------------------------------
    frame:Shake
    Rattles the frame around where it is, dying away over duration. A shake started
    mid-shake replaces it, still around the original spot. Runs from the frame's Think,
    so a frame given its own Think doesn't shake.
    @param strength: Furthest it's thrown at the start, in pixels.
    @param duration: Seconds until it's still again.
    @return: None
--]]---------------------------------------------------------
PANEL.Shake = function( self, strength, duration )
    if not self._shakeOriginX then
        self._shakeOriginX, self._shakeOriginY = self:GetPos()

    end

    self._shakeStrength = strength
    self._shakeDuration = duration
    self._shakeStartAt  = RealTime()

end

-- Puts it back where it was shaken from. Safe when it isn't shaking
PANEL.StopShaking = function( self )
    if not self._shakeOriginX then return end

    self:SetPos( self._shakeOriginX, self._shakeOriginY )
    self._shakeOriginX, self._shakeOriginY = nil, nil

end

PANEL.Think = function( self )
    vgui.GetControlTable( "DFrame" ).Think( self )

    if not self._shakeOriginX then return end

    local progress = ( RealTime() - self._shakeStartAt ) / self._shakeDuration
    if progress >= 1 then
        self:StopShaking()
        return

    end

    local reach = self._shakeStrength * ( 1 - progress ) ^ 2
    self:SetPos(
        self._shakeOriginX + math.Rand( -reach, reach ),
        self._shakeOriginY + math.Rand( -reach, reach )
    )
end

PANEL.AfterHudStyleChanged = function( self )
    if not self._sizesToContents then return end

    self:SizeToContents( self._maxContentHeight )

end

PANEL.Paint = function( self, w, h )
    self:Style():Background( 0, 0, w, h, self._backdrop, nil, 1, "idle", self )

end

vgui.Register( "glee_frame", PANEL, "DFrame" )
