AddCSLuaFile()

SWEP.Base = "weapon_terminatorfists_term"
SWEP.PrintName = "Boderman Fists"
SWEP.Author = "regunkyle"
SWEP.Purpose = "The claws of Boderman."

SWEP.Range = 80
SWEP.Weight = 0

if CLIENT then
    language.Add("weapon_boderman_fists", SWEP.PrintName)
    killicon.Add("weapon_boderman_fists", "Hud/killicons/default", Color(255, 255, 255))
end