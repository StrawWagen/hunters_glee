--[[
    glee_hl2hudscorecount — extends glee_hl2hudbox

    A live count display with flash-on-change, running-diff annotation, shake,
    and optional color override for large jumps.

    Usage (top-left HUD manager):
        box:SetLabel( "Score: " )
        box:SetCountFunc( function( ply ) return ply:GetScore() end )
        box:SetSmallCountThreshold( 10 )          -- always show while count <= 10
        box:SetLargePositiveChangeSound( "path/to/gain.wav" )
        box:SetLargeNegativeChangeSound( "path/to/loss.wav" )
        -- manager calls box:ManageHudState( ply, cur, alwaysShow, neverShow ) each frame

    Usage (standalone / ATM GUI):
        box:SetLabel( "Bank: " )
        box:SetNilLabel( "none" )          -- shown when countFunc returns nil
        box:SetCountFunc( function( ply )
            if not ply:GetNW2Bool( "Glee_HasBankAccount", false ) then return nil end
            return ply:GetNW2Int( "Glee_BankFunds", 0 )
        end )
        box:SetAutoManage( true )          -- drives itself via AdditionalThink
]]

local superScoreColor = Color( 255, 255, 0 )
local shakeMaxSize    = glee_sizeScaled( nil, 2 )

local PANEL = {}

PANEL.Init = function( self )
    self.BaseClass.Init( self )

    self._label              = ""
    self._countFunc          = nil
    self._nilLabel           = ""
    self._suffix0            = nil
    self._largePositiveChangeSound   = nil
    self._largeNegativeChangeSound   = nil
    self._smallCountThreshold = nil
    self._changeVisibleDur   = 0
    self._autoManage         = false

    self._colorOverride = nil
    self._colorExpiry   = 0
    self._addAtEnd      = nil
    self._visibleUntil  = 0
    self._shakeTime     = 0
    self._oldCount      = 0
    self._oldCompare    = 0

end

-- Prefix text, e.g. "Score: " or "Bank: ".
PANEL.SetLabel = function( self, label )
    self._label = label

end

-- Function( ply ) → number | nil.  Returning nil shows SetNilLabel instead of a number.
PANEL.SetCountFunc = function( self, fn )
    self._countFunc = fn

end

-- Appended to the label when countFunc returns nil.
PANEL.SetNilLabel = function( self, label )
    self._nilLabel = label

end

-- Appended to the text only when count == 0.
PANEL.SetSuffix0 = function( self, suffix )
    self._suffix0 = suffix

end

-- Sound played when the count rises by 500 or more in one step.
PANEL.SetLargePositiveChangeSound = function( self, path )
    self._largePositiveChangeSound = path

end

-- Sound played when the count falls by 500 or more in one step.
PANEL.SetLargeNegativeChangeSound = function( self, path )
    self._largeNegativeChangeSound = path

end

-- While count <= n the panel stays visible even without a recent change.
PANEL.SetSmallCountThreshold = function( self, n )
    self._smallCountThreshold = n

end

-- Minimum seconds to stay visible after ANY count change (regardless of size).
PANEL.SetChangeVisibleDuration = function( self, dur )
    self._changeVisibleDur = dur

end

-- Seeds the known starting count so the first frame doesn't treat the whole
-- value as a change from zero.  Call after SetCountFunc, before SetAutoManage.
PANEL.SetStartingCount = function( self, n )
    if n == nil then return end
    self._oldCount   = n
    self._oldCompare = n

end

-- When true, AdditionalThink drives ManageHudState each frame (for standalone use).
PANEL.SetAutoManage = function( self, v )
    self._autoManage = v

end

-- Called each frame by the top-left HUD manager, or internally when autoManage is on.
-- alwaysShow: override stayPresent to true (e.g. tab held)
-- neverShow:  force panel to fade (e.g. ConVar disabled)
-- Returns xOffset for horizontal position correction (shake animation).
PANEL.ManageHudState = function( self, ply, cur, alwaysShow, neverShow )
    local hud   = terminator_Extras.glee_HL2Hud
    local count = self._countFunc and self._countFunc( ply )

    local text
    if count == nil then
        text = self._label .. self._nilLabel

    else
        text = self._label .. count
        if count == 0 and self._suffix0 then
            text = text .. self._suffix0

        end
    end

    local textColor   = hud.colorUnHappyYellow
    local doFlash     = false
    local threshold   = self._smallCountThreshold
    local isWithinVisibleWindow = self._visibleUntil > cur
    local isBelowCountThreshold = threshold and count and count <= threshold
    local stayPresent           = isWithinVisibleWindow or isBelowCountThreshold

    if self._colorExpiry > cur then
        textColor = self._colorOverride

        if self._addAtEnd and count ~= nil then
            text = text .. self._addAtEnd

        end
    end

    if count ~= nil and self._oldCount ~= count then
        doFlash = true

        local overrideColor     = hud.colorHappyYellow
        local overrideColorTime = 0.1
        local textShakeTime     = 0

        local changeFromBaseline  = count - self._oldCompare
        local changeFromLastCount = count - self._oldCount
        local absDifference       = math.abs( changeFromLastCount )

        if changeFromBaseline >= 500 then
            overrideColor = superScoreColor

        end

        if absDifference >= 500 then
            overrideColorTime = 8
            textShakeTime     = 8
            if changeFromLastCount > 0 then
                if self._largePositiveChangeSound then
                    ply:EmitSound( self._largePositiveChangeSound, 70, 70 )

                end
            else
                if self._largeNegativeChangeSound then
                    ply:EmitSound( self._largeNegativeChangeSound, 70, 70 )

                end
            end
        elseif absDifference >= 100 then
            overrideColorTime = 4
            textShakeTime     = 3

        elseif absDifference >= 10 then
            overrideColorTime = 3
            textShakeTime     = 1

        end

        self._colorOverride = overrideColor
        local freshColorExpiry    = cur + overrideColorTime
        local extendedColorExpiry = math.Clamp( self._colorExpiry + overrideColorTime, 0, cur + 10 )
        self._colorExpiry         = math.max( freshColorExpiry, extendedColorExpiry )

        local freshShakeExpiry    = cur + textShakeTime
        local extendedShakeExpiry = self._shakeTime + textShakeTime / 4
        self._shakeTime           = math.max( freshShakeExpiry, extendedShakeExpiry )
        self._oldCount      = count

        local visibleFor = math.max( overrideColorTime, self._changeVisibleDur )
        if absDifference >= 25 or self._changeVisibleDur > 0 then
            self._visibleUntil = math.max( cur + visibleFor, self._visibleUntil )

        end

        if changeFromBaseline > 0 then
            self._addAtEnd = " +" .. changeFromBaseline

        else
            self._addAtEnd = " " .. changeFromBaseline

        end
    end

    if self._colorExpiry < cur then
        self._oldCompare = count or self._oldCompare

    end

    local xOffset = 0
    if self._shakeTime > cur then
        local shakeScale = ( self._shakeTime - cur ) * shakeMaxSize
        xOffset = math.Rand( -shakeScale, shakeScale )

    end

    doFlash = doFlash and stayPresent

    if neverShow then
        self:SetDoFadeDelays( false )
        stayPresent = false
        doFlash     = false

    elseif alwaysShow then
        stayPresent = true

    end

    self:SetIconColor( textColor )
    self:SetText( text )
    self:AutoSize()

    if stayPresent then
        if doFlash then
            self:SetState( self.STATE_FLASH )
        else
            self:SetState( self.STATE_NORMAL )
        end

    else
        self:SetState( self.STATE_FADING )

    end

    return xOffset

end

PANEL.AdditionalThink = function( self )
    if not self._autoManage then return end

    local ply = LocalPlayer()
    if not IsValid( ply ) then return end

    self:ManageHudState( ply, CurTime(), true, false )

end

vgui.Register( "glee_hl2hudscorecount", PANEL, "glee_hl2hudbox" )
