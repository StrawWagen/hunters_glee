AddCSLuaFile()

-- Thermal. Dulled, darker colours with a little night vision, anything warm shows up white. The rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
SWEP.PrintName = "T-7 Thermal"
SWEP.Category = "Hunter's Glee"
SWEP.SubCategory = "Night Vision"
SWEP.Author = "ye"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_t7.mdl"

SWEP.GleeNVG = {
    lamp = 0.001,
    gain = 0.7,
    saturation = 0.6, -- dulled colours
    heatColor = Color( 255, 255, 255 ), -- white hot
    vignette = { start = 0.5, finish = 0.98 },
    -- the goggles hum while they're down, the same sweep loop the haptic radar runs on
    runSound = "sound/glee/nvg/motiontracker_noise_loop.wav",
    runSoundVolume = 0.35,
}
