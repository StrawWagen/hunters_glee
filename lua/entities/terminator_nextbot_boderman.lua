AddCSLuaFile()

ENT.Base = "terminator_nextbot"
DEFINE_BASECLASS( ENT.Base )
ENT.PrintName = "Richard Boderman"
ENT.Author = "regunkyle (OG by Fay)"
ENT.AdminOnly = true

ENT.SubCategory = "Hunter's Glee"

terminator_Extras.RegisterNPC( "terminator_nextbot_boderman", ENT, {
    Weapons = { "weapon_boderman_fists" },
} )

if CLIENT then
    language.Add("terminator_nextbot_boderman", "Richard Boderman")
    return
end

local entMeta = FindMetaTable("Entity")

-- Hardcoded Properties
ENT.CoroutineThresh = terminator_Extras.baseCoroutineThresh / 2
ENT.MaxPathingIterations = 25000

ENT.JumpHeight = 500
ENT.DefaultStepHeight = 18
ENT.StandingStepHeight = ENT.DefaultStepHeight * 1.5
ENT.CrouchingStepHeight = ENT.DefaultStepHeight * 0.9
ENT.StepHeight = ENT.StandingStepHeight

ENT.SpawnHealth = 10000
ENT.AimSpeed = 480
ENT.WalkSpeed = 100
ENT.MoveSpeed = 300
ENT.RunSpeed = 900
ENT.AccelerationSpeed = 10000
ENT.term_AnimsWithIdealSpeed = false

ENT.DistToEnemy = math.huge
ENT.isTerminatorHunterChummy = "bodermen"

ENT.Models = { "models/fay/boderman/boderman.mdl" }
ENT.TERM_MODELSCALE = 1

ENT.CanFindWeaponsOnTheGround = false
ENT.CanHolsterWeapons = false
ENT.DefaultWeapon = nil
ENT.TERM_FISTS = "weapon_boderman_fists"
ENT.MySpecialActions = ENT.MySpecialActions or {}

ENT.DuelEnemyDist = 150
ENT.CloseEnemyDistance = 200
ENT.FistDamageMul = 1000000
ENT.FistDamageType = bit.bor( DMG_SLASH, DMG_CLUB, DMG_GENERIC )

ENT.term_SoundPitchShift = 0
ENT.term_SoundLevelShift = 0

ENT.term_LoseEnemySound = "scientist/noidea.wav"
ENT.term_CallingSound = "scientist/noidea.wav"
ENT.term_CallingSmallSound = "scientist/noidea.wav"
ENT.term_FindEnemySound = "scientist/noidea.wav"
ENT.term_AttackSound = { "scientist/holdstill.wav", "scientist/greetings.wav" }
ENT.term_AngerSound = "scientist/noidea.wav"
ENT.term_DamagedSound = { "scientist/noplease.wav", "scientist/sci_pain9.wav", "scientist/scream11.wav", "scientist/c1a3_sci_silo2a.wav" }
ENT.term_DieSound = { "scientist/scream24.wav", "scientist/scream21.wav", "scientist/scream20.wav" }
ENT.term_JumpSound = ""

ENT.AlwaysPlayLooping = false
ENT.CanSpeak = false

ENT.ConstSound = {"gamer/fnaf_amb.mp3","gamer/fnaf_amb2.mp3","gamer/valk_amb.mp3"}
ENT.ConstSoundLength = {604,10,300}

function ENT:OnKilled( dmg )
    if self.term_Dead then return end
    self.term_Dead = true
    
    self:EmitSound( self.term_DieSound[math.random(1, #self.term_DieSound)], 100, 90 )
    self:StopMoving()
    self:SetSolid( SOLID_NONE )
    self:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    
    if self.seq_diesimple and self.seq_diesimple >= 0 then
        self:ResetSequence( self.seq_diesimple )
        self:SetPlaybackRate( 1 )
        local duration = self:SequenceDuration( self.seq_diesimple )
        if duration <= 0 then duration = 3 end
        self.Term_DyingUntil = CurTime() + duration
        SafeRemoveEntityDelayed( self, duration )
    else
        SafeRemoveEntityDelayed( self, 0.1 )
    end
    
    hook.Call( "OnNPCKilled", GAMEMODE, self, dmg:GetAttacker(), dmg:GetInflictor() )
end

function ENT:PostHitObject( hitEnt, damage )
    if IsValid( hitEnt ) and (hitEnt:IsPlayer() or hitEnt:IsNPC() or hitEnt:IsNextBot()) then
        hitEnt:SetVelocity( self:GetForward()*75000 + self:GetUp()*5000 )
    end
end

function ENT:DoRangeGesture()
    if self.seq_attack1 and self.seq_attack1 >= 0 then
        self:DoGesture( self.seq_attack1, 1.2, false )
    end
    self:EmitSound( self.term_AttackSound[math.random(1,#self.term_AttackSound)], 100, 90 )
end

function ENT:Term_LookAround( myTbl )
    if self:IsMoving() then
        local path = myTbl.GetPath( self )
        if path and path:IsValid() then
            local goal = path:GetCurrentGoal()
            if goal then
                myTbl.SetDesiredEyeAngles( self, (goal.pos - myTbl.GetShootPos( self )):Angle() )
                return true
            end
        end
    end
    return BaseClass.Term_LookAround( self, myTbl )
end

ENT.MyClassTask = {
    PreventBecomeRagdollOnKilled = function( self, data, dmg )
        return true, true
    end,
    BehaveUpdatePriority = function( self, data )
        local enemy = self:GetEnemy()
        if IsValid( enemy ) and self.DistToEnemy > 2000000 then
            local cur = CurTime()
            if not data.nextTeleportCheck then data.nextTeleportCheck = cur + 10 end
            if data.nextTeleportCheck < cur then
                data.nextTeleportCheck = cur + 10
                if math.Rand(1, 100) <= 30 then
                    local tpPos = enemy:GetPos() + VectorRand() * 100
                    tpPos = findEmptyPos(tpPos, {self}, 3000, 1500, Vector(4, 4, 64)) or tpPos
                    terminator_Extras.TeleportTermTo( self, tpPos )
                    self:InvalidatePath( "teleported" )
                end
            end
        end
    end,
}

-- Optimized Activity Setup using cached sequence IDs
function ENT:SetupActivity()
    if self.term_Dead then return end
    
    local myTbl = entMeta.GetTable( self )
    local moType = myTbl.GetMotionType( self )
    local seqId
    
    if moType == TERMINATOR_NEXTBOT_MOTIONTYPE_IDLE then
        if myTbl.nextIdleChange == nil or myTbl.nextIdleChange < CurTime() then
            myTbl.nextIdleChange = CurTime() + math.Rand(5, 10)
            myTbl.currentIdle = math.random(1, 100) > 20 and myTbl.seq_idle2 or myTbl.seq_idle1
        end
        seqId = myTbl.currentIdle
    elseif moType == TERMINATOR_NEXTBOT_MOTIONTYPE_WALK then
        seqId = myTbl.seq_walk
    elseif moType == TERMINATOR_NEXTBOT_MOTIONTYPE_RUN or moType == TERMINATOR_NEXTBOT_MOTIONTYPE_MOVE then
        local enemy = myTbl.GetEnemy( self )
        local distSqr = IsValid(enemy) and self:GetRangeSquaredTo(enemy) or math.huge
        if distSqr <= 250000 then
            seqId = myTbl.seq_runshort
        else
            seqId = myTbl.seq_runlong
        end
    end
    
    if seqId and seqId >= 0 then
        if self:GetSequence() != seqId then
            self:ResetSequence(seqId)
            self:SetPlaybackRate(1)
        end
        return
    end

    BaseClass.SetupActivity(self)
end

function ENT:AdditionalInitialize()
    self:SetModel( "models/fay/boderman/boderman.mdl" )
    self.isTerminatorHunterChummy = "bodermen"
    self.HasBrains = true
    self.nextInterceptTry = 0

    -- Pre-cache sequence IDs for massive performance gains in SetupActivity
    self.seq_idle1 = self:LookupSequence( "idle1" )
    self.seq_idle2 = self:LookupSequence( "idle2" )
    self.seq_walk = self:LookupSequence( "walk" )
    self.seq_runlong = self:LookupSequence( "runlong" )
    self.seq_runshort = self:LookupSequence( "runshort" )
    self.seq_attack1 = self:LookupSequence( "attack1" )
    self.seq_diesimple = self:LookupSequence( "diesimple" )

    self.currentIdle = self.seq_idle2
    self.nextIdleChange = CurTime() + math.Rand(5, 10)

    self:EmitSound( self.term_FindEnemySound, 100, 90 )
    self.pickedSND = math.random(1, #self.ConstSound)
    self.loopSNDConst = 0
    local bdmn = self
    timer.Create( "boderman_sndloop_"..tostring(bdmn:GetCreationID()), 1, 0, function()
        if not IsValid(bdmn) then return end
        bdmn.loopSNDConst = bdmn.loopSNDConst - 1
        if bdmn.loopSNDConst <= 0 then
            bdmn:EmitSound(bdmn.ConstSound[bdmn.pickedSND])
            bdmn.loopSNDConst = bdmn.ConstSoundLength[bdmn.pickedSND]
        end
    end )
end

function ENT:OnRemove()
    timer.Remove( "boderman_sndloop_"..tostring(self:GetCreationID()))
    for _, soundName in ipairs(self.ConstSound) do
        self:StopSound(soundName)
    end
end

function ENT:EnemyAcquired( currentTask )
    if not IsValid( self ) then return end
    local myTbl = entMeta.GetTable( self )
    local enemy = myTbl.GetEnemy( self )
    
    if not IsValid( enemy ) then
        if not self:IsTaskActive( "movement_handler" ) then
            self:TaskComplete( currentTask )
            self:StartTask( "movement_handler", nil, "ea, enemy is invalid?" )
        end
        return true
    end

    local seeEnemy = myTbl.IsSeeEnemy

    if not seeEnemy then
        if not self:IsTaskActive( "movement_approachlastseen" ) then
            self:TaskComplete( currentTask )
            self:StartTask( "movement_approachlastseen", nil, "ea, where'd they go" )
        end
        return true
    end

    if not self:IsTaskActive( "movement_followenemy" ) then
        self:TaskComplete( currentTask )
        self:StartTask( "movement_followenemy", nil, "ea, rushing enemy" )
        self.PreventShooting = nil
    end
    return true
end

local function isEmpty(vector, ignore)
    ignore = ignore or {}
    local point = util.PointContents(vector)
    local a = point ~= CONTENTS_SOLID and point ~= CONTENTS_MOVEABLE and point ~= CONTENTS_LADDER and point ~= CONTENTS_PLAYERCLIP and point ~= CONTENTS_MONSTERCLIP
    if not a then return false end
    local b = true
    for _, v in ipairs(ents.FindInSphere(vector, 35)) do
        if (v:IsNPC() or v:IsPlayer() or v:GetClass() == "prop_physics" or v.NotEmptyPos) and not table.HasValue(ignore, v) then
            b = false
            break
        end
    end
    return a and b
end

local function findEmptyPos(pos, ignore, distance, step, area)
    if isEmpty(pos, ignore) and isEmpty(pos + area, ignore) then return pos end
    for j = step, distance, step do
        for i = -1, 1, 2 do
            local k = j * i
            if isEmpty(pos + Vector(k, 0, 0), ignore) and isEmpty(pos + Vector(k, 0, 0) + area, ignore) then return pos + Vector(k, 0, 0) end
            if isEmpty(pos + Vector(0, k, 0), ignore) and isEmpty(pos + Vector(0, k, 0) + area, ignore) then return pos + Vector(0, k, 0) end
            if isEmpty(pos + Vector(0, 0, k), ignore) and isEmpty(pos + Vector(0, 0, k) + area, ignore) then return pos + Vector(0, 0, k) end
        end
    end
    return pos
end

function ENT:DoCustomTasks( defaultTasks )
    self.TaskList = table.Copy( defaultTasks )
    
    self.TaskList["movement_handler"] = {
        StartsOnInitialize = true,
        BehaveUpdateMotion = function( self, data )
            local myTbl = entMeta.GetTable( self )
            if myTbl.term_SpawnDelayEnd == nil then
                myTbl.term_SpawnDelayEnd = CurTime() + 5
            end
            
            if CurTime() < myTbl.term_SpawnDelayEnd then
                if not self:IsTaskActive( "movement_wait" ) then
                    myTbl.KillAllTasksWith( self, "movement" )
                    myTbl.StartTask( self, "movement_wait", { time = 5 }, "spawn delay" )
                end
                return
            end

            if myTbl.GetEnemy( self ) and myTbl.EnemyAcquired( self, "movement_handler" ) then
                return
            elseif myTbl.term_WaitingForEnemy then
                if not self:IsTaskActive( "movement_waitforenemy" ) then
                    myTbl.KillAllTasksWith( self, "movement" )
                    myTbl.StartTask( self, "movement_waitforenemy", nil, "wait... ( for enemy )" )
                end
                return
            else
                if not self:IsTaskActive( "movement_wander" ) then
                    myTbl.KillAllTasksWith( self, "movement" )
                    myTbl.StartTask( self, "movement_wander", "wander" )
                end
                return
            end
        end,
    }
end