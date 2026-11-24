
-- Haptic vision. A dim light from the eyes lights the dark, the colours come up stronger and redder, and it has a radar.
-- Its wheel adds the radar to the goggles' own: on/off, the wavelength, the cone's width, and the resolution.
-- While the radar's on and they're flipped down, the wearer's client fires rays every frame from their eyes, inside the
-- cone, which is drawn around the crosshair. Rays don't bounce, they pierce: through walls and props, up to the
-- wavelength's pierce in total, knocked a little off course by every bit of solid. The rays aren't drawn.
-- A ray that hits a living player, npc or nextbot flashes a mark in the cone where that ray started off.
-- A newly found target beeps once, and counts as new again after 10 seconds without being hit. See cl_init.lua.
-- The rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
DEFINE_BASECLASS( "glee_nvg_base" )

SWEP.PrintName = "PVS-14 Haptic Vision"
SWEP.Category = "Hunter's Glee"
SWEP.Author = "ye"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_pvs14.mdl"

SWEP.GleeNVG = {
    lamp = 0.6,
    lampColor = Color( 70, 70, 100 ),
    lampFarZ = 2500, -- the haptic's lamp is a short throw, half the base 5000, so it reads close only
    gain = 1, -- no brightening, just the colour pass below
    saturation = 1.5, -- stronger colours
    tint = Color( 230, 230, 255 ),
    vignette = { start = 0.5, finish = 0.95 }, -- the same tube rim the thermal wears
}

-- rays = fired per frame, pierce = total hammer units of solid each can go through before it stops,
-- length = how far one ray travels in total, solid and air together, before it gives up,
-- deflectEvery / deflectDegrees = every this many units of solid bends the ray this many degrees
-- short waves are many rays that barely get through anything, long waves are few that go through a lot
SWEP.Wavelengths = {
    { name = "Short",  rays = 120, pierce = 64,   length = 4000,  deflectEvery = 50, deflectDegrees = 5 },
    { name = "Medium", rays = 50,  pierce = 256,  length = 8000,  deflectEvery = 50, deflectDegrees = 5 },
    { name = "Long",   rays = 20,  pierce = 512,  length = 12000, deflectEvery = 50, deflectDegrees = 5 },
    { name = "ELong",  rays = 10,  pierce = 1024, length = 20000, deflectEvery = 50, deflectDegrees = 1 },
}

-- how wide the cone the rays come out in is, whole width in degrees, picked from the wheel
SWEP.Cones = { 90, 40, 10 }

-- how long a blip stays in the cone before it's gone, in seconds. the fade is spread over this same
-- window, so this one number is the blip's lifetime and its decay rate both
SWEP.MarkLife = 10

-- how many points the whole sweep has, picked from the wheel; a frame only walks a slice of them
-- Low carries the old Max density, and the rest are stepped up from it
SWEP.Resolutions = {
    { name = "Low", points = 1920 },
    { name = "Medium", points = 3840 },
    { name = "High", points = 7680 },
    { name = "Max", points = 15360 },
}

function SWEP:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Bool", "RadarOn" )
    self:NetworkVar( "Int", "Wavelength" ) -- index into SWEP.Wavelengths
    self:NetworkVar( "Int", "Cone" ) -- index into SWEP.Cones
    self:NetworkVar( "Int", "Resolution" ) -- index into SWEP.Resolutions

end

function SWEP:Initialize()
    BaseClass.Initialize( self )
    self:SetWavelength( 1 )
    self:SetCone( 1 )

    -- on out of the box: the radar is the goggles' whole point, and a wearer who has never opened the
    -- wheel should still see it. server only, since the value is networked and the client would be
    -- writing over what the server is already sending it
    if SERVER then self:SetRadarOn( true ) end

    -- by name, so the default stays Medium if the list is ever reordered
    for i, wavelength in ipairs( self.Wavelengths ) do
        if wavelength.name == "Medium" then
            self:SetWavelength( i )
            break

        end
    end

    -- by name, so the default stays Medium if the list is ever reordered
    self:SetResolution( 1 )
    for i, resolution in ipairs( self.Resolutions ) do
        if resolution.name == "Medium" then
            self:SetResolution( i )
            break

        end
    end
end
