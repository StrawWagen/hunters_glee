
-- Context menu icons that only show while canShow( LocalPlayer() ) holds, checked each time the context menu opens

-- [id] = { windowData = windowData, canShow = canShow }
local gates = {}

-- returns true if the icon was added or removed
local function applyGate( id )
    local gate = gates[id]
    local desktopWindows = list.GetForEdit( "DesktopWindows" )

    local shown = desktopWindows[id] ~= nil
    local shouldShow = tobool( gate.canShow( LocalPlayer() ) )
    if shown == shouldShow then return false end

    if shouldShow then
        list.Set( "DesktopWindows", id, gate.windowData )

    else
        desktopWindows[id] = nil

    end

    return true

end

-- windowData is what list.Set( "DesktopWindows", id, windowData ) takes
function GM:DoGatedDesktopIcon( id, windowData, canShow )
    gates[id] = {
        windowData = windowData,
        canShow = canShow,
    }
end

-- runs just before sandbox opens g_ContextMenu, so a rebuild here is the menu that opens.
-- Not spawnmenu_reload, which rebuilds nothing for players SpawnMenuEnabled shuts out, see sh_unsandboxing
hook.Add( "ContextMenuOpen", "glee_desktopwindowgate", function()
    local changed = false
    for id, _ in pairs( gates ) do
        if applyGate( id ) then
            changed = true

        end
    end

    -- the context menu builds its icons once
    if changed then
        CreateContextMenu()

    end
end )
