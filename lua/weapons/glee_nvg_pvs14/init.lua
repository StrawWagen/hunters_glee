AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "cl_rays.lua" )
AddCSLuaFile( "cl_sweep.lua" )
AddCSLuaFile( "cl_overlay.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "glee_nvg_base" )

-- the radar's keys, see GetGleeActions in shared.lua, glee_actions has checked it's offered
-- the radar's settings live on the weapon, so they stay with the goggles if thrown
function SWEP:OnGleeAction( ply, key )
    if key == "radar" then
        local on = not self:GetRadarOn()
        self:SetRadarOn( on )
        ply:EmitSound( on and "buttons/button17.wav" or "buttons/button16.wav", 55, 120, 0.6 )

    elseif key == "cone" then
        local nextIndex = self:NextIndex( self.Cones, self:GetCone() )
        self:SetCone( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 150 - nextIndex * 15, 0.6 )

    elseif key == "resolution" then
        local nextIndex = self:NextIndex( self.Resolutions, self:GetResolution() )
        self:SetResolution( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 120 + nextIndex * 10, 0.6 )

    elseif key == "wavelength" then
        local nextIndex = self:NextIndex( self.Wavelengths, self:GetWavelength() )
        self:SetWavelength( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 90 + nextIndex * 15, 0.6 )

    else
        return BaseClass.OnGleeAction( self, ply, key )

    end

    return true

end
