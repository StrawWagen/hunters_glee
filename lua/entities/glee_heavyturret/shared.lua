AddCSLuaFile()

-- An npc, so hunters fight it once it shoots them, as they would any npc that hurts them
ENT.Type = "ai"
ENT.Base = "base_ai"

ENT.PrintName   = "Heavy Sentry Turret"
ENT.Author      = "StrawWagen"
ENT.Purpose     = "A gunship's gun, on the ground"
ENT.Spawnable   = true
ENT.AdminOnly   = game.IsDedicated()
ENT.Category    = "Hunter's Glee"
ENT.RenderGroup = RENDERGROUP_BOTH
ENT.IconOverride = "materials/entities/glee_backpackable_heavyturret.png"

ENT.Model = "models/combine_turrets/ground_turret.mdl" -- upside down, see SpawnFunction
ENT.GunModel = "models/airboatgun.mdl"

local glee_Turrets = terminator_Extras.glee_Turrets
local glee_Carrying = terminator_Extras.glee_Carrying

if CLIENT then
    terminator_Extras.glee_CL_SetupSent( ENT, "glee_heavyturret", "materials/vgui/hud/killicon/glee_heavyturret.png" )

end

glee_Carrying.MakeCarryable( ENT, "glee_backpackable_heavyturret" )

local function withShopTurretActions( action )
    local actions = table.Add( {}, glee_Turrets.UseActions )
    table.insert( actions, action )

    return actions

end

local detachedUseActions = withShopTurretActions( { key = "attach", label = "Attach" } )
local attachedUseActions = withShopTurretActions( { key = "detach", label = "Detach" } )

ENT.GleeUseActions = detachedUseActions
ENT.GleeUseWheelOnly = true

function ENT:SetupDataTables()
    self:NetworkVar( "Entity", "Gun" )
    self:NetworkVar( "Bool", "HasTarget" )
    -- settled back, looking where it faces
    -- false from when it spots a target, until it's done searching for it
    self:NetworkVar( "Bool", "LookingAhead" )
    -- welded to what's under it, see ENT:Attach
    self:NetworkVar( "Bool", "Attached" )
    -- the firing loops', 0 when it's not firing, see ENT:UpdateFiringSounds
    self:NetworkVar( "Float", "FiringVolume" )
    -- through its armour, see ENT:OnTakeDamage, picks its damaged effects
    self:NetworkVar( "Int", "HitsTaken" )

    self:NetworkVarNotify( "Attached", self.OnAttachedChanged )

end

function ENT:OnAttachedChanged( _, _, attached )
    self.GleeUseActions = attached and attachedUseActions or detachedUseActions

end

local attachMaxSpeed = 5 -- faster than this, it's sliding, falling, or being pushed
local attachGroundSlack = 4 -- past its bounds, how far from its hooks what it attaches to can be

-- The trace out its hooks to what it'd attach to, or nil and why not
-- whichever way they face, so it can hang from a ceiling, or the bottom of a helicopter
function ENT:FindAttachGround()
    if self:GetAttached() then return nil end
    if glee_Carrying.IsCarried( self ) then return nil end
    if self:GetVelocity():Length() > attachMaxSpeed then return nil, "It's moving." end

    local center = self:WorldSpaceCenter()
    local halfHeight = ( self:OBBMaxs().z - self:OBBMins().z ) * 0.5
    local tr = util.TraceLine( {
        start = center,
        -- the model's upside down, see SpawnFunction, its up is out its hooks
        endpos = center + self:GetUp() * ( halfHeight + attachGroundSlack ),
        filter = { self, self:GetGun() },
        mask = MASK_SOLID,
    } )

    local ground = tr.Entity
    if not tr.Hit or ground:IsPlayer() or ground:IsNPC() then return nil, "There's nothing for its hooks to grab." end

    return tr

end

function ENT:CanUseAction( ply, key )
    if key == "detach" then return self:GetAttached() end
    if key ~= "attach" then return glee_Turrets.CanUseAction( self, ply, key ) end

    local ground, reason = self:FindAttachGround()
    return ground ~= nil, reason

end

function ENT:CanPickUp()
    if self:GetAttached() then return false, "Detach it first." end

    return true

end

local maxFiringDist = 2500 -- g_helicopter_maxfiringdist

-- the gun's own entity, sitting on the upside down base
local gunLocalPos = Vector( 0, 0, -28 )
local gunLocalAng = Angle( 0, 0, 180 )
local muzzleAttachment = 1

-- drawn on it clientside, see ENT.MyExtraModels, and thrown off it as gibs when it dies
-- the model's upside down, +z is toward the floor
local hookMine = {
    model = "models/props_combine/combine_mine01.mdl",
    pos = Vector( 0, 0, -0.5 ),
    ang = Angle( 0, 0, 180 ),
}

local monitor = {
    model = "models/props_combine/combine_smallmonitor001.mdl",
    pos = Vector( 0, 0, -28 ),
    ang = Angle( 0, 0, 0 ),
}

-- the chopper's gun sounds, quieter, it's not a whole helicopter
local chopperSoundQuieter = 38 -- sound level, under the chopper's

-- Registers a copy of the chopper's soundName as newName, chopperSoundQuieter under it
local function addQuieterChopperSound( soundName, newName )
    local properties = sound.GetProperties( soundName )
    if not properties then return end

    local quieter = table.Copy( properties )
    quieter.name = newName
    quieter.level = quieter.level - chopperSoundQuieter
    sound.Add( quieter )

end

local firingSoundName = "glee_HeavyTurret.FireGun"
local chargeSoundName = "glee_HeavyTurret.ChargeGun"
addQuieterChopperSound( "NPC_AttackHelicopter.FireGun", firingSoundName )
addQuieterChopperSound( "NPC_AttackHelicopter.ChargeGun", chargeSoundName )

local closeFiringSoundName = "glee_HeavyTurret.FireGunClose"

local airboatGunSound = sound.GetProperties( "Airboat.FireGunLoop" )
if airboatGunSound then
    local closeFiringSound = table.Copy( airboatGunSound )
    closeFiringSound.name = closeFiringSoundName
    closeFiringSound.level = 78 -- heard only up close
    sound.Add( closeFiringSound )

end

-- the far chopper one and the close airboat one
local firingSoundNames = { firingSoundName, closeFiringSoundName }

local thinkInterval = 0.1 -- the gun only turns and shoots this often
local windDownPitch = 70 -- the firing loops', by the end of a wind down


if CLIENT then
    local blinkInterval = 0.5
    -- the gun's local, forward, left, up
    local warningSpriteOffset = Vector( 0, 0, 5 )
    local eyeOffset = Vector( 7, 2.9, 3.5 )
    local flashlightOffset = Vector( 7, 2.9, 1.5 ) -- just under the eye
    local warningSpriteMat = Material( "effects/blueflare1" )
    local warningSpriteColor = Color( 255, 0, 0, 50 )

    -- its spotlight, only on in the dark, from spotting a target until it settles back
    local flashlightSettings = {
        darkLevel = 0.4, -- under this, it's on
        checkInterval = 0.5,
        fov = 40,
        nearZ = 8, -- short of the barrel on purpose, the gun's shadow down the middle of its own light
        beamWidth = 75,
        beamLength = 150,
        beamAlpha = 100, -- seen side on, it fades looking down it
        spriteSize = 100,
        spriteMat = Material( "engine/lightsprite" ),
        beamMat = Material( "effects/lamp_beam" ),
        switchSound = { path = "buttons/lightswitch2.wav", level = 55, volume = 0.25 },
    }

    -- always on, a machine hum, clientside, kept alive by hand
    local idleHum = {
        path = "ambient/levels/canals/manhack_machine_loop1.wav",
        level = 68,
        pitch = 60,
        alertPitch = 100, -- while it has a target
        pitchChangeTime = 1, -- seconds, between the two
        checkInterval = 0.1,
        farCheckInterval = 1,
        hearDistSqr = 2000^2,
    }

    -- the hopper mine's blendstates, 64 is bouncebomb.cpp's BOUNCEBOMB_HOOK_RANGE
    local mineHooks = {
        open = 64,
        closed = 0,
        speed = 2048, -- blendstates per second
    }

    -- coming off it, worse with every hit through its armour, by hits taken
    -- intervals are seconds, picked between the two each time
    -- flare burns for damagedBurnTime after the hit, fire keeps burning
    local damagedEffects = {
        [1] = { sparkInterval = { 3, 5 } },
        [2] = { sparkInterval = { 1.5, 3 } },
        [3] = { sparkInterval = { 1, 2 }, smokeInterval = 0.25 },
        [4] = { sparkInterval = { 0.5, 1.5 }, smokeInterval = 0.12, flare = true },
        [5] = { sparkInterval = { 0.3, 0.8 }, smokeInterval = 0.06, fire = true },
    }
    local damagedBurnTime = 2.5
    local damagedFireName = "fire_small_01"
    local damagedFireOffset = Vector( 0, 0, -14 ) -- its local, between the hooks and the gun
    local damagedSmokeColor = 60
    PrecacheParticleSystem( damagedFireName )

    local function isBlinkOn()
        return math.floor( CurTime() / blinkInterval ) % 2 == 0

    end

    -- the ones with a flashlight to place, see glee_heavyturret_placeflashlights
    local litTurrets = {}

    -- every frame, so the flashlight turns on and off here
    -- where it points is glee_heavyturret_placeflashlights
    function ENT:Think()
        self:SetNextClientThink( CurTime() )

        -- nothing here's worth doing for a turret out of view, see glee_heavyturret_dormant
        if self:IsDormant() then return true end

        self:UpdateIdleSound()
        self:UpdateFiringSounds()

        local hooksTarget = self:GetAttached() and mineHooks.closed or mineHooks.open
        self.glee_HooksBlend = math.Approach( self.glee_HooksBlend or hooksTarget, hooksTarget, mineHooks.speed * FrameTime() )

        local gun = self:GetGun()
        if not IsValid( gun ) then return true end

        -- the carry system only hides the turret itself from its carrier, the gun's its own entity
        local ply = LocalPlayer()
        local hidden = glee_Carrying.IsCarriedBy( self, ply ) and not ply:ShouldDrawLocalPlayer()
        gun:SetNoDraw( hidden )

        self:UpdateDamagedEffects( hidden )

        -- off while it rides on someone, or sits settled with nothing to look for
        if glee_Carrying.IsCarried( self ) or self:GetLookingAhead() then
            self:RemoveFlashlight()
            return true

        end

        self:UpdateFlashlight()

        return true

    end

    local function randomInterval( interval )
        return math.Rand( interval[1], interval[2] )

    end

    function ENT:StopDamagedFire()
        if not IsValid( self.glee_DamagedFire ) then return end

        self.glee_DamagedFire:StopEmission()
        self.glee_DamagedFire = nil

    end

    -- by model, every triangle's vertices, read once
    -- NearestPoint only knows its bounding box, sparks came off the air around it
    local modelVerts = {}

    local function getModelVerts( model )
        local verts = modelVerts[model]
        if verts then return verts end

        verts = {}
        for _, meshData in ipairs( util.GetModelMeshes( model ) or {} ) do
            for _, vert in ipairs( meshData.triangles ) do
                verts[#verts + 1] = vert

            end
        end
        modelVerts[model] = verts

        return verts

    end

    -- a random spot on it, the gun, or its extra models, and which way it faces
    function ENT:RandomSurfacePoint()
        local parts = {
            { self:GetModel(), self:GetPos(), self:GetAngles() },
            { hookMine.model, self:LocalToWorld( hookMine.pos ), self:LocalToWorldAngles( hookMine.ang ) },
            { monitor.model, self:LocalToWorld( monitor.pos ), self:LocalToWorldAngles( monitor.ang ) },
        }
        local gun = self:GetGun()
        if IsValid( gun ) then
            parts[#parts + 1] = { gun:GetModel(), gun:GetPos(), gun:GetAngles() }

        end

        local part = parts[math.random( #parts )]
        local verts = getModelVerts( part[1] )
        if #verts == 0 then return self:WorldSpaceCenter(), VectorRand():GetNormalized() end

        local vert = verts[math.random( #verts )]
        local pos = LocalToWorld( vert.pos, angle_zero, part[2], part[3] )
        local normal = LocalToWorld( vert.normal, angle_zero, vector_origin, part[3] )

        return pos, normal

    end

    function ENT:DamagedSpark()
        local pos, normal = self:RandomSurfacePoint()

        local effect = EffectData()
        effect:SetOrigin( pos )
        effect:SetNormal( normal )
        effect:SetMagnitude( 2 )
        effect:SetScale( 1 )
        effect:SetRadius( 3 )
        util.Effect( "Sparks", effect )

        self:EmitSound( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav", 65, 100, 0.5 )

    end

    function ENT:DamagedSmoke()
        local emitter = self.glee_SmokeEmitter
        if not emitter then
            emitter = ParticleEmitter( self:GetPos() )
            self.glee_SmokeEmitter = emitter

        end

        local pos = self:RandomSurfacePoint()
        local particle = emitter:Add( "particles/smokey", pos )
        if not particle then return end

        particle:SetVelocity( vector_up * math.Rand( 30, 60 ) + VectorRand() * 10 )
        particle:SetDieTime( math.Rand( 2, 3 ) )
        particle:SetStartAlpha( 120 )
        particle:SetEndAlpha( 0 )
        particle:SetStartSize( math.Rand( 4, 8 ) )
        particle:SetEndSize( math.Rand( 30, 45 ) )
        particle:SetRoll( math.Rand( 0, 360 ) )
        particle:SetRollDelta( math.Rand( -1, 1 ) )
        particle:SetColor( damagedSmokeColor, damagedSmokeColor, damagedSmokeColor )
        particle:SetAirResistance( 50 )

    end

    -- every frame, see damagedEffects
    -- none while it's hidden on its carrier's back, it'd all be in their face
    function ENT:UpdateDamagedEffects( hidden )
        local now = CurTime()
        local hitsTaken = self:GetHitsTaken()

        -- not the first time it's seen, it'd flare up coming into view
        if self.glee_LastHitsTaken and self.glee_LastHitsTaken ~= hitsTaken then
            self.glee_BurnUntil = now + damagedBurnTime

        end
        self.glee_LastHitsTaken = hitsTaken

        local effects = damagedEffects[math.min( hitsTaken, #damagedEffects )]
        if not effects or hidden then
            self:StopDamagedFire()
            return

        end

        if ( self.glee_NextDamagedSpark or 0 ) < now then
            self.glee_NextDamagedSpark = now + randomInterval( effects.sparkInterval )
            self:DamagedSpark()

        end

        if effects.smokeInterval and ( self.glee_NextDamagedSmoke or 0 ) < now then
            self.glee_NextDamagedSmoke = now + effects.smokeInterval
            self:DamagedSmoke()

        end

        local flaring = effects.flare and ( self.glee_BurnUntil or 0 ) > now
        if not effects.fire and not flaring then
            self:StopDamagedFire()
            return

        end

        -- placed by hand, it'd stick to the origin, at the hooks
        local fire = self.glee_DamagedFire
        if not IsValid( fire ) then
            fire = CreateParticleSystemNoEntity( damagedFireName, self:LocalToWorld( damagedFireOffset ) )
            self.glee_DamagedFire = fire

        end
        if IsValid( fire ) then
            fire:SetControlPoint( 0, self:LocalToWorld( damagedFireOffset ) )

        end
    end

    function ENT:StopIdleSound()
        if not self.glee_IdleSound then return end

        self.glee_IdleSound:Stop()
        self.glee_IdleSound = nil

    end

    -- stopped out of earshot
    -- restarted whenever it's not playing, the engine drops loops out from under us
    function ENT:UpdateIdleSound()
        if ( self.glee_NextIdleCheck or 0 ) > CurTime() then return end
        self.glee_NextIdleCheck = CurTime() + idleHum.checkInterval

        if self:GetPos():DistToSqr( EyePos() ) > idleHum.hearDistSqr then
            self.glee_NextIdleCheck = CurTime() + idleHum.farCheckInterval
            self:StopIdleSound()
            return

        end

        local pitch = self:GetLookingAhead() and idleHum.pitch or idleHum.alertPitch

        local idle = self.glee_IdleSound
        if idle and idle:IsPlaying() then
            -- only on a change, each call starts the slide over
            if self.glee_IdlePitch ~= pitch then
                self.glee_IdlePitch = pitch
                idle:ChangePitch( pitch, idleHum.pitchChangeTime )

            end
            return

        end

        idle = CreateSound( self, idleHum.path )
        idle:SetSoundLevel( idleHum.level )
        idle:PlayEx( 1, pitch )
        self.glee_IdleSound = idle
        self.glee_IdlePitch = pitch

    end

    function ENT:StopFiringSounds()
        if not self.glee_FiringSounds then return end

        for _, firingSound in ipairs( self.glee_FiringSounds ) do
            firingSound:Stop()

        end
        self.glee_FiringSounds = nil
        self.glee_FiringVolume = nil

    end

    -- clientside like the idle hum
    -- a serverside loop only reaches whoever was in earshot when it started
    -- quieter is lower, the wind down sputtering out
    function ENT:UpdateFiringSounds()
        if ( self.glee_NextFiringCheck or 0 ) > CurTime() then return end
        self.glee_NextFiringCheck = CurTime() + thinkInterval

        local volume = self:GetFiringVolume()
        if volume <= 0 then
            self:StopFiringSounds()
            return

        end

        local pitch = Lerp( volume, windDownPitch, 100 )

        local firingSounds = self.glee_FiringSounds
        local playing = firingSounds and firingSounds[1]:IsPlaying() and firingSounds[2]:IsPlaying()
        if playing then
            if self.glee_FiringVolume == volume then return end
            self.glee_FiringVolume = volume

            for _, firingSound in ipairs( firingSounds ) do
                firingSound:ChangeVolume( volume, thinkInterval )
                firingSound:ChangePitch( pitch, thinkInterval )

            end
            return

        end

        self:StopFiringSounds()

        firingSounds = {}
        for index, name in ipairs( firingSoundNames ) do
            local firingSound = CreateSound( self, name )
            firingSound:PlayEx( volume, pitch )
            firingSounds[index] = firingSound

        end
        self.glee_FiringSounds = firingSounds
        self.glee_FiringVolume = volume

    end

    local function stopPlacingFlashlights()
        hook.Remove( "PreRender", "glee_heavyturret_placeflashlights" )

    end

    -- after interpolation, so it lands where the gun's drawn
    -- placed in Think, the light trails behind
    local function placeFlashlights()
        for turret in pairs( litTurrets ) do
            local gun = IsValid( turret ) and turret:GetGun()
            if not IsValid( gun ) or not IsValid( turret.glee_Flashlight ) then
                litTurrets[turret] = nil
                continue

            end

            local flashlight = turret.glee_Flashlight
            flashlight:SetPos( gun:LocalToWorld( flashlightOffset ) )
            flashlight:SetAngles( gun:GetAngles() )
            flashlight:Update()

        end

        if next( litTurrets ) then return end
        stopPlacingFlashlights()

    end

    -- only hooked while there's a lit turret
    local function markLit( turret )
        if not next( litTurrets ) then
            hook.Add( "PreRender", "glee_heavyturret_placeflashlights", placeFlashlights )

        end
        litTurrets[turret] = true

    end

    function ENT:UpdateFlashlight()
        if ( self.glee_NextLightCheck or 0 ) < CurTime() then
            self.glee_NextLightCheck = CurTime() + flashlightSettings.checkInterval
            self.glee_IsDark = render.ComputeLighting( self:GetPos(), vector_up ):Length() < flashlightSettings.darkLevel

        end

        if not self.glee_IsDark then
            self:RemoveFlashlight()
            return

        end

        if not IsValid( self.glee_Flashlight ) then
            local flashlight = ProjectedTexture()
            flashlight:SetTexture( "effects/flashlight/hard" )
            flashlight:SetNearZ( flashlightSettings.nearZ )
            flashlight:SetFarZ( maxFiringDist )
            flashlight:SetFOV( flashlightSettings.fov )
            flashlight:SetBrightness( 1 )
            self.glee_Flashlight = flashlight

            self:EmitFlashlightSwitch()

        end

        markLit( self ) -- every frame, an autorefresh empties it

    end

    -- quietly, without the switch's click, for the turret itself going away
    function ENT:RemoveFlashlight( quietly )
        if litTurrets[self] then
            litTurrets[self] = nil
            if not next( litTurrets ) then stopPlacingFlashlights() end

        end
        if not IsValid( self.glee_Flashlight ) then return end

        self.glee_Flashlight:Remove()
        self.glee_Flashlight = nil

        if quietly then return end
        self:EmitFlashlightSwitch()

    end

    function ENT:EmitFlashlightSwitch()
        local switchSound = flashlightSettings.switchSound
        self:EmitSound( switchSound.path, switchSound.level, 100, switchSound.volume )

    end


    -- its lights, loops and fire, Think starts them back up
    function ENT:StopClientEffects()
        self:RemoveFlashlight( true )
        self:StopIdleSound()
        self:StopFiringSounds()
        self:StopDamagedFire()

    end

    -- Think skips everything while it's dormant, so it can't be what turns these off
    hook.Add( "NotifyShouldTransmit", "glee_heavyturret_dormant", function( ent, shouldTransmit )
        if shouldTransmit then return end
        if ent:GetClass() ~= "glee_heavyturret" then return end

        ent:StopClientEffects()
        ent.glee_LastHitsTaken = nil -- hits taken out of view don't flare up coming back into it

    end )

    function ENT:OnRemove()
        self:StopClientEffects()

        if self.glee_SmokeEmitter then
            self.glee_SmokeEmitter:Finish()
            self.glee_SmokeEmitter = nil

        end

    end

    local function getTextureName( mat, param )
        local texture = mat:GetTexture( param )
        if not texture or texture:IsError() then return end

        return texture:GetName()

    end

    -- by original material name
    local matteNames = {}

    -- a copy of matName with just its textures, no envmap or phong, so it doesn't shine
    -- returns the name to SetSubMaterial, "!" and all
    local function getMatteName( matName )
        local matteName = matteNames[matName]
        if matteName then return matteName end

        local original = Material( matName )
        local createdName = "glee_heavyturret_matte_" .. string.gsub( matName, "[/\\]", "_" )
        CreateMaterial( createdName, "VertexLitGeneric", {
            ["$basetexture"] = getTextureName( original, "$basetexture" ),
            ["$bumpmap"] = getTextureName( original, "$bumpmap" ),
            ["$model"] = 1,
        } )

        matteName = "!" .. createdName
        matteNames[matName] = matteName

        return matteName

    end

    local function makeMatte( prop )
        for index, matName in ipairs( prop:GetMaterials() ) do
            prop:SetSubMaterial( index - 1, getMatteName( matName ) )

        end
    end

    hookMine.initialize = function( _, prop )
        makeMatte( prop )

    end
    hookMine.draw = function( _, prop, realTurret, flags )
        prop:SetPoseParameter( "blendstates", realTurret.glee_HooksBlend or mineHooks.open )
        prop:InvalidateBoneCache()
        prop:DrawModel( flags )

    end

    ENT.MyExtraModels = { hookMine, monitor }
    -- plus the gun, which is normally a separate entity, not an extra model
    ENT.HeldExtraModels = {
        hookMine,
        monitor,
        { model = ENT.GunModel, pos = gunLocalPos, ang = gunLocalAng },
    }

    function ENT:Initialize()
        terminator_Extras.AttachMyExtraModels( self, self.MyExtraModels )

    end

    function ENT:OnReloaded()
        terminator_Extras.AttachMyExtraModels( self, self.MyExtraModels )

    end

    -- the flare's brightest looking down the beam, the beam's brightest from the side
    function ENT:DrawFlashlightBeam( gun )
        local lightPos = gun:LocalToWorld( flashlightOffset )
        local forward = gun:GetForward()
        local facing = math.Clamp( -forward:Dot( ( lightPos - EyePos() ):GetNormalized() ), 0, 1 )

        local spriteBlocked = util.TraceLine( {
            start = EyePos(),
            endpos = lightPos,
            filter = { self, gun, LocalPlayer() },
        } ).Hit

        if facing > 0 and not spriteBlocked then
            local size = facing * flashlightSettings.spriteSize
            render.SetMaterial( flashlightSettings.spriteMat )
            render.DrawSprite( lightPos, size, size, Color( 255, 255, 255, 255 * facing ) )

        end

        local beamTr = util.TraceLine( {
            start = lightPos,
            endpos = lightPos + forward * flashlightSettings.beamLength,
            filter = { self, gun },
            mask = MASK_OPAQUE,
        } )
        -- the whole fade, even when it's cut short
        local beamColor = Color( 255, 255, 255, flashlightSettings.beamAlpha * ( 1 - facing ) )
        render.SetMaterial( flashlightSettings.beamMat )
        render.DrawBeam( lightPos, beamTr.HitPos, flashlightSettings.beamWidth, 0, 0.9, beamColor )

    end

    local laserMat = Material( "sprites/bluelaser1" )
    local glowMat = Material( "sprites/glow04_noz" )
    local laserColor = Color( 255, 0, 0 )
    local alertGlowColor = Color( 255, 100, 100 )
    local idleGlowColor = Color( 255, 255, 255 )

    -- not base_ai's, that draws the model a second time
    function ENT:DrawTranslucent()
        local gun = self:GetGun()
        if not IsValid( gun ) then return end

        local muzzle = gun:GetAttachment( muzzleAttachment )
        if not muzzle then return end

        if IsValid( self.glee_Flashlight ) then
            self:DrawFlashlightBeam( gun )

        end

        if isBlinkOn() and not glee_Carrying.IsCarried( self ) then
            render.SetMaterial( warningSpriteMat )
            render.DrawSprite( gun:LocalToWorld( warningSpriteOffset ), 30, 30, warningSpriteColor )

        end

        local hasTarget = self:GetHasTarget()
        if hasTarget then
            local tr = util.TraceLine( {
                start = muzzle.Pos,
                endpos = muzzle.Pos + gun:GetForward() * maxFiringDist,
                filter = { self, gun },
            } )
            render.SetMaterial( laserMat )
            render.DrawBeam( muzzle.Pos, tr.HitPos, 0.8, 0, 0, laserColor )

        end

        render.SetMaterial( glowMat )
        render.DrawSprite( gun:LocalToWorld( eyeOffset ), 2.7, 2.7, hasTarget and alertGlowColor or idleGlowColor )

    end

    return

end

-- HL2's attack chopper's gun
local gunTurnPerThink = 12 -- degrees, per axis
local chargeTime = 2 -- g_helicopter_chargetime
local idleTime = 3 -- g_helicopter_idletime
local burstCount = 12 -- sk_helicopter_burstcount, it fires between this and twice this many bursts
local roundsPerBurst = 5 -- sk_helicopter_roundsperburst
local chargeConeCos = math.cos( math.rad( 15 ) ) -- how close to the gun's aim a target has to be to charge
local firingCone = 6 -- degrees
local spread = math.sin( math.rad( firingCone * 0.5 ) )

local enemyDamage = 6 -- sk_npc_dmg_helicopter
local enemyDamageMul = 15
local allyDamage = 3 -- sk_npc_dmg_helicopter_to_plr, anything it wouldn't target, see onBulletHit

-- armoured like a floor turret, only the strongest hits hurt it
-- unlike one, it takes a few of them
local armour = {
    minDamage = 250, -- under this, a hit does nothing
    hitsToKill = 6,
    instakillDamage = 10000,
    -- seconds, after a hit through, before the next can land
    -- one blast's many pellets, or splashes, would otherwise take several hits at once
    hitCooldown = 0.1,
}

-- at half health or under, it falters, skipping bursts and turns, see ENT:FalterChance
local faltering = {
    healthFraction = 0.5,
    chance = 0.08,
    finalChance = 0.3, -- one hit from death
}
local maxHealth = armour.minDamage * armour.hitsToKill

-- terminator_nextbot's, off its armour
local ricochetSounds = {
    "weapons/fx/rics/ric3.wav",
    "weapons/fx/rics/ric5.wav",
}

-- a fifth of glee_bank_atm's, see its Die
local deathBlast = {
    damage = 300,
    radius = 70,
    shoveDamage = 5, -- a weak one, wider, it knocks things about
    shoveRadius = 150,
    effectScale = 0.4,
}
local maxAmmo = 2500
local targetSearchInterval = 0.5
local behindPriorityMul = 1.3 -- one right behind it counts as this much further away, less so the more it's in front

-- after it loses its target, it sweeps for it
local sweep = {
    delay = 0.5, -- held still this long first, there's often another target right away
    duration = 5, -- then it looks back ahead
    yaw = 60,
    yawRate = 1,
    pitch = 15,
    pitchRate = 0.5,
}
local pingInterval = 1
local quietRetargetTime = 3 -- a new target this soon after the last one makes no sound
local floorTurretSoundPitch = 70 -- its sounds, lower, it's bigger

-- tipped over like a floor turret, it gives up and cries, see ENT:IsSad
local sadUpDot = 0.5 -- npc_turret_floor's own tipped check, its up against the world's
-- the klaxon below, quieter, at its own pitch, restarted every loopDuration
local sadCry = { path = "ambient/alarms/klaxon1.wav", level = 65, pitch = 100, loopDuration = 2 }

-- under the retract, as it settles looking ahead
local settleSound = { path = "ambient/levels/canals/headcrab_canister_open1.wav", level = 68, pitch = 120 }

-- while it has a target, restarted every loop, sliding down from start to end pitch over it
local alarmKlaxon = { path = "ambient/alarms/klaxon1.wav", level = 80, startPitch = 100, endPitch = 70 }
-- the klaxon plays slower as its pitch drops
-- so a loop's as long as the sound lasts at the average pitch
-- at least a second, a klaxon of unknown length would restart every think
local averagePitch = ( alarmKlaxon.startPitch + alarmKlaxon.endPitch ) / 2
alarmKlaxon.loopDuration = math.max( SoundDuration( alarmKlaxon.path ) * 100 / averagePitch, 1 )

-- per burst
-- the kick throws the gun off its aim, the aim pulls it back next think
local recoil = {
    pitch = 0.8, -- degrees, up, at most
    yaw = 0.5, -- degrees, either way, at most
    push = 12, -- speed, on the base
    attachedNudge = 4, -- units, rotated back while it's attached, its weld pulls it home
}

-- per burst, a little longer than a think, so a burst's shakes run together
-- shakes in the air too, it can be mounted on a helicopter
local firingShake = {
    amplitude = 3, -- a full burst's, a wind down's sputters shake less
    frequency = 30,
    duration = 0.15,
    radius = 500,
}

local attachForceLimit = 100000 -- twice termhunt_weapon_hammer's nails

local TRACER_FLAG_WHIZ = 0x0001
local TRACER_FLAG_USEATTACHMENT = 0x0002
local tracerSpeed = 5000

local GUN_IDLE = 1
local GUN_CHARGING = 2
local GUN_FIRING = 3
local GUN_WINDING_DOWN = 4

-- its own parts, see ENT:Die, the gun's thrown from wherever it's aiming
local gibParts = { hookMine, monitor }
local gibThrowSpeed = 250
local gibLifetime = { 60, 90 } -- seconds, each its own

-- a kid's username, born 9 to 13 years ago, whatever year it is now
local function kidUsername( name )
    return function()
        return name .. ( os.date( "*t" ).year - math.random( 5, 13 ) )

    end
end

ENT.TurretNames = {
    "jerome",
    "joe",
    "frank",
    "big tim",
    "jimmy",
    "joe shmoe",
    "jane doe",
    "jemimah",
    "cheryl",
    "poppy",
    "timmy",
    "timmy 2",
    "charlotte",
    "fat",
    "burger tank",
    "pew pew pew",
    "nerf gun",
    "gary",
    "nicholas",
    "larry",
    "kyle",
    "sean",
    "linda",
    "karen",
    "nancy",
    "kimberly",
    "ruth",
    "dandylion",
    "squirt",
    "divot",
    "quarter",
    "penny",
    kidUsername( "damionbusby" ),
    "amazing",
    "pidgeon",
    "seagull",
    "starfish",
    "guppy",
    "hamster",
    "bethel",
    "orphaned kitten",
    "bellend",
    "blooming",
    "bollocks",
    "cobblers",
    "crikey",
    "git",
    "knobend",
    "knobhead",
    "knobber",
    "nutter",
    "pillock",
    "plonker",
    "prat",
    "swine",
    "tosser",
    kidUsername( "realbrandon" ),
    "newb",
    "noob",
    "glum",

    "):",
    ":(",
    "pls no kil",
    "the hi",
    kidUsername( "josegonzales" ),
    "do you want to be friends",
    "i am friendly :)",
    "123 for baby",
    "O_O",
    ":D",
    "bugger",
    "crumpet",
    "scallywag",
    "scoundrel",
    "lil` tony",
    ":steamhappy:",

    "betsy",
    "daisy",
    "nasty habit",
    "biscuits",
    "napkin",
    "pillow fight",
    "justaguy",
    "andy",
    "good company",
    "me hearty",
    "underdog",
    "beeschurger",
    "cindy",
    "hardly working",
    "tutter",
    "orbeez",
    "jellied eels",
    "mingebag",
    "knob",

    "french-frie",
    kidUsername( "juanjacques" ),
    kidUsername( "richardmobile" ),
    "essential oils",
    "metal stuff",
    "cough drop",

    "pls give score",
    "where free robux?",
    "grey gun verity",
    "lavender",
    "floppiDerekMeter30",
    "baby crab",
    "mark",
    "hi :)",
    "jamaltheunicorn552",
    "i am alive",

}

ENT.RareNameChance = 0.01
ENT.RareTurretNames = {
    "waltuh",
    "gus",
    "nacho",
    "23 orphans in a trenchcoat",
    "buttcheeks",
    "doodoo buttcheeks",
    "ricky pee pee",
    "popdog",
    "wallace",
    "gromit",
    "salty lip balm",
    "ricky pee -ee",
    kidUsername( "minecraft unblocked free download no virus " ),
    "thephonkmaster875",
    "iamtherich",
}

-- plus or minus 10%
local function withVariance( time )
    return math.Rand( time * 0.9, time * 1.1 )

end

function ENT:SpawnFunction( ply, tr, class )
    if not tr.Hit then return end

    local ent = ents.Create( class )
    ent:SetPos( tr.HitPos + tr.HitNormal * 10 )
    ent:SetAngles( Angle( 0, ply:EyeAngles().y, 180 ) )
    ent:Spawn()
    ent:Activate()

    return ent

end

function ENT:OnUseAction( ply, key )
    if key == "attach" then return self:Attach() end
    if key == "detach" then return self:Detach() end

    return glee_Turrets.OnUseAction( self, ply, key )

end

-- welds it to what's under it, see FindAttachGround
-- false if there's nothing to weld to
-- it can't be picked up until it's detached, or wrenched off past attachForceLimit
function ENT:Attach()
    local ground = self:FindAttachGround()
    if not ground then return false end

    local weld = constraint.Weld( self, ground.Entity, 0, ground.PhysicsBone, attachForceLimit, false )
    if not weld then return false end

    self.glee_AttachWeld = weld
    self:SetAttached( true )
    self:EmitSound( "NPC_CombineMine.CloseHooks" )

    weld:CallOnRemove( "glee_heavyturret_detach", function()
        if not IsValid( self ) then return end

        self:SetAttached( false )

        -- the weld goes with the turret, no hooks opening on a dead or removed one
        if self.glee_Dead or self:IsMarkedForDeletion() then return end
        self:EmitSound( "NPC_CombineMine.OpenHooks" )

    end )

    return true

end

function ENT:Detach()
    if not IsValid( self.glee_AttachWeld ) then return false end

    self.glee_AttachWeld:Remove()

    return true

end

function ENT:Initialize()
    self:SetModel( self.Model )

    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )

    self:CapabilitiesClear()
    self:SetNPCClass( CLASS_PLAYER_ALLY )
    -- npcs stop thinking when no player can see them, it'd ignore hunters out of everyone's view
    self:SetKeyValue( "spawnflags", SF_NPC_ALWAYSTHINK )

    self:SetMaxHealth( maxHealth )
    self:SetHealth( maxHealth )

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) then
        phys:Wake()
        phys:SetMass( 250 ) -- gravgun cannot pick up anything heavier
        phys:SetMaterial( "Canister" )

    end

    local gun = ents.Create( "prop_dynamic" )
    gun:SetModel( self.GunModel )
    gun:SetKeyValue( "solid", "0" )
    gun:SetPos( self:GetPos() )
    gun:Spawn()
    gun:SetParent( self )
    gun:SetLocalPos( gunLocalPos )
    gun:SetLocalAngles( gunLocalAng )
    self:DeleteOnRemove( gun )
    self:SetGun( gun )

    self.glee_GunState = GUN_IDLE
    self.glee_NextGunThink = 0
    self.glee_NextAttack = 0
    self.glee_NextTargetSearch = 0
    self.glee_IdleTimeDelay = 0
    self.glee_SearchStart = 0
    self.glee_SearchUntil = 0
    self.glee_NextPing = 0
    self.glee_LastHadTarget = -math.huge
    self:SetLookingAhead( true )

    self.glee_AlarmSound = CreateSound( self, alarmKlaxon.path )
    self.glee_AlarmSound:SetSoundLevel( alarmKlaxon.level )
    self.glee_NextAlarmLoop = 0

    self.glee_Sad = false
    self.glee_CrySound = CreateSound( self, sadCry.path )
    self.glee_CrySound:SetSoundLevel( sadCry.level )
    self.glee_NextCryLoop = 0

    glee_Turrets.MarkShopTurret( self, maxAmmo, self.TurretNames, self.RareTurretNames, self.RareNameChance )

end

-- base_ai's wanders
function ENT:SelectSchedule()
end

local goodDispositions = {
    [D_HT] = true,
    [D_FR] = true,
}

-- grigori, scary as a hunter
local function isEnemyPlayer( ply )
    if not ply.HasStatusEffect then return false end -- status effects are Hunter's Glee only

    return ply:Alive() and ply:HasStatusEffect( "divine_chosen" )

end

function ENT:IsValidTarget( ent )
    if ent == self then return false end
    if ent:IsFlagSet( FL_NOTARGET ) then return false end
    if ent:Health() <= 0 then return false end

    if ent:IsPlayer() then return isEnemyPlayer( ent ) end
    if not ent:IsNPC() then return false end -- hunters too, see terminator_nextbot_base's IsNPC hack

    return goodDispositions[self:Disposition( ent )] == true

end

function ENT:CanSeeTarget( ent, muzzlePos )
    local tr = util.TraceLine( {
        start = muzzlePos,
        endpos = ent:WorldSpaceCenter(),
        filter = { self, self:GetGun() },
        mask = MASK_SHOT,
    } )

    return not tr.Hit or tr.Entity == ent

end

-- distance, shrunk by how scary it is in the gamemode, so big threats come first
-- once the turret's nearly dead everything's about as scary, so it's just the nearest
-- and stretched by how far behind it they are, so it slightly prefers what's in front
function ENT:TargetPriority( ent, muzzlePos )
    local entPos = ent:WorldSpaceCenter()
    local facing = self:GetForward():Dot( ( entPos - muzzlePos ):GetNormalized() )
    local dist = muzzlePos:Distance( entPos ) * Lerp( ( 1 - facing ) / 2, 1, behindPriorityMul )
    if not GAMEMODE.GetBotScaryness then return dist end

    return dist / GAMEMODE:GetBotScaryness( self, ent ) -- 0 scaryness, silent stepping, is never picked

end

-- the best one it can see, see TargetPriority, nil if there's none
function ENT:FindTarget( muzzlePos )
    local best
    local bestPriority = math.huge

    for _, ent in ipairs( ents.FindInSphere( muzzlePos, maxFiringDist ) ) do
        if not self:IsValidTarget( ent ) then continue end

        local priority = self:TargetPriority( ent, muzzlePos )
        if priority >= bestPriority then continue end
        if not self:CanSeeTarget( ent, muzzlePos ) then continue end

        best = ent
        bestPriority = priority

    end

    return best

end

function ENT:UpdateTarget( gun, muzzlePos )
    local target = self.glee_Target

    local keepIt = IsValid( target )
        and self:IsValidTarget( target )
        and muzzlePos:DistToSqr( target:WorldSpaceCenter() ) <= maxFiringDist ^ 2
        and self:CanSeeTarget( target, muzzlePos )

    if not keepIt then
        target = nil
        -- straight after losing one, eg killing it
        if self:GetHasTarget() or self.glee_NextTargetSearch < CurTime() then
            self.glee_NextTargetSearch = CurTime() + targetSearchInterval
            target = self:FindTarget( muzzlePos )

        end
    end

    local hasTarget = IsValid( target )
    if hasTarget and target ~= self.glee_Target then
        if self.glee_LastHadTarget + quietRetargetTime < CurTime() then
            gun:EmitSound( "npc/turret_floor/active.wav", 75, floorTurretSoundPitch )

        end
        self.glee_SearchUntil = 0
        self:SetLookingAhead( false )

    elseif not hasTarget and self:GetHasTarget() then
        self.glee_SearchStart = CurTime() + sweep.delay
        self.glee_SearchUntil = self.glee_SearchStart + sweep.duration

    end

    if hasTarget then
        self.glee_LastHadTarget = CurTime()

    end

    self.glee_Target = target
    self:SetHasTarget( hasTarget )

end

-- per burst, and per turn
function ENT:FalterChance()
    if self:GetHitsTaken() >= armour.hitsToKill - 1 then return faltering.finalChance end
    if self:Health() <= self:GetMaxHealth() * faltering.healthFraction then return faltering.chance end

    return 0

end

function ENT:Falters()
    return math.random() < self:FalterChance()

end

-- off where the gun meets the base, its turning's what's broken
function ENT:FalterSpark( gun )
    local effect = EffectData()
    effect:SetOrigin( gun:GetPos() )
    effect:SetNormal( VectorRand():GetNormalized() )
    effect:SetMagnitude( 2 )
    effect:SetScale( 1 )
    effect:SetRadius( 3 )
    util.Effect( "Sparks", effect )

end

-- at most gunTurnPerThink on each axis, so it can be outrun
-- true while it's still turning, false once it's there
function ENT:AimGun( gun, desired )
    if self:Falters() then
        self:FalterSpark( gun )
        return true

    end

    local current = gun:GetAngles()
    local pitchDiff = math.AngleDifference( desired.p, current.p )
    local yawDiff = math.AngleDifference( desired.y, current.y )

    current.p = current.p + math.Clamp( pitchDiff, -gunTurnPerThink, gunTurnPerThink )
    current.y = current.y + math.Clamp( yawDiff, -gunTurnPerThink, gunTurnPerThink )
    current.r = 0

    gun:SetAngles( current )

    return math.abs( pitchDiff ) > 0.1 or math.abs( yawDiff ) > 0.1

end

-- without a target
-- sweeps for the one it lost, then goes back to looking where it faces
function ENT:IdleAim( gun )
    local ahead = self:GetForward():Angle()

    if self.glee_SearchUntil > CurTime() then
        if self.glee_SearchStart > CurTime() then return end

        local searchTime = CurTime() - self.glee_SearchStart
        ahead.p = ahead.p + math.sin( searchTime * sweep.pitchRate ) * sweep.pitch
        ahead.y = ahead.y + math.sin( searchTime * sweep.yawRate ) * sweep.yaw
        self:AimGun( gun, ahead )

        if self.glee_NextPing < CurTime() then
            self.glee_NextPing = CurTime() + pingInterval
            gun:EmitSound( "npc/turret_floor/ping.wav", 75, floorTurretSoundPitch )

        end
        return

    end

    if self:AimGun( gun, ahead ) or self:GetLookingAhead() then return end

    self:SetLookingAhead( true )
    gun:EmitSound( "npc/turret_floor/retract.wav", 75, floorTurretSoundPitch )
    gun:EmitSound( settleSound.path, settleSound.level, settleSound.pitch )

end

function ENT:IsOutOfAmmo()
    return glee_Turrets.GetAmmo( self ) <= 0

end

function ENT:IsGunOnTarget( gun, target )
    local toTarget = ( target:WorldSpaceCenter() - gun:GetPos() ):GetNormalized()
    return gun:GetForward():Dot( toTarget ) >= chargeConeCos

end

-- All the gun below ever asks of the targeting above
function ENT:IsAimedAtTarget( gun )
    local target = self.glee_Target
    return IsValid( target ) and self:IsGunOnTarget( gun, target )

end

function ENT:GunIdle( gun, aimed )
    if self.glee_NextAttack > CurTime() then return end
    if not aimed then return end
    if self:IsOutOfAmmo() then return end

    gun:EmitSound( chargeSoundName )
    self.glee_ChargedAt = CurTime() + withVariance( chargeTime )
    -- set once it's charged, stopped before then, there's no long burst to rest from
    self.glee_IdleTimeDelay = 0
    self.glee_GunState = GUN_CHARGING

end

function ENT:GunCharging()
    if self.glee_ChargedAt > CurTime() then return end

    self.glee_GunState = GUN_FIRING
    self.glee_RemainingBursts = math.random( burstCount, burstCount * 2 )
    self.glee_IdleTimeDelay = 0.1 * ( self.glee_RemainingBursts - burstCount )

end

-- an npc's tracers start at its origin, not where Src says, so they're drawn from the gun here
local function onBulletHit( turret, tr, dmgInfo )
    dmgInfo:SetInflictor( turret )

    local gun = turret:GetGun()
    if IsValid( gun ) then
        local tracer = EffectData()
        tracer:SetEntity( gun )
        tracer:SetAttachment( muzzleAttachment )
        tracer:SetStart( tr.StartPos )
        tracer:SetOrigin( tr.HitPos )
        tracer:SetScale( tracerSpeed )
        tracer:SetFlags( bit.bor( TRACER_FLAG_WHIZ, TRACER_FLAG_USEATTACHMENT ) )
        util.Effect( "HelicopterTracer", tracer )

    end

    local hit = tr.Entity
    if IsValid( hit ) and not turret:IsValidTarget( hit ) then
        dmgInfo:SetDamage( allyDamage )

    end
end

local isHuntersGlee = engine.ActiveGamemode() == "hunters_glee"

-- itself in Hunter's Glee
-- elsewhere, whoever last placed or spawned it, so its kills are theirs
function ENT:GetBulletAttacker()
    if isHuntersGlee then return self end

    local placer = self.glee_LastPlacer
    if IsValid( placer ) then return placer end

    local creator = self:GetCreator()
    if IsValid( creator ) then return creator end

    return self

end

-- where the gun faces, not quite at the target
function ENT:ShootBurst( gun, rounds )
    if self:Falters() then return end

    local kicked = gun:GetAngles()
    kicked.p = kicked.p - math.Rand( 0, recoil.pitch )
    kicked.y = kicked.y + math.Rand( -recoil.yaw, recoil.yaw )
    gun:SetAngles( kicked )

    local muzzle = gun:GetAttachment( muzzleAttachment )
    if not muzzle then return end

    local effect = EffectData()
    effect:SetEntity( gun )
    effect:SetAttachment( muzzleAttachment )
    effect:SetOrigin( muzzle.Pos )
    effect:SetAngles( muzzle.Ang )
    effect:SetScale( 1 )
    util.Effect( "ChopperMuzzleFlash", effect )

    local amplitude = firingShake.amplitude * rounds / roundsPerBurst
    util.ScreenShake( muzzle.Pos, amplitude, firingShake.frequency, firingShake.duration, firingShake.radius, true )

    self:FireBullets( {
        Attacker = self:GetBulletAttacker(),
        Inflictor = self,
        Num = rounds,
        Src = gun:WorldSpaceCenter(),
        Dir = gun:GetForward(),
        Spread = Vector( spread, spread, 0 ),
        Distance = 8192,
        Tracer = 0,
        AmmoType = "HelicopterGun",
        Damage = enemyDamage * enemyDamageMul,
        IgnoreEntity = gun,
        -- its first argument is the attacker, not always the turret, see GetBulletAttacker
        Callback = function( _attacker, tr, dmgInfo )
            onBulletHit( self, tr, dmgInfo )

        end,
    } )

    local phys = self:GetPhysicsObject()
    if not IsValid( phys ) then return end

    if self:GetAttached() then
        local ang = self:GetAngles()
        ang:RotateAroundAxis( gun:GetRight(), recoil.attachedNudge )
        self:SetAngles( ang )

        phys:Wake()

    end

    phys:ApplyForceOffset( -gun:GetForward() * phys:GetMass() * recoil.push, muzzle.Pos )

end

function ENT:GunFiring( gun, aimed )
    if self:IsOutOfAmmo() then
        self:StopFiring()
        return

    end

    -- winds down off target, rather than finishing the burst wherever it faces
    if not aimed then
        self.glee_GunState = GUN_WINDING_DOWN
        self.glee_WindDownStart = CurTime()
        self:GunWindingDown( gun, aimed )
        return

    end

    self:SetFiringVolume( 1 )
    self:ShootBurst( gun, roundsPerBurst )

    self.glee_RemainingBursts = self.glee_RemainingBursts - 1
    if self.glee_RemainingBursts > 0 then return end

    self:StopFiring()

end

-- off target with bursts left, it sputters out
-- firing less and less, lower and quieter
-- back on target before it's done, the burst picks back up
function ENT:GunWindingDown( gun, aimed )
    if self:IsOutOfAmmo() then
        self:StopFiring()
        return

    end

    if aimed then
        self.glee_GunState = GUN_FIRING
        self:GunFiring( gun, aimed )
        return

    end

    local left = 1 - ( CurTime() - self.glee_WindDownStart ) / sweep.delay
    if left <= 0 then
        self:SpunDown()
        return

    end

    self:SetFiringVolume( left )

    if math.random() > left then return end
    self:ShootBurst( gun, math.ceil( roundsPerBurst * left ) )

end

-- back to idle, and no charging again until its idle time's up
function ENT:StopFiring()
    if self.glee_GunState == GUN_IDLE then return end

    self:SetFiringVolume( 0 )
    self.glee_NextAttack = CurTime() + self.glee_IdleTimeDelay + withVariance( idleTime )
    self.glee_GunState = GUN_IDLE

end

-- sputtered out with bursts left
-- no idle time, it charges again the moment it's on a target
function ENT:SpunDown()
    self:SetFiringVolume( 0 )
    self.glee_NextAttack = CurTime()
    self.glee_GunState = GUN_IDLE

end

-- spin up when aimed, shoot while aimed, spin down when not
function ENT:UpdateGun( gun, aimed )
    local state = self.glee_GunState
    if state == GUN_IDLE then
        self:GunIdle( gun, aimed )

    elseif state == GUN_CHARGING then
        self:GunCharging()

    elseif state == GUN_FIRING then
        self:GunFiring( gun, aimed )

    else
        self:GunWindingDown( gun, aimed )

    end
end

function ENT:GunThink()
    local gun = self:GetGun()
    if not IsValid( gun ) then return end

    -- it'd be shooting from someone's back, or spraying from its side
    if glee_Carrying.IsCarried( self ) or self.glee_Sad then
        self:StopFiring()
        self.glee_Target = nil
        self:SetHasTarget( false )
        self.glee_SearchUntil = 0
        self:SetLookingAhead( true )
        return

    end

    local muzzle = gun:GetAttachment( muzzleAttachment )
    if not muzzle then return end

    self:UpdateTarget( gun, muzzle.Pos )

    local target = self.glee_Target
    if IsValid( target ) then
        self:AimGun( gun, ( target:WorldSpaceCenter() - gun:GetPos() ):Angle() )

    else
        self:IdleAim( gun )

    end

    self:UpdateGun( gun, self:IsAimedAtTarget( gun ) )

end

function ENT:Think()
    if self.glee_Dead then return end
    if self.glee_NextGunThink > CurTime() then return end
    self.glee_NextGunThink = CurTime() + thinkInterval

    self:UpdateSad()
    self:GunThink()
    self:UpdateAlarm()

end

-- tipped over and loose
-- welded or frozen, it's mounted, and can point any way it likes, eg under a helicopter
function ENT:IsSad()
    -- the model's upside down, see SpawnFunction, upright is its up facing the floor
    if -self:GetUp().z >= sadUpDot then return false end
    if constraint.FindConstraint( self, "Weld" ) then return false end

    local phys = self:GetPhysicsObject()
    if IsValid( phys ) and not phys:IsMotionEnabled() then return false end

    return true

end

-- FL_NOTARGET while it's sad, nothing bothers fighting it
function ENT:UpdateSad()
    local sad = not glee_Carrying.IsCarried( self ) and self:IsSad()
    local cry = self.glee_CrySound

    if sad ~= self.glee_Sad then
        self.glee_Sad = sad
        if sad then
            self:AddFlags( FL_NOTARGET )

        else
            self:RemoveFlags( FL_NOTARGET )
            cry:Stop()
            self.glee_NextCryLoop = 0

        end
    end

    if not sad then return end
    if self.glee_NextCryLoop > CurTime() then return end
    self.glee_NextCryLoop = CurTime() + sadCry.loopDuration

    cry:Stop()
    cry:PlayEx( 1, sadCry.pitch )

end

function ENT:UpdateAlarm()
    local alarm = self.glee_AlarmSound

    if not self:GetHasTarget() then
        alarm:Stop()
        self.glee_NextAlarmLoop = 0
        return

    end

    if self.glee_NextAlarmLoop > CurTime() then return end
    self.glee_NextAlarmLoop = CurTime() + alarmKlaxon.loopDuration

    alarm:Stop()
    alarm:PlayEx( 1, alarmKlaxon.startPitch )
    alarm:ChangePitch( alarmKlaxon.endPitch, alarmKlaxon.loopDuration )

end

function ENT:Die( dmgInfo )
    self.glee_Dead = true

    hook.Run( "OnNPCKilled", self, dmgInfo:GetAttacker(), dmgInfo:GetInflictor() )

    local pos = self:WorldSpaceCenter()

    local effect = EffectData()
    effect:SetOrigin( pos )
    effect:SetScale( 0.2 )
    util.Effect( "ManhackSparks", effect )

    sound.Play( "npc/turret_floor/die.wav", pos, 75 )
    sound.Play( "ambient/energy/spark" .. math.random( 1, 6 ) .. ".wav", pos, 75 )

    local attacker = self:GetBulletAttacker()
    terminator_Extras.GleeFancySplode( pos, deathBlast.damage, deathBlast.radius, attacker, self )
    terminator_Extras.GleeFancySplode( pos, deathBlast.shoveDamage, deathBlast.shoveRadius, attacker, self )

    -- damage hooks don't play effects, see glee_bank_atm's OnTakeDamage
    timer.Simple( 0, function()
        local splode = EffectData()
        splode:SetOrigin( pos )
        splode:SetScale( deathBlast.effectScale )
        splode:SetNormal( vector_up )
        util.Effect( "glee_huge_m9k_splode", splode )

    end )

    self:ThrowGib( self:GetModel(), self:GetPos(), self:GetAngles() )

    for _, part in ipairs( gibParts ) do
        self:ThrowGib( part.model, self:LocalToWorld( part.pos ), self:LocalToWorldAngles( part.ang ) )

    end

    local gun = self:GetGun()
    if IsValid( gun ) then
        self:ThrowGib( gun:GetModel(), gun:GetPos(), gun:GetAngles() )

    end

    SafeRemoveEntityDelayed( self, 0 )

end

function ENT:ThrowGib( model, pos, ang )
    local gib = ents.Create( "prop_physics" )
    gib:SetModel( model )
    gib:SetPos( pos )
    gib:SetAngles( ang )
    gib:SetCollisionGroup( COLLISION_GROUP_DEBRIS )
    gib:Spawn()
    SafeRemoveEntityDelayed( gib, math.Rand( gibLifetime[1], gibLifetime[2] ) )

    -- the gun's model has no physics of its own, it'd hang in the air
    local phys = gib:GetPhysicsObject()
    if not IsValid( phys ) then
        gib:PhysicsInitBox( gib:OBBMins(), gib:OBBMaxs(), "metal" )
        phys = gib:GetPhysicsObject()
        if not IsValid( phys ) then return end

        phys:Wake()

    end

    phys:SetVelocity( self:GetVelocity() + ( VectorRand() + vector_up ) * gibThrowSpeed )
    phys:AddAngleVelocity( VectorRand() * 360 )

end

-- Its own health, base_ai's OnTakeDamage leaves it alone
-- every hit through the armour takes the same chunk, however big, so it's always hitsToKill of them
function ENT:OnTakeDamage( dmgInfo )
    if self.glee_Dead then return end

    -- the armour stops the damage, not the push
    self:TakePhysicsDamage( dmgInfo )

    if dmgInfo:IsBulletDamage() then
        self:EmitSound( ricochetSounds[math.random( #ricochetSounds )], 75, math.random( 92, 100 ), 1, CHAN_STATIC )

    end

    local damage = dmgInfo:GetDamage()
    if damage >= armour.instakillDamage then
        self:Die( dmgInfo )
        return

    end
    if damage < armour.minDamage then return end
    if ( self.glee_NextHitTime or 0 ) > CurTime() then return end
    self.glee_NextHitTime = CurTime() + armour.hitCooldown

    self:SetHealth( self:Health() - armour.minDamage )
    self:SetHitsTaken( self:GetHitsTaken() + 1 )
    if self:Health() > 0 then return end

    self:Die( dmgInfo )

end

function ENT:OnRemove()
    if self.glee_AlarmSound then
        self.glee_AlarmSound:Stop()

    end
    if self.glee_CrySound then
        self.glee_CrySound:Stop()

    end
end
