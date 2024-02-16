AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Weapons"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Spawns random weapons"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

function ENT:commonCreationOptions()
    local tbl = {
        { class = "weapon_slam", count = 4 },
        { class = "weapon_frag", count = 4 },
        { class = "weapon_shotgun" },
        { class = "weapon_rpg" },
        { class = "weapon_pistol" },
        { class = "weapon_ar2" },
        { class = "weapon_357" },
        { class = "weapon_stunstick" },
        { class = "termhunt_aeromatix_flare_gun" },
        { class = "termhunt_weapon_beartrap", count = 2 },
        { class = "weapon_crossbow" }

    }

    return tbl

end


ENT.rareCreationChance = 0
ENT.AmmoInsideWeaponsScale = 2