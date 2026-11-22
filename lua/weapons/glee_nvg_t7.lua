AddCSLuaFile()

-- Thermal. Dulled, darker colours with a little night vision, anything warm shows up white. The rest is glee_nvg_base.

SWEP.Base = "glee_nvg_base"
SWEP.PrintName = "T-7 Thermal"
SWEP.Category = "Hunter's Glee"
SWEP.Author = "ye"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_t7.mdl"

SWEP.GleeNVG = {
    lamp = 0.001,
    gain = 0.6,
    saturation = 0.4, -- dulled colours
    heatColor = Color( 255, 255, 255 ), -- white hot: npcs, players and ragdolls read as pure white silhouettes
}
