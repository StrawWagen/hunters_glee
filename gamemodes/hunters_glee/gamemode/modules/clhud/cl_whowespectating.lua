--[[------------------------------------
    Who you are watching, or what you have taken over, in a box across the top of the
    screen while you are dead.

    A glee_hl2hudbox like the top left lane's, so it reads as the same hud. It never
    fades: it is either showing who you are watching or it is gone.

    Label and name are painted here rather than set as one string, because they can be
    in different fonts. See nameFontRole.

    It dodges the lane above it, but claims no space of its own.
--]]-------------------------------------

local GAMEMODE = GAMEMODE or GM

local LABEL_FONT = "mediumLarge" -- a font role, the style picks it
local NAME_FONT = "playerName" -- a plain face, level with the label, used if thing we spectating has :Nick

local topPadding = terminator_Extras.defaultHudPaddingFromBottom * 2 -- level with the top left lane
local textPadding = terminator_Extras.glee_HL2Hud.blockPadding
local gapBelowHud = terminator_Extras.glee_HL2Hud.laneSpacing

local box

-- A person's typing needs glyphs the style lacks. GetNameOfBot's doesn't
local function nameFontRole()
    if box.watchedHasNick then return NAME_FONT end

    return LABEL_FONT

end

local function createBox()
    if IsValid( box ) then box:Remove() end

    box = vgui.Create( "glee_hl2hudbox", GetAutoHidingHUDPanel() )
    box._myStyle = "soulthought" -- only ever drawn while dead

    box.label = ""
    box.watched = ""
    box.watchedHasNick = false

    -- the box's icon colour, faded. Nothing sets it, so it's the "happy" role
    function box:PaintContent( w, _h, textColor )
        local style = self:Style()
        local labelFont = style:Font( LABEL_FONT )

        draw.SimpleText( self.label, labelFont, w * 0.5, textPadding, textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )
        draw.SimpleText( self.watched, style:Font( nameFontRole() ), w * 0.5, textPadding + draw.GetFontHeight( labelFont ), textColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP )

    end
end

hook.Add( "OnGamemodeLoaded", "glee_whowespectating_create", createBox )
if GAMEMODE then createBox() end

-- Two fonts means two measures, so the box can't AutoSize. Matches its padding though:
-- pad * 4 across, pad * 2 down
local function sizeBox()
    local style = box:Style()
    local labelFont = style:Font( LABEL_FONT )
    local nameFont = style:Font( nameFontRole() )

    surface.SetFont( labelFont )
    local labelWidth = surface.GetTextSize( box.label )

    surface.SetFont( nameFont )
    local nameWidth = surface.GetTextSize( box.watched )

    local textHeight = draw.GetFontHeight( labelFont ) + draw.GetFontHeight( nameFont )

    box:SetSize( math.max( labelWidth, nameWidth ) + textPadding * 4, textHeight + textPadding * 2 )

end

-- Only written on a deliberate spectate switch, so it can name a target we left
local function watchedName()
    local sent = LocalPlayer():GetNW2String( "glee_currentlySpectatingName", "" )
    if sent ~= "" then return sent end

    return "Something"

end

-- the test sv_player.lua uses to pick between a Nick and GetNameOfBot, so the font we
-- choose matches the name it sent
local function hasNick( ent )
    return ent.Nick and isstring( ent:Nick() )

end

-- Label, name, and whether it has a Nick. Nothing when there's nothing to watch.
-- Driving first: spectate targets don't update while you drive, so that one is stale
local function watchingParts( ply )
    local driven = ply:GetDrivingEntity()
    if IsValid( driven ) then
        return "Posessing", watchedName(), hasNick( driven )

    end

    local observed = ply:GetObserverTarget()
    if IsValid( observed ) then
        return "Spectating", watchedName(), hasNick( observed )

    end
end

local function hideBox()
    if not IsValid( box ) then return end

    box:SetState( box.STATE_HIDDEN )

end

hook.Add( "glee_cl_deadplyhud", "glee_whowespectating_draw", function( ply, _cur )
    if not IsValid( box ) then return end

    local label, watched, watchedHasNick = watchingParts( ply )
    if not label or not GAMEMODE:CanShowDefaultHud() then
        hideBox()
        return

    end

    box.label = label
    box.watched = watched
    box.watchedHasNick = watchedHasNick
    sizeBox()
    box:SetState( box.STATE_NORMAL )

    local x = ScrW() * 0.5 - box:GetWide() * 0.5
    local y = topPadding

    -- a long Misery name stretches the top left lane out to here, and the lane shrinks
    -- back smoothly as it fades, so this slides rather than snaps
    local inTheWay = GAMEMODE:HudSpaceInMyWay( x, y, box:GetWide(), box:GetTall() )
    if inTheWay then
        y = inTheWay + gapBelowHud

    end

    box:SetPos( x, y )

end )

-- The panel keeps painting whether or not glee_cl_deadplyhud runs, and it stops running
-- on a respawn and on the win screen, so both have to put it away
hook.Add( "glee_cl_aliveplyhud", "glee_whowespectating_hide", hideBox )
hook.Add( "glee_paintWinScreen", "glee_whowespectating_hide", hideBox )
