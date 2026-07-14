AddCSLuaFile()

-- a bigger, tankier infernal skeleton. inherits all the ai/tasks/rendering/sounds,
-- only overrides the knobs that make it "big"
ENT.Base = "terminator_nextbot_infernalskeleton"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Big Infernal Skeleton"
ENT.Spawnable = false

local className = "terminator_nextbot_infernalskeleton_big"
list.Set( "NPC", className, {
    Name = "Big Infernal Skeleton",
    Class = className,
    Category = "Hunter's Glee",
    Weapons = { "weapon_infernalskeleton_fists" },
} )

if CLIENT then
    language.Add( className, ENT.PrintName )

    return

end

-- big
ENT.TERM_MODELSCALE = 1.75
local standxy = 8
local crouchxy = 7
ENT.CollisionBounds = { Vector( -standxy, -standxy, 0 ), Vector( standxy, standxy, 45 ) } -- this is then scaled by modelscale
ENT.CrouchCollisionBounds = { Vector( -crouchxy, -crouchxy, 0 ), Vector( crouchxy, crouchxy, 30 ) } -- this is then scaled by modelscale
ENT.MyPhysicsMass = 200

-- tanky mini-boss, not fodder
ENT.SpawnHealth = 300
ENT.IsFodder = false
ENT.ReallyHeavy = true -- crushes skulls underfoot, worth shooting for the heli, etc.
ENT.ReallyStrong = true

-- longer reach and heavier hits to match the size
ENT.FistDamageMul = 0.4
ENT.CloseEnemyDistance = 700

-- always keep the head so it drops a ( big ) skull
ENT.SpawnHeadlessChance = 0
