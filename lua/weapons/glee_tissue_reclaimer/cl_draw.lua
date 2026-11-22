-- The Medical Tissue Reclaimer's drawing, included by shared.lua
-- drawn for everyone who can see it held, from the viewmodel in first person, the world model otherwise
-- the healing's beams, the loops and the projection's sounds, then SWEP:DrawBeams at the bottom, which ties it all together

local reclaimer = SWEP.Reclaimer
local CLASS = reclaimer.CLASS
local reviveReach = reclaimer.reviveReach
local pointOutRange = reclaimer.pointOutRange
local reclamationColor = reclaimer.reclamationColor
local brokeColor = reclaimer.brokeColor
local randomSpot = reclaimer.randomSpot
local spotPos = reclaimer.spotPos
local beamWidth = reclaimer.beamWidth
local rayWidth = reclaimer.rayWidth
local diffuseWidth = reclaimer.diffuseWidth
local beamLod = reclaimer.beamLod
local drawBeam = reclaimer.drawBeam
local beamUp = reclaimer.beamUp
local reachingDist = reclaimer.reachingDist
local pointerLength = reclaimer.pointerLength
local buildTime = reclaimer.buildTime
local centerBone = reclaimer.centerBone
local poseHologram = reclaimer.poseHologram
local getBonePos = reclaimer.getBonePos
local drawHologram = reclaimer.drawHologram
local reclaimBones = reclaimer.reclaimBones
local restoreHologram = reclaimer.restoreHologram

-- The healing's beams ---------------------------------------------------
-- held on whoever the kit's healing, see HealTarget
-- healing others is clean, every ray lands on them
-- healing yourself isn't, the kit has to turn its beams back on its own medic, and most of the material splashes on the floor

local healBeams = {
    fadeIn = 0.1, -- seconds
    fadeOut = 0.25,
    reaimInterval = 0.12, -- seconds between picking new bones and spill points for the rays
    rayCount = 4,
    otherStrength = 2.5, -- times the beams' usual widths, healing someone else pours far more material
    selfBend = 1, -- see drawBeam, the kit isn't built to point at its own medic
    spillCount = 4, -- a self heal's rays that miss, onto the floor around them
    spillRadiusMin = 24,
    spillRadiusMax = 64,
    spillTraceUp = Vector( 0, 0, 32 ),
    spillTraceDown = Vector( 0, 0, -96 ),
}

-- somewhere on the floor around pos, just under it, so a beam to it splashes there. nil when there's no floor
local function spillPoint( pos )
    local offset = VectorRand()
    offset.z = 0
    offset:Normalize()

    local from = pos + offset * math.Rand( healBeams.spillRadiusMin, healBeams.spillRadiusMax ) + healBeams.spillTraceUp
    local tr = util.TraceLine( { start = from, endpos = from + healBeams.spillTraceDown, mask = MASK_SOLID_BRUSHONLY } )
    if not tr.Hit or tr.StartSolid then return end

    return tr.HitPos - tr.HitNormal * 2

end

-- new spots for the rays healing others, new spill points healing yourself
local function reaimHealing( healing, isSelf )
    healing.nextReaim = CurTime() + healBeams.reaimInterval
    healing.raySpots = {}
    healing.spills = {}

    local healTarget = healing.healTarget
    if isSelf then
        for _ = 1, healBeams.spillCount do
            local spill = spillPoint( healTarget:GetPos() )
            if spill then
                table.insert( healing.spills, spill )

            end
        end
        return

    end

    for ray = 1, healBeams.rayCount do
        healing.raySpots[ray] = randomSpot( healTarget ) -- nil without any bones, and the list stays empty

    end
end

-- see drawBeam, one for each beam DrawHealing draws
local simpleHealBeam = {}
local otherHealBeam = {}
local otherHealRay = {}
local selfHealBeam = {}
local selfHealSpill = {}

-- from DrawBeams, fades in on someone new, and out for a moment after the healing stops
-- barrelDir, the way the beams leave the muzzle. simple, far away, see beamLod, just the main beam
function SWEP:DrawHealing( startPos, barrelDir, simple )
    local healTarget = self:GetHealTarget()
    local healing = self.glee_healing

    if IsValid( healTarget ) then
        if not healing or healing.healTarget ~= healTarget then
            healing = { healTarget = healTarget, alpha = 0, nextReaim = 0 }
            self.glee_healing = healing

        end
        healing.alpha = math.min( healing.alpha + FrameTime() / healBeams.fadeIn, 1 )

    elseif healing then
        healing.alpha = healing.alpha - FrameTime() / healBeams.fadeOut

    end

    if not healing then return end
    healTarget = healing.healTarget
    if healing.alpha <= 0 or not IsValid( healTarget ) then
        self.glee_healing = nil
        return

    end

    local isSelf = healTarget == self:GetOwner()
    local alpha = healing.alpha
    local chest = healTarget:WorldSpaceCenter()

    if simple then
        simpleHealBeam.startPos = startPos
        simpleHealBeam.startDir = barrelDir
        simpleHealBeam.endPos = chest
        simpleHealBeam.color = reclamationColor
        simpleHealBeam.width = isSelf and beamWidth or beamWidth * healBeams.otherStrength
        simpleHealBeam.tipAlpha = nil
        simpleHealBeam.alpha = alpha
        simpleHealBeam.bend = isSelf and healBeams.selfBend or nil
        simpleHealBeam.tipWidth = nil
        simpleHealBeam.simple = true
        drawBeam( simpleHealBeam )
        return

    end

    if healing.nextReaim <= CurTime() then
        reaimHealing( healing, isSelf )

    end

    local tips = self:ProngTips()
    local tipCount = math.max( #tips, 1 )

    if not isSelf then
        otherHealBeam.startPos = startPos
        otherHealBeam.startDir = barrelDir
        otherHealBeam.endPos = chest
        otherHealBeam.color = reclamationColor
        otherHealBeam.width = beamWidth * healBeams.otherStrength
        otherHealBeam.tipAlpha = nil
        otherHealBeam.alpha = alpha
        otherHealBeam.bend = nil
        otherHealBeam.tipWidth = diffuseWidth * healBeams.otherStrength
        otherHealBeam.simple = nil
        drawBeam( otherHealBeam )

        for ray, spot in ipairs( healing.raySpots ) do
            local rayEnd = spotPos( healTarget, spot )
            if rayEnd then
                otherHealRay.startPos = tips[( ray - 1 ) % tipCount + 1] or startPos
                otherHealRay.startDir = barrelDir
                otherHealRay.endPos = rayEnd
                otherHealRay.color = reclamationColor
                otherHealRay.width = rayWidth * healBeams.otherStrength
                otherHealRay.tipAlpha = nil
                otherHealRay.alpha = alpha
                otherHealRay.bend = nil
                otherHealRay.tipWidth = nil
                otherHealRay.simple = nil
                drawBeam( otherHealRay )

            end
        end
        return

    end

    -- out of the barrel, turned onto the medic, then hooking back onto them, the rest spill
    selfHealBeam.startPos = startPos
    selfHealBeam.startDir = barrelDir
    selfHealBeam.endPos = chest
    selfHealBeam.color = reclamationColor
    selfHealBeam.width = beamWidth
    selfHealBeam.tipAlpha = nil
    selfHealBeam.alpha = alpha
    selfHealBeam.bend = healBeams.selfBend
    selfHealBeam.tipWidth = nil
    selfHealBeam.simple = nil
    drawBeam( selfHealBeam )

    for spill, spillPos in ipairs( healing.spills ) do
        selfHealSpill.startPos = tips[( spill - 1 ) % tipCount + 1] or startPos
        selfHealSpill.startDir = barrelDir
        selfHealSpill.endPos = spillPos
        selfHealSpill.color = reclamationColor
        selfHealSpill.width = rayWidth
        selfHealSpill.tipAlpha = nil
        selfHealSpill.alpha = 0.5 * alpha
        selfHealSpill.bend = healBeams.selfBend
        selfHealSpill.tipWidth = nil
        selfHealSpill.simple = nil
        drawBeam( selfHealSpill )

    end
end


-- The loops -------------------------------------------------------------
-- while the kit's reviving, or healing, off the networked RevivingTarget and HealTarget
-- clientside like the heavy turret's, a serverside loop only reaches whoever was in earshot when it started
-- a loop nobody stops plays forever, so every way a kit can go quiet stops them:
-- nothing to do, going dormant, put away, its holder gone, removed. See the sweep below, ShutDown and OnRemove

local reviveLoops = {
    { path = "items/medcharge4.wav", level = 75, volume = 1 },
}
local healLoops = {
    { path = "items/medcharge4.wav", level = 70, volume = 0.7 },
    { path = "weapons/physcannon/hold_loop.wav", level = 70, volume = 0.6 },
}
local loopPitch = 100
local healSelfLoopPitch = 85 -- the kit straining, turned back on its medic
local loopPitchTime = 0.2 -- seconds sliding between pitches
local loopCheckInterval = 0.1

function SWEP:StopLoopSounds()
    if not self.glee_loopSounds then return end

    for _, loop in ipairs( self.glee_loopSounds ) do
        loop:Stop()

    end
    self.glee_loopSounds = nil
    self.glee_loopSet = nil
    self.glee_loopPitch = nil

end

-- which loops should be going, and at what pitch. nil when none should
function SWEP:WantedLoops()
    if self:IsDormant() then return end
    if self:IsReviving() then return reviveLoops, loopPitch end

    local healTarget = self:GetHealTarget()
    if not IsValid( healTarget ) then return end

    return healLoops, healTarget == self:GetOwner() and healSelfLoopPitch or loopPitch

end

-- restarted whenever one's not playing, the engine drops loops out from under us, stopsound and the like
function SWEP:UpdateLoopSounds()
    local loopSet, pitch = self:WantedLoops()
    if not loopSet then
        self:StopLoopSounds()
        return

    end

    local sounds = self.glee_loopSounds
    local playing = sounds ~= nil and self.glee_loopSet == loopSet
    for _, loop in ipairs( sounds or {} ) do
        if not loop:IsPlaying() then
            playing = false

        end
    end

    if playing then
        -- only on a change, each call starts the slide over
        if self.glee_loopPitch ~= pitch then
            self.glee_loopPitch = pitch
            for _, loop in ipairs( sounds ) do
                loop:ChangePitch( pitch, loopPitchTime )

            end
        end
        return

    end

    self:StopLoopSounds()

    sounds = {}
    for index, loopData in ipairs( loopSet ) do
        local loop = CreateSound( self, loopData.path )
        loop:SetSoundLevel( loopData.level )
        loop:PlayEx( loopData.volume, pitch )
        sounds[index] = loop

    end
    self.glee_loopSounds = sounds
    self.glee_loopSet = loopSet
    self.glee_loopPitch = pitch

end


-- The hologram's sounds -------------------------------------------------
-- from the projection, so the hum follows it around. Only a kit's projected one sounds, see UpdateProjected
-- driven by DrawBeams, a kit nobody's drawing has its hum stopped by the sweep below

local holoBuildSound = "buttons/combine_button5.wav" -- once, as it starts building from the feet
local holoUnprojectSound = "buttons/combine_button2.wav" -- once, as it goes, walked away from or swapped for someone nearer
local holoAimedSound = "buttons/combine_button1.wav" -- once, as it brightens, aimed close enough to revive
local holoHum = { path = "ambient/machines/combine_shield_loop3.wav", level = 60 } -- looped while it's projected and the beam reaches it
local holoOneShotLevel = 65
local humVolume = 0.3
local humVolumeAimed = 1 -- aimed close enough to revive, or being revived
local humPitch = 150
local humPitchRevived = 200 -- it climbs here from humPitch over the revive
local humStaleTime = 0.25 -- seconds without DrawBeams before the hum's stopped

local function playHoloSound( path, holo )
    if not IsValid( holo ) then return end
    sound.Play( path, holo:GetPos(), holoOneShotLevel )

end

function SWEP:StopHologramHum()
    if self.glee_holoHum then
        self.glee_holoHum:Stop()

    end
    self.glee_holoHum = nil

end

-- from DrawBeams, once a frame
-- holo is the projection when the beam reaches it, nil otherwise. aimed when it's bright, reviveFrac 0 to 1 while it's revived
function SWEP:UpdateHologramSounds( holo, aimed, reviveFrac )
    local frame = FrameNumber()
    if self.glee_holoSoundFrame == frame then return end -- drawn in more than one view
    self.glee_holoSoundFrame = frame
    self.glee_holoSoundTime = CurTime()

    -- off who's projected, not whether the beam reaches, so a wall flickering in the way doesn't restart them
    local projected = self.glee_projectedDead
    if projected ~= self.glee_holoSoundDead then
        if self.glee_holoSoundDead then
            playHoloSound( holoUnprojectSound, self.glee_hologram )

        end
        if projected then
            playHoloSound( holoBuildSound, self.glee_hologram )

        end
        self.glee_holoSoundDead = projected
        self.glee_holoSoundAimed = nil

    end

    if not holo then
        self:StopHologramHum()
        return

    end

    if aimed and not self.glee_holoSoundAimed then
        playHoloSound( holoAimedSound, holo )

    end
    self.glee_holoSoundAimed = aimed

    -- restarted whenever it's not playing, like the loops
    local hum = self.glee_holoHum
    if not hum or not hum:IsPlaying() then
        self:StopHologramHum()
        hum = CreateSound( holo, holoHum.path )
        hum:SetSoundLevel( holoHum.level )
        hum:PlayEx( 0, humPitch )
        self.glee_holoHum = hum

    end
    hum:ChangeVolume( aimed and humVolumeAimed or humVolume )
    hum:ChangePitch( Lerp( reviveFrac or 0, humPitch, humPitchRevived ) )

end

function SWEP:HologramHumStale()
    return CurTime() - ( self.glee_holoSoundTime or 0 ) > humStaleTime

end


-- kits with their loops going. An autorefresh empties it, they're back in on their next check
local soundingKits = {}
local checkedKits = {}
local nextLoopCheck = 0

-- only held kits get checked, so any that stop being held are stopped here, nobody else would
hook.Add( "Think", "glee_reclaimer_loopsounds", function()
    if nextLoopCheck > CurTime() then return end
    nextLoopCheck = CurTime() + loopCheckInterval

    table.Empty( checkedKits )
    for _, ply in player.Iterator() do
        local wep = ply:GetActiveWeapon()
        if not IsValid( wep ) or wep:GetClass() ~= CLASS then continue end

        wep:UpdateLoopSounds()
        if wep:HologramHumStale() then
            wep:StopHologramHum()

        end
        checkedKits[wep] = true
        soundingKits[wep] = ( wep.glee_loopSounds or wep.glee_holoHum ) and true or nil

    end

    for wep in pairs( soundingKits ) do
        if checkedKits[wep] then continue end

        soundingKits[wep] = nil
        if IsValid( wep ) then
            wep:StopLoopSounds()
            wep:StopHologramHum()

        end
    end
end )


-- Drawing it all --------------------------------------------------------

local revivingBright = 0.6 -- the projection while it's revived, under the 1 it brightens to when aimed

-- see HeldProjection and drawBeam, one for each DrawBeams draws
local heldAim = {}
local pointerBeam = {}
local projectionBeam = {}
local projectionRay = {}

-- every frame, for a kit held where we can see it
-- points out the dead, projects the nearest, and reclaims their corpse while it's revived
function SWEP:DrawBeams()
    local owner = self:GetOwner()
    if not IsValid( owner ) then return end -- the active weapon can network before its owner does

    -- this view's eyes, so spectators and reflections get their own. See beamLod
    -- a revive culled here catches its corpse up quietly when it's back in range, see reclaimBones
    local ownerPos = owner:GetPos()
    local eyeDistSqr = ownerPos:DistToSqr( EyePos() )
    if eyeDistSqr > beamLod.cullDist^2 then return end

    local simpleDist = beamLod.simpleDist + ( self.glee_simpleBeams and -beamLod.simpleSlack or beamLod.simpleSlack )
    local simple = eyeDistSqr > simpleDist^2
    self.glee_simpleBeams = simple

    local isMine = owner == LocalPlayer()

    -- other players' ammo isn't networked to us, so their beams are always full
    local color = reclamationColor
    if isMine and not self:CanAffordRevive() then
        color = brokeColor

    end

    -- the same trace PrimaryAttack revives from
    local aimPos
    if isMine then
        aimPos = self:TraceAim().HitPos

    end
    local aimedHealable = self:GetAimedHealable()

    local startPos, kitAng = self:BeamStart()
    if not startPos then return end

    local barrelDir = kitAng:Forward() -- the beams leave the muzzle along it
    local revivables = self:RevivablesByDistance()
    self:UpdateProjected( revivables[1], ownerPos )

    local projecting = false
    local reviveFrac
    local soundingHolo, holoAimed -- the projection, once the beam's reached it, see UpdateHologramSounds
    for index, data in ipairs( revivables ) do
        local dist = ownerPos:Distance( data.pos )
        if index > 1 and dist > pointOutRange then break end

        local holo = data.ply == self.glee_projectedDead and self:GetHologram( data.ply )
        heldAim.dead = data.ply
        heldAim.kitPos = startPos
        heldAim.kitAng = kitAng
        heldAim.goalPos = data.pos
        heldAim.goalAng = holo and self.glee_projectAng or nil
        heldAim.goalDir = barrelDir
        heldAim.body = holo or nil
        local beamStart, standPos, standAng, startDir, raySpots = self:HeldProjection( heldAim )

        if not holo then
            -- not who we're projecting, point them out
            local further = math.Clamp( ( dist - reachingDist ) / ( pointOutRange - reachingDist ), 0, 1 )
            local length = Lerp( further, reachingDist, pointerLength )

            pointerBeam.startPos = beamStart
            pointerBeam.startDir = startDir
            pointerBeam.endPos = beamStart + ( standPos + beamUp - beamStart ):GetNormalized() * length
            pointerBeam.color = color
            pointerBeam.width = beamWidth
            pointerBeam.tipAlpha = 0
            pointerBeam.alpha = nil
            pointerBeam.bend = nil
            pointerBeam.tipWidth = nil
            pointerBeam.simple = simple
            drawBeam( pointerBeam )
            continue

        end

        -- brightens when aimed close enough to revive, see FindRevivable
        -- dims again while they're revived, for everyone watching, the corpse snapping into it is the show
        local revivingThem = self:GetRevivingTarget() == data.ply
        local aimedAt = aimPos and aimPos:DistToSqr( data.pos ) < reviveReach^2
        local bright = 0.45
        if revivingThem then
            bright = revivingBright

        elseif aimedAt then
            bright = 1

        end
        local beamStrength = revivingThem and 2 or 1
        local built = math.Clamp( ( CurTime() - self.glee_projectStart ) / buildTime, 0, 1 )

        poseHologram( holo, standPos, standAng )
        local centerPos = getBonePos( holo, holo:LookupBone( centerBone ) ) or standPos + beamUp

        -- a wall in the way, nothing gets through to project
        projectionBeam.startPos = beamStart
        projectionBeam.startDir = startDir
        projectionBeam.endPos = centerPos
        projectionBeam.color = color
        projectionBeam.width = beamWidth * beamStrength
        projectionBeam.tipAlpha = built
        projectionBeam.alpha = nil
        projectionBeam.bend = nil
        projectionBeam.tipWidth = diffuseWidth * beamStrength
        projectionBeam.simple = simple
        if not drawBeam( projectionBeam ) then continue end

        projecting = true
        soundingHolo, holoAimed = holo, aimedAt or revivingThem
        local builtHeight = drawHologram( holo, standPos, standAng, color, built, bright )

        if revivingThem then
            reviveFrac = self:GetRevivingProgress()
            reclaimBones( self, data.ply, holo, reviveFrac, simple )

        else
            restoreHologram( holo )

        end

        -- picked on the last re-aim, none until the first since projecting started
        if simple or not raySpots then continue end

        -- from the prongs' tips, taking turns. Each lights up once the build reaches it
        local tips = self:ProngTips()
        local up = standAng:Up()
        for rayIndex, spot in ipairs( raySpots ) do
            local rayEnd = spotPos( holo, spot )
            if rayEnd and up:Dot( rayEnd - standPos ) <= builtHeight then
                projectionRay.startPos = tips[( rayIndex - 1 ) % math.max( #tips, 1 ) + 1] or beamStart
                projectionRay.startDir = startDir
                projectionRay.endPos = rayEnd
                projectionRay.color = color
                projectionRay.width = rayWidth * beamStrength
                projectionRay.tipAlpha = nil
                projectionRay.alpha = 0.5 * bright
                projectionRay.bend = nil
                projectionRay.tipWidth = nil
                projectionRay.simple = nil
                drawBeam( projectionRay )

            end
        end
    end

    self:DrawHealing( startPos, barrelDir, simple )
    self:UpdateProngs( projecting, reviveFrac, aimedHealable )
    self:UpdateHologramSounds( soundingHolo, holoAimed, reviveFrac )

end

-- every reclaimer this client knows of, added in SWEP:Initialize
-- so the hook below checks a couple of weapons a frame, not what every player is holding
-- pruned here, not in OnRemove, the client calls OnRemove on a full update without removing it
local existing = reclaimer.existing
for _, wep in ipairs( ents.FindByClass( CLASS ) ) do -- for autorefresh, these won't Initialize again
    existing[wep] = true

end

hook.Add( "PostDrawTranslucentRenderables", "glee_reclaimer_drawbeams", function( drawingDepth, drawingSkybox )
    if drawingDepth or drawingSkybox then return end

    for wep in pairs( existing ) do
        if not IsValid( wep ) then
            existing[wep] = nil
            continue

        end

        local owner = wep:GetOwner()
        if not IsValid( owner ) then continue end
        if not owner:IsPlayer() then continue end
        if owner:GetActiveWeapon() ~= wep then continue end
        if owner:IsDormant() then continue end
        if owner:Health() <= 0 then continue end

        wep:DrawBeams()

    end
end )
