include( "shared.lua" )

function ENT:Draw()
	self:DrawModel()

end

terminator_Extras.glee_CL_SetupSent( ENT, "glee_maxwell_dancing", "materials/vgui/hud/killicon/glee_maxwell_weapon.png" )