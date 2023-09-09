AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Specials"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops SMG nades, ar2 balls"
ENT.Spawnable    = true
ENT.Category = "Hunter's Glee"
ENT.AdminOnly    = false

function ENT:commonCreationOptions()
    local tbl = {
        { class = "item_ammo_smg1_grenade" },
        { class = "item_ammo_ar2_altfire" },
        { class = "item_rpg_round" },
        { class = "termhunt_score_pickup", count = 3 }

    }

    return tbl

end


ENT.rareCreationChance = -1