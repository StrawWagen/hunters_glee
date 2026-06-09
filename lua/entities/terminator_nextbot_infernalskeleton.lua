AddCSLuaFile()

ENT.Base = "terminator_nextbot"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Infernal Skeleton"
ENT.Spawnable = false

ENT.TERM_FISTS = "weapon_infernalskeleton_fists"
ENT.PlayerColorVec = Vector( 1, 0, 0 ) -- used for player color

local className = "terminator_nextbot_infernalskeleton"
list.Set( "NPC", className, {
    Name = "Infernal Skeleton",
    Class = className,
    Category = "Hunter's Glee",
    Weapons = { ENT.TERM_FISTS },
} )

local entMeta = FindMetaTable( "Entity" )
local CurTime = CurTime
local math = math

if CLIENT then
    language.Add( className, ENT.PrintName )

    local offsetVec = Vector( 0, 0, 5 )
    ENT.FireEffects = {
        "fire_small_01",
        "fire_small_02",
        "fire_small_03",
    }

    function ENT:Think()
        if entMeta.IsDormant( self ) then return end
        local myTbl = entMeta.GetTable( self )
        if not myTbl.setupCL then
            myTbl.setupCL = true
            local fire = self.FireEffects[math.random( 1, #self.FireEffects )]
            CreateParticleSystem( self, fire, PATTACH_ABSORIGIN_FOLLOW, 0, offsetVec )

        end
    end

    local emptool_Glow = Material( "models/alyx/emptool_glow" )

    local render_MaterialOverride = render.MaterialOverride
    local render_SetColorModulation = render.SetColorModulation

    function ENT:Draw()
        entMeta.DrawModel( self )
        render_MaterialOverride( emptool_Glow )
        render_SetColorModulation( 1, 0.5, 0 )
        entMeta.DrawModel( self ) -- saves an _index call vs self:DrawModel()
        render_MaterialOverride( nil )
        render_SetColorModulation( 1, 1, 1 )

    end

    return

end

ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 40
ENT.ThreshMulIfDueling = 4 -- thresh is multiplied by this amount if we're closer than DuelEnemyDist
ENT.ThreshMulIfClose = 2 -- if we're closer than DuelEnemyDist * 2
ENT.MaxPathingIterations = 2500

ENT.JumpHeight = 150
ENT.Term_Leaps = true
ENT.DefaultStepHeight = 25
ENT.StandingStepHeight = ENT.DefaultStepHeight * 1 -- used in crouch toggle in motionoverrides
ENT.CrouchingStepHeight = ENT.DefaultStepHeight * 0.9
ENT.StepHeight = ENT.StandingStepHeight
ENT.PathGoalToleranceFinal = 50
ENT.SpawnHealth = 50
ENT.AimSpeed = 300
ENT.AccelerationSpeed = 1200

ENT.CanUseStuff = false

ENT.FistDamageMul = 0.15
ENT.CloseEnemyDistance = 500

ENT.TERM_WEAPON_PROFICIENCY = WEAPON_PROFICIENCY_POOR

ENT.term_DMG_ImmunityMask = bit.bor( DMG_BURN, DMG_RADIATION, DMG_POISON )
ENT.DoMetallicDamage = false -- metallic fx like bullet ricochet sounds
ENT.Term_BloodColor = DONT_BLEED
ENT.MetallicMoveSounds = false
ENT.ReallyStrong = false
ENT.ReallyHeavy = false
ENT.DontDropPrimary = true
ENT.CanSwim = false
ENT.BreathesAir = false

ENT.LookAheadOnlyWhenBlocked = nil
ENT.alwaysManiac = nil -- always create feuds between us and other terms/supercops, when they damage us
ENT.HasFists = true

ENT.IsFodder = true
ENT.IsStupid = true
ENT.CanSpeak = true -- enable speaking thinker
ENT.HasBrains = false -- default to no brains

ENT.Models = { "models/player/skeleton.mdl" }
ENT.TERM_MODELSCALE = function() return math.Rand( 0.9, 1.25 ) end
ENT.MyPhysicsMass = 50

ENT.FootstepClomping = false
ENT.Term_FootstepMode = "custom" -- make it use the sounds defined below, as opposed to picking right sound for the material its standing on
ENT.Term_FootstepSoundWalking = {
    {
        path = "npc/stalker/stalker_footstep_right1.wav",
        lvl = 68,
        pitch = { 180, 200 },
    },
    {
        path = "npc/stalker/stalker_footstep_right2.wav",
        lvl = 68,
        pitch = { 180, 200 },
    },
}
ENT.Term_FootstepSound = { -- running sounds
    {
        path = "physics/wood/wood_plank_impact_soft2.wav",
        lvl = 80,
        pitch = { 150, 170 },
    },
    {
        path = "physics/wood/wood_plank_impact_soft3.wav",
        lvl = 80,
        pitch = { 150, 170 },
    },
}

local IdleActivity = ACT_HL2MP_IDLE_ZOMBIE
ENT.IdleActivity = IdleActivity
ENT.IdleActivityTranslations = {
    [ACT_MP_STAND_IDLE]                 = IdleActivity,
    [ACT_MP_WALK]                       = ACT_HL2MP_WALK_ZOMBIE_06,
    [ACT_MP_RUN]                        = ACT_HL2MP_RUN_ZOMBIE_FAST,
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

function ENT:PostHitObject( object )
    if GAMEMODE.GivePanic and object:IsPlayer() then
        GAMEMODE:GivePanic( object, 50 )

    end

    object:Ignite( math.random( 3, 6 ) )

end

ENT.AlwaysPlayLooping = true
ENT.IdleLoopingSounds = { "ambient/levels/citadel/datatransmalevx01.wav", "ambient/levels/citadel/datatransmalevx02.wav" }
ENT.AngryLoopingSounds = { "ambient/levels/citadel/datatransmission04_loop.wav" }

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
    "npc/stalker/breathing3.wav",
    "ambient/levels/citadel/datatransrandom02.wav",
    "ambient/levels/citadel/datatransrandom03.wav",
}

local skins = {
    0,
    2,
    3,
}

ENT.MyClassTask = {
    OnCreated = function( self, data )
        self.WalkSpeed = math.random( 80, 100 )
        self.MoveSpeed = math.random( 240, 340 )
        self.RunSpeed = math.random( 380, 480 )
        self.DuelEnemyDist = math.random( 500, 1500 )
        self.term_SoundPitchShift = math.random( -10, 10 )

        self:SetSkin( skins[math.random( 1, #skins )] )

        local isHeadless
        local wantsHeadless = math.random( 0, 100 ) < 75
        if wantsHeadless then
            local headBone = self:LookupBone( "ValveBiped.Bip01_Head1" )
            if headBone then
                self:ManipulateBoneScale( headBone, Vector( 0.01, 0.01, 0.01 ) )
                self:ManipulateBonePosition( headBone, Vector( -5, 0, 0 ) )
                isHeadless = true
                self.glee_NeverDropSkull = true

            end
        end
        if not isHeadless then
            self.glee_AlwaysDropSkull = true

        end

    end,
    OnKilled = function( self, data )
        if not self.glee_AlwaysDropSkull then return end

        local headBone = self:LookupBone( "ValveBiped.Bip01_Head1" )
        if headBone then
            self:ManipulateBoneScale( headBone, Vector( 0.01, 0.01, 0.01 ) )
            self:ManipulateBonePosition( headBone, Vector( -5, 0, 0 ) )

        end
    end,
    Think = function( self, data )
        if self:IsSpeaking() then return end
        local idleSound = self.infernSkele_IdleSounds[math.random( 1, #self.infernSkele_IdleSounds )]
        self:Term_SpeakSound( idleSound )

    end,
}

local coroutine_yield = coroutine.yield

function ENT:DoCustomTasks( defaultTasks )
    self.TaskList = {
        ["shooting_handler"] = defaultTasks["shooting_handler"],
        ["enemy_handler"] = defaultTasks["enemy_handler"],

        ["movement_handler"] = {
            StartsOnInitialize = true,

            BehaveUpdateMotion = function( self, data )
                if self.IsSeeEnemy then
                    self:TaskComplete( "movement_handler" )
                    self:StartTask( "movement_duelenemy", "i found an enemy" )

                else
                    self:TaskComplete( "movement_handler" )
                    self:StartTask( "movement_wander", "i dont see an enemy" )

                end
            end,
        },
        ["movement_duelenemy"] = {
            BehaveUpdateMotion = function( self, data )
                local myTbl = self:GetTable()
                local enemy = self:GetEnemy()

                if IsValid( enemy ) and enemy:Alive() then
                    myTbl.GotoPosSimple( self, myTbl, enemy:GetPos(), 35, true )
                    if myTbl.DistToEnemy < myTbl.DuelEnemyDist then
                        self:Anger( 5 )

                    end
                elseif myTbl.TimeSinceEnemySpotted( self, myTbl ) > math.Rand( 3, 4 ) then
                    self:TaskComplete( "movement_duelenemy" )
                    self:StartTask( "movement_handler", "lost enemy for too long" )

                end
            end,
            ShouldRun = function( self, data )
                return self:IsAngry()

            end,
        },
        ["movement_wander"] = {
            OnStart = function( self, data )
                data.WanderPos = nil
                data.LastWanderPos = nil
                data.NextWanderChooseTime = 0
                data.LookAtVec = Vector( 0, 0, 0 )

            end,
            BehaveUpdateMotion = function( self, data )
                local myTbl = self:GetTable()

                if myTbl.IsSeeEnemy then
                    self:TaskComplete( "movement_wander" )
                    self:StartTask( "movement_handler", "i see an enemy" )
                    return

                end

                -- find a random nearby pos on navmesh to wander to
                -- avoid returning to LastWanderArea > 75% of the time

                local needsNewPathGoal = not data.CurrentTaskGoalPos
                needsNewPathGoal = needsNewPathGoal or entMeta.GetPos( self ):Distance( data.CurrentTaskGoalPos ) < 35
                needsNewPathGoal = needsNewPathGoal or ( myTbl.GetCurrentSpeed( self ) < 10 and CurTime() > data.NextWanderChooseTime )

                if needsNewPathGoal then
                    coroutine_yield()
                    local myNav = myTbl.GetCurrentNavArea( self, myTbl )
                    local areasToCheck = myNav:GetAdjacentAreas()
                    areasToCheck[#areasToCheck + 1] = myNav
                    local areasAlreadyAdded = {}
                    for _, area in ipairs( areasToCheck ) do
                        areasAlreadyAdded[area] = true

                    end
                    coroutine_yield()
                    local finalAreasToCheck = {}
                    for _, area in ipairs( areasToCheck ) do
                        local areasNeighbors = area:GetAdjacentAreas()
                        for _, neighbor in ipairs( areasNeighbors ) do
                            if areasAlreadyAdded[neighbor] then continue end
                            areasAlreadyAdded[neighbor] = true
                            finalAreasToCheck[#finalAreasToCheck + 1] = neighbor

                        end
                    end
                    coroutine_yield()

                    local lastArea = data.LastWanderArea
                    local currsDistToLast
                    if IsValid( lastArea ) then
                        currsDistToLast = myNav:GetCenter():Distance( lastArea:GetCenter() )

                    end
                    local chosenPos
                    local chosenArea
                    for _ = 1, 20 do
                        local area = table.remove( finalAreasToCheck, math.random( 1, #finalAreasToCheck ) )
                        if not IsValid( area ) then continue end
                        if currsDistToLast then
                            local distToLast = area:GetCenter():Distance( lastArea:GetCenter() )
                            if distToLast < currsDistToLast * math.Rand( 0.9, 1 ) then continue end

                        end
                        local visible = area:IsPartiallyVisible( self:WorldSpaceCenter(), self )
                        if not visible then continue end
                        chosenPos = area:GetCenter()
                        chosenArea = area
                        debugoverlay.Line( self:WorldSpaceCenter(), chosenPos, 1, color_white, true )
                        break

                    end

                    if chosenPos then
                        data.CurrentTaskGoalPos = chosenPos
                        data.NextWanderChooseTime = CurTime() + math.Rand( 2, 5 )
                        data.LastWanderArea = chosenArea

                    end
                end

                if data.CurrentTaskGoalPos then
                    myTbl.GotoPosSimple( self, myTbl, data.CurrentTaskGoalPos, 35, true )

                    local lookJitterScale = 25
                    if self:IsReallyAngry() then
                        lookJitterScale = 75

                    elseif self:IsAngry() then
                        lookJitterScale = 50

                    end

                    data.LookAtVec:SetUnpacked(
                        data.CurrentTaskGoalPos.x + math.random( -lookJitterScale, lookJitterScale ),
                        data.CurrentTaskGoalPos.y + math.random( -lookJitterScale, lookJitterScale ),
                        data.CurrentTaskGoalPos.z + math.random( -lookJitterScale, lookJitterScale )
                    )
                    self:justLookAt( data.LookAtVec )
                    myTbl.lastShootingType = "infernalskeleton_wander"

                end

            end,
            ShouldRun = function( self, data )
                return self:IsReallyAngry()

            end,
            ShouldWalk = function( self, data )
                return not self:IsAngry()

            end
        },
    }
end