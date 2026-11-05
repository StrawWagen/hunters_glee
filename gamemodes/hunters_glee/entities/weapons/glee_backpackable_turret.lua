AddCSLuaFile()

DEFINE_BASECLASS( "glee_backpackable_base" )

SWEP.Base = "glee_backpackable_base"

SWEP.PrintName = "Combine Turret"
SWEP.Purpose = "Ain't that just the cutest turret ever!"
SWEP.Instructions = "Hold RELOAD to place."
SWEP.Slot = 4

if CLIENT then
    terminator_Extras.glee_CL_SetupSwep( SWEP, "glee_backpackable_turret", "materials/entities/npc_turret_floor.png" )

end

SWEP.HoldType = "physgun" -- both hands together out front, duel's are spread wide either side of it
SWEP.ViewModelOffset = Vector( 8, 0, 0 )

local glee_Turrets = terminator_Extras.glee_Turrets

terminator_Extras.glee_Carrying.RegisterUseActions( "npc_turret_floor", "glee_shopturret", {
    Matches = glee_Turrets.IsShopTurret,
    GleeCarryWeapon = "glee_backpackable_turret",
    GleeUseActions = glee_Turrets.UseActions,
    CanUseAction = glee_Turrets.CanUseAction,
    OnUseAction = glee_Turrets.OnUseAction,
} )

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

local turretClass = "npc_turret_floor"

-- the spawnmenu's Resistance Turret, made as sandbox makes NPCs from their list entry
local resistanceTurretKey = "npc_turret_floor_resistance"

SWEP.TurretNames = {
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
    "#####################",

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
    "TEARY EYED ORPHAN",
    "THE MICHELIN MAN",
    "MORBIDLY A BEAST",
    "TICKLE ME ELMO",
    "FEED ME AMMO",
    "EVISCERATOR",
    "YOUR OBITUARY",
    "BULLS EYE",
    "TROGDOR THE BURNINATOR",
    "DRAZZLE FRIP",
    "FULL COURSE MEAL",
    "R2D2",
    "MUSTY UNCLE",
    "NEW AND IMPROVED",
    "CONTROL FREAK",
    "COLD SHOULDER",
    "THE. WHOLE. ORDEAL.",

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
    "THE MEAT GRINDER",
    "#1 CAT FACTORY EMPLOYEE",
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
    "SALMONELLA",
    "SUPER COVID",
    "COVID-19",
    "EBOLA",
    "MALARIA INFECTED MOSQUITO",
    "RABID CHIPMUNK",
    "RICH SPOILED ORPHAN",
    "POOR PENNILESS ORPHAN",
    "WELL-LOVED CHILD",
    "ABUSED CHILD",
    "MAGIC POWERS",
    "ABANDONED INFANT",
    "BARGAIN BIN BILLY",
    "NERF GUN",
    "ORANGE TIPPED",
    "NOT A REAL GUN",
    "FAKER",
    "SLIM JIM",
    "SLIPPIN' JIMMY",
    "VEHICULAR HOMICIDE",
    "MASS MURDER 2",
    "CHICAGO 4",
    "THE FINAL BOSS",
    "KAREN OF ULTIMATE POWER",
    "THE RED BARON",
    "THE PRIME MINISTER OF YO MOMMA",
    "THE MOTHERFUCKING POPE",
    "MACHINE GOD",
    "FEED ME BABIES",
    "GLEELOV3R22",
    "GLEE PRO",
    "2CROWBARS2SKULLS",
    "LEON",
    "DEATH NOTE",
    "ALEXANDER THE GREAT",

    "BART",
    "HOMER",
    "EVIL HOMER",
    "BIG BAG FULL OF SNACKS",
    "ANGRY MEXICAN MOM",
    "THE BIG BAD WOLF",
    "MINECRAFT 2019 FREE DOWNLOAD",

    "FOOD METER",
    "BIG TONY",
    "FLOOR RECIEPT",
    "Scrooge McFrumpus",
    "SCALP OILS",
    "coughdropguzzle",

}

SWEP.RareNameChance = 0.01
SWEP.RareTurretNames = {
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
    "BABY HITLER KILLER",
    "CLANKER",
    "BRAP GODDESS",
    "CAN OF WHOOPASS",
    "12 GNOMES IN A TRENCHCOAT",
    "SMARTER THAN THE AVERAGE TURRET",
    "THE OFFENDER",
    "waltuh",
    "GARY, INDIANA",
    "GOD MOTHERFUCKING ZILLA",
    "i forgot",
    "I HEAR YOUR ORGANS",
    "PrtSc",
    "I AM MADE OF PURE OBAMIUM",
    "TRUST EXERCISE: LOOK DOWN MY BARREL",
    "MY BULLETS ARE MADE OF JELLIED EELS",
    "IM A REFRIGERATOR, NAIL ME DOWN OR I RUN AWAY",
    "i live in a low income housing environment",
    "#1 STEAL A BRAINROT FAN",
    "MOOSE PICTURE",
    "DORADO MOLD",
    "THE SIGMA",
    "SKIBIDI DOM DOM YES YES",
    "WouldYouRatherHaveANewHouseOrFifteenPears",
    "mrbeastscam.png",
    "iamracisttowardsnextbots3000",
    "skibiditoiletupdatecomingin3295",
    "kills you no dodge no block",
    "*dodges*",
    "#1 PNG NEXTBOT FAN",
    "BILLCYPHERLIVES",
    "PewDiePie",

}

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

    -- this weapon isn't spawnable, only the shop hands it out without a turret
    glee_Turrets.MarkShopTurret( turret, nil, self.TurretNames, self.RareTurretNames, self.RareNameChance )

    return turret

end

-- out of ammo, it stops shooting and lets its targets know it's empty
hook.Add( "glee_shopturret_hasammochanged", "glee_floorturret_ammoinputs", function( turret, hasAmmo )
    if turret:GetClass() ~= turretClass then return end

    if hasAmmo then
        turret:Fire( "RestoreAmmo" )

    else
        turret:Fire( "DepleteAmmo" )

    end
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

local npcDamageMul = 4 -- their bullets, against npcs
local shopNpcDamageMul = 6 -- instead, for the shop's, see glee_Turrets.IsShopTurret
local selfDestructDamage = 500 -- one hit bigger than this, and it blows itself up, rather than recharging off a shock

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

    dmgInfo:ScaleDamage( glee_Turrets.IsShopTurret( inflictor ) and shopNpcDamageMul or npcDamageMul )

end )
