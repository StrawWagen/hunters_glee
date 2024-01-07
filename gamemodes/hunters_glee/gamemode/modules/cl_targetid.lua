
local distNeededToSeeTargetIdSqr = 1500^2

function GM:paintNameAndHealth( trace )

    local close
    local text = "????"
    local font = "TargetID"

    local hitEnt = trace.Entity

    if trace.HitPos:DistToSqr( trace.StartPos ) < distNeededToSeeTargetIdSqr then
        close = true

        if hitEnt.Nick then
            text = hitEnt:Nick()

        else
            text = ""

        end
    end

    if not text or text == "" then return end

    surface.SetFont( font )
    local w, h = surface.GetTextSize( text )

    local MouseX, MouseY = gui.MousePos()

    if MouseX == 0 and MouseY == 0 then

        MouseX = ScrW() / 2
        MouseY = ScrH() / 2

    end

    local x = MouseX
    local y = MouseY

    x = x - w / 2
    y = y + 100

    surface.drawShadowedTextBetter( text, font, self:GetTeamColor( trace.Entity ), x, y, false )

    y = y + h + 5

    if not close then return end
    if not hitEnt:IsPlayer() then return end

    text = hitEnt:Health() .. "%"
    font = "TargetIDSmall"

    surface.SetFont( font )
    w, h = surface.GetTextSize( text )
    x = MouseX - w / 2

    surface.drawShadowedTextBetter( text, font, self:GetTeamColor( trace.Entity ), x, y, false )

end

function GM:paintSpectateInfo( trace )

    local text = "Mouse1 to follow!"
    local font = "TargetID"

    surface.SetFont( font )
    local w, _ = surface.GetTextSize( text )

    local MouseX, MouseY = gui.MousePos()

    if MouseX == 0 and MouseY == 0 then

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

local LocalPlayer = LocalPlayer

function GM:HUDDrawTargetID()

    local me = LocalPlayer()

    local trace = me:GetEyeTrace()
    if not trace.Hit then return end
    if not trace.HitNonWorld then return end

    if not trace.Entity.Nick and not trace.Entity:IsNextBot() then return end

    local spectating = me:Health() <= 0

    if not spectating then self:paintNameAndHealth( trace ) return false end
    if IsValid( me:GetObserverTarget() ) then return false end
    self:paintSpectateInfo( trace )

    -- intercept all stuff that respects HUDDrawTargetID returning false
    return false

end