AddCSLuaFile()

-- Normal night vision. Grey, brightened and green, sees in the dark, lit areas blow out. The rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
SWEP.PrintName = "GPNVG-18 Night Vision"
SWEP.Category = "Hunter's Glee"
SWEP.SubCategory = "Night Vision"
SWEP.Author = "ye"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_gpnvg.mdl"

SWEP.GleeNVG = {
    lamp = 0.01, -- any brighter washes out up close
    gain = 5,
    saturation = 0,
    bloom = { darken = 0.6, multiply = 2, size = 6, passes = 2 },
    tint = Color( 80, 255, 80 ), -- green
}
