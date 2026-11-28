
local glee_Turrets = terminator_Extras.glee_Turrets

-- for the bullet hooks, they run on every FireBullets on the server, this skips the NW2 lookup.
-- On glee_Turrets so autorefresh keeps it, weak so removed turrets drop out
glee_Turrets.ShopTurretSet = glee_Turrets.ShopTurretSet or setmetatable( {}, { __mode = "k" } )
local shopTurrets = glee_Turrets.ShopTurretSet

local maxNameLength = 30
local renameWindow = 30 -- seconds after picking Rename, their next chat message is the name

function glee_Turrets.SetAmmo( turret, ammo )
    turret:SetNW2Int( "glee_TurretAmmo", ammo )

    local statusLine = ammo .. "/" .. glee_Turrets.GetMaxAmmo( turret ) .. " rounds"
    if ammo <= 0 then statusLine = "Out of ammo" end
    turret:SetNWString( "glee_lookedat_statusline", statusLine )

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
function glee_Turrets.OnGleeAction( turret, ply, key )
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
    shopTurrets[turret] = true

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
local dryClickPitch = 90 -- where the low ammo clicks bottom out

-- Empty, its bullets are swallowed here, whatever kind of turret it is.
-- Not the floor turret's DepleteAmmo input, a floor turret that tips over while that's set plays
-- dead, and RestoreAmmo doesn't bring it back, see npc_turret_floor.cpp's PreThink
hook.Add( "EntityFireBullets", "glee_shopturret_dry", function( ent )
    if not shopTurrets[ent] then return end
    if glee_Turrets.GetAmmo( ent ) > 0 then return end

    ent:EmitSound( "weapons/pistol/pistol_empty.wav", 75, dryClickPitch, 1, CHAN_ITEM )
    return false

end )

hook.Add( "PostEntityFireBullets", "glee_shopturret_ammo", function( ent, data )
    if not shopTurrets[ent] then return end

    local ammo = glee_Turrets.GetAmmo( ent )
    if ammo <= 0 then return end

    ammo = math.max( ammo - ( data.Num or 1 ), 0 )
    glee_Turrets.SetAmmo( ent, ammo )

    if ammo >= lowAmmo then return end

    local pitch = math.Remap( ammo, lowAmmo, 0, 110, dryClickPitch )
    local volume = math.Remap( ammo, lowAmmo, 0, 0.5, 1 )
    ent:EmitSound( "weapons/pistol/pistol_empty.wav", 75, pitch, volume, CHAN_ITEM )

end )

-- npc_turret_floor's own tipped check, its up against the world's, see npc_turret_floor.cpp's OnSide
-- matching it means FL_NOTARGET goes on as the turret gives up
local tippedUpDot = 0.5

-- Tipped over and loose.
-- Welded or frozen, it's mounted, and can point any way it likes, eg under a helicopter
-- up, the turret's upright direction, not every model's is its GetUp
function glee_Turrets.IsTipped( turret, up )
    if up.z >= tippedUpDot then return false end
    if constraint.FindConstraint( turret, "Weld" ) then return false end

    local phys = turret:GetPhysicsObject()
    if IsValid( phys ) and not phys:IsMotionEnabled() then return false end

    return true

end

-- Tipped floor turrets get FL_NOTARGET, like the heavy turret's ENT:UpdateSad.
-- Every floor turret, whoever's side it's on, so other addons' NPCs leave them be too
local tippedCheckInterval = 0.5

timer.Create( "glee_floorturrets_notargettipped", tippedCheckInterval, 0, function()
    for _, turret in ipairs( ents.FindByClass( "npc_turret_floor" ) ) do
        local tipped = not terminator_Extras.glee_Carrying.IsCarried( turret ) and glee_Turrets.IsTipped( turret, turret:GetUp() )
        if tipped == ( turret.glee_Tipped or false ) then continue end

        turret.glee_Tipped = tipped
        if tipped then
            turret:AddFlags( FL_NOTARGET )

        else
            turret:RemoveFlags( FL_NOTARGET )

        end
    end
end )

local roundsPerShockDamage = 2

-- Post, after every EntityTakeDamage hook's had its say, some add DMG_SHOCK, eg the galvanizing gland's melee
hook.Add( "PostEntityTakeDamage", "glee_shopturret_shockrecharge", function( target, dmgInfo )
    if not glee_Turrets.IsShopTurret( target ) then return end
    if target.glee_SelfDestructing then return end
    if not dmgInfo:IsDamageType( DMG_SHOCK ) then return end

    glee_Turrets.AddAmmo( target, math.floor( dmgInfo:GetDamage() * roundsPerShockDamage ) )

end )
