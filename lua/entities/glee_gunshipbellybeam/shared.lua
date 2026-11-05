AddCSLuaFile()

-- the gunship's belly cannon, a strider warp cannon shot, parented under its hull
-- glows small while the gunship lines it up, charges, tracking its target, then one instant beam and a huge dissolving blast
-- the charge and shot visuals are c_strider.cpp's C_StriderFX, keyframes and all
ENT.Type = "anim"
ENT.PrintName = "Gunship Belly Cannon"
ENT.Spawnable = false
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

-- the strider's timeline, it fires at bigShotTime, everything's faded by endAllTime
-- our charge is longer, so the time before the shot is stretched to fit, the time after runs as is
local striderBigShotTime = 1.25
local striderEndAllTime = 4

-- timings come from the gunship's BellyCannonCfg, on the server
function ENT:SetupDataTables()
    self:NetworkVar( "Float", "ChargeStart" )
    self:NetworkVar( "Float", "FireTime" )
    self:NetworkVar( "Vector", "AimPos" )
    self:NetworkVar( "Vector", "ImpactPos" )
    self:NetworkVar( "Bool", "Fired" )

end

-- before this, the gunship's still lining the shot up
function ENT:IsCharging()
    return self:GetChargeStart() > 0

end

if SERVER then
    local dangerRadius = 600

    -- charging, standing where it'll land builds panic, the blast's radius is about 1100
    local chargePanic = 20
    local chargePanicRadius = 1000
    local chargePanicInterval = 0.25
    -- the shot itself, everyone near it
    local shotPanic = 75
    local shotPanicRadius = 1800
    local blastOffsetMin = 25
    local blastOffsetMax = 100

    -- the gunship module can load after this file
    local function cannonCfg()
        return terminator_Extras.glee_Gunship.BellyCannonCfg

    end

    function ENT:Initialize()
        -- never drawn, but entities without a model don't get drawn at all
        self:SetModel( "models/props_junk/PopCan01a.mdl" )
        self:SetMoveType( MOVETYPE_NONE )
        self:SetSolid( SOLID_NONE )
        self:DrawShadow( false )

    end

    -- turns from towards to, by at most maxDeg
    local function swingTowards( from, to, maxDeg )
        local along = math.Clamp( from:Dot( to ), -1, 1 )
        local maxRad = math.rad( maxDeg )
        if math.acos( along ) <= maxRad then return to end

        local across = to - from * along
        if across:LengthSqr() < 0.0001 then return from end
        across:Normalize()
        return from * math.cos( maxRad ) + across * math.sin( maxRad )

    end

    -- flat, a jump would lead the shot into the sky
    function ENT:RememberTarget( target )
        local vel = target:GetVelocity()
        vel.z = 0
        self.seenPos = target:WorldSpaceCenter()
        self.seenVel = vel
        self.seenTime = CurTime()

    end

    -- where they'll be when it fires, going by the last time it saw them
    function ENT:PredictedPos()
        local lead = math.min( self:GetFireTime() - self.seenTime, cannonCfg().maxLead )
        return self.seenPos + self.seenVel * lead

    end

    -- lined up on aimPos, where the gunship last saw them, the shot's coming
    function ENT:StartCharge( aimPos )
        local cur = CurTime()
        self:SetChargeStart( cur )
        self:SetFireTime( cur + cannonCfg().prefireTime )

        -- it starts there, and swings out ahead once the belly sees them run
        local owner = self:GetOwner()
        local bellyPos = terminator_Extras.glee_Gunship.BellyPos( owner )
        self.seenPos = aimPos
        self.seenVel = Vector( 0, 0, 0 )
        self.seenTime = cur
        self.aimDir = ( aimPos - bellyPos ):GetNormalized()
        self.lastTrack = cur
        self:TrackTarget()

    end

    -- swings towards where they'll be, no faster than turnRate
    -- the aim is where it'd land right now, so if they've left the belly's cone, the shot misses
    function ENT:TrackTarget()
        local owner = self:GetOwner()
        local gunship = terminator_Extras.glee_Gunship
        local bellyPos = gunship.BellyPos( owner )

        local target = self.target
        if IsValid( target ) and terminator_Extras.PosCanSee( bellyPos, target:WorldSpaceCenter(), MASK_SOLID_BRUSHONLY ) then
            self:RememberTarget( target )

        end

        local cur = CurTime()
        local turn = cannonCfg().turnRate * ( cur - self.lastTrack )
        self.lastTrack = cur

        local wantDir = ( self:PredictedPos() - bellyPos ):GetNormalized()
        self.aimDir = swingTowards( self.aimDir, wantDir, turn )

        local landing = gunship.BellyShotTrace( owner, bellyPos + self.aimDir * 1000, { owner, self } ).HitPos
        self:SetAimPos( landing )

    end

    function ENT:Shoot()
        local cfg = cannonCfg()
        local owner = self:GetOwner()
        local gunship = terminator_Extras.glee_Gunship

        local result = gunship.BellyShotTrace( owner, self:GetAimPos(), { owner, self } )
        local impactPos = result.HitPos
        local dir = result.Normal
        self:SetImpactPos( impactPos )
        self:SetFired( true )

        local hitEnt = result.Entity
        if IsValid( hitEnt ) then
            local damage = DamageInfo()
            damage:SetDamage( cfg.hitDamage )
            damage:SetDamageType( DMG_DISSOLVE )
            damage:SetAttacker( owner )
            damage:SetInflictor( self )
            damage:SetDamagePosition( impactPos )
            damage:SetDamageForce( dir * cfg.hitForce )
            hitEnt:TakeDamageInfo( damage )

            local phys = hitEnt:GetPhysicsObject()
            if IsValid( phys ) then
                phys:ApplyForceCenter( dir * cfg.hitForce )

            end
        end

        for _, magnitude in ipairs( cfg.blastMagnitudes ) do
            local explosion = ents.Create( "env_explosion" )
            explosion:SetPos( impactPos )
            explosion:SetOwner( owner )
            explosion:SetKeyValue( "iMagnitude", magnitude )
            explosion:Spawn()
            explosion:Fire( "Explode" )

        end

        local boom = EffectData()
        boom:SetOrigin( impactPos )
        boom:SetScale( 3.25 )
        boom:SetNormal( Vector( 0, 0, 1 ) )
        util.Effect( "glee_huge_m9k_splode", boom, true, true )

        for _ = 1, 4 do
            local explode = EffectData()
            explode:SetOrigin( impactPos + VectorRand() * math.random( blastOffsetMin, blastOffsetMax ) )
            util.Effect( "Explosion", explode, true, true )

        end

        sound.Play( "ambient/levels/labs/electric_explosion3.wav", impactPos, 150, 98 )
        sound.Play( "ambient/explosions/explode_9.wav", impactPos, 150, 100 )
        util.ScreenShake( impactPos, 1.5, 20, 0.4, 8000, true )
        util.ScreenShake( impactPos, 5, 20, 0.2, 2000, true )

        if GAMEMODE.PanicSource then
            GAMEMODE:PanicSource( impactPos, shotPanic, shotPanicRadius )

        end

        gunship.BellyCannonRecoil( owner, dir )

    end

    function ENT:Think()
        local owner = self:GetOwner()
        local cur = CurTime()
        local fireTime = self:GetFireTime()

        -- the afterglow's done
        if self:GetFired() and cur >= fireTime + ( striderEndAllTime - striderBigShotTime ) then
            self:Remove()
            return

        end

        if not self:GetFired() then
            -- died lining up or charging, the shot never happens
            if not IsValid( owner ) or owner:Health() <= 0 then
                self:Remove()
                return

            end
            -- the gunship's brain starts the charge, or removes us
            if not self:IsCharging() then
                self:NextThink( cur + 0.1 )
                return true

            end

            self:TrackTarget()
            sound.EmitHint( SOUND_DANGER, self:GetAimPos(), dangerRadius, 0.3, self )

            if GAMEMODE.PanicSource and cur >= ( self.nextPanic or 0 ) then
                self.nextPanic = cur + chargePanicInterval
                GAMEMODE:PanicSource( self:GetAimPos(), chargePanic, chargePanicRadius )

            end

            if cur >= fireTime then
                self:Shoot()

            end
        end

        self:NextThink( cur + 0.05 )
        return true

    end
else
    local narrowBeamMat = Material( "sprites/bluelaser1" )
    local wideBeamMat = Material( "effects/blueblacklargebeam" )
    local pinchMat = Material( "effects/strider_pinch_dudv" )
    local bulgeMat = Material( "effects/strider_bulge_dudv" )
    local flashMat = Material( "effects/blueblackflash" )
    local warnMat = Material( "effects/blueflare1" )

    -- while it's lining up, small, but you'd notice it
    local warnSizeMin = 24
    local warnSizeMax = 48
    local warnPulseRate = 8

    -- c_strider.cpp's sizes, the beam widths there are half widths
    local narrowBeamWidth = 2
    local wideBeamWidth = 16
    local flareSize = 128
    local afterglowSize = 64
    local warpSize = 512
    local warpRefract = 0.075
    local bubbleSize = 256
    local bubbleRefract = 1

    local LINEAR, SPLINE, ACCELERATE, DECELERATE = 1, 2, 3, 4
    local easings = {
        [LINEAR] = function( frac ) return frac end,
        [SPLINE] = function( frac ) return frac * frac * ( 3 - 2 * frac ) end,
        [ACCELERATE] = function( frac ) return frac * frac end,
        [DECELERATE] = function( frac ) return math.sqrt( frac ) end,
    }

    -- { time, how it eases in from the previous key, value }, straight from CStriderFXEnvelope
    local envelope = {
        warpScale = { { 0, LINEAR, 0 }, { 1.25, ACCELERATE, 1 }, { 1.25, LINEAR, 1 }, { 1.3, LINEAR, 0 } },
        darkness = { { 0, LINEAR, 0 }, { 0.5, SPLINE, 1 }, { 1, LINEAR, 1 }, { 1.25, SPLINE, 0 }, { 2, SPLINE, 0 } },
        flareColor = { { 0, LINEAR, 0 }, { 0.5, LINEAR, 0 }, { 1.25, ACCELERATE, 1 }, { 1.5, LINEAR, 1 }, { 2, SPLINE, 0 } },
        flareSize = { { 0, LINEAR, 0 }, { 1, LINEAR, 1 }, { 2, LINEAR, 1 } },
        bubbleSize = { { 1.3, LINEAR, 0.5 }, { 2, DECELERATE, 2 } },
        bubbleRefract = { { 1.3, LINEAR, 1 }, { 2, LINEAR, 0 } },
        narrowBeamColor = { { 0, LINEAR, 0 }, { 1.25, ACCELERATE, 1 }, { 1.5, SPLINE, 0 } },
        narrowBeamSize = { { 0, LINEAR, 0 }, { 0.5, ACCELERATE, 1 }, { 1.25, LINEAR, 1 }, { 1.5, DECELERATE, 2 } },
        wideBeamColor = { { 1.25, LINEAR, 0 }, { 1.5, SPLINE, 1 }, { 1.75, LINEAR, 1 }, { 2.1, SPLINE, 0 } },
        wideBeamSize = { { 1.25, LINEAR, 1 }, { 2.1, LINEAR, 1 } },
        afterglowColor = { { 1, LINEAR, 0 }, { 1.25, SPLINE, 1 }, { 3, LINEAR, 1 }, { 3.5, ACCELERATE, 0 } },
        wideBeamLength = { { 1.25, LINEAR, 1 }, { 1.5, ACCELERATE, 0 }, { 2.1, LINEAR, 0 } },
    }

    -- nil outside the keys' span, the effect isn't drawn then
    local function interp( keys, t )
        if t < keys[1][1] or t > keys[#keys][1] then return end

        for i = 1, #keys - 1 do
            local from, to = keys[i], keys[i + 1]
            local span = to[1] - from[1]
            if span > 0 and t <= to[1] then
                local frac = easings[to[2]]( ( t - from[1] ) / span )
                return Lerp( frac, from[3], to[3] )

            end
        end
        return keys[#keys][3]

    end

    local function scaledWhite( bright, alpha )
        local channel = math.Clamp( bright, 0, 1 ) * 255
        return Color( channel, channel, channel, alpha or channel )

    end

    -- where we are on the strider's timeline
    function ENT:StriderTime()
        local cur = CurTime()
        local fireTime = self:GetFireTime()
        if cur < fireTime then
            local chargeStart = self:GetChargeStart()
            return ( cur - chargeStart ) / ( fireTime - chargeStart ) * striderBigShotTime

        end
        return striderBigShotTime + ( cur - fireTime )

    end

    function ENT:Initialize()
        self.gunVisHandle = util.GetPixelVisibleHandle()
        self.endVisHandle = util.GetPixelVisibleHandle()

    end

    function ENT:Draw()
    end

    function ENT:DrawWarning( gunPos )
        self:SetRenderBoundsWS( gunPos - Vector( 64, 64, 64 ), gunPos + Vector( 64, 64, 64 ) )

        local pulse = ( math.sin( CurTime() * warnPulseRate ) + 1 ) / 2
        local size = Lerp( pulse, warnSizeMin, warnSizeMax )
        render.SetMaterial( warnMat )
        render.DrawSprite( gunPos, size, size, color_white )

    end

    function ENT:DrawTranslucent()
        local gunPos = self:GetPos()
        if not self:IsCharging() then
            self:DrawWarning( gunPos )
            return

        end

        local t = self:StriderTime()
        local targetPos = self:GetFired() and self:GetImpactPos() or self:GetAimPos()

        -- OrderVectors swaps in place, so copies
        local mins, maxs = Vector( gunPos ), Vector( targetPos )
        OrderVectors( mins, maxs )
        self:SetRenderBoundsWS( mins - Vector( 300, 300, 300 ), maxs + Vector( 300, 300, 300 ) )

        local params = {}
        for name, keys in pairs( envelope ) do
            params[name] = interp( keys, t )

        end

        local gunVisible = util.PixelVisible( gunPos, 4, self.gunVisHandle )

        if params.narrowBeamColor and params.narrowBeamSize then
            render.SetMaterial( narrowBeamMat )
            render.DrawBeam( gunPos, targetPos, narrowBeamWidth * params.narrowBeamSize * 2, 0, 1, scaledWhite( params.narrowBeamColor ) )

        end

        -- its back end races down the beam into the target
        local wideBeamEnd = gunPos
        if params.wideBeamLength then
            wideBeamEnd = LerpVector( params.wideBeamLength, targetPos, gunPos )

        end

        if params.wideBeamColor and params.wideBeamSize then
            render.SetMaterial( wideBeamMat )
            render.DrawBeam( wideBeamEnd, targetPos, wideBeamWidth * params.wideBeamSize * 2, 0, 1, scaledWhite( params.wideBeamColor ) )

        end

        local refractUpdated
        local function updateRefract()
            if refractUpdated then return end
            refractUpdated = true
            render.UpdateRefractTexture()

        end

        if params.warpScale and not params.bubbleSize and gunVisible > 0 then
            updateRefract()
            pinchMat:SetFloat( "$refractamount", params.warpScale * warpRefract * gunVisible )
            render.SetMaterial( pinchMat )
            render.DrawSprite( gunPos, warpSize, warpSize, color_white )

        end

        if params.flareColor and params.flareSize and params.darkness and gunVisible > 0 then
            local size = flareSize * params.flareSize
            render.SetMaterial( flashMat )
            render.DrawSprite( gunPos, size, size, scaledWhite( params.flareColor * gunVisible, 255 * params.darkness ) )

        end

        if params.bubbleSize then
            local endVisible = util.PixelVisible( wideBeamEnd, 4, self.endVisHandle )
            if endVisible > 0 then
                updateRefract()
                bulgeMat:SetFloat( "$refractamount", endVisible * bubbleRefract * params.bubbleRefract )
                local size = bubbleSize * params.bubbleSize
                render.SetMaterial( bulgeMat )
                render.DrawSprite( wideBeamEnd, size, size, color_white )

            end
        end

        if params.afterglowColor and gunVisible > 0 then
            local bright = params.afterglowColor * gunVisible
            render.SetMaterial( flashMat )
            render.DrawSprite( gunPos, afterglowSize, afterglowSize, scaledWhite( bright ) )

            local dlight = DynamicLight( self:EntIndex() )
            if dlight then
                dlight.pos = gunPos
                dlight.r = 40
                dlight.g = 60
                dlight.b = 255
                dlight.brightness = 5
                dlight.size = bright * 128
                dlight.dietime = CurTime() + 0.001

            end
        end
    end

    function ENT:Think()
        if not self:IsCharging() then return end

        if not self:GetFired() then
            if not self.chargeSound then
                self.chargeSound = CreateSound( self, "NPC_Strider.Charge" )
                self.chargeSound:Play()

            end

        elseif not self.didShoot then
            self.didShoot = true
            if self.chargeSound then self.chargeSound:Stop() end
            self:EmitSound( "NPC_Strider.Shoot" )

        end
    end

    function ENT:OnRemove()
        if self.chargeSound then self.chargeSound:Stop() end

    end
end
