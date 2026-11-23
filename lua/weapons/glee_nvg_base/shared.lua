
-- Night vision goggles, worn on the eyes while carried, see glee_wearable_base.
-- Bought in the shop, see glee_shopitems/sh_nightvision.lua.
-- Left click with them out flips them down or up.
-- Goggles with more to them, eg the haptic, hold left click for a wheel instead, flipping is on it.
-- Models and sounds come from Neosun's Cooler Nightvision, workshop 3425531829, copied into
-- models/glee/nvg, materials/models/glee/nvg and sound/hunters_glee/nvg, so only glee is needed.
-- The .mdl files had their internal name and texture folder paths repointed there.
--
-- Each goggle sets its own SWEP.GleeNVG, how its vision looks, see below.
-- The vision and the wheel are cl_init.lua, what picking from the wheel does is init.lua.

SWEP.Base = "glee_wearable_base"
SWEP.PrintName = "Night Vision"
SWEP.Category = "Hunter's Glee"
SWEP.Spawnable = false
SWEP.DrawCrosshair = true

SWEP.WorldModel = "models/glee/nvg/nvg_gpnvg.mdl"
SWEP.GleeWearSlot = "eyes"
SWEP.WornAttachment = "eyes"
SWEP.WornAttachmentPos = Vector( -4, 0, -2 )

-- SWEP.GleeNVG, the vision, every field optional:
-- lamp = brightness of a light from the eyes, only the wearer sees it, lights pitch black. nil for none
-- lampColor = colour of that light, white if nil
-- lampFarZ = how far that light reaches
-- gain = the picture is multiplied by this, bigger blows lit areas out sooner. nil skips the colour pass
-- saturation = 0 turns the picture grey, 1 keeps the map's colours, above 1 makes them stronger
-- bloom = glare around bright spots
-- tint = the picture is then multiplied by this, black stays black and white becomes this colour
-- heatColor = draw living npcs, players and nextbots in this colour on top; ragdolls get a flat grey
-- runSound, runSoundVolume = a loop that hums while they're down
SWEP.GleeNVG = {}

-- each goggle file has to set these on its own table, the spawnmenu reads that and not the base's:
-- SWEP.PrintName, SWEP.Category = "Hunter's Glee", SWEP.Spawnable = true, SWEP.WorldModel, SWEP.GleeNVG

SWEP.GleeNVGOnSound = "hunters_glee/nvg/nvg_on_1.wav"
SWEP.GleeNVGOffSound = "hunters_glee/nvg/nvg_off_1.wav"

function SWEP:SetupDataTables()
    self:NetworkVar( "Bool", "Down" ) -- flipped down over the eyes, seeing through them

end
