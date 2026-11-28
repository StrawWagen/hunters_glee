
-- Deep motion vision. The T-7, but anything alive moving nearby shows up through walls too.
-- Drawing them is cl_init.lua, everything else is glee_nvg_t7.

SWEP.Base = "glee_nvg_t7"

SWEP.PrintName = "T-8 Deep Motion Vision"
SWEP.Category = "Hunter's Glee"
SWEP.SubCategory = "Vision Augments"
SWEP.Author = "ye + Straw W Wagen"
SWEP.Spawnable = true
SWEP.WorldModel = "models/glee/nvg/nvg_pvs14.mdl"

-- range = past this, nothing shows through walls
-- fadeFrom = from this far out, they dim, to nothing at range
SWEP.Deep = {
    range = 900,
    fadeFrom = 500,
}
