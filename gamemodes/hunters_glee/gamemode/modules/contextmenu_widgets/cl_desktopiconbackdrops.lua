-- Puts a glee backdrop behind every context menu desktop icon, ours and other addons' alike.
-- Sandbox builds the icons after ContextMenuCreated runs, so this waits for the menu to open

local iconPadding = 6 -- pixels, sandbox sizes its icons unscaled

-- sandbox leaves each icon's Paint nil, and a panel's Paint draws beneath its image and label
local function paintIconBackdrop( icon, w, h )
    local state = icon:IsHovered() and "hovered" or "idle"
    -- bg, like the hud boxes. bgDark's blur re-blurs its neighbours' overlap and streaks the column
    terminator_Extras.glee_PanelStyle( icon ):Background( 0, 0, w, h, "bg", nil, 1, state, icon )

end

hook.Add( "ContextMenuOpened", "glee_desktopiconbackdrops", function()
    if not IsValid( g_ContextMenu ) then return end

    local icons = g_ContextMenu.DesktopWidgets
    if not IsValid( icons ) then return end

    for _, icon in ipairs( icons:GetChildren() ) do
        icon.Paint = paintIconBackdrop

        -- grown once, every open would grow it again
        if not icon.glee_Padded then
            icon.glee_Padded = true
            icon:SetSize( icon:GetWide() + iconPadding * 2, icon:GetTall() + iconPadding * 2 )
            icon:DockPadding( iconPadding, iconPadding, iconPadding, iconPadding )

        end
    end

    icons:InvalidateLayout()

end )
