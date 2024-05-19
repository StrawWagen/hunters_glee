ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = ""
ENT.Author = "Loures"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.AutomaticFrameAdvance = true

local className = "termhunt_bear_trap"
if CLIENT then
    language.Add( className, ENT.PrintName )
    killicon.Add( className, "vgui/hud/killicon/" .. className .. ".png", color_white )

else
    resource.AddFile( "materials/vgui/hud/killicon/" .. className .. ".png" )

end

function ENT:Think()
    self:NextThink( CurTime() )
    return true
end
