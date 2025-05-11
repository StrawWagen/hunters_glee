AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Specials"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "Drops SMG nades, ar2 balls, spawned rarely by 'normal' supplies"
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

function ENT:commonCreationOptions()
    local tbl = {
        { class = "item_ammo_smg1_grenade" },
        { class = "item_ammo_ar2_altfire" },
        { class = "item_rpg_round", count = 2 },
        { class = "termhunt_score_pickup", count = 3 },

    }

    return tbl

end


ENT.rareCreationChance = 10

function ENT:rareCreationOptions()
    local tbl = {
        { class = "item_battery", count = 2 },

    }
    return tbl

end