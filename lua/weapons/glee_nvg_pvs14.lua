AddCSLuaFile()

-- Haptic vision. Boosts the picture by how dark it is where you stand, and has a radar, see
-- lua/autorun/sh_glee_nvg_haptic.lua. E with them out opens the wheel: radar on/off, cycle wavelength.
-- See glee_nvg_base and lua/autorun/sh_glee_nightvision.lua.

SWEP.Base = "glee_nvg_base"
GleeNVG_SetupSwep( SWEP, "glee_nvg_pvs14" )

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool", 0, "RadarOn" )
    self:NetworkVar( "Int", 0, "Wavelength" ) -- index into GleeNVG.wavelengths

end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    self:SetWavelength( 1 )

end
