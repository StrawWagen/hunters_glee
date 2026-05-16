AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Heavy Weapons"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Spawns random heavy weapons"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

function ENT:commonCreationOptions()
    local tbl = {
        { class = "termhunt_taucannon" },
        { class = "termhunt_ar3" },
        { class = "termhunt_annabelle" },

    }

    return tbl

end


ENT.rareCreationChance = 15

function ENT:rareCreationOptions()
    local tbl = {
        { class = "weapon_rpg" },
        { class = "weapon_ar2" },
        { class = "item_ammo_ar2_altfire", count = 8 },
        { class = "item_ammo_ar2_altfire", count = 4 },

    }
    return tbl

end

ENT.AmmoInsideWeaponsScale = 2