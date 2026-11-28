
-- Night vision goggles, worn on the eyes while carried, see glee_wearable_base.
-- Bought in the shop, see glee_shopitems/sh_default_items.lua.
-- Hold left click with them out for a wheel, flipping them down or up is on it.
-- Models and sounds come from Neosun's Cooler Nightvision, workshop 3425531829, copied into
-- models/glee/nvg, materials/models/glee/nvg and sound/hunters_glee/nvg, so only glee is needed.
-- The .mdl files had their internal name and texture folder paths repointed there.
--
-- Each goggle sets its own SWEP.GleeNVG, how its vision looks, see below.
-- The vision is cl_init.lua, what left click offers is below, what picking one does is init.lua.

SWEP.Base = "glee_wearable_base"
DEFINE_BASECLASS( "glee_wearable_base" )

SWEP.PrintName = "Vision Augments"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = false
SWEP.DrawCrosshair = true

SWEP.WorldModel = "models/glee/nvg/nvg_gpnvg.mdl"
SWEP.GleeWearSlot = "eyes"
SWEP.WornOnAttachment = {
    { attachment = "eyes", pos = Vector( -4, 0, -2 ) },
}

-- SWEP.GleeNVG, the vision, every field optional:
-- lamp = brightness of a light from the eyes, only the wearer sees it, lights pitch black. nil for none
-- lampColor = colour of that light, white if nil
-- lampFarZ = how far that light reaches
-- gain = the picture is multiplied by this, bigger blows lit areas out sooner. nil skips the colour pass
-- saturation = 0 turns the picture grey, 1 keeps the map's colours, above 1 makes them stronger
-- bloom = glare around bright spots
-- tint = the picture is then multiplied by this, black stays black and white becomes this colour
-- vignette = { start = , finish = , aspect = , roundness = }, a tube, round or a rounded square, or a border round the screen, darkens the edges, see drawVignette in cl_init.lua and CurrentVignette below
-- runSound, runSoundVolume = a loop that hums while they're down
SWEP.GleeNVG = {}

-- goggles with a picture of their own define SWEP:DrawGleeVision( wearer ), clientside
-- it's drawn over the picture after the tint, before the vignette. see glee_nvg_t7

-- goggles that draw into the world itself define SWEP:DrawGleeWorld( wearer ), clientside
-- it's drawn after everything else in the world, so it's in the picture the vision starts from. see glee_nvg_t7_deep

-- the vignette drawn this frame, goggles with a setting for it override this, see glee_nvg_t7
function SWEP:CurrentVignette()
    return self.GleeNVG.vignette

end

-- the index after index in list, round to the first after the last. what picking a setting steps it to
function SWEP:NextIndex( list, index )
    return index % #list + 1

end


-- each goggle file has to set these on its own table, the spawnmenu reads that and not the base's:
-- SWEP.PrintName, SWEP.Category = "Hunter's Glee", SWEP.SubCategory = "Vision Augments", SWEP.Spawnable = true,
-- SWEP.WorldModel, SWEP.GleeNVG

SWEP.GleeNVGOnSound = "hunters_glee/nvg/nvg_on_1.wav"
SWEP.GleeNVGOffSound = "hunters_glee/nvg/nvg_off_1.wav"

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool", "Down" ) -- flipped down over the eyes, seeing through them

    -- the click plays on every flip, from the wheel or from coming handed over already down
    if SERVER then self:NetworkVarNotify( "Down", self.OnDownChanged ) end

end

-- flipping, first, then the wearable's, keys handled by OnGleeAction in init.lua
-- goggles with more add theirs to this, see glee_nvg_pvs14
-- built as it's asked for, so the labels are current
function SWEP:GetGleeActions()
    local actions = BaseClass.GetGleeActions( self )
    table.insert( actions, 1, { key = "flip", label = self:GetDown() and "Flip up" or "Flip down" } )

    return actions

end
