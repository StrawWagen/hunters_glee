ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = ""
ENT.Author = "Loures"
ENT.Spawnable = false
ENT.AdminOnly    = game.IsDedicated()
ENT.AutomaticFrameAdvance = true

local className = "termhunt_bear_trap"
if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, className, "vgui/hud/killicon/" .. className .. ".png" )

end

function ENT:Think()
    self:NextThink( CurTime() )
    return true
end
