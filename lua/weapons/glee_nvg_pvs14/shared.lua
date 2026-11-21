
-- Haptic vision. A dim light from the eyes lights the dark, the colours come up stronger and redder, and it has a radar.
-- E with them out (not aimed at anything usable) opens a use wheel: radar on/off, or cycle the wavelength.
-- E with them out also changes how wide the cone the rays come out in is.
-- While the radar's on and they're flipped down, the wearer's client fires rays every frame from their eyes, inside the
-- cone, which is drawn around the crosshair. Rays don't bounce, they pierce: through walls and props, up to the
-- wavelength's pierce in total, knocked a little off course by every bit of solid. The rays aren't drawn.
-- A ray that hits a living player, npc or nextbot flashes a mark in the cone where that ray started off.
-- A newly found target beeps once, and counts as new again after 10 seconds without being hit. See cl_init.lua.
-- The rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
SWEP.PrintName = "PVS-14 Haptic Vision"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_pvs14.mdl"

SWEP.GleeNVG = {
    lamp = 0.6,
    lampColor = Color( 80, 80, 80 ),
    gain = 1, -- no brightening, just the colour pass below
    saturation = 1.5, -- stronger colours
    tint = Color( 150, 150, 255 ), -- a little redder
}

-- rays = fired per frame, pierce = total hammer units of solid each can go through before it stops
-- short waves are many rays that barely get through anything, long waves are few that go through a lot
SWEP.Wavelengths = {
    { name = "Short", rays = 60, pierce = 64 },
    { name = "Medium", rays = 20, pierce = 256 },
    { name = "Long", rays = 8, pierce = 1024 },
}

-- how wide the cone the rays come out in is, whole width in degrees, picked from the wheel
SWEP.Cones = { 90, 40, 10 }

-- every this many units of solid a ray goes through, it's knocked this many degrees off course
SWEP.PierceDeflectEvery = 50
SWEP.PierceDeflectDegrees = 3

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool", 0, "RadarOn" )
    self:NetworkVar( "Int", 0, "Wavelength" ) -- index into SWEP.Wavelengths
    self:NetworkVar( "Int", 1, "Cone" ) -- index into SWEP.Cones

end

function SWEP:Initialize()
    self:SetHoldType( self.HoldType )
    self:SetWavelength( 1 )
    self:SetCone( 1 )

end
