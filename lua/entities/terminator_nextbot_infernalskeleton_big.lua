AddCSLuaFile()

-- a bigger, tankier infernal skeleton. inherits all the ai/tasks/rendering/sounds,
-- only overrides the knobs that make it "big"
ENT.Base = "terminator_nextbot_infernalskeleton"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Infernal Sentinel"
ENT.Spawnable = false

terminator_Extras.RegisterNPC( "terminator_nextbot_infernalskeleton_big", ENT, {
    Weapons = { "weapon_infernalskeleton_fists" },

} )

ENT.MySpecialActions = {
    ["Call"] = {
        inBind = IN_RELOAD, -- IN_ Input for players driving this bot to trigger this action
        drawHint = true, -- Show hint to player when driving bot, lots of default, silent actions exist, like switching weapons, etc
        name = "Call", -- Display name shown to player
        desc = "Scream and intimidate your enemy", -- unused for now
        ratelimit = 8, -- Minimum 2 seconds between uses

        svAction = function( driveController, driver, bot )
            local allPlyFilter = terminator_Extras.recipFilterAllTargetablePlayers()
            bot:EmitSound( "ambient/levels/streetwar/gunship_distant2.wav", 120, 120, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
            bot:EmitSound( "npc/stalker/go_alert2a.wav", 120, 15, 0.5, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
            bot:EmitSound( "npc/combine_gunship/see_enemy.wav", 90, 30, 1, CHAN_STATIC )
            bot:EmitSound( "npc/stalker/stalker_die2.wav", 90, 50, 1, CHAN_STATIC )

            -- Do the gesture, with a slower rate, and dont block movement while it happens
            bot:DoGesture( ACT_GMOD_GESTURE_TAUNT_ZOMBIE, 0.75, false )

            bot:Anger( 8 )

            util.ScreenShake( bot:WorldSpaceCenter(), 5, 20, 5, 2000, true )

        end,

    }
}

if CLIENT then

    ENT.FireEffects = {
        "fire_medium_01",
        "fire_medium_02",
        "fire_medium_03",
    }
    ENT.FireParticleChance = 100

    return

end

ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 20

-- big
ENT.TERM_MODELSCALE = 1.75
local standxy = 8
local crouchxy = 7
ENT.CollisionBounds = { Vector( -standxy, -standxy, 0 ), Vector( standxy, standxy, 45 ) } -- this is then scaled by modelscale
ENT.CrouchCollisionBounds = { Vector( -crouchxy, -crouchxy, 0 ), Vector( crouchxy, crouchxy, 30 ) } -- this is then scaled by modelscale
ENT.MyPhysicsMass = 200

-- tanky mini-boss, not fodder
ENT.SpawnHealth = 2500
ENT.IsFodder = false
ENT.ReallyHeavy = true -- crushes skulls underfoot, worth shooting for the heli, etc.
ENT.ReallyStrong = true

-- longer reach and heavier hits to match the size
ENT.FistDamageMul = 10
ENT.FistRangeMul = 2
ENT.CloseEnemyDistance = 700
ENT.JumpHeight = 1000

-- always keep the head so it drops a ( big ) skull
ENT.SpawnHeadlessChance = 0


ENT.Term_FootstepTiming = "timed"
ENT.Term_BaseMsBetweenSteps = 600
ENT.Term_FootstepMsReductionPerUnitSpeed = 0.5
ENT.Term_FootstepSoundWalking = {
    {
        path = "npc/vort/vort_foot4.wav",
        lvl = 75,
        pitch = 80,
    },
    {
        path = "npc/vort/vort_foot2.wav",
        lvl = 75,
        pitch = 80,
    },
}
ENT.Term_FootstepSound = { -- running sounds
    {
        path = "NPC_Strider.Footstep",
        lvl = 78,
        pitch = 90,
    },
    {
        path = "NPC_Strider.Footstep",
        lvl = 78,
        pitch = 90,
    },
}
ENT.Term_FootstepShake = {
    amplitude = 2,
    frequency = 20,
    duration = 0.35,
    radius = 1500,
}

local IdleActivity = ACT_HL2MP_IDLE_ZOMBIE
ENT.IdleActivity = IdleActivity
ENT.IdleActivityTranslations = {
    [ACT_MP_STAND_IDLE]                 = IdleActivity,
    [ACT_MP_WALK]                       = ACT_HL2MP_WALK_ZOMBIE_06,
    [ACT_MP_RUN]                        = ACT_HL2MP_RUN_PANICKED,
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

ENT.AccelerationSpeed = 200
ENT.LooksForwardWhenRunning = true

function ENT:SetupSkeletonMoveSpeeds()
    self.WalkSpeed = 100
    self.MoveSpeed = 200
    self.RunSpeed = 1000
    self.DuelEnemyDist = 800
    self.term_SoundPitchShift = -40

end

ENT.IdleLoopingSounds = { "ambient/levels/streetwar/city_riot1.wav", "ambient/levels/citadel/datatransmalevx01.wav" }
ENT.AngryLoopingSounds = { "ambient/fire/fire_big_loop1.wav" }

ENT.infernSkele_IdleSounds = {
    "npc/strider/strider_hunt1.wav",
    "npc/strider/strider_hunt2.wav",
    "npc/strider/strider_hunt3.wav",
    "ambient/levels/citadel/strange_talk1.wav",
    "ambient/levels/citadel/strange_talk8.wav",
    "npc/stalker/breathing3.wav",
    "ambient/levels/citadel/datatransrandom02.wav",
    "ambient/levels/citadel/datatransrandom03.wav",
}

ENT.MyClassTask = {
    OnStart = function( self, data )
        data.nextCall = CurTime() + 3

    end,
    BehaveUpdateMotion = function( self, data )
        if not data.needsCall then return end
        if not self:CanTakeAction( "Call" ) then return end

        local nextCall = data.nextCall
        if nextCall > CurTime() then return end

        data.nextCall = CurTime() + 30
        data.needsCall = nil
        self:TakeAction( "Call" )

    end,
    EnemyFound = function( self, data )
        data.needsCall = true

    end,
    TranslateActivity = function( self, data, act )
        if act ~= ACT_MP_RUN then return end
        if self:GetIdealMoveSpeed() < self.RunSpeed * 0.9 then return end

        if not self:IsAngry() then
            self:Anger( 1 )

        end

        return ACT_HL2MP_RUN_FAST

    end,
    -- circle of fire
    --OnLandOnGround = 
}

-- does not flinch
function ENT:HandleFlinching()
end
