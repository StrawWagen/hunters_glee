AddCSLuaFile()

ENT.Base = "terminator_nextbot_infernalskeleton_large"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Infernal Sentinel"
ENT.Spawnable = false

ENT.IsEldritch = true
ENT.glee_SkullWorthMul = 2

terminator_Extras.RegisterNPC( "terminator_nextbot_infernalskeleton_big", ENT, {
    Weapons = { "weapon_infernalskeleton_fists" },

} )


ENT.Term_BaseMsBetweenSteps = 600
ENT.Term_FootstepMsReductionPerUnitSpeed = 0.5

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
    amplitude = 4,
    frequency = 20,
    duration = 0.5,
    radius = 1750,
}

-- shares the Ambler's action name, so it replaces that action rather than adding to it
ENT.MySpecialActions = {
    ["Call"] = {
        inBind = IN_RELOAD,
        drawHint = true,
        name = "Call",
        desc = "Scream and intimidate your enemy", -- unused for now
        ratelimit = 8,

        svAction = function( driveController, driver, bot )
            local allPlyFilter = terminator_Extras.recipFilterAllTargetablePlayers()
            bot:EmitSound( "ambient/levels/streetwar/gunship_distant2.wav", 120, 120, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
            bot:EmitSound( "npc/stalker/go_alert2a.wav", 120, 15, 0.5, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
            bot:EmitSound( "hunters_glee/169628__dinsfire__male-voice-screaming-loudly.wav", 90, 40, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
            bot:EmitSound( "npc/combine_gunship/see_enemy.wav", 90, 30, 1, CHAN_STATIC )

            -- Do the gesture, with a slower rate, and dont block movement while it happens
            bot:DoGesture( ACT_GMOD_GESTURE_TAUNT_ZOMBIE, 0.75, false )

            bot:Anger( 8 )

            util.ScreenShake( bot:WorldSpaceCenter(), 10, 20, 5, 2000, true )

        end,
    }
}

if CLIENT then
    function ENT:GetFireEffects()
        return {
            "fire_large_01",
        }

    end
    return

end

ENT.MyClassTask = {
    DealtGoobmaDamage = function( self, data, damage, fallHeight, _dealtTo )
        if fallHeight <= 250 then return end
        local myPos = self:GetPos()
        local scale = fallHeight / 200
        scale = math.Clamp( scale, 0, 4 )

        local shock = EffectData()
        shock:SetOrigin( myPos )
        shock:SetScale( scale )
        util.Effect( "eff_huntersglee_infernal_landing", shock )

        if fallHeight < 750 then return end

        local dmgRad = fallHeight * 0.25
        dmgRad = math.Clamp( dmgRad, 500, 5000 )

        local dmg = 150 * scale
        util.BlastDamage( self, self, self:GetPos(), dmgRad, dmg )

        local splode = EffectData()
        splode:SetOrigin( myPos )
        splode:SetNormal( Vector( 0, 0, 1 ) )
        splode:SetScale( scale * 0.75 )
        util.Effect( "glee_huge_m9k_splode", splode )

    end,
}

ENT.TERM_MODELSCALE = 1.75 -- inherited CollisionBounds are scaled by this
local standxy = 8
local crouchxy = 7
ENT.CollisionBounds = { Vector( -standxy, -standxy, 0 ), Vector( standxy, standxy, 45 ) } -- this is then scaled by modelscale
ENT.CrouchCollisionBounds = { Vector( -crouchxy, -crouchxy, 0 ), Vector( crouchxy, crouchxy, 30 ) } -- this is then scaled by modelscale
ENT.MyPhysicsMass = 2000

ENT.SpawnHealth = 2500

ENT.FistDamageMul = 10
ENT.FistRangeMul = 2
ENT.CloseEnemyDistance = 200
ENT.JumpHeight = 1000

ENT.AccelerationSpeed = 200
ENT.SkeleRunSpeed = 1000
ENT.SkeleRunAct = ACT_HL2MP_RUN_FAST

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

ENT.SkeleDeathAnim = ACT_GMOD_GESTURE_TAUNT_ZOMBIE
ENT.SkeleDeathAnimRate = 0.35
ENT.SkeleCallInterval = 35
ENT.SkeleAlwaysRun = true


function ENT:SkeletonDeathFX()
    local allPlyFilter = terminator_Extras.recipFilterAllTargetablePlayers()
    self:EmitSound( "ambient/levels/streetwar/gunship_distant2.wav", 120, 140, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
    self:EmitSound( "npc/stalker/go_alert2a.wav", 120, 30, 0.5, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
    self:EmitSound( "hunters_glee/169628__dinsfire__male-voice-screaming-loudly.wav", 90, 50, 1, CHAN_STATIC, SND_NOFLAGS, 0, allPlyFilter )
    self:EmitSound( "npc/combine_gunship/see_enemy.wav", 90, 40, 1, CHAN_STATIC )

    util.ScreenShake( self:WorldSpaceCenter(), 10, 20, 5, 3000, true )
    util.ScreenShake( self:WorldSpaceCenter(), 100, 20, 5, 1000, true )

end