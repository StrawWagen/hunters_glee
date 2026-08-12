AddCSLuaFile()

-- a bigger, tankier infernal skeleton. inherits all the ai/tasks/rendering/sounds,
-- only overrides the knobs that make it "big"
ENT.Base = "terminator_nextbot_infernalskeleton"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Infernal Ambler"
ENT.Spawnable = false

terminator_Extras.RegisterNPC( "terminator_nextbot_infernalskeleton_slow", ENT, {
    Weapons = { "weapon_infernalskeleton_fists" },

} )

if CLIENT then
    ENT.FireParticleChance = 0

end

ENT.SpawnHealth = 25
ENT.SpawnHeadlessChance = 95

ENT.FistDamageMul = 0.1

ENT.JumpHeight = 50
ENT.Term_Leaps = false

ENT.TERM_MODELSCALE = function() return math.Rand( 0.85, 0.95 ) end

ENT.Term_FootstepSound = { -- running sounds
    {
        path = "physics/wood/wood_plank_impact_soft2.wav",
        lvl = 73,
        pitch = { 180, 190 },
    },
    {
        path = "physics/wood/wood_plank_impact_soft3.wav",
        lvl = 73,
        pitch = { 180, 190 },
    },
}

local walkStart = ACT_HL2MP_WALK_ZOMBIE_01
local function randomWalk( ent )
    return walkStart + ( ent:GetCreationID() % 4 )

end

local IdleActivity = ACT_HL2MP_IDLE_ZOMBIE
ENT.IdleActivity = IdleActivity
ENT.IdleActivityTranslations = {
    [ACT_MP_STAND_IDLE]                 = IdleActivity,
    [ACT_MP_WALK]                       = randomWalk,
    [ACT_MP_RUN]                        = randomWalk,
    [ACT_MP_CROUCH_IDLE]                = ACT_HL2MP_IDLE_CROUCH,
    [ACT_MP_CROUCHWALK]                 = ACT_HL2MP_WALK_CROUCH,
    [ACT_MP_ATTACK_STAND_PRIMARYFIRE]   = IdleActivity + 5,
    [ACT_MP_ATTACK_CROUCH_PRIMARYFIRE]  = IdleActivity + 5,
    [ACT_MP_RELOAD_STAND]               = IdleActivity + 6,
    [ACT_MP_RELOAD_CROUCH]              = IdleActivity + 7,
    [ACT_MP_JUMP]                       = ACT_HL2MP_JUMP_FIST,
    [ACT_MP_SWIM]                       = ACT_HL2MP_SWIM,
    [ACT_LAND]                          = ACT_LAND,
}

-- the parent randomises these every spawn, infernals want them fixed. subclasses
-- change SkeleRunSpeed instead of reimplementing the whole override
ENT.SkeleRunSpeed = 500

function ENT:SetupSkeletonMoveSpeeds()
    self.WalkSpeed = 25
    self.MoveSpeed = 50
    self.RunSpeed = 100
    self.DuelEnemyDist = math.random( 500, 1500 )
    self.term_SoundPitchShift = math.random( 20, 30 )

end

ENT.AlwaysPlayLooping = true
ENT.IdleLoopingSounds = { "ambient/levels/citadel/datatransmalevx01.wav", "ambient/levels/citadel/datatransmalevx02.wav" }
ENT.AngryLoopingSounds = { "ambient/levels/citadel/datatransrandom02.wav" }

ENT.infernSkele_IdleSounds = {
    "ambient/levels/citadel/strange_talk1.wav",
    "ambient/levels/citadel/strange_talk3.wav",
    "ambient/levels/citadel/strange_talk4.wav",
    "ambient/levels/citadel/strange_talk5.wav",
    "ambient/levels/citadel/strange_talk6.wav",
    "ambient/levels/citadel/strange_talk7.wav",
    "ambient/levels/citadel/strange_talk8.wav",
    "ambient/levels/citadel/strange_talk9.wav",
    "ambient/levels/citadel/strange_talk10.wav",
    "ambient/levels/citadel/strange_talk11.wav",
}