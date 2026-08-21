AddCSLuaFile()

-- a bigger, tankier infernal skeleton. inherits all the ai/tasks/rendering/sounds,
-- only overrides the knobs that make it "big"
ENT.Base = "terminator_nextbot_infernalskeleton"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Infernal Rumbler"
ENT.Spawnable = false

ENT.glee_SkullWorthMul = 1.5 -- makes dropped skull worth more

terminator_Extras.RegisterNPC( "terminator_nextbot_infernalskeleton_large", ENT, {
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
            bot:EmitSound( "npc/combine_gunship/see_enemy.wav", 90, 40, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
            bot:EmitSound( "npc/stalker/stalker_die2.wav", 90, 60, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )

            -- Do the gesture, with a slower rate, and block movement while it happens
            bot:DoGesture( ACT_GMOD_GESTURE_TAUNT_ZOMBIE, 1, true )

            bot:Anger( 8 )

            util.ScreenShake( bot:WorldSpaceCenter(), 5, 20, 5, 2000, true )

        end,
    }
}

if CLIENT then
    function ENT:GetFireEffects()
        return {
            "fire_small_03",
        }

    end
    ENT.FireParticleChance = 100

    return

end

ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 20

-- big
ENT.TERM_MODELSCALE = 1.35
local standxy = 10
local crouchxy = 8
ENT.CollisionBounds = { Vector( -standxy, -standxy, 0 ), Vector( standxy, standxy, 45 ) } -- this is then scaled by modelscale
ENT.CrouchCollisionBounds = { Vector( -crouchxy, -crouchxy, 0 ), Vector( crouchxy, crouchxy, 30 ) } -- this is then scaled by modelscale
ENT.MyPhysicsMass = 500

-- tanky mini-boss, not fodder
ENT.SpawnHealth = 1000
ENT.IsFodder = false
ENT.ReallyHeavy = true -- crushes skulls underfoot, worth shooting for the heli, etc.
ENT.ReallyStrong = true

-- longer reach and heavier hits to match the size
ENT.FistDamageMul = 0.6
ENT.FistRangeMul = 1.5
ENT.CloseEnemyDistance = 300
ENT.JumpHeight = 500

-- always keep the head so it drops a ( big ) skull
ENT.SpawnHeadlessChance = 0


ENT.Term_FootstepTiming = "timed"
ENT.Term_BaseMsBetweenSteps = 500
ENT.Term_FootstepMsReductionPerUnitSpeed = 1.5
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
        path = "npc/antlion_guard/foot_heavy1.wav",
        lvl = 84,
        pitch = 80,
    },
    {
        path = "npc/antlion_guard/foot_heavy2.wav",
        lvl = 84,
        pitch = 80,
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

ENT.AccelerationSpeed = 300
ENT.LooksForwardWhenRunning = true
-- the parent randomises these every spawn, infernals want them fixed. subclasses
-- change SkeleRunSpeed instead of reimplementing the whole override
ENT.SkeleRunSpeed = 500
ENT.SkeleRunAct = ACT_HL2MP_RUN_ZOMBIE_FAST

function ENT:SetupSkeletonMoveSpeeds()
    self.WalkSpeed = 100
    self.MoveSpeed = 200
    self.RunSpeed = self.SkeleRunSpeed
    self.DuelEnemyDist = 800
    self.term_SoundPitchShift = -40

end

ENT.SkeleDeathAnim = ACT_GMOD_GESTURE_TAUNT_ZOMBIE
ENT.SkeleDeathAnimRate = 0.6
ENT.SkeleCallInterval = 15

function ENT:SkeletonDeathFX()
    self:EmitSound( "npc/combine_gunship/see_enemy.wav", 100, 50, 1, CHAN_STATIC )
    self:EmitSound( "npc/stalker/stalker_die2.wav", 100, 70, 1, CHAN_STATIC )

    util.ScreenShake( self:WorldSpaceCenter(), 5, 20, 5, 3000, true )
    util.ScreenShake( self:WorldSpaceCenter(), 50, 20, 5, 1000, true )

end

function ENT:SkeletonJumpFX()
    self:Term_SpeakSoundNow( "npc/stalker/stalker_alert3b.wav", math.random( 0, 30 ) )
    sound.Play( "physics/concrete/concrete_break3.wav", self:GetPos(), 75, math.random( 40, 60 ) )

end

ENT.MyClassTask = {
    OnStart = function( self, data )
        data.nextCall = CurTime() + 3

    end,
    BehaveUpdateMotion = function( self, data )

        self.Term_LeapMinimizesHeight = not self:IsReallyAngry()

        if not data.needsCall then return end
        if not self:CanTakeAction( "Call" ) then return end

        local nextCall = data.nextCall
        if nextCall > CurTime() then return end

        data.nextCall = CurTime() + self.SkeleCallInterval
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

        return self.SkeleRunAct

    end,
    ShouldRun = function( self, data )
        if self.SkeleAlwaysRun then return end
        if self:Health() > self:GetMaxHealth() * 0.9 then return false end

    end,
}
