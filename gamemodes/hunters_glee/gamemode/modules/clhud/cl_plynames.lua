

local entMeta = FindMetaTable( "Entity" )


-- Panel lifecycle -----------------------------------------------------------

local terminator_Extras = terminator_Extras

terminator_Extras.glee_EntNamePanels = terminator_Extras.glee_EntNamePanels or {}

local nearbyPlayersHudVar = CreateClientConVar( "cl_huntersglee_draw_nearby_players", "1", true, false, "Draw nearby player locations?" )
local nearbyFriendsOnly = CreateClientConVar( "cl_huntersglee_draw_nearby_friendsonly", "0", true, false, "Only draw the location of nearby players on your friends list?" )
local drawPlayerNamesWhenDead = CreateClientConVar( "cl_huntersglee_draw_playernames_whendead", "1", true, false, "Draw player names when you're dead?" )

local function createNamePanel( ent )
    if IsValid( ent.gleeEntNamePanel ) then ent.gleeEntNamePanel:Remove() end

    local panel = vgui.Create( "glee_hl2hudplayer", GetAutoHidingHUDPanel() )
    ent.gleeEntNamePanel = panel

    terminator_Extras.glee_EntNamePanels[ent] = panel

    ent:CallOnRemove( "gleeEntNamePanel", function()
        if IsValid( panel ) then panel:Remove() end

    end )
end

hook.Add( "NetworkEntityCreated", "glee_entnames_tracknewents", function( ent )
    timer.Simple( 0, function()
        if not IsValid( ent ) then return end
        if not ent.Nick then return end
        createNamePanel( ent )

    end )
end )

local function refreshNamePanels()
    for _, ent in ipairs( ents.GetAll() ) do
        if not ent.Nick then continue end

        createNamePanel( ent )

    end

end

refreshNamePanels()

local function cleanupPanels()
    for _, panel in pairs( terminator_Extras.glee_EntNamePanels ) do
        if IsValid( panel ) then panel:SetVisible( false ) end

    end

    if terminator_Extras.glee_SpectatePromptPanel then
        terminator_Extras.glee_SpectatePromptPanel:Remove()
        terminator_Extras.glee_SpectatePromptPanel = nil

    end
end


-- Painting ------------------------------------------------------------------

-- Lazily-created panel: shows "Mouse1 to follow!" when a non-player spectatable
-- entity is under the crosshair while dead. Created on first use.

local spectatePromptText = "Mouse1 to follow!"
local showEntPromptWait = 0

local function getSpectatePromptPanel()
    if IsValid( terminator_Extras.glee_SpectatePromptPanel ) then return terminator_Extras.glee_SpectatePromptPanel end

    local hud        = terminator_Extras.glee_HL2Hud
    local textPad    = glee_sizeScaled( nil, 5 )
    local font       = "TargetID"
    surface.SetFont( font )

    local textW, textH = surface.GetTextSize( spectatePromptText )
    local panelW       = textW + textPad * 2
    local panelH       = textH + textPad * 2

    local panel = vgui.Create( "DPanel", GetHUDPanel() )
    panel:SetSize( panelW, panelH )
    panel:SetVisible( false )
    panel:SetPaintBackground( false )
    panel:SetMouseInputEnabled( false )

    panel.Paint = function( _self, w, h )
        if showEntPromptWait > CurTime() then return end -- visual bug fix
        draw.RoundedBox( hud.boxCornerRadius, 0, 0, w, h, hud.colorBackground )
        draw.SimpleText( spectatePromptText, font, w * 0.5, h * 0.5, hud.colorRedUrgent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

    end

    terminator_Extras.glee_SpectatePromptPanel = panel
    return panel

end

-- autorefresh
if IsValid( terminator_Extras.glee_SpectatePromptPanel ) then
    terminator_Extras.glee_SpectatePromptPanel:Remove()
    terminator_Extras.glee_SpectatePromptPanel = nil

end

local keepShowingEntPrompt = 0
local promptTarget = nil

local function whileDeadPaintOtherPlys( localPlayer, cur )
    local inEye      = localPlayer:GetObserverMode() == OBS_MODE_IN_EYE
    local hasObsTarg = IsValid( localPlayer:GetObserverTarget() )

    local trace     = localPlayer:GetEyeTrace()
    local spectateTarg  = localPlayer:GetObserverTarget()

    local focusEnt
    if IsValid( spectateTarg ) and spectateTarg.Nick then
        focusEnt = spectateTarg

    elseif IsValid( trace.Entity ) and ( trace.Entity.Nick or trace.Entity:GetNW2Bool( "glee_IsSpectatable", false ) ) then
        focusEnt = trace.Entity

    end
    local paintedSpecHint

    local drawWhenDead = drawPlayerNamesWhenDead:GetBool()
    local paintData = {}

    for ent, panel in pairs( terminator_Extras.glee_EntNamePanels ) do
        if not IsValid( panel ) then continue end
        if not ent:IsPlayer() then
            panel:SetVisible( false )
            continue

        end
        if ent == localPlayer then continue end

        local isLookedAt = focusEnt == ent
        if not isLookedAt and not drawWhenDead then
            panel:SetVisible( false )
            continue

        end

        if inEye then
            if entMeta.Health( ent ) <= 0 then
                panel:SetVisible( false )
                continue

            end

            -- throttle the wall check to avoid per-frame flickering at edges
            if not ent.glee_wallCheckNext or ent.glee_wallCheckNext < cur then
                ent.glee_wallCheckNext    = cur + 0.15
                ent.glee_wallCheckVisible = terminator_Extras.PosCanSee( EyePos(), ent:GetShootPos(), MASK_SOLID_BRUSHONLY )

            end
            if not ent.glee_wallCheckVisible then
                panel:SetVisible( false )
                continue

            end
        end

        panel:SetMode( panel.MODE_FULL )

        -- infoLine: dead -> score, alive -> health%
        local health = ent:Health()
        local infoLine
        if health <= 0 then
            infoLine = ent:GetScore() .. " Score"

        else
            infoLine = health .. "%"

        end

        -- extraLine: spectate prompt when looking directly at them with no current target
        local pleasePaintSpectateHint = isLookedAt and not hasObsTarg
        local extraLine  = pleasePaintSpectateHint and spectatePromptText or nil

        paintedSpecHint = pleasePaintSpectateHint


        paintData.infoLine = infoLine
        paintData.extraLine = extraLine
        paintData.ignoreDist = true
        paintData.isLookedAt = isLookedAt

        panel:UpdateForPlayer( ent, cur, paintData )

    end

    local obsMode = localPlayer:GetObserverMode()
    local spectateable = focusEnt and ( focusEnt:GetNW2Bool( "glee_IsSpectatable", false ) or focusEnt:IsNPC() or focusEnt:IsNextBot() )
    local showEntPrompt  = spectateable and not paintedSpecHint and obsMode == OBS_MODE_ROAMING

    local rawPanel = terminator_Extras.glee_SpectatePromptPanel

    if showEntPrompt then
        keepShowingEntPrompt = cur + 0.5
        promptTarget = focusEnt

    end

    if keepShowingEntPrompt > cur and IsValid( promptTarget ) then
        local promptPanel = getSpectatePromptPanel()
        local screenData = promptTarget:WorldSpaceCenter():ToScreen()
        if screenData.visible then
            local pw, ph = promptPanel:GetSize()
            promptPanel:SetPos( screenData.x - pw * 0.5, screenData.y - ph * 0.5 )
            if not promptPanel:IsVisible() then -- let it reposition itself
                showEntPromptWait = cur + 0.01

            end
            promptPanel:SetVisible( true )

        else
            promptPanel:SetVisible( false )

        end
    elseif rawPanel and rawPanel:IsVisible() then
        rawPanel:SetVisible( false )

    end
end

local dontShootHintFor = 0
local hideNamesFor = 0

local function whileAlivePaintOtherEnts( localPlayer, cur )
    -- much smaller distance if we have 0 armor (HUD needs power!)
    local armor = localPlayer:Armor()
    local noPower = armor <= 0

    local friendsOnly = nearbyFriendsOnly:GetBool()
    local onlyDoLookedAt = not nearbyPlayersHudVar:GetBool()

    local recentlyAttacked = hideNamesFor > cur
    if recentlyAttacked and localPlayer:HasStatusEffect( "divine_chosen" ) then
        hideNamesFor = 0

    end

    local trace = localPlayer:GetEyeTrace()

    local focusEnt
    if IsValid( trace.Entity ) and trace.Entity.Nick then
        focusEnt = trace.Entity

    end

    local paintData = {}

    for ent, panel in pairs( terminator_Extras.glee_EntNamePanels ) do
        if not IsValid( panel ) then continue end

        if ent == localPlayer then continue end
        local isLookedAt = focusEnt == ent

        local posOverride, ignoreDist, paintDead = hook.Run( "glee_cl_shouldpaintply_whilealive", ent, panel, isLookedAt )
        if not paintDead and ent:Health() <= 0 then panel:SetVisible( false ) continue end

        panel:SetMode( isLookedAt and panel.MODE_FULL or panel.MODE_WORLD )

        local infoLine
        if isLookedAt then
            local health
            -- health normalized to 0-100
            if not ent:IsPlayer() then
                health = math.ceil( ent:Health() / ent:GetMaxHealth() * 100 )

            else
                health = ent:Health()

            end
            infoLine = health .. "%"

        else
            local badNotLooking
            if ignoreDist then
                badNotLooking = false

            elseif noPower or recentlyAttacked or onlyDoLookedAt then
                badNotLooking = true

            elseif friendsOnly then
                -- let ents without GetFriendStatus be visible
                badNotLooking = ent.GetFriendStatus and ent:GetFriendStatus() ~= "friend"

            end
            if badNotLooking then
                panel:SetVisible( false )
                continue

            end
        end

        paintData.posOverride = posOverride
        paintData.infoLine = infoLine
        paintData.extraLine = nil
        paintData.ignoreDist = ignoreDist
        paintData.isLookedAt = isLookedAt

        panel:UpdateForPlayer( ent, cur, paintData )

    end

    if terminator_Extras.glee_SpectatePromptPanel then
        terminator_Extras.glee_SpectatePromptPanel:Remove()
        terminator_Extras.glee_SpectatePromptPanel = nil

    end
end

hook.Add( "huntersglee_cl_displayhint_poststack", "glee_hintafterattacking", function()
    if dontShootHintFor < CurTime() then return end
    return true, "Homicidal action detected.\nFriendlies display on cooldown..."

end )

hook.Add( "glee_dealtpvpdamage", "glee_hidenames_afterdamaging", function( dmgAmount )
    if LocalPlayer():HasStatusEffect( "divine_chosen" ) then return end
    if dmgAmount <= 50 then return end
    if hideNamesFor < CurTime() then
        dontShootHintFor = CurTime() + 3

    end
    hideNamesFor = CurTime() + 30

end )

hook.Add( "glee_homicidallygleeful", "glee_hidenames_afterdamaging", function()
    if LocalPlayer():HasStatusEffect( "divine_chosen" ) then return end
    dontShootHintFor = CurTime() + 10
    hideNamesFor = math.max( CurTime() + 120, hideNamesFor + 120 )

end )

hook.Add( "glee_cl_paintplayers",           "glee_cl_paintplayers_hook",                whileDeadPaintOtherPlys  )
hook.Add( "glee_cl_paintplayers_whilealive", "glee_cl_paintplayers_whilealive_hook",    whileAlivePaintOtherEnts )

hook.Add( "glee_cl_paintplayers_stop",     "glee_cl_stoppaintingplayers_hook",          cleanupPanels )
