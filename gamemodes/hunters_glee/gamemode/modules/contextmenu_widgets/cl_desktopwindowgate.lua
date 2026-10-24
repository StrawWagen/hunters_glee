
-- Context menu icons that only show while canShow( LocalPlayer() ) holds, rechecked whenever a watched NW2 var changes,
-- and every few seconds in case a change slipped past

-- [id] = { windowData = windowData, canShow = canShow }
local gates = {}

-- [varName] = { [id] = true }
local watchers = {}

-- [varName] = true, once its proxy is on LocalPlayer
local proxiedVars = {}

-- [id] = true, checked on the next tick
local pending = {}

-- set inside InitPostEntity, and kept on terminator_Extras so it survives autorefresh,
-- where InitPostEntity has long since fired and won't fire again
local function entitiesReady()
    return terminator_Extras.glee_DesktopWindowGateReady

end

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

-- the proxy fires before the new value is stored, so canShow's getters only read it a tick later.
-- Waiting also gathers every change in a tick into one reload
local function checkPendingNextTick()
    timer.Create( "glee_desktopwindowgate_check", 0, 1, function()
        local changed = false
        for id, _ in pairs( pending ) do
            if applyGate( id ) then
                changed = true

            end
        end
        table.Empty( pending )

        -- the context menu builds its icons once
        if changed then
            RunConsoleCommand( "spawnmenu_reload" )

        end
    end )
end

-- an entity holds one proxy per var, and a second SetNW2VarProxy replaces the first.
-- So each var gets one, shared by every gate watching it
local function installProxy( varName )
    if proxiedVars[varName] then return end
    proxiedVars[varName] = true

    LocalPlayer():SetNW2VarProxy( varName, function()
        for id, _ in pairs( watchers[varName] ) do
            pending[id] = true

        end
        checkPendingNextTick()

    end )
end

-- windowData is what list.Set( "DesktopWindows", id, windowData ) takes.
-- options.nw2Vars are the NW2 vars on LocalPlayer that canShow reads, options.canShow( me ) returns whether to show the icon
function GM:DoGatedDesktopIcon( id, windowData, options )
    gates[id] = {
        windowData = windowData,
        canShow = options.canShow,
    }

    for _, varName in ipairs( options.nw2Vars ) do
        watchers[varName] = watchers[varName] or {}
        watchers[varName][id] = true

    end

    if not entitiesReady() then return end

    for _, varName in ipairs( options.nw2Vars ) do
        installProxy( varName )

    end

    pending[id] = true
    checkPendingNextTick()

end

-- the first sync can land before this, so every gate is checked now too
hook.Add( "InitPostEntity", "glee_desktopwindowgate_init", function()
    terminator_Extras.glee_DesktopWindowGateReady = true

    for varName, _ in pairs( watchers ) do
        installProxy( varName )

    end

    for id, _ in pairs( gates ) do
        pending[id] = true

    end
    checkPendingNextTick()

end )

-- after a map change, a var's first value can land after InitPostEntity without ever firing its proxy
timer.Create( "glee_desktopwindowgate_recheck", 2, 0, function()
    if not entitiesReady() then return end

    for id, _ in pairs( gates ) do
        pending[id] = true

    end
    checkPendingNextTick()

end )
