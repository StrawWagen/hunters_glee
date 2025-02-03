
AddCSLuaFile()
terminator_Extras = terminator_Extras or {}
local input_IsKeyDown = input.IsKeyDown
local input_IsMouseDown = input.IsMouseDown

local justTabbedIn = false

local function ShutDownPanel( pnl )
    if pnl.glee_easyCloseFirst then
        pnl.glee_easyCloseFirst()

    end
    if not IsValid( pnl ) then return end
    pnl:Close()

end

function terminator_Extras.easyClosePanel( pnl, callFirst )
    pnl.keyWasDown = {}

    local clientsMenuKey = input.LookupBinding( "+menu" )
    if clientsMenuKey then
        clientsMenuKey = input.GetKeyCode( clientsMenuKey )
        pnl.keyWasDown[clientsMenuKey] = true
    end

    local clientsUseKey = input.LookupBinding( "+use" )
    if clientsUseKey then
        clientsUseKey = input.GetKeyCode( clientsUseKey )
        pnl.keyWasDown[clientsUseKey] = true
    end

    pnl.gleeOld_Think = pnl.Think

    pnl.glee_easyCloseFirst = callFirst

    function pnl:Think()
        if not system.HasFocus() then
            justTabbedIn = true
            self:gleeOld_Think()
            return

        end
        -- bail if they open any menu, or press use
        if input_IsKeyDown( KEY_ESCAPE ) then ShutDownPanel( self ) return end
        if input_IsKeyDown( clientsUseKey ) then
            if not pnl.keyWasDown[clientsUseKey] then
                ShutDownPanel( self )
                return

            else
                pnl.keyWasDown[clientsUseKey] = true

            end
        else
            pnl.keyWasDown[clientsUseKey] = nil

        end

        if input_IsKeyDown( clientsMenuKey ) then
            if not pnl.keyWasDown[clientsMenuKey] then
                ShutDownPanel( self )
                return

            else
                pnl.keyWasDown[clientsMenuKey] = true

            end
        else
            pnl.keyWasDown[clientsMenuKey] = nil

        end

        if not input_IsMouseDown( MOUSE_LEFT ) and not input_IsMouseDown( MOUSE_RIGHT ) then
            self:gleeOld_Think()
            justTabbedIn = nil
            return

        end

        if justTabbedIn then return end

        -- close when clicking off menu
        local myX, myY = self:GetPos()
        local myWidth, myHeight = self:GetSize()
        local mouseX, mouseY = input.GetCursorPos()

        if mouseX < myX or mouseX > myX + myWidth then ShutDownPanel( self ) return end
        if mouseY < myY or mouseY > myY + myHeight then ShutDownPanel( self ) return end

        self:gleeOld_Think()

    end
end
