AddCSLuaFile()

ENT.Type = "anim"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar( "Bool", "Disabled" )
    self:NetworkVar( "Bool", "StartsInactive" )
    self:NetworkVar( "Bool", "Active" )
    self:NetworkVar( "Entity", "Attacker" )
    self:NetworkVar( "Entity", "Inflictor" )
end

if SERVER then
    local DAMAGE_MUL            = 1
    local MOBILITY_MUL           = 1

    local MISSILE_HITBOX_MAXS = Vector( 10, 10, 10 )
    local MISSILE_HITBOX_MINS = -MISSILE_HITBOX_MAXS
    local MISSILE_HITTRACE_DIST = 20

    local BLAST_DAMAGE = 1500
    local BLAST_RADIUS = 500
    local DIRECTHIT_DAMAGE = 1500

    local BLINDFIRE_MAXSPEED_TIME = 1
    local BLIND_STABILITY_AT_MAXSPEED = 0.25
    local BLIND_STABILITY_BEFORE_MAXSPEED = 0.10
    local BLINDFIRE_ANGVEL_DECAY = 0.99
    local MAX_BLINDFIRE_SPEED = 4000

    sound.Add( {
        name = "heli_missile_impactflesh",
        channel = CHAN_STATIC,
        volume = 1.0,
        level = 130,
        pitch = { 90, 100 },
        sound = {
            "physics/flesh/flesh_squishy_impact_hard1.wav",
            "physics/flesh/flesh_squishy_impact_hard2.wav",
            "physics/flesh/flesh_squishy_impact_hard3.wav",
            "physics/flesh/flesh_squishy_impact_hard4.wav"
        }
    } )

    function ENT:SpawnFunction( _, tr, className )
        if not tr.Hit then return end

        local ent = ents.Create( className )
        ent:SetPos( tr.HitPos + tr.HitNormal * 20 )
        ent:Spawn()
        ent:Activate()

        return ent
    end

    function ENT:BlindFire()
        if self:DoHitTrace() then return end -- we hit something

        local pObj = self:GetPhysicsObject()
        if not IsValid( pObj ) then return end

        -- ramp up to full speed over a bit less than 1 second
        local timeAlive = math.abs( self.ActiveTime - CurTime() )
        local tillFullSpeed = timeAlive / BLINDFIRE_MAXSPEED_TIME

        local instability
        if tillFullSpeed >= 1 then -- drift a LOT once we get to max speed
            instability = BLIND_STABILITY_AT_MAXSPEED
        else
            instability = BLIND_STABILITY_BEFORE_MAXSPEED
        end

        local speed = math.Clamp( tillFullSpeed * MAX_BLINDFIRE_SPEED, 0, MAX_BLINDFIRE_SPEED )
        local vel = ( speed * MOBILITY_MUL )
        pObj:SetVelocityInstantaneous( self:GetForward() * vel )

        local angVel = pObj:GetAngleVelocity() * BLINDFIRE_ANGVEL_DECAY -- bias towards going straight, spiral out of turns
        angVel = angVel + VectorRand() * instability -- but not too straight

        pObj:SetAngleVelocity( angVel )
    end

    function ENT:Initialize()
        self:SetModel( "models/props_phx/amraam.mdl" )
        self:PhysicsInit( SOLID_VPHYSICS )
        self:SetMoveType( MOVETYPE_VPHYSICS )
        self:SetSolid( SOLID_VPHYSICS )
        self:SetRenderMode( RENDERMODE_TRANSALPHA )
        self:PhysWake()
        local pObj = self:GetPhysicsObject()

        if IsValid( pObj ) then
            pObj:EnableGravity( false )
            pObj:SetMass( 1 )
        end

        if self:GetStartsInactive() then return end
        self:MissileActivate()

    end

    function ENT:MissileActivate()
        if self:GetActive() then return end
        self:SetActive( true )
        self.ActiveTime = CurTime()

        local filterEveryone = RecipientFilter()
        filterEveryone:AddAllPlayers()
        self:EmitSound( "weapons/mortar/mortar_shell_incomming1.wav", 120, 80, 1, CHAN_STATIC, SND_NOFLAGS, 0, filterEveryone )

    end

    function ENT:Think()
        if not self:GetActive() then return end

        local curtime = CurTime()
        self:NextThink( curtime )

        if not self:GetDisabled() then
            self:BlindFire()
        end

        if ( self.ActiveTime + 12 ) < curtime then
            self:Detonate()
        end

        return true
    end

    function ENT:PhysicsCollide( data )
        if self:GetDisabled() then
            self:Detonate()
        else
            local hitEnt = data.HitEntity
            local owner = self:GetOwner()
            if hitEnt == owner then return end
            if IsValid( owner ) and IsValid( hitEnt:GetParent() ) and hitEnt:GetParent() == owner then return end
            if hitEnt:GetClass() == "phys_bone_follower" then return end

            self:HitEntity( hitEnt )
        end
    end

    function ENT:DoHitTrace( myPos )
        local startPos = myPos or self:GetPos()
        local offset = self:GetForward() * MISSILE_HITTRACE_DIST
        local owner = self:GetOwner()

        local trResult = util.TraceHull( {
            start = startPos,
            endpos = startPos + offset,
            filter = { self, owner },
            maxs = MISSILE_HITBOX_MAXS,
            mins = MISSILE_HITBOX_MINS,
            mask = MASK_SOLID,
        } )

        if trResult.Hit then
            -- dont hit sub-ents of the owner
            if IsValid( owner ) then
                if IsValid( trResult.Entity:GetParent() ) and trResult.Entity:GetParent() == owner then return end
                if trResult.Entity == owner then return end

            end
            self:HitEntity( trResult.Entity )
            return true
        end
    end

    function ENT:GetDirectHitDamage( hitEnt )
        local hookResultDmg, hookResultSound = hook.Run( "LFS.MissileDirectHitDamage", self, hitEnt )
        if hookResultDmg ~= nil and isnumber( hookResultDmg ) then return hookResultDmg, hookResultSound end

        local dmgAmount = DIRECTHIT_DAMAGE
        local dmgSound = "Missile.ShotDown"
        if hitEnt:IsNPC() or hitEnt:IsNextBot() then
            local obj = hitEnt:GetPhysicsObject()
            if IsValid( obj ) and obj:GetMaterial() and not string.find( obj:GetMaterial(), "metal" ) then
                dmgSound = "heli_missile_impactflesh"
            end
        elseif hitEnt:IsPlayer() then
            dmgSound = "heli_missile_impactflesh"
        end

        return dmgAmount, dmgSound
    end

    function ENT:HitEntity( hitEnt )
        if not IsValid( hitEnt ) then
            self:Detonate() -- hit world
            return

        end

        local Pos = self:GetPos()
        -- hit simfphys car instead of simfphys wheel
        if hitEnt.GetBaseEnt and IsValid( hitEnt:GetBaseEnt() ) then
            hitEnt = hitEnt:GetBaseEnt()
        end

        local effectdata = EffectData()
            effectdata:SetOrigin( Pos )
            effectdata:SetNormal( -self:GetForward() )
        util.Effect( "manhacksparks", effectdata, true, true )

        local dmgAmount, dmgSound = self:GetDirectHitDamage( hitEnt )
        dmgAmount = dmgAmount * DAMAGE_MUL

        local dmginfo = DamageInfo()
            dmginfo:SetDamage( dmgAmount )
            dmginfo:SetAttacker( IsValid( self:GetAttacker() ) and self:GetAttacker() or self )
            dmginfo:SetDamageType( DMG_DIRECT )
            dmginfo:SetInflictor( self )
            dmginfo:SetDamagePosition( Pos )
            dmginfo:SetDamageForce( self:GetForward() * dmgAmount * 500 )
        hitEnt:TakeDamageInfo( dmginfo )

        sound.Play( dmgSound, Pos, 140 )

        self:Detonate()
    end

    function ENT:BreakMissile()
        if not self:GetDisabled() then
            self:SetDisabled( true )

            local pObj = self:GetPhysicsObject()

            if IsValid( pObj ) then
                pObj:EnableGravity( true )
                self:PhysWake()
                self:EmitSound( "Missile.ShotDown" )
            end
        end
    end

    function ENT:Detonate()
        local inflictor = self:GetInflictor()
        local attacker = self:GetAttacker()
        local explodePos = self:WorldSpaceCenter()

        local effectdata = EffectData()
            effectdata:SetOrigin( self:GetPos() )
        util.Effect( "Explosion", effectdata )

        effectdata = EffectData()
            effectdata:SetOrigin( explodePos )
            effectdata:SetScale( 3.5 )
            effectdata:SetNormal( Vector( 0, 0, 1 ) )
        util.Effect( "glee_huge_m9k_splode", effectdata, true, true )

        self:EmitSound( "vehicles/airboat/pontoon_impact_hard1.wav", 100, 50, 0.5 )
        self:EmitSound( "Explo.ww2bomb" )

        self:Remove()

        timer.Simple( 0, function()
            local fallbackDamager = Entity( 0 )
            inflictor = IsValid( inflictor ) and inflictor or fallbackDamager
            attacker = IsValid( attacker ) and attacker or fallbackDamager

            util.BlastDamage( inflictor, attacker, explodePos, BLAST_RADIUS, BLAST_DAMAGE )
        end )
    end

    function ENT:OnTakeDamage( dmginfo )
        if not dmginfo:IsDamageType( DMG_AIRBOAT ) then return end
        if self:GetAttacker() == dmginfo:GetAttacker() then return end

        self:BreakMissile()
    end

else -- client
    ENT.HasStartedFX = false

    function ENT:Initialize()
    end

    function ENT:Draw()
        self:DrawModel()
    end

    function ENT:SoundStop()
        if self.snd then
            self.snd:Stop()
        end
    end

    function ENT:Think()
        if self:GetActive() and not self.HasStartedFX then
            self.HasStartedFX = true
            self.snd = CreateSound( self, "Phx.Afterburner5" )
            self.snd:SetSoundLevel( 110 )
            self.snd:Play()

            -- make trail effect on client init
            -- very very unreliable on server init
            local effectdata = EffectData()
                effectdata:SetOrigin( self:GetPos() )
                effectdata:SetEntity( self )
            util.Effect( "heli_missile_trail", effectdata, true, true )

        end
        if self:GetDisabled() then
            self:SoundStop()
        end

        return true
    end

    function ENT:OnRemove()
        self:SoundStop()
    end
end