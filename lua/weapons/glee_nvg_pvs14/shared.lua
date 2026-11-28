
-- Haptic vision. A dim light from the eyes lights the dark, the colours come up stronger and redder, and it has a radar.
-- Its wheel adds the radar to the goggles' own: on/off, the wavelength, the cone's width, and the resolution.
-- While the radar's on and they're flipped down, the wearer's client fires rays every frame from their eyes, inside the
-- cone, which is drawn around the crosshair. Rays don't bounce, they pierce: through walls and props, up to the
-- wavelength's pierce in total, knocked a little off course by every bit of solid. The rays aren't drawn.
-- A ray that hits a living player, npc or nextbot leaves a blip, on the bearing it was fired along, and each
-- target's blips get a box round them, with a line up to its name over the cone.
-- A newly found target beeps once, and counts as new again once it's gone unhit a while. See cl_init.lua.
-- The rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
DEFINE_BASECLASS( "glee_nvg_base" )

SWEP.PrintName = "PVS-14 Haptic Vision"
SWEP.Category = "Hunter's Glee"
SWEP.SubCategory = "Vision Augments"
SWEP.Author = "ye + Straw W Wagen"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_t7.mdl"

SWEP.GleeNVG = {
    lamp = 0.6,
    lampColor = Color( 70, 70, 100 ),
    lampFarZ = 2500, -- a short throw, it only lights what's close
    gain = 1, -- no brightening, just the colour pass below
    saturation = 1.5, -- stronger colours
    tint = Color( 230, 230, 255 ),
    vignette = { start = 0.5, finish = 0.95, aspect = "full", roundness = 4 }, -- one tube, a monocular
}

-- raysPerSecond = fired per second, spread over the frames, so the sweep runs the same speed at any framerate
-- a full sweep takes the cone's points / raysPerSecond seconds, see SWEP.Resolutions
-- pierce = total hammer units of solid each can go through before it stops,
-- length = how far one ray travels in total, solid and air together, before it gives up,
-- deflectEvery / deflectDegrees = every this many units of solid bends the ray this many degrees
-- short waves are many rays that barely get through anything, long waves are few that go through a lot
-- name fits the wheel, fullName is for the readout under the cone, when it's different
SWEP.Wavelengths = {
    { name = "Short",  raysPerSecond = 7200, pierce = 64,   length = 4000,  deflectEvery = 50, deflectDegrees = 5 },
    { name = "Medium", raysPerSecond = 3000, pierce = 256,  length = 8000,  deflectEvery = 50, deflectDegrees = 5 },
    { name = "Long",   raysPerSecond = 1200, pierce = 512,  length = 12000, deflectEvery = 50, deflectDegrees = 5 },
    { name = "ELong",  fullName = "Extra Long", raysPerSecond = 600,  pierce = 1024, length = 20000, deflectEvery = 50, deflectDegrees = 1 },
}

-- under SlowFps the sweep fires SlowShare of its rays per second
-- more rays on a frame that's already slow makes the next one slower still
SWEP.SlowFps = 30
SWEP.SlowShare = 0.5

-- how wide the cone the rays come out in is, whole width in degrees, picked from the wheel
SWEP.Cones = { 90, 40, 10 }

-- how dense the sweep's points are, picked from the wheel; a frame only walks a slice of them
-- points is how many fill the widest cone, a narrower one gets fewer, spaced the same
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

-- the picked entry, or the first while the index hasn't arrived yet
function SWEP:CurrentWavelength()
    return self.Wavelengths[self:GetWavelength()] or self.Wavelengths[1]

end

function SWEP:CurrentCone()
    return self.Cones[self:GetCone()] or self.Cones[1]

end

function SWEP:CurrentResolution()
    return self.Resolutions[self:GetResolution()] or self.Resolutions[1]

end

-- the goggles' own, then the radar's, keys handled by OnGleeAction in init.lua
function SWEP:GetGleeActions()
    local actions = BaseClass.GetGleeActions( self )

    -- each shows its current value, and hovered, the one picking it steps to
    local function setting( key, name, current, upcoming )
        return { key = key, label = name .. ": " .. current, hoveredLabel = "Next:\n" .. name .. ": " .. upcoming }

    end

    local nextWavelength = self.Wavelengths[self:NextIndex( self.Wavelengths, self:GetWavelength() )]
    local nextResolution = self.Resolutions[self:NextIndex( self.Resolutions, self:GetResolution() )]
    local nextCone = self.Cones[self:NextIndex( self.Cones, self:GetCone() )]

    table.Add( actions, {
        setting( "radar", "Radar", self:GetRadarOn() and "On" or "Off", self:GetRadarOn() and "Off" or "On" ),
        setting( "wavelength", "Wl", self:CurrentWavelength().name, nextWavelength.name ),
        setting( "resolution", "Res", self:CurrentResolution().name, nextResolution.name ),
        setting( "cone", "Cone", self:CurrentCone() .. "°", nextCone .. "°" ),
    } )

    return actions

end

function SWEP:Initialize()
    BaseClass.Initialize( self )
    self:SetWavelength( 1 )
    self:SetCone( 1 )

    -- on out of the box: the radar is the goggles' whole point, and a wearer who has never opened the
    -- wheel should still see it. server only, since the value is networked and the client would be
    -- writing over what the server is already sending it
    if SERVER then self:SetRadarOn( true ) end

    -- wavelength and resolution default to Medium by name, so reordering the lists keeps it
    for i, wavelength in ipairs( self.Wavelengths ) do
        if wavelength.name == "Medium" then
            self:SetWavelength( i )
            break

        end
    end

    self:SetResolution( 1 )
    for i, resolution in ipairs( self.Resolutions ) do
        if resolution.name == "Medium" then
            self:SetResolution( i )
            break

        end
    end
end
