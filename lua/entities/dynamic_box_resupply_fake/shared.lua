AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "dynamic_resupply_fake"

ENT.Category    = "Other"
ENT.PrintName   = "DynSupplies Present"
ENT.Author      = "Boomertaters"
ENT.Purpose     = "Creates real good juicy loot! Used in the present crate."
ENT.Spawnable    = true
ENT.AdminOnly    = game.IsDedicated()
ENT.Category = "Hunter's Glee"

function ENT:commonCreationOptions()
    local tbl = {
        { class = "termhunt_ar3" },
        { class = "termhunt_taucannon" },
        { class = "termhunt_score_pickup", count = 8 },
        { class = "termhunt_score_pickup", count = 4 },
        { class = "termhunt_score_pickup", count = 6 },
        { class = "termhunt_skull_pickup", count = 6 },
        { class = "termhunt_skull_pickup", count = 4 },

    }
    return tbl
end

ENT.rareCreationChance = 0.5

function ENT:rareCreationOptions()
    local tbl = {
        { class = "termhunt_divine_chosen" },
        { class = "weapon_flechettegun" }, -- spawn more often cuz dookie weapon
        { class = "weapon_flechettegun" },
        { class = "manhack_welder" },
        { class = "weapon_physgun" },
        
    }
    return tbl

end
