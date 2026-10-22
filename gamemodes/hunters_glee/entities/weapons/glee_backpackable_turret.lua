AddCSLuaFile()

DEFINE_BASECLASS( "glee_backpackable_base" )

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Combine Turret"
SWEP.Purpose = "Put it down somewhere it'll do some good."
SWEP.Instructions = "Reload to place it down."
SWEP.Slot = 4

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_turret", "materials/entities/npc_turret_floor.png" )

end

SWEP.HoldType = "physgun" -- both hands together out front, duel's are spread wide either side of it
SWEP.ViewModelOffset = Vector( 8, 0, 0 )

-- The shop's turrets: limited ammo, refilled from suit charge, and a name ---

local maxAmmo = 1000
local fullResupplyCharge = 50 -- suit charge, empty to maxAmmo
local roundsPerCharge = maxAmmo / fullResupplyCharge

local maxNameLength = 30
local renameWindow = 30 -- seconds after picking Rename, their next chat message is the name

local function isShopTurret( ent )
    return ent:GetNW2Bool( "glee_IsShopTurret", false )

end

local function getAmmo( turret )
    return turret:GetNW2Int( "glee_TurretAmmo", 0 )

end

-- server only
local function setAmmo( turret, ammo )
    local hadAmmo = getAmmo( turret ) > 0

    turret:SetNW2Int( "glee_TurretAmmo", ammo )

    local statusLine = ammo .. "/" .. maxAmmo .. " rounds"
    if ammo <= 0 then statusLine = "Out of ammo" end
    turret:SetNWString( "glee_lookedat_statusline", statusLine )

    if hadAmmo and ammo <= 0 then
        turret:Fire( "DepleteAmmo" )

    elseif not hadAmmo and ammo > 0 then
        turret:Fire( "RestoreAmmo" )

    end
end

-- Server only. Up to maxAmmo, with a charge-up sound, higher the less was added
local function addAmmo( turret, amount )
    local ammo = getAmmo( turret )
    local added = math.min( maxAmmo, ammo + amount ) - ammo
    if added <= 0 then return end

    setAmmo( turret, ammo + added )

    local pitch = math.Clamp( math.Remap( added, 1, maxAmmo, 200, 150 ), 150, 200 )
    turret:EmitSound( "weapons/physcannon/physcannon_charge.wav", 60, pitch )

end

terminator_Extras.glee_Carrying.RegisterUseActions( "npc_turret_floor", "glee_shopturret", {
    Matches = isShopTurret,
    GleeCarryWeapon = "glee_backpackable_turret",
    GleeUseActions = {
        terminator_Extras.glee_Carrying.PickUpAction,
        { key = "resupply", label = "Recharge" },
        { key = "rename", label = "Rename" },
    },
    CanUseAction = function( turret, ply, key )
        if key ~= "resupply" then return true end
        if getAmmo( turret ) >= maxAmmo then return false, "It's fully loaded." end
        if not ply:PlayerHasBatteryCharge() then return false, "You've got no suit charge to spare." end

        return true

    end,
    -- resupply spends what suit charge they have, up to a full resupply's worth
    OnUseAction = function( turret, ply, key )
        if key == "rename" then
            ply.glee_RenamingTurret = turret
            ply.glee_RenamingTurretUntil = CurTime() + renameWindow
            huntersGlee_Announce( { ply }, 5, 5, "Type its new name in chat." )
            return true

        end

        local ammo = getAmmo( turret )
        local chargeWanted = ( maxAmmo - ammo ) / roundsPerCharge
        local chargeSpent = math.min( chargeWanted, ply:GetBatteryCharge() )

        ply:GivePlayerBatteryCharge( -chargeSpent )
        addAmmo( turret, math.floor( chargeSpent * roundsPerCharge ) )

        turret:EmitSound( "items/ammo_pickup.wav", 70, 90 )

        return true

    end,
} )

if CLIENT then
    local turretColor = Vector( 255, 190, 0 ) / 255

    hook.Add( "EntityNetworkedVarChanged", "glee_shopturret_nick", function( ent, varName )
        if varName ~= "glee_TurretName" then return end

        -- "" hides its name tag, see glee_nametag
        ent.Nick = function()
            if terminator_Extras.glee_Carrying.IsCarried( ent ) then return "" end
            return ent:GetNW2String( "glee_TurretName", "???" )

        end
        ent.GetPlayerColor = function()
            return turretColor

        end

        -- the name panels only pick up ents that had a Nick when they were created
        timer.Simple( 0, function()
            if not IsValid( ent ) then return end
            hook.Run( "glee_cl_proxyhud_pleasepaintthis", ent )

        end )
    end )
end


-- any floor turret, whoever's side it's on
terminator_Extras.glee_Carrying.RegisterCarryable( "npc_turret_floor", "glee_backpackable_turret" )

-- upper arms swung in towards each other, palms facing in
SWEP.ViewModelBoneMods = terminator_Extras.glee_Carrying.ElitesBoneMods( -20, 0, 0 )

-- starting points, needs tuning in game
SWEP.HeldModelPos, SWEP.HeldModelAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 4, 4, 18 ), Angle( 180, 160, -1 ) )
SWEP.HeldModelScale = 0.6

SWEP.WorldModelHandPos, SWEP.WorldModelHandAng = terminator_Extras.glee_Carrying.SCKToLocal( Vector( 10, 0, 25 ), Angle( 180, 180, -4 ) )
SWEP.WorldModelHandScale = 1

SWEP.WorldModelBackPos = Vector( -25, -6, -15 )
SWEP.WorldModelBackAng = Angle( 60, 0, 0 )
SWEP.WorldModelBackScale = 0.9

SWEP.PlaceDistance = 115
SWEP.PlacedUpOffset = 2
SWEP.PlacedSound = {
    pitch = 80,
    sounds = {
        { path = "physics/metal/metal_computer_impact_bullet1.wav" },
        { path = "physics/metal/metal_computer_impact_bullet2.wav" },
        { path = "physics/metal/metal_computer_impact_bullet3.wav" },
    },
}

if not SERVER then return end

-- the spawnmenu's Resistance Turret, made as sandbox makes NPCs from their list entry
local resistanceTurretKey = "npc_turret_floor_resistance"

local turretNames = {
    "THE SECOND AMENDMENT",
    "DONKEY JAWBONE",

    "BENJAMIN FRANKLIN",
    "GIANT FUCKASS BOB",
    "PRINCIPAL NORRIS",
    "QUIZNOS THE DESTROYER",
    "VOLATILE GREEN EGG",
    "FRAGRANCE MAN",
    "COMBINE GRUNT #5",
    "COMBINE GRUNT #6",
    "COMBINE GRUNT #9",
    "GREG",
    "GREG 2",
    "BENDER BENDING RODRIGUEZ",
    "BROGLE",
    "THE SINNER",
    "FREE SCORE! STAND IN FRONT OF ME",
    "NONDESCRIPT PILE OF GOOP",
    "I EAT DIRT",
    "THE OVERMIND",
    "I'M WITH STUPID",
    "SHITASS",
    "[CENSORED]",
    "YO MOMMA",
    "GROK III",
    "CLEAN HARRY",
    "CAPTAIN UNDERPANTS",
    "EVERY SINGLE POWER RANGER",
    "THE MOTHERFUCKING BATMAN",
    "EVIL SATAN",

    "WOMP WOMPINATOR",
    "SKULL_GRINDER_9000",
    "JOE",

    "BALKAN DAD",
    "FUCKING CHATGPT",
    "SANDWICH",

    "EAGER GEEKER",
    "CRINE BOI BILLY",
    "MAJOR TOM",
    "DRAGON DEEZ DAVE",
    "YOUR MAKER",
    "RICK ROLL",
    "PULL MY FINGER",
    "SUITE SIOUXANNE",
    "THE HAPPY GANGSTER",
    "BALLS ALLOUT",
    "THE FABULOUS DISASTER",
    "DIRTY HARRY",
    "EYES EMOJI",

    "OCTAGON",
    "NULL",
    "xX_FeedMeArmor_Xx",
    "SKULL EATER",
    "SKULL",
    "INFERNAL BASTARD",
    "THE GOD CRAB",
    "VOID_LOVER",
    "GOD",
    "INFERNAL FANATIC",
    "SMELL YOU LATER",
    "JEREMY",
    "JEREMY 2",
    "CORROSIVE MURDER",
    "WTF",
    "BEEP BOOP",
    "COUGHING BABY",
    "NUCLEAR WARHEAD",
    "POINT AND SHOOT",
    "BOOM HEADSHOT",
    "xX_NEVERMISSES_Xx",
    "FATHER GRIGORI",
    "GOT MILK?",
    "G-MAN",
    "BARNEY, FROM BLACK MESA",
    "THAT BEER",
    "BUUUUURP",
    "ALYX VANCE",
    "SUPREME OVERLORD",
    "DIMENSIONAL RIFT",
    "VEGAN",
    "CARNIVORE",
    "I_EAT_JERMAS",
    "NO_TERMINATORS_PLEASE",
    "TOOLGUN",
    "PHYSGUN",
    "GARRY NEWMAN",
    "GABE NEWELL",
    "FORTNITE",
    "HAMSTERS NEVER DIE OF OLD AGE",

    "BART",
    "HOMER",
    "EVIL HOMER",
    "BIG BAG FULL OF SNACKS",

}

local rareNameChance = 0.01
local rareTurretNames = {
    "bethel",
    "crawl with me",
    "JESUS CHRIST",
    "THE GOBLIN JERMA KING",
    "THE HORROR",
    "I TIME TRAVELED FROM THE 17TH CENTURY TO MURDER HITLER",
    "NOOOOOOOOOOOOOOOOOOOOOOOO",
    "GOD CRAB SKULL",
    "THE MECHANICAL MENACE",
    "HOW DO YOU LIKE THAT, OBAMA?!",
    "SHADOW THE HEDGEHOG",
    "BITCH-ASS MOTHERFUCKER",
    "FUCKED MY WIFE",
    "9/11 2",
    "THE NORTH TOWER",
    "JET FUELED",
    "MrTurretDude",
    "CANDY",
    "FUCKING BILLIONAIRE",
    "CROID",

}

local function pickTurretName()
    local names = turretNames
    if math.random() < rareNameChance then names = rareTurretNames end

    return names[math.random( #names )]

end

function SWEP:CreateCarryEnt( pos )
    local data = list.Get( "NPC" )[resistanceTurretKey]
    if not data then return end

    local turret = ents.Create( data.Class )
    if not IsValid( turret ) then return end

    local spawnFlags = bit.bor( SF_NPC_FADE_CORPSE, SF_NPC_ALWAYSTHINK )
    if data.SpawnFlags then spawnFlags = bit.bor( spawnFlags, data.SpawnFlags ) end
    if data.TotalSpawnFlags then spawnFlags = data.TotalSpawnFlags end
    turret:SetKeyValue( "spawnflags", spawnFlags )

    for key, value in pairs( data.KeyValues or {} ) do
        turret:SetKeyValue( key, value )

    end

    if data.Model then turret:SetModel( data.Model ) end
    if data.Skin then turret:SetSkin( data.Skin ) end
    if data.Material then turret:SetMaterial( data.Material ) end

    turret:SetPos( pos )
    turret:Spawn()
    turret:Activate()

    if data.Health then
        turret:SetMaxHealth( data.Health )
        turret:SetHealth( data.Health )

    end

    timer.Simple( 0.25, function() -- for some reason glee_IsShopTurret is super unreliable unless this is done
        if not IsValid( turret ) then return end
        -- this weapon isn't spawnable, only the shop hands it out without a turret
        turret:SetNW2Bool( "glee_IsShopTurret", true )

        turret:SetNW2String( "glee_TurretName", pickTurretName() )

    end )
    setAmmo( turret, maxAmmo )

    turret.Nick = function()
        return turret:GetNW2String( "glee_TurretName", "???" )

    end

    return turret

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

hook.Add( "PostEntityFireBullets", "glee_shopturret_ammo", function( ent )
    if not isShopTurret( ent ) then return end

    local ammo = getAmmo( ent )
    if ammo <= 0 then return end

    ammo = ammo - 1
    setAmmo( ent, ammo )

    if ammo >= lowAmmo then return end

    local pitch = math.Remap( ammo, lowAmmo, 0, 110, 90 )
    local volume = math.Remap( ammo, lowAmmo, 0, 0.5, 1 )
    ent:EmitSound( "weapons/pistol/pistol_empty.wav", 75, pitch, volume, CHAN_ITEM )

end )

local redisableInterval = 0.25

-- the engine starts these on the turret itself and doesn't always stop them, a carried one would keep
-- alarming or whirring on someone's back. Its sound scripts' names, the ones that can be left going
local turretLoopingSounds = {
    "NPC_FloorTurret.Alarm",
    "NPC_FloorTurret.AlarmPing",
    "NPC_FloorTurret.Move",
    "NPC_FloorTurret.Ping",
    "NPC_FloorTurret.Alert",
    "NPC_FloorTurret.Activate",
}

local function stopTurretLoops( turret )
    for _, soundName in ipairs( turretLoopingSounds ) do
        turret:StopSound( soundName )

    end
end

-- Off while it rides on someone, it'd be shooting from their back. It turns itself back on when it's
-- stood upright, which carrying it can do, so it's kept off for as long as it's carried
function SWEP:KeepTurretDisabled()
    if ( self.glee_NextRedisable or 0 ) > CurTime() then return end
    self.glee_NextRedisable = CurTime() + redisableInterval

    local ent = self:GetCarriedEnt()
    if not IsValid( ent ) then return end

    ent:Fire( "Disable" )
    stopTurretLoops( ent )

end

function SWEP:Think()
    BaseClass.Think( self )
    self:KeepTurretDisabled()

end

function SWEP:OnBackThink()
    self:KeepTurretDisabled()

end

function SWEP:OnCarryStart( ent )
    ent:Fire( "Disable" )
    stopTurretLoops( ent )

end

function SWEP:OnCarryEnd( ent )
    ent:Fire( "Enable" )
    ent:SetCollisionGroup( COLLISION_GROUP_NPC )

end


-- Every floor turret, carried or not, the shop's and the map's alike --------

local turretClass = "npc_turret_floor"

local npcDamageMul = 4 -- their bullets, against npcs
local shopNpcDamageMul = 6 -- instead, for the shop's, see isShopTurret
local selfDestructDamage = 500 -- one hit bigger than this, and it blows itself up
local roundsPerShockDamage = 2 -- a shock short of selfDestructDamage recharges a shop turret instead

hook.Add( "EntityTakeDamage", "glee_turrettweaks", function( target, dmgInfo )
    if target:GetClass() == turretClass then
        if dmgInfo:GetDamage() <= selfDestructDamage then return end
        if target.glee_SelfDestructing then return end

        target.glee_SelfDestructing = true
        target:Fire( "SelfDestruct" )

        -- self destructing never calls OnNPCKilled, this is just the gamemode's killfeed half of it
        GAMEMODE:OnNPCKilled( target, dmgInfo:GetAttacker(), dmgInfo:GetInflictor() )
        return

    end

    if not target:IsNPC() then return end

    local inflictor = dmgInfo:GetInflictor()
    if not IsValid( inflictor ) or inflictor:GetClass() ~= turretClass then return end

    dmgInfo:ScaleDamage( isShopTurret( inflictor ) and shopNpcDamageMul or npcDamageMul )

end )

-- Post, after every EntityTakeDamage hook's had its say, some add DMG_SHOCK, eg the galvanizing gland's melee
hook.Add( "PostEntityTakeDamage", "glee_shopturret_shockrecharge", function( target, dmgInfo )
    if target:GetClass() ~= turretClass then return end
    if not isShopTurret( target ) then return end
    if target.glee_SelfDestructing then return end
    if not dmgInfo:IsDamageType( DMG_SHOCK ) then return end

    addAmmo( target, math.floor( dmgInfo:GetDamage() * roundsPerShockDamage ) )

end )
