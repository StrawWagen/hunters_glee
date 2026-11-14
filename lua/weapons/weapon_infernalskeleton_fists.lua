AddCSLuaFile()

SWEP.Base = "weapon_terminatorfists_term"

SWEP.PrintName = "Infernal Skeleton Fists"
SWEP.Spawnable = false
SWEP.Author = "StrawWagen"
SWEP.Purpose = "Innate weapon that the infernal skeleton uses"

local className = "weapon_infernalskeleton_fists"
if CLIENT then
    language.Add( className, SWEP.PrintName )
    killicon.Add( className, "vgui/hud/killicon/" .. className .. ".png", color_white )

end
