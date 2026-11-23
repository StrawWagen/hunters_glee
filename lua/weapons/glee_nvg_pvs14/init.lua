AddCSLuaFile( "shared.lua" )
AddCSLuaFile( "cl_init.lua" )
include( "shared.lua" )

DEFINE_BASECLASS( "glee_nvg_base" )

-- the radar's keys on the wheel, see GetWheelActions in cl_init.lua
-- the radar's settings live on the weapon, so they stay with the goggles if thrown
function SWEP:OnWheelPick( ply, key )
    if key == "radar" then
        local on = not self:GetRadarOn()
        self:SetRadarOn( on )
        ply:EmitSound( on and "buttons/button17.wav" or "buttons/button16.wav", 55, 120, 0.6 )

    elseif key == "cone" then
        local nextIndex = self:GetCone() % #self.Cones + 1
        self:SetCone( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 150 - nextIndex * 15, 0.6 )

    elseif key == "resolution" then
        local nextIndex = self:GetResolution() % #self.Resolutions + 1
        self:SetResolution( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 120 + nextIndex * 10, 0.6 )

    elseif key == "wavelength" then
        local nextIndex = self:GetWavelength() % #self.Wavelengths + 1
        self:SetWavelength( nextIndex )
        ply:EmitSound( "buttons/lightswitch2.wav", 55, 90 + nextIndex * 15, 0.6 )

    else
        BaseClass.OnWheelPick( self, ply, key )

    end
end
