--[[------------------------------------
    Which style and scale a panel draws in.

    Each comes from the nearest panel up the parent chain that sets one, so setting them
    on a frame sets them for everything in it. With nothing set, it's generic at gui:

        terminator_Extras.glee_SetPanelStyle( frame, "hl2" )
        terminator_Extras.glee_SetPanelScale( frame, "fixed" )
        local style = terminator_Extras.glee_PanelStyle( somePanelInTheFrame )

    When what a panel draws in may have changed, its OnHudStyleChanged is called, parents
    before children, then AfterHudStyleChanged once its children have had theirs, for a
    parent sizing itself around them. That's the whole vgui tree on a rebuild or an alias
    resolving differently, and the panel's own subtree on a set or glee_NotifyPanelStyle.
--]]-------------------------------------

local defaultStyle = "generic"
local defaultScale = "gui"

-- escaped players are at 0 health, so they get soulthought too
terminator_Extras.glee_RegisterStyleAlias( "generic", function()
    local me = LocalPlayer()
    if IsValid( me ) and me:Health() <= 0 then return "soulthought" end

    return "hl2"

end )


local function inherited( panel, key, default )
    while IsValid( panel ) do
        local value = panel[key]
        if value then return value end

        panel = panel:GetParent()

    end

    return default

end

--[[---------------------------------------------------------
    terminator_Extras.glee_PanelStyle
    Gets the handle for whatever style and scale a panel draws in.
    @param panel: Any panel.
    @return: The handle. Look it up where you draw, a panel's context can change under it.
--]]---------------------------------------------------------
function terminator_Extras.glee_PanelStyle( panel )
    local styleName = inherited( panel, "glee_HudStyle", defaultStyle )
    local scaleName = inherited( panel, "glee_HudScale", defaultScale )

    return terminator_Extras.glee_Style( styleName, scaleName )

end


local function notifyTree( panel )
    if not IsValid( panel ) then return end

    if panel.OnHudStyleChanged then
        panel:OnHudStyleChanged()

    end

    for _, child in ipairs( panel:GetChildren() ) do
        notifyTree( child )

    end

    if panel.AfterHudStyleChanged then
        panel:AfterHudStyleChanged()

    end
end

local function notifyEverything()
    local worldPanel = vgui.GetWorldPanel()
    notifyTree( worldPanel )

    local hudPanel = GetHUDPanel()
    if IsValid( hudPanel ) and not hudPanel:HasParent( worldPanel ) then
        notifyTree( hudPanel )

    end
end

-- For a change this file can't see, like a panel being moved to another parent
terminator_Extras.glee_NotifyPanelStyle = notifyTree

-- These two work on any panel, glee's or not. nil goes back to inheriting
function terminator_Extras.glee_SetPanelStyle( panel, styleName )
    panel.glee_HudStyle = styleName
    notifyTree( panel )

end

function terminator_Extras.glee_SetPanelScale( panel, scaleName )
    panel.glee_HudScale = scaleName
    notifyTree( panel )

end


hook.Add( "glee_hud_stylesrebuilt", "glee_hud_notifypanels", notifyEverything )

local aliases = terminator_Extras.glee_HudStyleAliases
local lastResolved = {}

hook.Add( "Think", "glee_hud_watchstylealiases", function()
    local changed = false

    for aliasName, resolve in pairs( aliases ) do
        local resolved = resolve()
        if lastResolved[aliasName] ~= resolved then
            lastResolved[aliasName] = resolved
            changed = true

        end
    end

    if not changed then return end

    notifyEverything()

end )
