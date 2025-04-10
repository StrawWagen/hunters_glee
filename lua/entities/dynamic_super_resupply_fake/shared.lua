AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Super"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops either armor or medkits, chance to spawn weapon is much higher, Used in screaming/beacon crate"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

function ENT:commonCreationOptions()
    local tbl = {
        { class = "item_battery", count = 1 },
        { class = "item_healthkit" },
        { class = "item_healthvial" }

    }

    return tbl

end


ENT.rareCreationChance = 35

function ENT:rareCreationOptions()
    local tbl = {
        { class = "weapon_frag", count = 4 },
        { class = "weapon_slam", count = 4 },
        { class = "termhunt_weapon_beartrap", count = 2 },
        { class = "item_battery", count = 4 },
        { class = "termhunt_score_pickup", count = 3 },
        { class = "item_ammo_smg1_grenade", count = 3 },
        { class = "weapon_smg1" },
        { class = "item_ammo_ar2_altfire", count = 3 },
        { class = "weapon_ar2" },
        { class = "weapon_stunstick" },
        { class = "weapon_shotgun" },
        { class = "weapon_rpg" },
        { class = "item_rpg_round", count = 3 },
        { class = "weapon_pistol" },
        { class = "termhunt_aeromatix_flare_gun" },
    }
    return tbl

end

ENT.AmmoInsideWeaponsScale = 2