--[[
    glee_hl2hudplayer

    World-space player name-tag panel. Anchored to the player's feet position
    on screen, offset upward by _headOffset pixels.

    Modes:
        MODE_FULL  (1)  Always visible at full size. Used in dead/spectator view.
        MODE_WORLD (2)  Distance-driven: text fades, panel shrinks to a dot,
                        then fades out entirely.

    Distance thresholds for MODE_WORLD (all configurable via Set* methods, world units):
        SetNameFadeStartDist  text starts fading; bg starts shifting toward player color
        SetNameFadeEndDist    text gone; bg fully player color; panel starts shrinking
        SetFadeStartDist      panel fully a dot; starts fading out entirely
        SetFadeEndDist        panel is invisible

    Per-frame call:
        panel:UpdateForPlayer( ply, cur, infoLine, extraLine, ignoreDist, isLookedAt )

        infoLine   string|nil   Shown always in MODE_FULL. Only shown when isLookedAt in MODE_WORLD.
        extraLine  string|nil   Shown only when isLookedAt is true in either mode.
        ignoreDist bool         If true, distance-based fading is ignored.
        isLookedAt  bool         Controls MODE_WORLD infoLine visibility, extraLine visibility,
                                and "????" name substitution when text has faded.

    Background lerps from hl2hud.colorBackground toward ply:GetPlayerColor() as distance
    increases through the name-fade zone. Text always uses team/state color.
]]


local MODE_FULL  = 1
local MODE_WORLD = 2


local PANEL = {
    MODE_FULL  = 1,
    MODE_WORLD = 2,
}

function PANEL:Init()
    local hud = terminator_Extras.hl2hud

    self._mode = MODE_FULL

    -- Distance thresholds, MODE_WORLD only (world units)
    self._nameFadeStartDist = 575
    self._nameFadeEndDist   = 600
    self._becomeCircleDist  = 625
    self._fadeStartDist     = 1450
    self._fadeEndDist       = 1850

    -- Per-frame content (written by UpdateForPlayer)
    self._name      = ""
    self._infoLine  = nil
    self._extraLine = nil
    self._isLookedAt = false

    -- Background color base (read-only; lerp target is set per-frame)
    self._bgBaseR = hud.colorBackground.r
    self._bgBaseG = hud.colorBackground.g
    self._bgBaseB = hud.colorBackground.b
    self._bgBaseA = hud.colorBackground.a

    -- Background lerp target (set from ply:GetPlayerColor() each frame)
    self._bgTargetR = 255
    self._bgTargetG = 255
    self._bgTargetB = 255

    self._teamColor    = Color( 255, 255, 255, 255 )
    self._cornerRadius = hud.boxCornerRadius
    self._textPad      = glee_sizeScaled( nil, 5 )
    self._dotSize      = glee_sizeScaled( nil, 10 )

    -- Animated state (all computed in UpdateForPlayer, read in Paint)
    self._textAlpha                 = 0
    self._bgColorLerpTransition     = 0
    self._sizeT                     = 0
    self._panelAlpha                = 0

    self._lastAwakeTime = 0 -- last CurTime() when the player was non-dormant; used to delay hiding after dormancy

    -- Reusable color objects (avoid per-frame Color allocation)
    self._drawBg   = Color( 0, 0, 0, 0 )
    self._drawText = Color( 0, 0, 0, 0 )

    self:SetPaintBackground( false )
    self:SetMouseInputEnabled( false )
    self:SetSize( self._dotSize, self._dotSize )
    self:SetVisible( false )

end

function PANEL:SetMode( mode )              self._mode               = mode end
function PANEL:SetNameFadeStartDist( d )    self._nameFadeStartDist   = d    end
function PANEL:SetNameFadeEndDist( d )      self._nameFadeEndDist   = d    end
function PANEL:SetFadeStartDist( d )        self._fadeStartDist     = d    end
function PANEL:SetFadeEndDist( d )          self._fadeEndDist       = d    end
function PANEL:SetBecomeCircleDist( d )     self._becomeCircleDist  = d    end
function PANEL:SetHeadOffset( px )          self._headOffset        = px   end

function PANEL:ComputeShowName()
    return self._textAlpha > 0 and self._name or "????"

end


-- Measures the natural (full) panel size from current content.
-- Must be called inside a valid render context (HUDPaint is fine).
local function computeFullSize( self )
    surface.SetFont( "TargetID" )
    local displayName    = self:ComputeShowName()
    local nameW          = surface.GetTextSize( displayName )
    local nameH          = draw.GetFontHeight( "TargetID" )
    local widestLineW    = nameW
    local extraH         = 0

    if self._infoLine and #self._infoLine > 0 then
        surface.SetFont( "TargetID" )
        local infoLineW = surface.GetTextSize( self._infoLine )
        if infoLineW > widestLineW then widestLineW = infoLineW end
        extraH = extraH + draw.GetFontHeight( "TargetID" )

    end

    if self._extraLine and #self._extraLine > 0 then
        surface.SetFont( "TargetID" )
        local extraLineW = surface.GetTextSize( self._extraLine )
        if extraLineW > widestLineW then widestLineW = extraLineW end
        extraH = extraH + draw.GetFontHeight( "TargetID" )

    end

    local pad = self._textPad
    return widestLineW + pad * 2, nameH + extraH + pad * 2

end


-- Called every frame from the hook. Resolves world position, computes all
-- animated values, and repositions the panel on screen.
function PANEL:UpdateForPlayer( ply, cur, data )
    local posOverride = data.posOverride
    local infoLine = data.infoLine
    local extraLine = data.extraLine
    local ignoreDist = data.ignoreDist
    local isLookedAt = data.isLookedAt

    local pos
    if posOverride then
        pos = posOverride

    -- soul pos, this is networked more frequently than real pos when player is dead
    elseif ply.glee_SoulDisplayPosTime and ply.glee_SoulDisplayPosTime > cur then
        pos = ply.glee_SoulDisplayPos

    else
        pos = ply:WorldSpaceCenter()

    end

    local screenData = pos:ToScreen()
    if not screenData.visible then
        self:SetVisible( false )
        return

    end

    local dist = EyePos():Distance( pos )

    if not ignoreDist then
        if ply:IsDormant() then -- automatically fade out if dormant
            local sinceAwake = cur - self._lastAwakeTime
            dist = dist + sinceAwake * 100

        else
            self._lastAwakeTime = cur

        end

        if dist > self._fadeEndDist then -- too far, dont waste perf
            self:SetVisible( false )
            return

        end
    end

    -- Text color = team/state color (glee_PlayerNameColor mutates its shared Color
    -- objects, so this is valid only until the next call to that function)
    self._teamColor = terminator_Extras.glee_PlayerNameColor( ply, true )

    -- Background lerp target = player body color (Vector 0-1 -> 0-255)
    local plyColorVec   = ply:GetPlayerColor()
    self._bgTargetR     = plyColorVec.x * 255
    self._bgTargetG     = plyColorVec.y * 255
    self._bgTargetB     = plyColorVec.z * 255

    self._name      = ply:Nick()
    self._infoLine  = infoLine
    self._extraLine = extraLine
    self._isLookedAt = isLookedAt
    local nameFadeStartDist = self._nameFadeStartDist
    local nameFadeEndDist   = self._nameFadeEndDist

    if ignoreDist then
        self._textAlpha = 255

    else
        if dist <= nameFadeStartDist then
            self._textAlpha = 255

        elseif dist >= nameFadeEndDist then
            self._textAlpha = 0

        else
            -- Within the fade zone: line-of-sight locks the name at full alpha
            if isLookedAt then
                self._textAlpha = 255

            else
                local nameFadeRange = nameFadeEndDist - nameFadeStartDist
                local nameFadeT     = ( dist - nameFadeStartDist ) / nameFadeRange
                self._textAlpha     = math.floor( 255 * ( 1 - nameFadeT ) )

            end
        end
    end

    -- Bg lerp t is purely distance-based; it doesn't depend on mode.
    -- Dead/spectator panels always stay at 0 (neutral background, no player tint).
    -- Alive panels use the full zone from nameFadeStartDist to becomeCircleDist.
    local bgTransition
    local bgTransitionMax = 0.9

    if ignoreDist then
        bgTransitionMax = 0.5

    end

    local theyDead = ply:Health() <= 0
    if not theyDead then
        if isLookedAt then
            bgTransition = 0

        elseif ignoreDist then -- gradual dropoff from 1 at 0 dist, to 0 at _fadeEndDist
            bgTransition = math.Clamp( 1 - ( dist / self._fadeEndDist ), 0, 1 )

        else
            local bgTransitionRange = self._becomeCircleDist - nameFadeStartDist
            bgTransition = ( dist - nameFadeStartDist ) / bgTransitionRange

        end

    else
        bgTransition = 0.01

    end
    self._bgColorLerpTransition           = math.Clamp( bgTransition, 0.01, bgTransitionMax )

    if self._mode == MODE_FULL then
        self._sizeT      = 0
        self._panelAlpha = 255

    else -- MODE_WORLD
        local fadeStartDist    = self._fadeStartDist
        local fadeEndDist      = self._fadeEndDist
        local becomeCircleDist = self._becomeCircleDist

        -- Size lerp: 0 (full) -> 1 (dot) across name-end to becomeCircleDist
        local shrinkRange = becomeCircleDist - nameFadeEndDist
        if shrinkRange <= 0 then
            self._sizeT = dist >= nameFadeEndDist and 1 or 0

        else
            self._sizeT = math.Clamp( ( dist - nameFadeEndDist ) / shrinkRange, 0, 1 )

        end

        -- Panel alpha: 255 -> 0 across the fade zone
        if ignoreDist then
            self._panelAlpha = 255

        elseif dist <= fadeStartDist then
            self._panelAlpha = 255

        elseif dist >= fadeEndDist then
            self._panelAlpha = 0

        else
            local panelFadeRange = fadeEndDist - fadeStartDist
            local panelFadeT     = ( dist - fadeStartDist ) / panelFadeRange
            self._panelAlpha     = math.floor( 255 * ( 1 - panelFadeT ) )

        end
    end

    if self._panelAlpha <= 0 then
        self:SetVisible( false )
        return

    end

    self:SetVisible( true )

    -- Compute full natural size, then lerp toward dot
    local fullW, fullH = computeFullSize( self )
    local dotSize      = self._dotSize
    local currentW     = math.floor( fullW + ( dotSize - fullW ) * self._sizeT )
    local currentH     = math.floor( fullH + ( dotSize - fullH ) * self._sizeT )
    self:SetSize( currentW, currentH )

    local sx = screenData.x
    local sy = screenData.y
    if sx == 0 and sy == 0 then
        sx = ScrW() * 0.5
        sy = ScrH() * 0.5

    end

    -- sy is the projected world-position Y on screen. The name line sits at sy;
    -- the panel top is one textPad above it, so extra lines hang downward.
    self:SetPos( sx - currentW * 0.5, sy - self._textPad )

end

function PANEL:Paint( w, h )
    local panelAlpha = self._panelAlpha
    if panelAlpha <= 0 then return end

    -- Background: lerp from colorBackground toward ply:GetPlayerColor()
    local bgLerpT = self._bgColorLerpTransition
    local drawBg  = self._drawBg
    drawBg.r = math.floor( self._bgBaseR + ( self._bgTargetR - self._bgBaseR ) * bgLerpT )
    drawBg.g = math.floor( self._bgBaseG + ( self._bgTargetG - self._bgBaseG ) * bgLerpT )
    drawBg.b = math.floor( self._bgBaseB + ( self._bgTargetB - self._bgBaseB ) * bgLerpT )
    local bgAlpha = math.floor( self._bgBaseA + ( 255 - self._bgBaseA ) * bgLerpT )
    drawBg.a = math.floor( bgAlpha * panelAlpha / 255 )

    -- Corner radius lerps from box -> perfect circle as panel shrinks to dot
    local boxCornerRadius    = self._cornerRadius
    local circleCornerRadius = math.floor( math.min( w, h ) * 0.5 )
    local radiusRange        = circleCornerRadius - boxCornerRadius
    local cornerRadius       = math.floor( boxCornerRadius + radiusRange * self._sizeT )

    draw.RoundedBox( cornerRadius, 0, 0, w, h, drawBg )

    -- Don't draw text when the panel is nearly a dot
    if self._sizeT > 0.8 then return end

    local teamColor = self._teamColor
    local drawText  = self._drawText
    local textAlpha = self._textAlpha
    local pad       = self._textPad

    -- Name line: real name when readable, "????" when isLookedAt but too far
    local showName     = textAlpha > 0
    local showQuestion = textAlpha == 0 and self._isLookedAt

    if showName or showQuestion then
        local label = self:ComputeShowName()

        local textFraction  = textAlpha / 255
        local panelFraction = panelAlpha / 255
        local nameAlpha
        if showName then
            nameAlpha = math.floor( teamColor.a * textFraction * panelFraction )

        else
            nameAlpha = math.floor( teamColor.a * panelFraction )

        end

        drawText.r = teamColor.r
        drawText.g = teamColor.g
        drawText.b = teamColor.b
        drawText.a = nameAlpha
        draw.SimpleText( label, "TargetID", w * 0.5, pad, drawText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

    end

    local nameH      = draw.GetFontHeight( "TargetID" )
    local subLineY   = pad + nameH
    local subAlpha   = math.floor( teamColor.a * panelAlpha / 255 )
    drawText.r = teamColor.r
    drawText.g = teamColor.g
    drawText.b = teamColor.b
    drawText.a = subAlpha

    -- infoLine: always in MODE_FULL; only when isLookedAt in MODE_WORLD
    local showInfo = self._mode == MODE_FULL or self._isLookedAt
    if showInfo and self._infoLine and #self._infoLine > 0 then
        draw.SimpleText( self._infoLine, "TargetID", w * 0.5, subLineY, drawText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        subLineY = subLineY + draw.GetFontHeight( "TargetID" )

    end

    -- extraLine: only when isLookedAt
    if self._isLookedAt and self._extraLine and #self._extraLine > 0 then
        draw.SimpleText( self._extraLine, "TargetID", w * 0.5, subLineY, drawText, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

    end

end

vgui.Register( "glee_hl2hudplayer", PANEL, "DPanel" )
