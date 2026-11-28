AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "glee_nvg_base" )

-- the width's key, see GetGleeActions in shared.lua, glee_actions has checked it's offered
function SWEP:OnGleeAction( ply, key )
    if key ~= "fov" then return BaseClass.OnGleeAction( self, ply, key ) end

    local nextIndex = self:NextIndex( self.Fovs, self:GetFov() )
    self:SetFov( nextIndex )
    ply:EmitSound( "buttons/lightswitch2.wav", 55, 150 - nextIndex * 15, 0.6 )

    return true

end
