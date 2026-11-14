--[[
    The shop's turrets, whatever kind they are: a name, limited ammo refilled from suit charge or shocks,
    and a use wheel to recharge and rename them. All of it's on terminator_Extras.glee_Turrets.
    glee_Turrets.MarkShopTurret( turret, maxAmmo, names ), server side, makes one.
]]

terminator_Extras = terminator_Extras or {}
terminator_Extras.glee_Turrets = terminator_Extras.glee_Turrets or {}

local glee_Turrets = terminator_Extras.glee_Turrets

glee_Turrets.DefaultMaxAmmo = 1000
glee_Turrets.FullResupplyCharge = 50 -- suit charge, empty to full, whatever its max

function glee_Turrets.IsShopTurret( ent )
    return ent:GetNW2Bool( "glee_IsShopTurret", false )

end

function glee_Turrets.GetAmmo( turret )
    return turret:GetNW2Int( "glee_TurretAmmo", 0 )

end

function glee_Turrets.GetMaxAmmo( turret )
    return turret:GetNW2Int( "glee_TurretMaxAmmo", glee_Turrets.DefaultMaxAmmo )

end

function glee_Turrets.GetName( turret )
    return turret:GetNW2String( "glee_TurretName", "???" )

end

-- a shop turret's wheel, OnUseAction's server side, see sv_turrets
glee_Turrets.UseActions = {
    terminator_Extras.glee_Carrying.PickUpAction,
    { key = "resupply", label = "Recharge" },
    { key = "rename", label = "Rename" },
}

function glee_Turrets.CanUseAction( turret, ply, key )
    if key ~= "resupply" then return true end
    if not ply.PlayerHasBatteryCharge then return false end -- suit charge is the gamemode's
    if glee_Turrets.GetAmmo( turret ) >= glee_Turrets.GetMaxAmmo( turret ) then return false, "CANNOT CHARGE\nFully charged." end
    if not ply:PlayerHasBatteryCharge() then return false, "CANNOT CHARGE\nNo charge to give." end

    return true

end
