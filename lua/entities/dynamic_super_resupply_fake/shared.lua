AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Super"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops either armor or medkits, chance to spawn weapon is much higher, Used in screaming/beacon crate"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

function ENT:commonCreationOptions()
    local tbl = {
        { class = "item_battery" },
        { class = "item_healthkit" },
        { class = "item_healthvial" }

    }

    return tbl

end


ENT.rareCreationChance = 30

function ENT:rareCreationOptions()
    local tbl = {
        { class = "weapon_frag", count = 4 },
        { class = "item_ammo_smg1_grenade", count = 3 },
        { class = "termhunt_score_pickup", count = 3 },
        { class = "weapon_slam", count = 2 },
        { class = "weapon_stunstick" },
        { class = "termhunt_aeromatix_flare_gun" },
        { class = "weapon_shotgun" },
        { class = "weapon_rpg" },
        { class = "weapon_pistol" }

    }
    return tbl

end

ENT.AmmoInsideWeaponsScale = 1.5