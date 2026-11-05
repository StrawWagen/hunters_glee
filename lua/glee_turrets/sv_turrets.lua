
local glee_Turrets = terminator_Extras.glee_Turrets

local maxNameLength = 30
local renameWindow = 30 -- seconds after picking Rename, their next chat message is the name

-- Runs glee_shopturret_hasammochanged( turret, hasAmmo ) as it runs out, or gets some back
function glee_Turrets.SetAmmo( turret, ammo )
    local hadAmmo = glee_Turrets.GetAmmo( turret ) > 0

    turret:SetNW2Int( "glee_TurretAmmo", ammo )

    local statusLine = ammo .. "/" .. glee_Turrets.GetMaxAmmo( turret ) .. " rounds"
    if ammo <= 0 then statusLine = "Out of ammo" end
    turret:SetNWString( "glee_lookedat_statusline", statusLine )

    local hasAmmo = ammo > 0
    if hadAmmo ~= hasAmmo then
        hook.Run( "glee_shopturret_hasammochanged", turret, hasAmmo )

    end
end

-- Up to its max, with a charge-up sound, higher the less was added
function glee_Turrets.AddAmmo( turret, amount )
    local maxAmmo = glee_Turrets.GetMaxAmmo( turret )
    local ammo = glee_Turrets.GetAmmo( turret )
    local added = math.min( maxAmmo, ammo + amount ) - ammo
    if added <= 0 then return end

    glee_Turrets.SetAmmo( turret, ammo + added )

    local pitch = math.Clamp( math.Remap( added, 1, maxAmmo, 200, 150 ), 150, 200 )
    turret:EmitSound( "weapons/physcannon/physcannon_charge.wav", 60, pitch )

end

-- resupply spends what suit charge they have, up to a full resupply's worth
function glee_Turrets.OnUseAction( turret, ply, key )
    if key == "rename" then
        ply.glee_RenamingTurret = turret
        ply.glee_RenamingTurretUntil = CurTime() + renameWindow
        huntersGlee_Announce( { ply }, 5, 5, "Type its new name in chat." )
        return true

    end

    local maxAmmo = glee_Turrets.GetMaxAmmo( turret )
    local roundsPerCharge = maxAmmo / glee_Turrets.FullResupplyCharge

    local ammo = glee_Turrets.GetAmmo( turret )
    local chargeWanted = ( maxAmmo - ammo ) / roundsPerCharge
    local chargeSpent = math.min( chargeWanted, ply:GetBatteryCharge() )

    ply:GivePlayerBatteryCharge( -chargeSpent )
    glee_Turrets.AddAmmo( turret, math.floor( chargeSpent * roundsPerCharge ) )

    turret:EmitSound( "items/ammo_pickup.wav", 70, 90 )

    return true

end

local function pickTurretName( names, rareNames, rareChance )
    if rareNames and #rareNames > 0 and math.random() < rareChance then names = rareNames end

    local name = names[math.random( #names )]
    if isfunction( name ) then name = name() end

    return name

end

-- A random name, full ammo, and kills near players move the hunters' spawns forward, see sv_hunterspawner.
-- maxAmmo, optional, DefaultMaxAmmo without it
-- names, the pool its name's picked from, strings or functions returning one
-- rareNames and rareChance, optional, the pool it's swapped for, rareChance of the time
function glee_Turrets.MarkShopTurret( turret, maxAmmo, names, rareNames, rareChance )
    if not names or #names == 0 then error( "MarkShopTurret needs a names pool", 2 ) end

    turret:SetNW2Int( "glee_TurretMaxAmmo", maxAmmo or glee_Turrets.DefaultMaxAmmo )

    timer.Simple( 0.25, function() -- for some reason glee_IsShopTurret is super unreliable unless this is done
        if not IsValid( turret ) then return end
        turret:SetNW2Bool( "glee_IsShopTurret", true )

        turret:SetNW2String( "glee_TurretName", pickTurretName( names, rareNames, rareChance ) )

    end )
    glee_Turrets.SetAmmo( turret, glee_Turrets.GetMaxAmmo( turret ) )

    turret.glee_TriggersForwardSpawns = true

    turret.Nick = function()
        return glee_Turrets.GetName( turret )

    end
end

-- by characters, not bytes, so a multibyte name isn't cut mid-character
local function trimName( text )
    text = string.Trim( text )

    local cutAt = utf8.offset( text, maxNameLength + 1 )
    if cutAt then text = string.sub( text, 1, cutAt - 1 ) end

    return text

end

-- if ulib, run last, after chat filters have had their go at it
hook.Add( "PlayerSay", "glee_shopturret_rename", function( speaker, text )
    local turret = speaker.glee_RenamingTurret
    if not turret then return end

    speaker.glee_RenamingTurret = nil

    if not IsValid( turret ) then return end
    if speaker.glee_RenamingTurretUntil < CurTime() then return end
    if not speaker:Alive() then return end

    local name = trimName( text )
    if name == "" then return end

    turret:SetNW2String( "glee_TurretName", name )
    turret:EmitSound( "npc/turret_floor/deploy.wav", 67 )

end, HOOK_LOW )

local lowAmmo = 100 -- under this, each shot clicks, lower and louder as it runs dry

hook.Add( "PostEntityFireBullets", "glee_shopturret_ammo", function( ent, data )
    if not glee_Turrets.IsShopTurret( ent ) then return end

    local ammo = glee_Turrets.GetAmmo( ent )
    if ammo <= 0 then return end

    ammo = math.max( ammo - ( data.Num or 1 ), 0 )
    glee_Turrets.SetAmmo( ent, ammo )

    if ammo >= lowAmmo then return end

    local pitch = math.Remap( ammo, lowAmmo, 0, 110, 90 )
    local volume = math.Remap( ammo, lowAmmo, 0, 0.5, 1 )
    ent:EmitSound( "weapons/pistol/pistol_empty.wav", 75, pitch, volume, CHAN_ITEM )

end )

local roundsPerShockDamage = 2

-- Post, after every EntityTakeDamage hook's had its say, some add DMG_SHOCK, eg the galvanizing gland's melee
hook.Add( "PostEntityTakeDamage", "glee_shopturret_shockrecharge", function( target, dmgInfo )
    if not glee_Turrets.IsShopTurret( target ) then return end
    if target.glee_SelfDestructing then return end
    if not dmgInfo:IsDamageType( DMG_SHOCK ) then return end

    glee_Turrets.AddAmmo( target, math.floor( dmgInfo:GetDamage() * roundsPerShockDamage ) )

end )
