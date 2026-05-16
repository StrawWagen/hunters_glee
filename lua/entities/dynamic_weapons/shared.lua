AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Weapons"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Spawns random weapons"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

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

ENT.rareCreationChance = 2
function ENT:rareCreationOptions()
    local tbl = {
        { class = "termhunt_taucannon", count = 1 },
        { class = "termhunt_annabelle", count = 1 },
        { class = "termhunt_ar3", count = 1 },

    }
    return tbl

end
ENT.AmmoInsideWeaponsScale = 2