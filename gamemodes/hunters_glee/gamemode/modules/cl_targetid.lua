function GM:paintNameAndHealth( trace )

    local text = "ERROR"
    local font = "TargetID"

    text = trace.Entity:Nick()

    surface.SetFont( font )
    local w, h = surface.GetTextSize( text )

    local MouseX, MouseY = gui.MousePos()

    if ( MouseX == 0 && MouseY == 0 ) then

        MouseX = ScrW() / 2
        MouseY = ScrH() / 2

    end

    local x = MouseX
    local y = MouseY

    x = x - w / 2
    y = y + 30

    -- The fonts internal drop shadow looks lousy with AA on
    draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
    draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
    draw.SimpleText( text, font, x, y, self:GetTeamColor( trace.Entity ) )

    y = y + h + 5

    text = trace.Entity:Health() .. "%"
    font = "TargetIDSmall"

    surface.SetFont( font )
    w, h = surface.GetTextSize( text )
    x = MouseX - w / 2

    draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
    draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
    draw.SimpleText( text, font, x, y, self:GetTeamColor( trace.Entity ) )
end

function GM:paintSpectateInfo( trace )

    local text = "Mouse1 to follow!"
    local font = "TargetID"

    surface.SetFont( font )
    local w, _ = surface.GetTextSize( text )

    local MouseX, MouseY = gui.MousePos()

    if ( MouseX == 0 && MouseY == 0 ) then

        MouseX = ScrW() / 2
        MouseY = ScrH() / 2

    end

    local x = MouseX
    local y = MouseY

    x = x - w / 2
    y = y + 30

    local color = self:GetTeamColor( trace.Entity )
    color.a = 100

    -- The fonts internal drop shadow looks lousy with AA on
    draw.SimpleText( text, font, x + 1, y + 1, Color( 0, 0, 0, 120 ) )
    draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 50 ) )
    draw.SimpleText( text, font, x, y, color )

end

function GM:HUDDrawTargetID()

    local me = LocalPlayer()

    local trace = me:GetEyeTrace()
    if not trace.Hit then return end
    if not trace.HitNonWorld then return end

    if not trace.Entity:IsPlayer() then return end

    local spectating = me:Health() <= 0

    if not spectating then self:paintNameAndHealth( trace ) return end
    if IsValid( me:GetObserverTarget() ) then return end
    self:paintSpectateInfo( trace )

end