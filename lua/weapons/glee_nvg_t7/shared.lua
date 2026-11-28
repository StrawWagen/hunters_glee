
-- Motion vision. Only what moves shows up, down a tube, everything else is black.
-- Its wheel picks how wide the tube is, the wider, the choppier the picture.
-- The motion camera is cl_init.lua, picking a width is init.lua, the rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
DEFINE_BASECLASS( "glee_nvg_base" )

SWEP.PrintName = "T-7 Motion Vision"
SWEP.Category = "Hunter's Glee"
SWEP.SubCategory = "Vision Augments"
SWEP.Author = "ye + Straw W Wagen"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_pvs14.mdl"

SWEP.GleeNVG = {
    lamp = 0.001,
    -- the goggles hum while they're down, the same sweep loop the haptic radar runs on
    runSound = "sound/glee/nvg/motiontracker_noise_loop.wav",
    runSoundVolume = 0.35,
}

-- lag = seconds back the frame it's compared against is. longer, slow movers show up more, and leave a ghost behind
-- threshold = changes smaller than this, out of 1, are dropped
-- gain = what's left is multiplied by this
-- afterglow = seconds what changed keeps glowing as it fades, about. why nothing's missed between redraws on wide tubes
-- grain = brightness of the static over it all, out of 1, redrawn every frame so it never looks frozen
SWEP.Motion = {
    lag = 0.1,
    threshold = 0.04,
    gain = 6,
    afterglow = 0.4,
    grain = 0.25,
}

-- how wide the tube is, picked from the wheel
-- vignette = the tube, see glee_nvg_base's vignette
-- refreshRate = times a second the picture's redrawn, nil for every frame
SWEP.Fovs = {
    { name = "Wide", vignette = { start = 0.8, finish = 1 }, refreshRate = 8 },
    { name = "Medium", vignette = { start = 0.6, finish = 0.8 }, refreshRate = 20 },
    { name = "Narrow", vignette = { start = 0.5, finish = 0.6 } }, -- like looking down a telescope
}

function SWEP:SetupDataTables()
    BaseClass.SetupDataTables( self )

    self:NetworkVar( "Int", "Fov" ) -- index into SWEP.Fovs

end

-- the picked entry, or the first while the index hasn't arrived yet
function SWEP:CurrentFov()
    return self.Fovs[self:GetFov()] or self.Fovs[1]

end

function SWEP:CurrentVignette()
    return self:CurrentFov().vignette

end

-- the goggles' own, then the width, its key handled by OnGleeAction in init.lua
function SWEP:GetGleeActions()
    local actions = BaseClass.GetGleeActions( self )
    local nextFov = self.Fovs[self:NextIndex( self.Fovs, self:GetFov() )]

    table.insert( actions, {
        key = "fov",
        label = "FOV: " .. self:CurrentFov().name,
        hoveredLabel = "Next:\nFOV: " .. nextFov.name,
    } )

    return actions

end

function SWEP:Initialize()
    BaseClass.Initialize( self )

    -- narrow by name, so reordering the list keeps it
    self:SetFov( 1 )
    for i, fov in ipairs( self.Fovs ) do
        if fov.name == "Narrow" then
            self:SetFov( i )
            break

        end
    end
end
