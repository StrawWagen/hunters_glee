
AddCSLuaFile()
terminator_Extras = terminator_Extras or {}
local input_IsKeyDown = input.IsKeyDown
local input_IsMouseDown = input.IsMouseDown

terminator_Extras.easyClosers = terminator_Extras.easyClosers or {}

local function catch( err )
    ErrorNoHaltWithStack( err )

end

local function ShutDownPanel( pnl )
    if pnl.glee_easyCloseFirst then
        xpcall( pnl.glee_easyCloseFirst, catch, pnl )

    end
    if not IsValid( pnl ) then return end
    pnl:Close()

end

local clientsMenuKey = input.LookupBinding( "+menu" )
if clientsMenuKey then
    clientsMenuKey = input.GetKeyCode( clientsMenuKey )
end

local clientsUseKey = input.LookupBinding( "+use" )
if clientsUseKey then
    clientsUseKey = input.GetKeyCode( clientsUseKey )
end

function terminator_Extras.easyClosePanel( pnl, callFirst )
    -- if we already did all the fun stuff, just override the shutdown func
    if pnl.easyClosing then
        pnl.glee_easyCloseFirst = callFirst
        return

    end

    table.insert( terminator_Extras.easyClosers, pnl )

    pnl.glee_easyCloseFirst = callFirst
    pnl.easyClosing = true

    pnl.justTabbedIn = nil

    pnl.keyWasDown = {
        [clientsUseKey] = true,
        [clientsMenuKey] = true,

    }

end

-- dont give these damn panels any chances
hook.Add( "Think", "glee_shutdownallpanels", function()
    if #terminator_Extras.easyClosers <= 0 then return end

    for index, panel in ipairs( terminator_Extras.easyClosers ) do
        if not IsValid( panel ) then table.remove( terminator_Extras.easyClosers, index ) continue end

        if input_IsKeyDown( KEY_ESCAPE ) then ShutDownPanel( panel ) end
        if not system.HasFocus() then
            panel.justTabbedIn = true
            continue

        end
        -- bail if they open any menu, or press use
        if input_IsKeyDown( clientsUseKey ) then
            if not panel.keyWasDown[clientsUseKey] then
                ShutDownPanel( panel )
                continue

            else
                panel.keyWasDown[clientsUseKey] = true

            end
        else
            panel.keyWasDown[clientsUseKey] = nil

        end

        if input_IsKeyDown( clientsMenuKey ) then
            if not panel.keyWasDown[clientsMenuKey] then
                ShutDownPanel( panel )
                continue

            else
                panel.keyWasDown[clientsMenuKey] = true

            end
        else
            panel.keyWasDown[clientsMenuKey] = nil

        end

        if not input_IsMouseDown( MOUSE_LEFT ) and not input_IsMouseDown( MOUSE_RIGHT ) then
            panel.justTabbedIn = nil
            continue

        end

        if panel.justTabbedIn then continue end

        -- close when clicking off menu
        local myX, myY = panel:GetPos()
        local myWidth, myHeight = panel:GetSize()
        local mouseX, mouseY = input.GetCursorPos()

        if mouseX < myX or mouseX > myX + myWidth then ShutDownPanel( panel ) continue end
        if mouseY < myY or mouseY > myY + myHeight then ShutDownPanel( panel ) continue end

    end
end )