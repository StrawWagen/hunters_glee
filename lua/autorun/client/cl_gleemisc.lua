
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

-- make a panel thats super easy to close
-- just click off it, or press use or menu key
-- arg1, the panel to make easy to close
-- arg2, optional function called right before the panel closes
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

        -- catch people tabbing in
        -- super annoying if you click on the window to tab back in, and the menu closes
        if not system.HasFocus() then
            justTabbedIn = true
            self:gleeOld_Think()
            return

        end

        -- bail if they open any menu, or press use
        if input_IsKeyDown( KEY_ESCAPE ) then ShutDownPanel( self ) return end
        if clientsUseKey then
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
        end

        if clientsMenuKey then
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


-- override baseclass DrawWeaponSelection to accept actual materials instead of texids, so it can handle pngs with no bs
local function drawTexOverride( self, x, y, wide, tall, alpha )

    -- Set us up the texture
    surface.SetDrawColor( 255, 255, 255, alpha )
    surface.SetMaterial( self.glee_WepSelectIcon )

    -- Lets get a sin wave to make it bounce
    local fsin = 0

    if ( self.BounceWeaponIcon == true ) then
        fsin = math.sin( CurTime() * 10 ) * 5
    end

    -- Borders
    y = y + 10
    x = x + 10
    wide = wide - 20

    -- Draw that mother
    surface.DrawTexturedRect( x + fsin, y - fsin,  wide - fsin * 2 , ( wide / 2 ) + fsin )

    -- Draw weapon info box
    self:PrintWeaponInfo( x + wide + 20, y + tall * 0.95, alpha )

end

local white = Color( 255, 255, 255 )

-- function that setups the weapon's PrintName translation, select icon. and killicon, all in one place
function terminator_Extras.glee_CL_SetupSwep( SWEP, class, texture )
    language.Add( class, SWEP.PrintName )
    killicon.Add( class, texture, white )

    local mat = Material( texture, "alphatest" )
    if not mat:IsError() then
        SWEP.glee_WepSelectIcon = mat
        SWEP.DrawWeaponSelection = drawTexOverride

    else
        ErrorNoHaltWithStack( "Error loading weapon icon texture for " .. class .. "\n" .. mat:GetName() .. "\n" .. texture )

    end
end

function terminator_Extras.glee_CL_SetupSent( ENT, class, texture )
    language.Add( class, ENT.PrintName )
    killicon.Add( class, texture, white )

end