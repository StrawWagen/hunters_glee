AddCSLuaFile()

game.AddAmmoType( {
    name = "GLEE_NAILS",
    dmgtype = DMG_BULLET,
    tracer = TRACER_LINE,
    maxcarry = 9999,

} )

game.AddAmmoType( {
    name = "GLEE_BEARTRAP",
    dmgtype = DMG_CRUSH,
    tracer = TRACER_NONE,
    maxcarry = 9999,

} )

game.AddAmmoType( {
    name = "GLEE_FLAREGUN_PLAYER", -- Note that whenever picked up, the localization string will be '#BULLET_PLAYER_556MM_ammo'
    dmgtype = DMG_BURN,
    tracer = TRACER_NONE,
    plydmg = 25, -- This can either be a number or a ConVar name.
    npcdmg = 25, -- Ditto.
    force = 0,
    maxcarry = 9999, -- Ditto.
    minsplash = 0,
    maxsplash = 0
} )

game.AddAmmoType( {
    name = "GLEE_SIGNALFLAREGUN_PLAYER",
    dmgtype = DMG_BURN,
    tracer = TRACER_NONE,
    plydmg = 45, -- This can either be a number or a ConVar name.
    npcdmg = 45, -- Ditto.
    force = 0,
    maxcarry = 9999, -- Ditto.
    minsplash = 0,
    maxsplash = 0
} )

game.AddAmmoType( {
    name = "Uranium_235",
    dmgtype = DMG_AIRBOAT
} )

game.AddAmmoType( {
    name = "GLEE_ANNABELLE_SLUGS",
    dmgtype = bit.bor( DMG_BULLET, DMG_SNIPER ), -- DMG_SNIPER penetrates .DoMetallicDamage npc dmg resist
} )
