AddCSLuaFile()

-- the gunship's dumbfire missile, hangs out of the pod for a second, then screams off
-- flown by hand, no physics, so the hit traces see every inch of the path
ENT.Type = "anim"
ENT.PrintName = "Gunship Missile"
ENT.Spawnable = false

-- units per second, ported from the old e2's per-30ms steps
ENT.StartSpeed = 3
ENT.IgnitionTime = 1.02
ENT.IgnitionAccel = 350
ENT.BurnAccel = 2000
ENT.MaxSpeed = 4000

ENT.WarnTime = 1.2 -- the incoming whistle
ENT.MaxLifetime = 12

function ENT:SetupDataTables()
    self:NetworkVar( "Float", "LaunchTime" )
    self:NetworkVar( "Bool", "Detonated" )
    self:NetworkVar( "Bool", "Exploded" ) -- detonated, and not into the sky

end

function ENT:SpeedAt( age )
    if age <= self.IgnitionTime then
        return self.StartSpeed + self.IgnitionAccel * age

    end
    local ignitedSpeed = self.StartSpeed + self.IgnitionAccel * self.IgnitionTime
    return math.min( ignitedSpeed + self.BurnAccel * ( age - self.IgnitionTime ), self.MaxSpeed )

end

if SERVER then
    local hitHullMaxs = Vector( 5, 5, 5 )
    local hitHullMins = -hitHullMaxs

    local blastMagnitudes = { 150, 75 } -- env_explosion radius is 2.5x this
    local dangerRadius = 500
    -- standing where one's going to land, the blast's radius is 500
    local landingPanic = 15
    local landingPanicRadius = 650

    -- seconds to fly dist, stepped, it's only done once per missile
    function ENT:TimeToFly( dist )
        local step = 0.05
        local age = 0
        local flown = 0
        while flown < dist and age < self.MaxLifetime do
            flown = flown + self:SpeedAt( age ) * step
            age = age + step

        end
        return age

    end

    function ENT:Initialize()
        self:SetModel( "models/weapons/w_missile_launch.mdl" )
        self:SetModelScale( 0.8 )
        self:SetColor( Color( 170, 195, 220 ) )
        self:SetMoveType( MOVETYPE_NONE )
        self:SetSolid( SOLID_NONE )
        self:DrawShadow( false )

        self:SetLaunchTime( CurTime() )
        self.lastThink = CurTime()

        util.SpriteTrail( self, 0, Color( 255, 255, 255 ), true, 3, 0, 0.5, 1 / 3 * 0.5, "trails/laser" )
        util.SpriteTrail( self, 0, Color( 170, 220, 255 ), true, 6, 0, 0.3, 1 / 6 * 0.5, "trails/laser" )
        util.SpriteTrail( self, 0, Color( 150, 165, 190, 90 ), false, 10, 100, 4, 1 / 110 * 0.5, "trails/smoke" )

        self:WarnWhereItLands()

    end

    function ENT:HitTrace( startPos, endPos )
        return util.TraceHull( {
            start = startPos,
            endpos = endPos,
            filter = { self, self:GetOwner() },
            mins = hitHullMins,
            maxs = hitHullMaxs,
            mask = MASK_SHOT,
        } )
    end

    -- it never turns, so where it lands is known now, everything nearby gets a head start running
    function ENT:WarnWhereItLands()
        local myPos = self:GetPos()
        local result = self:HitTrace( myPos, myPos + self:GetForward() * 40000 )
        if result.HitSky or not result.Hit then return end

        local flyTime = self:TimeToFly( myPos:Distance( result.HitPos ) )
        sound.EmitHint( SOUND_DANGER, result.HitPos, dangerRadius, flyTime + 0.5, self )

        if GAMEMODE.PanicSource then
            GAMEMODE:PanicSource( result.HitPos, landingPanic, landingPanicRadius )

        end

    end

    function ENT:Detonate( hitPos, hitSky )
        self:SetDetonated( true )
        self:SetPos( hitPos )
        -- the trails stay a moment, they'd vanish with us
        SafeRemoveEntityDelayed( self, 4 )

        if hitSky then return end
        self:SetExploded( true )

        local owner = self:GetOwner()
        for _, magnitude in ipairs( blastMagnitudes ) do
            local explosion = ents.Create( "env_explosion" )
            explosion:SetPos( hitPos )
            explosion:SetOwner( owner )
            explosion:SetKeyValue( "iMagnitude", magnitude )
            explosion:Spawn()
            explosion:Fire( "Explode" )

        end
    end

    function ENT:Think()
        if self:GetDetonated() then return end

        local cur = CurTime()
        local age = cur - self:GetLaunchTime()
        if age > self.MaxLifetime then
            self:Detonate( self:GetPos() )
            return

        end

        if not self.incomingSound and age > self.WarnTime then
            local filterTargetable = terminator_Extras.recipFilterAllTargetablePlayers()
            self.incomingSound = CreateSound( self, "weapons/mortar/mortar_shell_incomming1.wav", filterTargetable )
            self.incomingSound:SetSoundLevel( 140 )
            self.incomingSound:PlayEx( 1, 70 )
            self.incomingSound:ChangePitch( 90, 1 )

        end

        local sinceLast = cur - self.lastThink
        self.lastThink = cur

        local myPos = self:GetPos()
        local nextPos = myPos + self:GetForward() * self:SpeedAt( age ) * sinceLast
        local result = self:HitTrace( myPos, nextPos )
        if result.Hit then
            self:Detonate( result.HitPos, result.HitSky )
            return

        end

        self:SetPos( nextPos )
        self:NextThink( cur )
        return true

    end

    function ENT:OnRemove()
        if self.incomingSound then self.incomingSound:Stop() end

    end
else
    local glowMat = Material( "sprites/light_glow02_add" )
    local glowColor = Color( 150, 210, 255 )
    local flareColor = Color( 255, 255, 255 )

    -- the flying loop only starts once it's this close to us, a missile screaming in out of nowhere
    local engineHearDist = 2500

    -- the snap when it stops hanging and burns, it's committed now
    local igniteFlashTime = 0.15
    local igniteFlashSize = 160

    local function flash( pos, size, brightness, lifetime, index )
        local light = DynamicLight( index )
        if not light then return end
        light.pos = pos
        light.r = glowColor.r
        light.g = glowColor.g
        light.b = glowColor.b
        light.brightness = brightness
        light.size = size
        light.decay = size / lifetime
        light.dietime = CurTime() + lifetime

    end

    function ENT:Draw()
        if self:GetDetonated() then return end
        self:DrawModel()

        local cur = CurTime()
        local age = cur - self:GetLaunchTime()
        local size
        if age < self.IgnitionTime then
            -- arming, a weak flicker
            size = math.Rand( 8, 24 )

        elseif age < self.IgnitionTime + igniteFlashTime then
            size = igniteFlashSize

        else
            size = 48 + math.sin( cur * 40 ) * 8

        end

        local forward = self:GetForward()
        local myPos = self:GetPos()
        render.SetMaterial( glowMat )
        render.DrawSprite( myPos - forward * 12, size, size, glowColor )
        -- white hot core, and a flare streak behind it
        render.DrawSprite( myPos - forward * 20, size * 0.5, size * 0.5, flareColor )

        -- the streak's full size when it's coming straight at you, gone from side on
        local facingYou = math.max( forward:Dot( ( EyePos() - myPos ):GetNormalized() ), 0 )
        if facingYou <= 0 then return end
        local streakSize = size * facingYou
        render.DrawSprite( myPos - forward * 24, streakSize * 2.5, streakSize * 0.3, flareColor )

    end

    function ENT:Think()
        local age = CurTime() - self:GetLaunchTime()

        if self:GetDetonated() then
            if self.engineSound then
                self.engineSound:Stop()
                self.engineSound = nil

            end
            if self:GetExploded() and not self.didImpactFlash then
                self.didImpactFlash = true
                flash( self:GetPos(), 1200, 6, 0.5, self:EntIndex() )

            end
            return

        end

        if not self.didIgnite and age >= self.IgnitionTime then
            self.didIgnite = true
            self:EmitSound( "weapons/cguard/charging.wav", 75, 140, 1, CHAN_STATIC )
            flash( self:GetPos(), 400, 3, igniteFlashTime, self:EntIndex() )

        end

        -- the old e2 pitched it by speed per 30ms step
        local pitch = math.Clamp( self:SpeedAt( age ) * 0.03, 20, 150 )
        if not self.engineSound and self:GetPos():DistToSqr( LocalPlayer():EyePos() ) < engineHearDist^2 then
            self.engineSound = CreateSound( self, "Missile.Ignite" )
            self.engineSound:PlayEx( 1, pitch )

        elseif self.engineSound then
            self.engineSound:ChangePitch( pitch, 0.1 )

        end
    end

    function ENT:OnRemove()
        if self.engineSound then self.engineSound:Stop() end

    end
end
